import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/staff_provider.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _designation = TextEditingController();
  final _phone = TextEditingController();
  final _cnic = TextEditingController();
  final _salary = TextEditingController();
  final _joining = TextEditingController();
  String _type = 'teaching';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    _phone.dispose();
    _cnic.dispose();
    _salary.dispose();
    _joining.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<StaffProvider>().add({
        'name': _name.text.trim(),
        'staff_type': _type,
        'designation': _designation.text.trim(),
        'phone': _phone.text.trim(),
        'cnic': _cnic.text.trim(),
        'salary_monthly': double.tryParse(_salary.text.trim()) ?? 0,
        'joining_date':
            _joining.text.trim().isEmpty ? null : _joining.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Staff member added.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Add Staff'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            TextFormField(
                controller: _name,
                decoration: fieldDecoration('Full name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: fieldDecoration('Staff type'),
              items: const [
                DropdownMenuItem(
                    value: 'teaching', child: Text('Teaching')),
                DropdownMenuItem(
                    value: 'non_teaching', child: Text('Non-teaching')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'teaching'),
            ),
            const SizedBox(height: 10),
            TextFormField(
                controller: _designation,
                decoration: fieldDecoration('Designation *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                      controller: _phone,
                      decoration: fieldDecoration('Phone'),
                      keyboardType: TextInputType.phone),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                      controller: _cnic,
                      decoration: fieldDecoration('CNIC'),
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                      controller: _salary,
                      decoration:
                          fieldDecoration('Monthly salary (Rs) *'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                      controller: _joining,
                      decoration: fieldDecoration(
                          'Joining date (YYYY-MM-DD)')),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Add Staff Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
