import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/staff_provider.dart';
import '../../services/urdu_transliterate.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Staff — one table, matching the HTML v7 Staff screen: Name | Role |
/// Class | Contact | Monthly Salary | Status | Remove, with a "+ Add
/// Staff" button opening the HTML's Add Staff modal. The HTML has no
/// leave-requests UI on this screen, so the Leave FAB is gone.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<StaffProvider>().loadStaff());
  }

  Future<void> _remove(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this staff member?'),
        content: Text(name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await context.read<StaffProvider>().remove(id);
    }
  }

  Future<void> _openAddStaff() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddStaffDialog(),
    );
    if (added == true && mounted) {
      setState(() => _message = 'Staff added.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Staff'),
      body: Consumer<StaffProvider>(
        builder: (context, p, _) {
          if (p.loading && p.staff.isEmpty) return const LoadingView();
          if (p.error != null && p.staff.isEmpty) {
            return EmptyState(message: p.error!);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Teachers aur staff ki list, monthly salary ke saath.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  Text(_message!,
                      style: TextStyle(color: Colors.green[800])),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _openAddStaff,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black),
                    child: const Text('+ Add Staff'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: p.staff.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Koi staff nahi.',
                                style: TextStyle(color: Colors.grey)),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Role')),
                                DataColumn(label: Text('Class')),
                                DataColumn(label: Text('Contact')),
                                DataColumn(label: Text('Monthly Salary')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('')),
                              ],
                              rows: p.staff.map((s) {
                                return DataRow(cells: [
                                  DataCell(Text(s.name)),
                                  DataCell(Text(s.roleLabel)),
                                  DataCell(Text(s.className.isEmpty
                                      ? '-'
                                      : s.className)),
                                  DataCell(Text(s.phone.isEmpty
                                      ? '-'
                                      : s.phone)),
                                  DataCell(Text(fmtMoney(s.salaryMonthly))),
                                  DataCell(const Text('active')),
                                  DataCell(TextButton(
                                    onPressed: () => _remove(s.id, s.name),
                                    child: const Text('Remove',
                                        style:
                                            TextStyle(color: Colors.red)),
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The HTML's Add Staff modal: Name, Name (Urdu, auto-filled from the
/// transliterator when left blank), Role, Class, Monthly salary, Since
/// date, Contact, Login password (default teacher123).
class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _name = TextEditingController();
  final _nameUrdu = TextEditingController();
  final _salary = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  String _role = 'Teacher';
  String? _className;
  DateTime _since = DateTime.now();
  bool _urduManual = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _nameUrdu.dispose();
    _salary.dispose();
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name zaroori hai.');
      return;
    }
    final nameUrdu = _nameUrdu.text.trim().isEmpty
        ? urduName('', name)
        : _nameUrdu.text.trim();
    final body = {
      'name': name,
      'name_urdu': nameUrdu,
      'staff_type':
          (_role == 'Teacher' || _role == 'Principal')
              ? 'teaching'
              : 'non_teaching',
      'designation': _role,
      'class_name': _className ?? '',
      'salary_monthly': double.tryParse(_salary.text.trim()) ?? 0,
      'joining_date': _since.toIso8601String().substring(0, 10),
      'phone': _contact.text.trim(),
      'password': _password.text.trim().isEmpty
          ? 'teacher123'
          : _password.text.trim(),
    };
    await context.read<StaffProvider>().add(body);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Staff'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
              onChanged: (v) {
                if (!_urduManual) {
                  _nameUrdu.text = urduName('', v);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameUrdu,
              decoration: const InputDecoration(
                  labelText: 'نام (اردو)', border: OutlineInputBorder()),
              onChanged: (_) => _urduManual = true,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                  labelText: 'Role', border: OutlineInputBorder()),
              items: const ['Teacher', 'Principal', 'Clerk', 'Peon', 'Other']
                  .map((r) =>
                      DropdownMenuItem<String>(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? 'Teacher'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _className,
              decoration: const InputDecoration(
                  labelText: 'Class', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('No class')),
                ...AppConfig.classNames.map((c) => DropdownMenuItem<String>(
                    value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _className = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _salary,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Monthly salary (Rs)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Since: '),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _since,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _since = picked);
                    }
                  },
                  child: Text(_since.toIso8601String().substring(0, 10)),
                ),
              ],
            ),
            TextField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Contact number (e.g. 0300-1234567)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                  labelText: 'Login password (default: teacher123)',
                  border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: Colors.black),
          child: const Text('Add Staff'),
        ),
      ],
    );
  }
}
