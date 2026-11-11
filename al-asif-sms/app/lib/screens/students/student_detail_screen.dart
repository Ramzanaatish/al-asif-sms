import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/student.dart';
import '../../providers/student_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';
import 'benazir_slip_screen.dart';
import 'leaving_certificate_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final int id;
  final bool readOnly;
  const StudentDetailScreen({super.key, required this.id, this.readOnly = false});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Student? _student;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _student = await context.read<StudentProvider>().detail(widget.id);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markLeft() async {
    final dateCtrl = TextEditingController(
        text: ymd(DateTime.now()));
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mark student as left'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: dateCtrl,
                decoration: fieldDecoration('Leaving date (YYYY-MM-DD)')),
            const SizedBox(height: 12),
            TextField(
                controller: reasonCtrl,
                decoration: fieldDecoration('Reason'),
                maxLines: 2),
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
              child: const Text('Mark as Left')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (reasonCtrl.text.trim().isEmpty) {
      showSnack(context, 'Please enter a reason.', error: true);
      return;
    }
    try {
      final res = await context.read<StudentProvider>().markLeft(
          widget.id, dateCtrl.text.trim(), reasonCtrl.text.trim());
      final cert =
          ((res['certificate'] as Map?) ?? {}).cast<String, dynamic>();
      final updated =
          ((res['student'] as Map?) ?? {}).cast<String, dynamic>();
      if (!mounted) return;
      showSnack(context, 'Student marked as left.');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeavingCertificatePreviewScreen(
            student: _student!.copyWithStatusLeft(updated),
            certificateNo: cert['certificate_no']?.toString() ?? '',
            leavingDate: dateCtrl.text.trim(),
            reason: reasonCtrl.text.trim(),
          ),
        ),
      );
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _editStudent() async {
    final s = _student;
    if (s == null) return;
    final nameCtrl = TextEditingController(text: s.name);
    final rollCtrl =
        TextEditingController(text: s.rollNumber?.toString() ?? '');
    final dobCtrl = TextEditingController(text: s.dob ?? '');
    final guardianCtrl = TextEditingController(text: s.guardianName);
    final phoneCtrl = TextEditingController(text: s.guardianPhone);
    final relationCtrl = TextEditingController(text: s.guardianRelation);
    final addressCtrl = TextEditingController(text: s.address);
    String gender = s.gender;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: fieldDecoration('Full name *')),
              const SizedBox(height: 12),
              TextField(
                  controller: rollCtrl,
                  decoration: fieldDecoration('Roll number'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(
                  controller: dobCtrl,
                  decoration:
                      fieldDecoration('Date of birth (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ['Male', 'Female'].contains(gender) ? gender : null,
                decoration: fieldDecoration('Gender'),
                items: const ['Male', 'Female']
                    .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) gender = v;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: guardianCtrl,
                  decoration: fieldDecoration('Father/Guardian name')),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneCtrl,
                  decoration: fieldDecoration('Guardian phone'),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(
                  controller: relationCtrl,
                  decoration: fieldDecoration('Relation (e.g. Father)')),
              const SizedBox(height: 12),
              TextField(
                  controller: addressCtrl,
                  decoration: fieldDecoration('Address'),
                  maxLines: 2),
            ],
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
    if (nameCtrl.text.trim().isEmpty) {
      showSnack(context, 'Name is required.', error: true);
      return;
    }
    try {
      await context.read<StudentProvider>().updateStudent(widget.id, {
        'name': nameCtrl.text.trim(),
        'roll_number': rollCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(rollCtrl.text.trim()),
        'dob': dobCtrl.text.trim().isEmpty ? null : dobCtrl.text.trim(),
        'gender': gender,
        'guardian_name': guardianCtrl.text.trim(),
        'guardian_phone': phoneCtrl.text.trim(),
        'guardian_relation': relationCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Student updated.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SchoolAppBar(
        title: 'Student Detail',
        actions: [
          if (!widget.readOnly && _student != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit student',
              onPressed: _editStudent,
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? EmptyState(message: _error!, icon: Icons.cloud_off_outlined)
              : _body(),
    );
  }

  Widget _body() {
    final s = _student!;
    return ListView(
      children: [
        Container(
          color: AppColors.navy,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.gold,
                child: Text(s.name.isEmpty ? '?' : s.name[0],
                    style: const TextStyle(
                        fontSize: 26, color: AppColors.navy)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(
                        '${s.admissionNo} - ${s.className}${s.sectionName.isNotEmpty ? ' (${s.sectionName})' : ''}',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(s.isActive ? 'Active' : 'Left',
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: s.isActive
                          ? AppColors.success
                          : Colors.grey,
                      labelStyle: const TextStyle(color: Colors.white),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        InfoCard(title: 'Profile', children: [
          InfoRow(label: 'Gender', value: s.gender),
          InfoRow(label: 'Date of birth', value: fmtDate(s.dob)),
          InfoRow(label: 'Address', value: s.address),
        ]),
        InfoCard(title: 'Guardian', children: [
          InfoRow(label: 'Name', value: s.guardianName),
          InfoRow(label: 'Relation', value: s.guardianRelation),
          InfoRow(label: 'Phone', value: s.guardianPhone),
        ]),
        InfoCard(title: 'Documents', children: [
          if (s.documents.isEmpty)
            const Text('No documents recorded.',
                style: TextStyle(color: Colors.black54)),
          ...s.documents.map((d) => Row(
                children: [
                  Icon(d.received ? Icons.check_circle : Icons.cancel,
                      color: d.received
                          ? AppColors.success
                          : AppColors.danger,
                      size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d.name)),
                ],
              )),
        ]),
        InfoCard(title: 'Summary', children: [
          InfoRow(
              label: 'Attendance',
              value: s.attendancePct == null
                  ? '-'
                  : '${s.attendancePct!.toStringAsFixed(1)}%'),
          InfoRow(
              label: 'Fee balance',
              value: s.feeBalance == null
                  ? '-'
                  : fmtMoney(s.feeBalance!)),
        ]),
        if (!widget.readOnly && s.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.verified_outlined,
                  color: AppColors.success),
              label: const Text('Benazir Verification Slip',
                  style: TextStyle(color: AppColors.success)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BenazirSlipScreen(student: s),
                ),
              ),
            ),
          ),
        if (!widget.readOnly && s.isActive)
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.exit_to_app,
                  color: AppColors.danger),
              label: const Text('Mark as left',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _markLeft,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Builds a [Student] merged with the mark-left response payload so the
/// leaving certificate prints with fresh dates.
extension StudentLeaveX on Student {
  Student copyWithStatusLeft(Map<String, dynamic> updated) {
    return Student(
      id: id,
      admissionNo: admissionNo,
      name: updated['name']?.toString() ?? name,
      dob: dob,
      gender: gender,
      classId: classId,
      className: className,
      sectionId: sectionId,
      sectionName: sectionName,
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      guardianRelation: guardianRelation,
      address: address,
      status: 'left',
      photoPath: photoPath,
      documents: documents,
      attendancePct: attendancePct,
      feeBalance: feeBalance,
      nameUrdu: nameUrdu,
      fatherUrdu: fatherUrdu,
      motherName: motherName,
      motherNameUrdu: motherNameUrdu,
      bForm: bForm,
      groupName: groupName,
      admStatus: admStatus,
      leavingDate: updated['leaving_date']?.toString(),
      leavingReason: updated['leaving_reason']?.toString(),
      admissionDate: updated['admission_date']?.toString() ?? admissionDate,
    );
  }
}
