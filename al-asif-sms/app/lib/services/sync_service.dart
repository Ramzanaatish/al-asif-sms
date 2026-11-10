import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_client.dart';
import 'backup_service.dart';
import 'local_db.dart';

/// Offline-first synchronisation engine.
///
/// Responsibilities:
///  * watch connectivity (connectivity_plus); auto-sync when back online,
///  * push queued write-ops to the REST API in FIFO order,
///  * translate local ids -> server ids in outgoing payloads (and back on pull),
///  * pull fresh master/operational data after pushing,
///  * expose sync state (isOnline / isSyncing / pendingCount) to the UI.
///
/// The full numbering + conflict protocol is documented in
/// lib/services/SYNC_PROTOCOL.md.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _c = BackendClient.instance;
  final _db = LocalDb.instance;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;
  bool _hasNetwork = true;
  bool _syncing = false;
  bool _rerun = false; // set when writes land mid-sync
  int _pending = 0;
  String? _lastSyncAt;
  String? _lastError;

  bool get isOnline => _hasNetwork;
  bool get isSyncing => _syncing;
  int get pendingCount => _pending;
  String? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    await _db.db; // open + seed
    await _migrateLegacyQueue();
    await BackupService.instance.init(); // daily auto-backup check
    await _refreshPending();
    try {
      final cur = await Connectivity().checkConnectivity();
      _hasNetwork = !cur.contains(ConnectivityResult.none);
    } catch (_) {
      _hasNetwork = true;
    }
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final up = !results.contains(ConnectivityResult.none);
      if (up && !_hasNetwork) {
        _hasNetwork = true;
        notifyListeners();
        // Auto-sync only once a server address is saved in Settings.
        // Without one the app would retry the unreachable default address
        // (10.0.2.2:8000) every minute, forever.
        if (BackendClient.instance.hasServerConfigured) {
          unawaited(syncNow());
        }
      } else if (!up && _hasNetwork) {
        _hasNetwork = false;
        notifyListeners();
      }
    });
    if (_hasNetwork && BackendClient.instance.hasServerConfigured) {
      unawaited(syncNow());
    }
  }

  /// One-time upgrade: the pre-offline app queued failed attendance saves in
  /// shared_preferences ('pending_attendance_queue') with SERVER ids.
  /// Move them into sync_queue as bulk ops flagged __ids_are_server so they
  /// push without id translation, mirror them into the local attendance
  /// table (translating server student ids to local), then clear the old queue.
  Future<void> _migrateLegacyQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pending_attendance_queue');
      if (raw == null) return;
      final list = (jsonDecode(raw) as List?) ?? const [];
      // server student id -> local student id
      final students = await _db.query('students');
      final byServer = <int, int>{};
      for (final s in students) {
        final sid = s['server_id'];
        if (sid != null) byServer[(sid as num).toInt()] = (s['id'] as num).toInt();
      }
      for (final item in list) {
        final payload =
            ((item as Map).cast<String, dynamic>())..remove('_queued_at');
        final date = payload['date']?.toString() ?? '';
        for (final r in (payload['records'] as List? ?? [])) {
          final rm = (r as Map).cast<String, dynamic>();
          final localSid = byServer[(rm['student_id'] as num?)?.toInt() ?? -1];
          if (localSid == null) continue;
          final status = rm['status']?.toString() ?? 'present';
          final existing = await _db.query('student_attendance',
              where: 'date = ? AND student_id = ? AND deleted = 0',
              whereArgs: [date, localSid],
              limit: 1);
          if (existing.isEmpty) {
            await _db.insert('student_attendance', {
              'date': date,
              'student_id': localSid,
              'status': status,
              'dirty': 0,
              'data': jsonEncode({
                'student_id': localSid,
                'status': status,
                'leave_type':
                    status == 'leave' ? rm['leave_type']?.toString() : null,
              }),
            });
          }
        }
        payload['__ids_are_server'] = true;
        await _db.enqueue('attendance_students', 'bulk', null, payload);
      }
      await prefs.remove('pending_attendance_queue');
    } catch (_) {
      // never block boot on a best-effort migration
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refreshPending() async {
    _pending = await _db.pendingCount();
    notifyListeners();
  }

  /// Called by repositories after they enqueue a write.
  Future<void> notifyDirty() async {
    await _refreshPending();
    // Every write counts toward the auto-backup threshold (fire-and-forget;
    // backups must never block the sync flow).
    unawaited(BackupService.instance.recordChange());
    if (_syncing) {
      _rerun = true; // the running sync picks this up before finishing
      return;
    }
    if (_hasNetwork) unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      do {
        _rerun = false;
        await _pushAll();
        await _pullAll();
      } while (_rerun && _hasNetwork);
      _lastSyncAt = DateTime.now().toIso8601String();
      await _db.setMeta('last_sync', _lastSyncAt!);
    } on NetworkException {
      _hasNetwork = false; // connectivity said up, server unreachable
      _scheduleRetry();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _syncing = false;
      await _refreshPending();
      notifyListeners();
    }
  }

  Timer? _retryTimer;

  /// Server unreachable while the radio is up (server restart, wrong URL,
  /// captive wifi): without this the app stayed 'offline' until restart,
  /// because the connectivity stream only fires on radio changes.
  void _scheduleRetry() {
    // No server address saved: nothing to retry against. Without this
    // guard the app retried the unreachable default address every minute.
    if (!BackendClient.instance.hasServerConfigured) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 60), () async {
      try {
        final cur = await Connectivity().checkConnectivity();
        if (cur.contains(ConnectivityResult.none)) return;
      } catch (_) {}
      _hasNetwork = true;
      notifyListeners();
      unawaited(syncNow());
    });
  }

  // ================================================================ PUSH

  /// Push queued ops FIFO. Repeats passes while progress is made so that an
  /// op whose dependency synced earlier in the same run can go through.
  /// If a full pass makes no progress, one mid-run pull is attempted: it
  /// links seeded master rows (classes, subjects, fee heads, …) to their
  /// server ids by natural key, unblocking dependent creates.
  Future<void> _pushAll() async {
    var guard = 0;
    var pulledMidRun = false;
    while (guard < 10) {
      guard++;
      final ops = await _db.pendingOps();
      if (ops.isEmpty) break;
      var progress = false;
      for (final op in ops) {
        final handled = await _pushOp(op);
        if (handled) progress = true;
      }
      if (progress) continue;
      if (pulledMidRun) break;
      pulledMidRun = true;
      await _pullAll();
    }
  }

  /// Returns true when the op is finished (dequeued), false when skipped
  /// this pass (e.g. a referenced row has no server id yet).
  Future<bool> _pushOp(Map<String, Object?> op) async {
    final qid = LocalDb.intOf(op['id']);
    final entity = LocalDb.strOf(op['entity']);
    final opp = LocalDb.strOf(op['op']);
    final localId = op['local_id'] == null
        ? null
        : LocalDb.intOf(op['local_id']);
    Map<String, dynamic> payload;
    try {
      payload =
          (jsonDecode(LocalDb.strOf(op['payload_json'])) as Map).cast<String, dynamic>();
    } catch (_) {
      payload = <String, dynamic>{};
    }
    try {
      switch (opp) {
        case 'create':
          return await _pushCreate(qid, entity, localId, payload);
        case 'update':
          return await _pushUpdate(qid, entity, localId, payload);
        case 'delete':
          return await _pushDelete(qid, entity, localId);
        case 'bulk':
          return await _pushBulk(qid, entity, payload);
        case 'action':
          return await _pushAction(qid, entity, payload);
        default:
          await _db.dequeue(qid); // unknown op: drop
          return true;
      }
    } on NetworkException {
      rethrow; // abort the whole sync run; retry later
    } on ApiException catch (e) {
      // Server-side validation failures should not block the queue forever.
      await _db.bumpAttempts(qid);
      if (e.statusCode == 404 || LocalDb.intOf(op['attempts']) >= 5) {
        // Gone on server, or persistently invalid. Never lose it silently:
        // keep the full payload in the audit log so it can be re-entered.
        await _db.audit('system', 'sync_dropped', entity, localId,
            'HTTP ${e.statusCode}: ${e.message} | op=$opp | payload=${jsonEncode(payload)}');
        await _db.dequeue(qid);
        return true;
      }
      return false;
    } catch (_) {
      await _db.bumpAttempts(qid);
      return false;
    }
  }

  // ---------------------------------------------------------- simple CRUD

  static const _createPath = {
    'students': '/api/students',
    'staff': '/api/staff',
    'staff_leaves': '/api/staff/leaves',
    'salaries': '/api/staff/salaries',
    'sections': '/api/academics/sections',
    'subjects': '/api/academics/subjects',
    'syllabus': '/api/academics/syllabus',
    'timetable': '/api/academics/timetable',
    'fee_heads': '/api/fees/heads',
    'expense_categories': '/api/expenses/categories',
    'expenses': '/api/expenses',
    'holidays': '/api/attendance/holidays',
    'exam_terms': '/api/exams/terms',
    'date_sheets': '/api/exams/datesheets',
    'notices': '/api/comms/notices',
    'complaints': '/api/comms/complaints',
  };

  static const _updatePath = {
    'students': '/api/students',
    'staff': '/api/staff',
    'syllabus': '/api/academics/syllabus',
    'complaints': '/api/comms/complaints',
  };

  /// entity -> local table (usually identical).
  static const _entityTable = {
    'students': 'students',
    'staff': 'staff',
    'staff_leaves': 'staff_leaves',
    'salaries': 'salaries',
    'sections': 'sections',
    'subjects': 'subjects',
    'syllabus': 'syllabus',
    'timetable': 'timetable',
    'fee_heads': 'fee_heads',
    'expense_categories': 'expense_categories',
    'expenses': 'expenses',
    'holidays': 'holidays',
    'exam_terms': 'exam_terms',
    'date_sheets': 'date_sheets',
    'notices': 'notices',
    'complaints': 'complaints',
    'fee_challans': 'fee_challans',
    'fee_receipts': 'fee_receipts',
  };

  /// payload field -> local table it references (for local->server translation).
  static const _refTables = {
    'class_id': 'classes',
    'section_id': 'sections',
    'subject_id': 'subjects',
    'student_id': 'students',
    'staff_id': 'staff',
    'teacher_id': 'staff',
    'term_id': 'exam_terms',
    'challan_id': 'fee_challans',
    'category_id': 'expense_categories',
  };

  /// Translate local ids in [payload] to server ids in place.
  /// Returns false if any referenced row has no server id yet (caller skips).
  Future<bool> _resolveRefs(Map<String, dynamic> payload) async {
    for (final e in _refTables.entries) {
      final field = e.key;
      final v = payload[field];
      if (v == null) continue;
      if (v is List) {
        final out = <int>[];
        for (final id in v) {
          final sid = await _serverIdOf(e.value, (id as num).toInt());
          if (sid == null) return false;
          out.add(sid);
        }
        payload[field] = out;
      } else if (v is num && v != 0) {
        final sid = await _serverIdOf(e.value, v.toInt());
        if (sid == null) return false;
        payload[field] = sid;
      }
    }
    return true;
  }

  Future<int?> _serverIdOf(String table, int localId) async {
    if (localId == 0) return null;
    final row = await _db.getById(table, localId);
    if (row == null) return null;
    final sid = row['server_id'];
    if (sid == null) return null;
    return (sid as num).toInt();
  }

  /// Fields the server always derives from the JWT; never send them.
  static const _serverDerived = {
    'issued_by',
    'received_by',
    'entered_by',
    'marked_by',
    'published_by',
    'decided_by',
    'paid_by',
    'created_by',
    'parent_user_id',
  };

  Future<bool> _pushCreate(int qid, String entity, int? localId,
      Map<String, dynamic> payload) async {
    final path = _createPath[entity];
    if (path == null || localId == null) {
      await _db.dequeue(qid);
      return true;
    }
    // Idempotency: a previous push may have succeeded before the ack.
    final row = await _db.getById(_entityTable[entity]!, localId);
    if (row != null && row['server_id'] != null) {
      await _db.dequeue(qid);
      return true;
    }
    payload.removeWhere((k, _) => _serverDerived.contains(k));
    if (!await _resolveRefs(payload)) return false; // dependency not synced yet
    dynamic res;
    try {
      res = await _c.post(path, body: payload);
    } on ApiException catch (e) {
      if (entity == 'students' &&
          e.statusCode == 400 &&
          payload.containsKey('admission_no')) {
        // Provisional admission_no collided: let the server assign one.
        payload.remove('admission_no');
        res = await _c.post(path, body: payload);
      } else {
        rethrow;
      }
    }
    final map = (res as Map).cast<String, dynamic>();
    final serverId = (map['id'] as num?)?.toInt();
    final patch = <String, Object?>{'dirty': 0, 'provisional': 0};
    if (serverId != null) patch['server_id'] = serverId;
    if (entity == 'students' && map['admission_no'] != null) {
      final ano = map['admission_no'].toString();
      patch['admission_no'] = ano;
      final data = Map<String, dynamic>.from(LocalDb.dataOf(row ?? {}))
        ..['id'] = localId
        ..['admission_no'] = ano;
      patch['data'] = jsonEncode(data);
    }
    await _db.updateById(_entityTable[entity]!, localId, patch);
    await _db.dequeue(qid);
    return true;
  }

  Future<bool> _pushUpdate(int qid, String entity, int? localId,
      Map<String, dynamic> payload) async {
    final base = _updatePath[entity];
    if (base == null || localId == null) {
      await _db.dequeue(qid);
      return true;
    }
    final table = _entityTable[entity]!;
    final row = await _db.getById(table, localId);
    final serverId = row?['server_id'];
    if (serverId == null) return false; // create not pushed yet; FIFO will get it
    payload.removeWhere((k, _) => _serverDerived.contains(k));
    if (!await _resolveRefs(payload)) return false;
    await _c.put('$base/${(serverId as num).toInt()}', body: payload);
    await _db.updateById(table, localId, {'dirty': 0});
    await _db.dequeue(qid);
    return true;
  }

  Future<bool> _pushDelete(int qid, String entity, int? localId) async {
    // Best effort: try the conventional REST path; a 404/405 just drops it.
    final base = _updatePath[entity] ?? _createPath[entity];
    if (base == null || localId == null) {
      await _db.dequeue(qid);
      return true;
    }
    final table = _entityTable[entity]!;
    final row = await _db.getById(table, localId);
    final serverId = row?['server_id'];
    if (serverId == null) {
      // Never reached the server: just forget it locally.
      final d = await _db.db;
      await d.delete(table, where: 'id = ?', whereArgs: [localId]);
      await _db.dequeue(qid);
      return true;
    }
    try {
      await _c.delete('$base/${(serverId as num).toInt()}');
    } on ApiException {
      // endpoint may not exist; treat as acknowledged
    }
    final d = await _db.db;
    await d.delete(table, where: 'id = ?', whereArgs: [localId]);
    await _db.dequeue(qid);
    return true;
  }

  // ---------------------------------------------------------- bulk + actions

  /// Bulk ops: attendance_students, attendance_staff, marks.
  Future<bool> _pushBulk(int qid, String entity, Map<String, dynamic> payload) async {
    final legacy = payload.remove('__ids_are_server') == true;
    if (entity == 'attendance_students' || entity == 'attendance_staff') {
      final records = (payload['records'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from((r as Map).cast<String, dynamic>()))
          .toList();
      if (!legacy) {
        for (final r in records) {
          final key = entity == 'attendance_students' ? 'student_id' : 'staff_id';
          final table = entity == 'attendance_students' ? 'students' : 'staff';
          final sid = await _serverIdOf(table, (r[key] as num).toInt());
          if (sid == null) return false;
          r[key] = sid;
        }
      }
      final path = entity == 'attendance_students'
          ? '/api/attendance/students'
          : '/api/attendance/staff';
      payload['records'] = records;
      await _c.post(path, body: payload);
      await _db.dequeue(qid);
      return true;
    }
    if (entity == 'marks') {
      final records = (payload['records'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from((r as Map).cast<String, dynamic>()))
          .toList();
      for (final r in records) {
        final sid = await _serverIdOf('students', (r['student_id'] as num).toInt());
        if (sid == null) return false;
        r['student_id'] = sid;
      }
      final body = Map<String, dynamic>.from(payload)..['records'] = records;
      if (!await _resolveRefs(body)) return false;
      await _c.post('/api/exams/marks', body: body);
      await _db.dequeue(qid);
      return true;
    }
    await _db.dequeue(qid);
    return true;
  }

  /// Action ops: challans_generate, fee_collect, student_mark_left,
  /// student_promote, leave_decision, syllabus_status, complaint_resolve,
  /// absent_alerts.
  Future<bool> _pushAction(int qid, String entity, Map<String, dynamic> payload) async {
    switch (entity) {
      case 'challans_generate':
        return await _pushGenerateChallans(qid, payload);
      case 'fee_collect':
        return await _pushCollect(qid, payload);
      case 'student_mark_left':
        return await _pushMarkLeft(qid, payload);
      case 'student_promote':
        return await _pushPromote(qid, payload);
      case 'leave_decision':
        return await _pushSimpleAction(
            qid, payload, 'leave_local_id', 'staff_leaves',
            (sid, p) => _c.put('/api/staff/leaves/$sid/decision',
                body: {'decision': p['decision']}));
      case 'syllabus_status':
        return await _pushSimpleAction(
            qid, payload, 'local_id', 'syllabus',
            (sid, p) => _c.put('/api/academics/syllabus/$sid',
                body: {'status': p['status']}));
      case 'complaint_resolve':
        return await _pushSimpleAction(
            qid, payload, 'local_id', 'complaints',
            (sid, p) => _c.put('/api/comms/complaints/$sid',
                body: {'status': p['status']}));
      case 'absent_alerts':
        await _c.post('/api/attendance/alerts/absent',
            body: {'date': payload['date']});
        await _db.dequeue(qid);
        return true;
      default:
        await _db.dequeue(qid);
        return true;
    }
  }

  Future<bool> _pushSimpleAction(
      int qid,
      Map<String, dynamic> payload,
      String idKey,
      String table,
      Future<dynamic> Function(int, Map<String, dynamic>) call) async {
    final localId = (payload[idKey] as num?)?.toInt();
    if (localId == null) {
      await _db.dequeue(qid);
      return true;
    }
    final sid = await _serverIdOf(table, localId);
    if (sid == null) return false;
    await call(sid, payload);
    await _db.updateById(table, localId, {'dirty': 0});
    await _db.dequeue(qid);
    return true;
  }

  Future<bool> _pushGenerateChallans(
      int qid, Map<String, dynamic> payload) async {
    final classLocal = (payload['class_id'] as num?)?.toInt() ?? 0;
    final classServer = await _serverIdOf('classes', classLocal);
    if (classServer == null) return false;
    final headIds = <int>[];
    for (final h in (payload['head_ids'] as List? ?? [])) {
      final sid = await _serverIdOf('fee_heads', (h as num).toInt());
      if (sid == null) return false;
      headIds.add(sid);
    }
    await _c.post('/api/fees/challans/generate', body: {
      'class_id': classServer,
      'month': payload['month'],
      'year': payload['year'],
      'head_ids': headIds,
    });
    // Reconcile: pull server challans for this month/year and match our
    // provisional rows by (student, month, year).
    await _reconcileChallans(
        month: (payload['month'] as num).toInt(),
        year: (payload['year'] as num).toInt());
    await _db.dequeue(qid);
    return true;
  }

  Future<void> _reconcileChallans(
      {required int month, required int year}) async {
    final res = await _c.get('/api/fees/challans', query: {
      'month': month.toString(),
      'year': year.toString(),
    });
    final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
    // server student id -> local student id
    final students = await _db.query('students');
    final stuByServer = <int, int>{};
    for (final s in students) {
      final sid = s['server_id'];
      if (sid != null) stuByServer[(sid as num).toInt()] = (s['id'] as num).toInt();
    }
    for (final c in list) {
      final sSid = (c['student_id'] as num?)?.toInt();
      final localStu = sSid == null ? null : stuByServer[sSid];
      if (localStu == null) continue;
      final rows = await _db.query('fee_challans',
          where: 'student_id = ? AND month = ? AND year = ? AND deleted = 0',
          whereArgs: [localStu, month, year]);
      if (rows.isEmpty) continue;
      final localId = (rows.first['id'] as num).toInt();
      await _db.updateById('fee_challans', localId, {
        'server_id': (c['id'] as num).toInt(),
        'challan_no': c['challan_no']?.toString(),
        'total_amount': (c['total_amount'] as num?)?.toDouble(),
        'discount': (c['discount'] as num?)?.toDouble(),
        'amount_paid': (c['amount_paid'] as num?)?.toDouble(),
        'status': c['status']?.toString(),
        'provisional': 0,
        'dirty': 0,
        'data': jsonEncode({...c, 'id': localId}),
      });
    }
  }

  Future<bool> _pushCollect(int qid, Map<String, dynamic> payload) async {
    final challanLocal = (payload['challan_local_id'] as num?)?.toInt();
    final receiptLocal = (payload['receipt_local_id'] as num?)?.toInt();
    if (challanLocal == null) {
      await _db.dequeue(qid);
      return true;
    }
    final challanServer = await _serverIdOf('fee_challans', challanLocal);
    if (challanServer == null) return false; // generate op runs first
    final res = await _c.post('/api/fees/challans/$challanServer/collect', body: {
      'amount': payload['amount'],
      'discount': payload['discount'] ?? 0,
      'payment_method': payload['payment_method'] ?? 'cash',
    });
    final map = (res as Map).cast<String, dynamic>();
    final srvChallan = (map['challan'] as Map).cast<String, dynamic>();
    final srvReceipt = (map['receipt'] as Map).cast<String, dynamic>();
    await _db.updateById('fee_challans', challanLocal, {
      'server_id': (srvChallan['id'] as num).toInt(),
      'total_amount': (srvChallan['total_amount'] as num?)?.toDouble(),
      'discount': (srvChallan['discount'] as num?)?.toDouble(),
      'amount_paid': (srvChallan['amount_paid'] as num?)?.toDouble(),
      'status': srvChallan['status']?.toString(),
      'provisional': 0,
      'dirty': 0,
      'data': jsonEncode({...srvChallan, 'id': challanLocal}),
    });
    if (receiptLocal != null) {
      // The collect response carries no receipt id; the server id is resolved
      // lazily on pull by matching receipt_no (_pullReceipts).
      await _db.updateById('fee_receipts', receiptLocal, {
        'receipt_no': srvReceipt['receipt_no']?.toString(),
        'provisional': 0,
        'dirty': 0,
      });
      // The collect response has no receipt id; match by receipt_no on next pull.
      final row = await _db.getById('fee_receipts', receiptLocal);
      if (row != null) {
        final data = Map<String, dynamic>.from(LocalDb.dataOf(row))
          ..['receipt_no'] = srvReceipt['receipt_no']?.toString();
        await _db.updateById('fee_receipts', receiptLocal,
            {'data': jsonEncode(data)});
      }
    }
    await _db.dequeue(qid);
    return true;
  }

  Future<bool> _pushMarkLeft(int qid, Map<String, dynamic> payload) async {    final localId = (payload['student_local_id'] as num?)?.toInt();
    if (localId == null) {
      await _db.dequeue(qid);
      return true;
    }
    final sid = await _serverIdOf('students', localId);
    if (sid == null) return false;
    final res = await _c.post('/api/students/$sid/mark-left', body: {
      'leaving_date': payload['leaving_date'],
      'reason': payload['reason'],
    });
    final map = (res as Map).cast<String, dynamic>();
    final srv = (map['student'] as Map).cast<String, dynamic>();
    final cert = (map['certificate'] as Map?)?.cast<String, dynamic>();
    final local = await _db.getById('students', localId) ?? {};
    final data = Map<String, dynamic>.from(LocalDb.dataOf(local))
      ..['status'] = srv['status']?.toString() ?? 'left'
      ..['leaving_date'] = payload['leaving_date']
      ..['leaving_reason'] = payload['reason'];
    if (cert?['certificate_no'] != null) {
      data['certificate_no'] = cert!['certificate_no'].toString();
    }
    await _db.updateById('students', localId, {
      'status': srv['status']?.toString() ?? 'left',
      'dirty': 0,
      'provisional': 0,
      'data': jsonEncode(data),
    });
    await _db.dequeue(qid);
    return true;
  }

  Future<bool> _pushPromote(int qid, Map<String, dynamic> payload) async {
    final fromServer = await _serverIdOf(
        'classes', (payload['from_class_id'] as num).toInt());
    final toServer = await _serverIdOf(
        'classes', (payload['to_class_id'] as num).toInt());
    if (fromServer == null || toServer == null) return false;
    final promoted = <int>[];
    for (final id in (payload['promoted_ids'] as List? ?? [])) {
      final sid = await _serverIdOf('students', (id as num).toInt());
      if (sid == null) return false;
      promoted.add(sid);
    }
    final retained = <int>[];
    for (final id in (payload['retained_ids'] as List? ?? [])) {
      final sid = await _serverIdOf('students', (id as num).toInt());
      if (sid == null) return false;
      retained.add(sid);
    }
    await _c.post('/api/students/promote', body: {
      'from_class_id': fromServer,
      'to_class_id': toServer,
      'promoted_ids': promoted,
      'retained_ids': retained,
      'session_id': payload['session_id'] ?? 0,
    });
    for (final id in (payload['promoted_ids'] as List? ?? [])) {
      await _db.updateById('students', (id as num).toInt(), {'dirty': 0});
    }
    await _db.dequeue(qid);
    return true;
  }

  // ================================================================ PULL

  /// Pull authoritative data after pushing. Local dirty rows always win.
  Future<void> _pullAll() async {
    var idMaps = await _buildIdMaps();
    await _pullClasses(idMaps);
    // Classes/sections may just have been linked to seeded rows; rebuild so
    // later filters translate against the fresh server->local maps.
    idMaps = await _buildIdMaps();
    await _pullSimpleList('/api/academics/subjects', 'subjects', idMaps,
        (j) => {'class_id': j['class_id'], 'name': j['name']},
        naturalKey: const ['class_id', 'name']);
    await _pullSimpleList('/api/fees/heads', 'fee_heads', idMaps,
        (j) => {'name': j['name'], 'class_id': j['class_id']},
        naturalKey: const ['name']);
    await _pullSimpleList('/api/expenses/categories', 'expense_categories',
        idMaps, (j) => {'name': j['name']},
        naturalKey: const ['name']);
    await _pullSimpleList('/api/exams/terms', 'exam_terms', idMaps,
        (j) => {'name': j['name'], 'term_type': j['term_type'], 'session_id': j['session_id']},
        naturalKey: const ['name']);
    await _pullSimpleList('/api/comms/notices', 'notices', idMaps,
        (j) => {'audience': j['audience'], 'created_at': j['created_at']?.toString()});
    await _pullSimpleList('/api/comms/complaints', 'complaints', idMaps,
        (j) => {'status': j['status'], 'parent_user_id': j['parent_user_id']});
    await _pullSimpleList('/api/staff/leaves', 'staff_leaves', idMaps,
        (j) => {'staff_id': j['staff_id'], 'status': j['status'], 'from_date': j['from_date']?.toString()});
    await _pullSimpleList('/api/exams/datesheets', 'date_sheets', idMaps,
        (j) => {'term_id': j['term_id'], 'class_id': j['class_id'], 'subject_id': j['subject_id'], 'exam_date': j['exam_date']?.toString()});
    await _pullStudents(idMaps);
    await _pullStaff(idMaps);
    await _pullHolidays();
    final now = DateTime.now();
    await _pullSimpleList('/api/staff/salaries', 'salaries', idMaps,
        (j) => {'staff_id': j['staff_id'], 'month': j['month'], 'year': j['year']},
        query: {'month': now.month.toString(), 'year': now.year.toString()});
    await _pullChallans(idMaps, now.month, now.year);
    await _pullReceipts(idMaps, now.month, now.year);
  }

  /// server_id -> local id maps, rebuilt per pull.
  Future<Map<String, Map<int, int>>> _buildIdMaps() async {
    final maps = <String, Map<int, int>>{};
    for (final t in [
      'students', 'staff', 'classes', 'sections', 'subjects', 'fee_heads',
      'expense_categories', 'exam_terms', 'fee_challans'
    ]) {
      final m = <int, int>{};
      for (final r in await _db.query(t)) {
        final sid = r['server_id'];
        if (sid != null) m[(sid as num).toInt()] = (r['id'] as num).toInt();
      }
      maps[t] = m;
    }
    return maps;
  }

  int? _localId(Map<String, Map<int, int>> maps, String table, Object? serverId) {
    if (serverId == null) return null;
    return maps[table]?[(serverId as num).toInt()];
  }

  Future<void> _pullClasses(Map<String, Map<int, int>> idMaps) async {
    final res = await _c.get('/api/academics/classes');
    final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
    for (final c in list) {
      final serverId = (c['id'] as num).toInt();
      final localId = await _upsertPulled('classes', serverId, {
        'name': c['name']?.toString(),
        'level_order': (c['level_order'] as num?)?.toInt(),
      }, Map<String, dynamic>.from(c), naturalKey: const ['name']);
      for (final s in (c['sections'] as List? ?? [])) {
        final sm = (s as Map).cast<String, dynamic>();
        final sServer = (sm['id'] as num).toInt();
        await _upsertPulled('sections', sServer, {
          'class_id': localId,
          'name': sm['name']?.toString(),
        }, {...sm, 'id': 0, 'class_id': localId},
            naturalKey: const ['class_id', 'name']);
      }
    }
  }

  Future<void> _pullSimpleList(
      String path,
      String table,
      Map<String, Map<int, int>> idMaps,
      Map<String, Object?> Function(Map<String, dynamic>) filters,
      {List<String> naturalKey = const [],
      Map<String, String>? query}) async {
    dynamic res;
    try {
      res = await _c.get(path, query: query);
    } on ApiException {
      return; // endpoint may not exist for this role; skip
    }
    final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
    for (final j in list) {
      final serverId = (j['id'] as num?)?.toInt();
      if (serverId == null) continue;
      final f = Map<String, Object?>.from(filters(j));
      // translate *_id filter fields from server ids to local ids
      for (final k in f.keys.toList()) {
        if (k.endsWith('_id') && f[k] != null) {
          final refTable = _refTables[k];
          final local = refTable == null
              ? null
              : _localId(idMaps, refTable, f[k]);
          if (f[k] != null && (f[k] as num).toInt() != 0 && local == null) {
            f[k] = null; // referenced row not synced yet; store null, keep data JSON
          } else {
            f[k] = local;
          }
        }
      }
      final data = Map<String, dynamic>.from(j);
      await _upsertPulled(table, serverId, f, data, naturalKey: naturalKey);
    }
  }

  Future<void> _pullStudents(Map<String, Map<int, int>> idMaps) async {
    dynamic res;
    try {
      res = await _c.get('/api/students', query: {'status': 'all'});
    } on ApiException {
      return;
    }
    final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
    for (final j in list) {
      final serverId = (j['id'] as num).toInt();
      final data = Map<String, dynamic>.from(j);
      final localClass = _localId(idMaps, 'classes', j['class_id']);
      final localSection = _localId(idMaps, 'sections', j['section_id']);
      await _upsertPulled('students', serverId, {
        'admission_no': j['admission_no']?.toString(),
        'roll_number': (j['roll_number'] as num?)?.toInt(),
        'name': j['name']?.toString(),
        'class_id': localClass,
        'section_id': localSection,
        'status': j['status']?.toString(),
      }, data);
    }
    await _syncAdmissionSeq();
  }

  /// Keep the local admission-number sequence ahead of anything pulled, so
  /// provisional numbers never collide with server-issued ones.
  Future<void> _syncAdmissionSeq() async {
    final year = DateTime.now().year;
    var maxSeq = 0;
    final rows = await _db.query('students',
        where: 'admission_no LIKE ?', whereArgs: ['AS-$year-%']);
    for (final r in rows) {
      final no = LocalDb.strOf(r['admission_no']);
      final seq = int.tryParse(no.split('-').last) ?? 0;
      if (seq > maxSeq) maxSeq = seq;
    }
    final cur = int.tryParse(await _db.getMeta('seq:admission_no:$year') ?? '0') ?? 0;
    if (maxSeq > cur) {
      await _db.setMeta('seq:admission_no:$year', maxSeq.toString());
    }
  }

  Future<void> _pullStaff(Map<String, Map<int, int>> idMaps) async {
    dynamic res;
    try {
      res = await _c.get('/api/staff', query: {'status': 'all'});
    } on ApiException {
      return;
    }
    final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
    for (final j in list) {
      final serverId = (j['id'] as num).toInt();
      await _upsertPulled('staff', serverId, {
        'name': j['name']?.toString(),
        'staff_type': j['staff_type']?.toString(),
        'status': j['status']?.toString(),
      }, Map<String, dynamic>.from(j));
    }
  }

  Future<void> _pullHolidays() async {
    final now = DateTime.now();
    for (final m in [now.month, now.month % 12 + 1]) {
      final y = m == 1 && now.month == 12 ? now.year + 1 : now.year;
      dynamic res;
      try {
        res = await _c.get('/api/attendance/holidays',
            query: {'month': m.toString(), 'year': y.toString()});
      } on ApiException {
        continue;
      }
      // Server expands ranges into individual day entries; store each day.
      final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
      for (final j in list) {
        final date = j['date']?.toString() ?? '';
        final rows = await _db.query('holidays',
            where: 'date = ? AND kind = ? AND deleted = 0',
            whereArgs: [date, j['kind']?.toString() ?? 'unexpected']);
        if (rows.isEmpty) {
          await _db.insert('holidays', {
            'server_id': null, // day-entries have no stable server id
            'date': date,
            'kind': j['kind']?.toString(),
            'data': jsonEncode({...j, 'id': 0}),
            'dirty': 0,
            'deleted': 0,
            'provisional': 0,
          });
        }
      }
    }
  }

  Future<void> _pullChallans(
      Map<String, Map<int, int>> idMaps, int month, int year) async {
    dynamic res;
    try {
      res = await _c.get('/api/fees/challans',
          query: {'month': month.toString(), 'year': year.toString()});
    } on ApiException {
      return;
    }
    final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
    for (final j in list) {
      final serverId = (j['id'] as num).toInt();
      final localStu = _localId(idMaps, 'students', j['student_id']);
      if (localStu == null) continue;
      final data = Map<String, dynamic>.from(j)..['student_id'] = localStu;
      await _upsertPulled('fee_challans', serverId, {
        'challan_no': j['challan_no']?.toString(),
        'student_id': localStu,
        'month': (j['month'] as num?)?.toInt(),
        'year': (j['year'] as num?)?.toInt(),
        'status': j['status']?.toString(),
      }, data);
    }
  }

  Future<void> _pullReceipts(
      Map<String, Map<int, int>> idMaps, int month, int year) async {
    dynamic res;
    try {
      res = await _c.get('/api/fees/receipts',
          query: {'month': month.toString(), 'year': year.toString()});
    } on ApiException {
      return;
    }
    final list = (res as List? ?? []).cast<Map>().map((e) => e.cast<String, dynamic>());
    // receipt -> server challan id -> local challan id
    final challanRows = await _db.query('fee_challans');
    final challanByServer = <int, int>{};
    for (final r in challanRows) {
      final sid = r['server_id'];
      if (sid != null) challanByServer[(sid as num).toInt()] = (r['id'] as num).toInt();
    }
    for (final j in list) {
      // _receipt_out has no receipt id; match by receipt_no.
      final rno = j['receipt_no']?.toString() ?? '';
      final existing = await _db.query('fee_receipts',
          where: 'receipt_no = ?', whereArgs: [rno], limit: 1);
      final data = Map<String, dynamic>.from(j);
      if (existing.isNotEmpty) {
        final lid = (existing.first['id'] as num).toInt();
        if (existing.first['dirty'] == 0) {
          await _db.updateById('fee_receipts', lid, {
            'provisional': 0,
            'dirty': 0,
            'data': jsonEncode({...data, 'receipt_no': rno}),
          });
        }
        continue;
      }
      await _db.insert('fee_receipts', {
        'server_id': null,
        'receipt_no': rno,
        'challan_id': null,
        'data': jsonEncode(data),
        'dirty': 0,
        'deleted': 0,
        'provisional': 0,
      });
    }
  }

  /// Insert or update a pulled row. Returns the local id.
  /// The stored `data` JSON always carries the LOCAL id (screens keep working
  /// with local ids); server ids live in the server_id column only.
  ///
  /// When no local row carries this server_id yet, [naturalKey] columns are
  /// used to link a seeded/offline-created row (server_id IS NULL) instead of
  /// inserting a duplicate — this is how bundled seed data joins the server's
  /// master records on first sync.
  Future<int> _upsertPulled(String table, int serverId,
      Map<String, Object?> filters, Map<String, dynamic> data,
      {List<String> naturalKey = const []}) async {
    final existing = await _db.getByServerId(table, serverId);
    if (existing != null) {
      final lid = (existing['id'] as num).toInt();
      if (existing['dirty'] == 0 && existing['deleted'] == 0) {
        final merged = Map<String, dynamic>.from(data)..['id'] = lid;
        await _db.updateById(
            table, lid, {...filters, 'dirty': 0, 'data': jsonEncode(merged)});
      }
      return lid;
    }
    if (naturalKey.isNotEmpty) {
      // Only link clean rows: a dirty offline-created row must keep its own
      // data and be pushed normally (it gets its server_id from the push).
      final where = <String>['server_id IS NULL', 'deleted = 0', 'dirty = 0'];
      final args = <Object?>[];
      for (final k in naturalKey) {
        where.add('$k = ?');
        args.add(filters[k]);
      }
      final match = await _db.query(table,
          where: where.join(' AND '), whereArgs: args, limit: 1);
      if (match.isNotEmpty) {
        final lid = (match.first['id'] as num).toInt();
        final merged = Map<String, dynamic>.from(data)..['id'] = lid;
        await _db.updateById(table, lid, {
          ...filters,
          'server_id': serverId,
          'dirty': 0,
          'provisional': 0,
          'data': jsonEncode(merged),
        });
        return lid;
      }
    }
    final lid = await _db.insert(table, {
      ...filters,
      'server_id': serverId,
      'dirty': 0,
      'deleted': 0,
      'provisional': 0,
      'data': jsonEncode({} as Map<String, dynamic>),
    });
    final merged = Map<String, dynamic>.from(data)..['id'] = lid;
    await _db.updateById(table, lid, {'data': jsonEncode(merged)});
    return lid;
  }
}
