import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/academics.dart';
import '../../models/attendance.dart';
import '../../providers/academics_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Student attendance marking. Offline-tolerant: when the network is down the
/// payload is queued locally and auto-synced later (pending-sync badge).
class MarkAttendanceScreen extends StatefulWidget {
  /// True when rendered as a HomeShell tab (no app bar).
  final bool embedded;
  const MarkAttendanceScreen({super.key, this.embedded = true});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime _date = DateTime.now();
  int? _classId;
  int? _sectionId;
  List<AttendanceMark> _marks = [];
  bool _loadingStudents = false;
  bool _saving = false;
  bool _alerting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
      context.read<AttendanceProvider>().init();
    });
  }

  Future<void> _loadStudents() async {
    if (_classId == null) return;
    setState(() => _loadingStudents = true);
    try {
      await context.read<StudentProvider>().load(
          classId: _classId, sectionId: _sectionId, status: 'active');
      final students = context.read<StudentProvider>().students;
      // Pre-fill with any already-saved records for this date.
      var existing = <int, Map<String, String>>{};
      try {
        final records = await context
            .read<AttendanceProvider>()
            .fetchStudentRecords(
                date: ymd(_date),
                classId: _classId,
                sectionId: _sectionId);
        for (final r in records) {
          final id = (r['student_id'] as num?)?.toInt();
          final st = r['status']?.toString();
          if (id != null && st != null) {
            existing[id] = {
              'status': st,
              'leave_type': r['leave_type']?.toString() ?? ''
            };
          }
        }
      } catch (_) {}
      final sorted = students.toList()
        ..sort((a, b) {
          final ra = a.rollNumber ?? 1 << 30;
          final rb = b.rollNumber ?? 1 << 30;
          final c = ra.compareTo(rb);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
      _marks = sorted
          .map((s) {
            final ex = existing[s.id];
            return AttendanceMark(
              studentId: s.id,
              rollNumber: s.rollNumber,
              name: s.name,
              status: ex?['status'] ?? 'present',
              leaveType: (ex?['leave_type'] ?? '').isEmpty
                  ? null
                  : ex!['leave_type'],
            );
          })
          .toList();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _save() async {
    if (_marks.isEmpty) return;
    setState(() => _saving = true);
    try {
      final res =
          await context.read<AttendanceProvider>().saveStudentAttendance({
        'date': ymd(_date),
        'class_id': _classId,
        'section_id': _sectionId,
        'records': _marks
            .map((m) => {
                  'student_id': m.studentId,
                  'status': m.status,
                  if (m.status == 'leave' && m.leaveType != null)
                    'leave_type': m.leaveType,
                })
            .toList(),
      });
      if (!mounted) return;
      if (res['offline'] == true) {
        showSnack(context,
            'No network - attendance saved on device, will sync automatically.');
      } else {
        showSnack(context, 'Attendance saved (${res['saved']} records).');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendAlerts() async {
    setState(() => _alerting = true);
    try {
      final queued = await context
          .read<AttendanceProvider>()
          .sendAbsentAlerts(ymd(_date));
      if (!mounted) return;
      showSnack(context, 'Absence alerts queued for $queued guardians.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _alerting = false);
    }
  }

  Future<void> _syncNow() async {
    final res = await context.read<AttendanceProvider>().syncPending();
    if (!mounted) return;
    showSnack(context,
        'Sync complete: ${res['synced']} sent, ${res['failed']} still pending.');
  }

  void _setAll(String status) {
    setState(() {
      for (final m in _marks) {
        m.status = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;
    final sections = _classId == null
        ? <Section>[]
        : classes
            .firstWhere((c) => c.id == _classId,
                orElse: () => const ClassInfo(id: 0, name: ''))
            .sections;
    final pending = context.watch<AttendanceProvider>().pendingCount;
    final syncing = context.watch<AttendanceProvider>().syncing;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : const SchoolAppBar(title: 'Mark Attendance'),
      body: Column(
        children: [
          if (pending > 0)
            InkWell(
              onTap: syncing ? null : _syncNow,
              child: Container(
                width: double.infinity,
                color: Colors.orange.shade100,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncing
                            ? 'Syncing...'
                            : '$pending attendance record(s) pending sync - tap to retry',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (syncing)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2)),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 1)),
                          );
                          if (d != null) {
                            setState(() => _date = d);
                            _loadStudents();
                          }
                        },
                        child: InputDecorator(
                          decoration: fieldDecoration('Date'),
                          child: Text(ymd(_date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _classId,
                        decoration: fieldDecoration('Class'),
                        items: classes
                            .map((c) => DropdownMenuItem<int?>(
                                value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _classId = v;
                            _sectionId = null;
                            _marks = [];
                          });
                          _loadStudents();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _sectionId,
                        decoration: fieldDecoration('Section'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('All')),
                          ...sections.map((s) => DropdownMenuItem<int?>(
                              value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _sectionId = v;
                            _marks = [];
                          });
                          _loadStudents();
                        },
                      ),
                    ),
                  ],
                ),
                if (_marks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                          onPressed: () => _setAll('present'),
                          child: const Text('All present')),
                      TextButton(
                          onPressed: () => _setAll('absent'),
                          child: const Text('All absent')),
                      const Spacer(),
                      TextButton.icon(
                        icon: _alerting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.sms, size: 16),
                        label: const Text('Send absence alerts'),
                        onPressed: _alerting ? null : _sendAlerts,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loadingStudents
                ? const LoadingView()
                : _marks.isEmpty
                    ? const EmptyState(
                        message:
                            'Select a class to load its students.')
                    : ListView.builder(
                        itemCount: _marks.length,
                        itemBuilder: (_, i) {
                          final m = _marks[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 3),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 34,
                                        child: Text(
                                          m.rollNumber?.toString() ??
                                              '${i + 1}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.navy),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(m.name,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w500)),
                                      ),
                                      _statusBtn(m, 'present', 'P',
                                          AppColors.success),
                                      const SizedBox(width: 6),
                                      _statusBtn(m, 'absent', 'A',
                                          AppColors.danger),
                                      const SizedBox(width: 6),
                                      _statusBtn(m, 'leave', 'L',
                                          Colors.orange),
                                    ],
                                  ),
                                  if (m.status == 'leave')
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 6, left: 34),
                                      child: Row(
                                        children: [
                                          _leaveChip(m, 'sick',
                                              'Sick Leave'),
                                          const SizedBox(width: 6),
                                          _leaveChip(m, 'casual',
                                              'Casual Leave'),
                                          const SizedBox(width: 6),
                                          _leaveChip(m, 'urgent',
                                              'Urgent Work'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_marks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Attendance'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _leaveChip(AttendanceMark m, String value, String label) {
    final selected = m.leaveType == value;
    return InkWell(
      onTap: () => setState(() => m.leaveType = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? Colors.orange : Colors.transparent,
          border: Border.all(color: Colors.orange, width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.orange)),
      ),
    );
  }

  Widget _statusBtn(
      AttendanceMark m, String value, String label, Color color) {
    final selected = m.status == value;
    return InkWell(
      onTap: () => setState(() => m.status = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
