import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/academics.dart';
import '../models/fee.dart';
import '../providers/auth_provider.dart';
import '../repositories/academics_repository.dart';
import '../repositories/fees_repository.dart';
import '../repositories/school_info_repository.dart';
import '../repositories/staff_repository.dart';
import '../repositories/teacher_assignments_repository.dart';
import '../services/backup_service.dart';
import '../services/backend_client.dart';
import '../services/csv_backup_service.dart';
import '../services/license_service.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';
import '../widgets/school_app_bar.dart';
import '../widgets/ui_helpers.dart';
import 'home_shell.dart';
import 'license_screen.dart';

/// Settings: manual backup, backup import/restore.
///
/// Note: there is deliberately NO app-open password lock in this app
/// (owner's explicit decision).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _checkingUpdate = false;
  bool? _pwLoginEnabled;
  String? _currentVersion;
  String? _updateMessage;
  String? _csvMessage;
  LicenseStatus? _licenseStatus;
  String? _deviceId;

  BackupService get _backups => BackupService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backups.refreshStatus();
      _loadPwSetting();
      _loadVersion();
      _loadLicense();
    });
  }

  Future<void> _loadLicense() async {
    final id = await LicenseService.instance.getDeviceId();
    await LicenseService.instance.load();
    if (mounted) {
      setState(() {
        _licenseStatus = LicenseService.instance.status;
        _deviceId = id;
      });
    }
  }

  String _licenseStatusText() {
    final s = _licenseStatus;
    if (s == null) return 'Loading...';
    if (!s.licensed) return 'Not activated';
    final days = s.daysLeft;
    if (days != null && days <= LicenseService.warningDays) {
      return 'Active — expiring soon ($days din reh gaye)';
    }
    return 'Active';
  }

  Future<void> _openLicense() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LicenseScreen(fromSettings: true),
      ),
    );
    await _loadLicense();
  }

  Future<void> _loadVersion() async {
    try {
      final v = await UpdateService.instance.currentVersion();
      if (mounted) setState(() => _currentVersion = v);
    } catch (_) {
      // Version label is informational; never block Settings on it.
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await UpdateService.instance.checkForUpdate();
      if (!mounted) return;
      if (info == null) {
        setState(() => _updateMessage =
            'Could not reach GitHub. Check the internet and try again.');
        return;
      }
      if (info.updateAvailable) {
        setState(() => _updateMessage =
            'New version ${info.latestVersion} is available '
            '(you have ${info.currentVersion}). Download it from the '
            'release page and install it over this version — your data stays.');
      } else {
        setState(() => _updateMessage =
            'You are on the latest version (${info.currentVersion}).');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updateMessage = 'Update check failed: $e');
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _loadPwSetting() async {
    final v =
        await context.read<AuthProvider>().isPasswordLoginEnabled();
    if (mounted) setState(() => _pwLoginEnabled = v);
  }

  Future<void> _togglePwLogin(bool v) async {
    setState(() => _pwLoginEnabled = v);
    await context.read<AuthProvider>().setPasswordLoginEnabled(v);
    if (!mounted) return;
    showSnack(context,
        v ? 'Password login ON. App will ask for login next time.'
            : 'Password login OFF. App opens directly.');
  }

  Future<void> _changePassword() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                  labelText: 'Username (principal / teacher)'),
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final username = userCtrl.text.trim();
    final np = passCtrl.text;
    if (username.isEmpty || np.isEmpty) {
      showSnack(context, 'Enter username and new password.', error: true);
      return;
    }
    try {
      await context
          .read<AuthProvider>()
          .changePassword(username, np);
      if (mounted) showSnack(context, 'Password changed.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      final path = await _backups.backupNow();
      if (!mounted) return;
      showSnack(context, 'Backup saved.');
      debugPrint('Backup: $path');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------ HTML popups
  // The HTML's Settings popups (School Info & Login, Class Monthly Fee,
  // Teacher Assignments, Student Charges, Server Sync). Each opens a
  // dialog that reads/writes the same meta keys the rest of the app
  // uses, so the popups and the screens stay in sync.

  Future<void> _openSchoolInfo() async {
    final repo = SchoolInfoRepository();
    final info = await repo.get();
    if (!mounted) return;
    final emis = TextEditingController(text: info.emis);
    final tehsil = TextEditingController(text: info.tehsil);
    final address = TextEditingController(text: info.address);
    final pass = TextEditingController();
    var type = info.type;
    var shift = info.shift;
    var showSign = info.showPrincipalSign;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('School Info & Login'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: emis,
                    decoration: const InputDecoration(
                        labelText: 'School EMIS / College Code')),
                TextField(
                    controller: tehsil,
                    decoration:
                        const InputDecoration(labelText: 'Tehsil')),
                TextField(
                    controller: address,
                    decoration: const InputDecoration(
                        labelText: 'School / College Address')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const ['Govt', 'Private', 'Semi Private', 'Community']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDlg(() => type = v ?? type),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: shift,
                  decoration: const InputDecoration(labelText: 'Shift'),
                  items: const ['Morning', 'Evening']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDlg(() => shift = v ?? shift),
                ),
                CheckboxListTile(
                  title: const Text(
                      'Reports mein principal ke sign aur stamp dikhayein'),
                  value: showSign,
                  onChanged: (v) => setDlg(() => showSign = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                TextField(
                  controller: pass,
                  decoration: const InputDecoration(
                      labelText:
                          'New principal password (khali chhodein to na badle)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Save School Info')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await repo.save(SchoolInfo(
      emis: emis.text.trim(),
      address: address.text.trim(),
      tehsil: tehsil.text.trim(),
      type: type,
      shift: shift,
      showPrincipalSign: showSign,
    ));
    final np = pass.text.trim();
    if (np.isNotEmpty) {
      try {
        await context.read<AuthProvider>().changePassword('principal', np);
      } catch (e) {
        if (mounted) showSnack(context, e.toString(), error: true);
        return;
      }
    }
    if (mounted) showSnack(context, 'School info saved.');
  }

  Future<void> _openClassFees() async {
    final classes = await AcademicsRepository().classes();
    final feesRepo = FeesRepository();
    final saved = await feesRepo.classFees();
    if (!mounted) return;
    final ctrls = <int, TextEditingController>{};
    for (final c in classes) {
      ctrls[c.id] = TextEditingController(
          text: '${(saved[c.id] ?? 800).toStringAsFixed(0)}');
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Class Monthly Fee'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: classes
                  .map((cl) => Row(
                        children: [
                          Expanded(child: Text(cl.name)),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: ctrls[cl.id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  prefixText: 'Rs '),
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    for (final cl in classes) {
      final v = double.tryParse(ctrls[cl.id]?.text.trim() ?? '');
      if (v != null && v >= 0) await feesRepo.setClassFee(cl.id, v);
    }
    if (mounted) showSnack(context, 'Class fees saved.');
  }

  Future<void> _openAssignments() async {
    final repo = TeacherAssignmentsRepository();
    final staff = await StaffRepository().list(status: 'active');
    final teachers =
        staff.where((s) => s.staffType == 'teaching').map((s) => s.name).toList();
    final classes = await AcademicsRepository().classes();
    final classRows = await repo.classAssignments();
    final subjectRows = await repo.subjectAssignments();
    if (!mounted) return;
    // Current class teacher per class (fixed mapping wins, else saved).
    final classTeacher = <int, String?>{};
    for (final cl in classes) {
      final saved = classRows
          .where((r) => (r['class_id'] as num?)?.toInt() == cl.id)
          .firstOrNull;
      classTeacher[cl.id] =
          saved?['teacher']?.toString() ?? AppConfig.classTeacher(cl.name);
    }
    // Current subject teacher per (class, subject).
    final subjectTeacher = <String, String?>{};
    final subjectsByClass = <int, List<Subject>>{};
    for (final cl in classes) {
      final subjects =
          await AcademicsRepository().subjectsForClass(cl.id);
      subjectsByClass[cl.id] = subjects;
      for (final s in subjects) {
        final key = '${cl.id}|${s.name}';
        final saved = subjectRows
            .where((r) =>
                (r['class_id'] as num?)?.toInt() == cl.id &&
                r['subject'] == s.name)
            .firstOrNull;
        subjectTeacher[key] = saved?['teacher']?.toString();
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Teacher Assignments'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Class teachers',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final cl in classes)
                    Row(
                      children: [
                        Expanded(child: Text(cl.name)),
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            value: classTeacher[cl.id],
                            isExpanded: true,
                            items: teachers
                                .map((t) => DropdownMenuItem(
                                    value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) =>
                                setDlg(() => classTeacher[cl.id] = v),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Text('Subject teachers',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final cl in classes)
                    for (final s in (subjectsByClass[cl.id] ?? const []))
                      Row(
                        children: [
                          Expanded(
                              child: Text('${cl.name} — ${s.name}')),
                          SizedBox(
                            width: 170,
                            child: DropdownButtonFormField<String>(
                              value: subjectTeacher['${cl.id}|${s.name}'],
                              isExpanded: true,
                              hint: const Text('All teachers'),
                              items: teachers
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) => setDlg(() =>
                                  subjectTeacher['${cl.id}|${s.name}'] = v),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await repo.setClassAssignments([
      for (final cl in classes)
        if (classTeacher[cl.id] != null)
          {'teacher': classTeacher[cl.id]!, 'class_id': cl.id},
    ]);
    await repo.setSubjectAssignments([
      for (final e in subjectTeacher.entries)
        if (e.value != null)
          {
            'teacher': e.value!,
            'class_id': int.parse(e.key.split('|').first),
            'subject': e.key.split('|').last,
          },
    ]);
    if (mounted) showSnack(context, 'Teacher assignments saved.');
  }

  Future<void> _openCharges() async {
    final feesRepo = FeesRepository();
    final classes = await AcademicsRepository().classes();
    if (!mounted) return;
    final name = TextEditingController();
    final amount = TextEditingController();
    var chargeClass = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Student Charges'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder(
                    future: feesRepo.charges(),
                    builder: (c, snap) {
                      final list = snap.data ?? [];
                      return Column(
                        children: list
                            .map((ch) {
                              final className = ch.classId == null
                                  ? 'All classes'
                                  : classes
                                          .where((cl) => cl.id == ch.classId)
                                          .firstOrNull
                                          ?.name ??
                                      'Class ${ch.classId}';
                              return ListTile(
                                title: Text(ch.name),
                                subtitle: Text(
                                    'Rs ${ch.amount.toStringAsFixed(0)} · $className'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: AppColors.danger),
                                  onPressed: () async {
                                    await feesRepo.deleteCharge(ch.name);
                                    setDlg(() {});
                                  },
                                ),
                              );
                            })
                            .toList(),
                      );
                    },
                  ),
                  const Divider(),
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Charge name')),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Amount', prefixText: 'Rs '),
                  ),
                  DropdownButtonFormField<int>(
                    value: chargeClass,
                    decoration:
                        const InputDecoration(labelText: 'Class'),
                    items: [
                      const DropdownMenuItem(
                          value: 0, child: Text('All classes')),
                      ...classes.map((cl) => DropdownMenuItem(
                          value: cl.id, child: Text(cl.name))),
                    ],
                    onChanged: (v) =>
                        setDlg(() => chargeClass = v ?? 0),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final amt =
                          double.tryParse(amount.text.trim());
                      if (name.text.trim().isEmpty || amt == null) {
                        showSnack(context,
                            'Charge name aur amount zaroori hain.',
                            error: true);
                        return;
                      }
                      await feesRepo.addCharge(StudentCharge(
                        name: name.text.trim(),
                        amount: amt,
                        classId: chargeClass == 0 ? null : chargeClass,
                      ));
                      name.clear();
                      amount.clear();
                      setDlg(() {});
                    },
                    child: const Text('Add Charge'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Done')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) showSnack(context, 'Charges updated.');
  }

  Future<void> _openSync() async {
    final urlCtrl =
        TextEditingController(text: BackendClient.instance.baseUrl);
    final sync = SyncService.instance;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Server Sync'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PC server se live sync — APK aur software ka data aik jaisa rahe. PC on ho aur sab aik hi WiFi par hon.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                    labelText: 'Server URL (e.g. http://192.168.1.50:8000)'),
              ),
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: sync,
                builder: (c, _) => Text(
                  sync.isSyncing
                      ? 'Syncing...'
                      : 'Pending changes: ${sync.pendingCount}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                await BackendClient.instance.setBaseUrl(urlCtrl.text);
                await sync.syncNow();
                setDlg(() {});
                if (context.mounted) {
                  showSnack(context, 'Sync started.');
                }
              },
              child: const Text('Save & Sync now'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) showSnack(context, 'Server URL saved.');
  }

  Future<void> _resetDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset demo data?'),
        content: const Text(
          'Aapki changes delete ho jayengi aur app dobara seed data (217 students, classes, fee heads) se shuru hoga. Login, license aur server URL waisay hi rahenge.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await LocalDb.instance.resetDemoData();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  Future<void> _importBackup() async {
    setState(() => _busy = true);
    try {
      final info = await _backups.pickAndValidate();
      if (!mounted) return;
      if (info == null) return; // user cancelled
      final confirmed = await _confirmRestore(info);
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      await _backups.restore(info);
      if (!mounted) return;
      showSnack(context, 'Backup restored successfully.');
      // Rebuild the shell so every screen reloads from the restored DB.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } on BackupValidationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final path = await CsvBackupService.instance.exportCsvBackup();
      if (!mounted) return;
      if (path == null) return; // user cancelled
      setState(() => _csvMessage = 'CSV backup saved.');
      debugPrint('CSV backup: $path');
    } catch (e) {
      if (mounted) {
        setState(() => _csvMessage = 'CSV export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importCsv() async {
    setState(() => _busy = true);
    try {
      final path = await CsvBackupService.instance.pickCsvBackupFile();
      if (!mounted) return;
      if (path == null) return; // user cancelled
      final summary =
          await CsvBackupService.instance.validateCsvBackup(path);
      if (!mounted) return;
      final confirmed = await _confirmCsvImport(summary);
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      final done =
          await CsvBackupService.instance.importCsvBackupFile(path);
      if (!mounted) return;
      setState(() => _csvMessage = 'CSV backup imported: $done');
      showSnack(context, 'CSV backup imported: $done');
      // Rebuild the shell so every screen reloads from the imported data.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } on CsvBackupException catch (e) {
      if (mounted) setState(() => _csvMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _csvMessage = 'CSV import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmCsvImport(CsvBackupSummary summary) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Import CSV backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Tables: ${summary.tableCount} · Rows: ${summary.rowCount}'),
            const SizedBox(height: 12),
            const Text(
              'All current data in these tables will be replaced by the CSV file. This cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Import')),
        ],
      ),
    );
  }

  Future<bool?> _confirmRestore(BackupInfo info) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup created: ${_prettyDate(info.createdAt)}'),
            const SizedBox(height: 4),
            Text(
                'Students: ${info.studentCount} · Fee receipts: ${info.receiptCount}'),
            const SizedBox(height: 12),
            const Text(
              'All current data on this device will be replaced by this backup. This cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Restore')),
        ],
      ),
    );
  }

  String _prettyDate(String iso) {
    if (iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Settings'),
      body: ListenableBuilder(
        listenable: _backups,
        builder: (_, __) {
          final running = _backups.isRunning || _busy;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle('License'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!LicenseService.isLicenseEnforced) ...[
                        const Text(
                          'Is software (Windows) ke liye license key ki '
                          'zaroorat nahi hai — license sirf mobile app '
                          '(APK) mein lagti hai.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ] else ...[
                        _InfoRow('Status', _licenseStatusText()),
                        _InfoRow('Key', _licenseStatus?.maskedKey ?? '-'),
                        _InfoRow('Device ID', _deviceId ?? 'Loading...'),
                        if (_licenseStatus?.licensed == true) ...[
                          _InfoRow(
                            'Expiry',
                            _licenseStatus!.expiryDate == null
                                ? '-'
                                : _fmtDate(_licenseStatus!.expiryDate!),
                          ),
                          _InfoRow(
                            'Days left',
                            '${_licenseStatus!.daysLeft ?? '-'}',
                          ),
                          _InfoRow(
                            'Device-locked',
                            _licenseStatus!.deviceLocked ? 'Yes' : 'No',
                          ),
                        ],
                        if (_licenseStatus != null &&
                            !_licenseStatus!.licensed &&
                            _licenseStatus!.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _licenseStatus!.message!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openLicense,
                          icon: const Icon(Icons.key_outlined),
                          label: Text(
                            _licenseStatus?.licensed == true
                                ? 'Change key'
                                : 'Enter license key',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Login & Password'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Password login'),
                      subtitle: const Text(
                          'Off: app opens directly. On: asks username + password.'),
                      value: _pwLoginEnabled ?? false,
                      onChanged: _pwLoginEnabled == null
                          ? null
                          : _togglePwLogin,
                    ),
                    if (_pwLoginEnabled == true)
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Change password'),
                        subtitle: const Text(
                            'For principal or teacher'),
                        onTap: _changePassword,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Backup'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The app keeps automatic backups of the whole database '
                        '(students, attendance, fees, receipts, expenses and '
                        'everything else) as a single .alasif file.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow('Last backup',
                          _prettyDate(_backups.lastBackupLabel ?? '')),
                      _InfoRow('Backups kept', '${_backups.backupCount} of 7'),
                      _InfoRow('Folder', _backups.backupDirPath ?? '-'),
                      const SizedBox(height: 4),
                      const Text(
                        'Auto-backup runs once a day and after every 50 changes.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (running) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: running ? null : _backupNow,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Backup now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: running ? null : _importBackup,
                icon: const Icon(Icons.restore),
                label: const Text('Import backup'),
              ),
              const SizedBox(height: 24),
              const Text(
                'A backup file (.alasif) can be copied to another phone or '
                'to the Windows app and imported there to move the full database.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('CSV backup'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The whole database as CSV files (one file per table) inside a zip. Unzip it to open any table in Excel.',
                        style: TextStyle(fontSize: 13),
                      ),
                      if (_csvMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(_csvMessage!,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: running ? null : _exportCsv,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export CSV backup'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: running ? null : _exportCsv,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export CSV (APK / Flutter format)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: running ? null : _importCsv,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Import CSV backup'),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('School Settings'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: const Text('School Info & Login'),
                      subtitle: const Text(
                          'EMIS, address, tehsil, type, shift, principal password'),
                      onTap: _openSchoolInfo,
                    ),
                    ListTile(
                      leading: const Icon(Icons.attach_money_outlined),
                      title: const Text('Class Monthly Fee'),
                      subtitle: const Text(
                          'Har class ki monthly tuition fee — popup mein edit karein'),
                      onTap: _openClassFees,
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Teacher Assignments'),
                      subtitle: const Text(
                          'Class aur subject assign karein — popup mein'),
                      onTap: _openAssignments,
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Student Charges'),
                      subtitle: const Text(
                          'Extra charges add / remove karein — popup mein'),
                      onTap: _openCharges,
                    ),
                    ListTile(
                      leading: const Icon(Icons.sync_outlined),
                      title: const Text('Server Sync'),
                      subtitle: const Text(
                          'PC server se live sync — APK aur software ka data aik jaisa rahe'),
                      onTap: _openSync,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('App & Updates'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow('Version', _currentVersion ?? '-'),
                      if (_updateMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(_updateMessage!,
                            style: const TextStyle(fontSize: 13)),
                      ],
                      const SizedBox(height: 4),
                      const Text(
                        'Installing a new version over the old one keeps all '
                        'data: the database lives outside the app folder.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_busy || _checkingUpdate)
                          ? null
                          : _checkForUpdate,
                      icon: const Icon(Icons.system_update_outlined),
                      label: const Text('Check for updates'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _resetDemo,
                      icon: const Icon(Icons.restart_alt_outlined),
                      label: const Text('Reset demo data'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.navy),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black54))),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
