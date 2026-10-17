import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/academics.dart';
import '../../models/student.dart';
import '../../providers/academics_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class AdmissionScreen extends StatefulWidget {
  const AdmissionScreen({super.key});

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rollNo = TextEditingController();
  final _dob = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _guardianRelation = TextEditingController();
  final _address = TextEditingController();

  String _gender = 'Male';
  int? _classId;
  int? _sectionId;
  bool _busy = false;

  final Map<String, bool> _docs = {
    'B-Form / Birth certificate': false,
    'Guardian CNIC copy': false,
    'Photographs (4)': false,
    'Previous school certificate': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _rollNo.dispose();
    _dob.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    _guardianRelation.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null) {
      showSnack(context, 'Please select a class.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<StudentProvider>().admit({
        // admission_no omitted on purpose: the system auto-generates it
        'name': _name.text.trim(),
        'roll_number': _rollNo.text.trim().isEmpty
            ? null
            : int.tryParse(_rollNo.text.trim()),
        'dob': _dob.text.trim().isEmpty ? null : _dob.text.trim(),
        'gender': _gender,
        'class_id': _classId,
        'section_id': _sectionId,
        'guardian_name': _guardianName.text.trim(),
        'guardian_phone': _guardianPhone.text.trim(),
        'guardian_relation': _guardianRelation.text.trim(),
        'address': _address.text.trim(),
        'documents': _docs.entries
            .map((e) => StudentDocument(name: e.key, received: e.value).toJson())
            .toList(),
      });
      if (!mounted) return;
      showSnack(context, 'Student admitted.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;
    final sections = _classId == null
        ? []
        : classes
            .firstWhere((c) => c.id == _classId,
                orElse: () => const ClassInfo(id: 0, name: ''))
            .sections;

    return Scaffold(
      appBar: const SchoolAppBar(title: 'New Admission'),
      body: classes.isEmpty
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  const Text('Student',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: context
                        .read<StudentProvider>()
                        .nextAdmissionNo(),
                    builder: (ctx, snap) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.navy.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined,
                              color: AppColors.navy, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Student ID (auto-generated)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54)),
                              Text(
                                snap.data ?? '…',
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.navy),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _name,
                      decoration: fieldDecoration('Full name *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _rollNo,
                      decoration:
                          fieldDecoration('Roll number (optional)'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                            controller: _dob,
                            decoration: fieldDecoration(
                                'Date of birth (YYYY-MM-DD)')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: fieldDecoration('Gender'),
                          items: const ['Male', 'Female']
                              .map((g) => DropdownMenuItem(
                                  value: g, child: Text(g)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _gender = v ?? 'Male'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _classId,
                          decoration: fieldDecoration('Class *'),
                          items: classes
                              .map((c) => DropdownMenuItem<int?>(
                                  value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _classId = v;
                            _sectionId = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _sectionId,
                          decoration: fieldDecoration('Section'),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('None')),
                            ...sections.map((s) => DropdownMenuItem<int?>(
                                value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (v) =>
                              setState(() => _sectionId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Guardian',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _guardianName,
                      decoration: fieldDecoration('Guardian name *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                            controller: _guardianPhone,
                            decoration:
                                fieldDecoration('Guardian phone *'),
                            keyboardType: TextInputType.phone,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                            controller: _guardianRelation,
                            decoration:
                                fieldDecoration('Relation (e.g. Father)')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _address,
                      decoration: fieldDecoration('Address'),
                      maxLines: 2),
                  const SizedBox(height: 16),
                  const Text('Documents checklist',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  ..._docs.keys.map((k) => CheckboxListTile(
                        title: Text(k),
                        value: _docs[k],
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setState(() => _docs[k] = v ?? false),
                      )),
                  const SizedBox(height: 16),
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
                          : const Text('Admit Student'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
