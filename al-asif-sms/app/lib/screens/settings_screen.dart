import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
import '../widgets/school_app_bar.dart';
import '../widgets/ui_helpers.dart';
import 'home_shell.dart';

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
  bool? _pwLoginEnabled;

  BackupService get _backups => BackupService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backups.refreshStatus();
      _loadPwSetting();
    });
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
                'A backup file (.alasif) can be copied to another phone and '
                'imported there to move the full database.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
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
