import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/student.dart';
import '../../printing/benazir_slip.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Benazir Taleemi Wazaif verification slip: auto-filled from the student
/// record, remaining fields editable, then print/share.
class BenazirSlipScreen extends StatefulWidget {
  final Student student;
  const BenazirSlipScreen({super.key, required this.student});

  @override
  State<BenazirSlipScreen> createState() => _BenazirSlipScreenState();
}

class _BenazirSlipScreenState extends State<BenazirSlipScreen> {
  late final TextEditingController _mother;
  late final TextEditingController _emis;
  late final TextEditingController _address;
  late final TextEditingController _tehsil;
  late final TextEditingController _teacher;
  late final TextEditingController _teacherPhone;
  late final TextEditingController _group;
  bool _newAdmission = true;
  int _outOfSchool = 3;

  @override
  void initState() {
    super.initState();
    _mother = TextEditingController();
    _emis = TextEditingController();
    _address = TextEditingController(text: 'Basti Shaikhan');
    _tehsil = TextEditingController(text: 'Zafar Abad');
    _teacher = TextEditingController();
    _teacherPhone = TextEditingController();
    _group = TextEditingController();
    // Heuristic: admitted this academic year (Apr onward) => new admission.
    final adm = widget.student.admissionDate;
    if (adm != null && adm.isNotEmpty) {
      final d = DateTime.tryParse(adm);
      if (d != null) {
        final now = DateTime.now();
        final sessionStart =
            DateTime(now.month >= 4 ? now.year : now.year - 1, 4, 1);
        _newAdmission = !d.isBefore(sessionStart);
      }
    }
  }

  @override
  void dispose() {
    _mother.dispose();
    _emis.dispose();
    _address.dispose();
    _tehsil.dispose();
    _teacher.dispose();
    _teacherPhone.dispose();
    _group.dispose();
    super.dispose();
  }

  Future<Uint8List> _build(PdfPageFormat format) async {
    final bytes = await BenazirSlipPdf.build(
      student: widget.student,
      motherName: _mother.text.trim(),
      emisCode: _emis.text.trim(),
      schoolAddress: _address.text.trim(),
      tehsil: _tehsil.text.trim(),
      teacherName: _teacher.text.trim(),
      teacherContact: _teacherPhone.text.trim(),
      group: _group.text.trim(),
      isNewAdmission: _newAdmission,
      outOfSchoolStatus: _outOfSchool,
      schoolType: 'private',
      shift: 'morning',
    );
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Benazir Verification Slip'),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('Auto-filled from record: ${s.name}, ${s.admissionNo}, '
              'Class ${s.className}, Father: ${s.guardianName}'),
          const SizedBox(height: 10),
          TextField(
              controller: _mother,
              decoration: fieldDecoration('Mother Name')),
          const SizedBox(height: 8),
          TextField(
              controller: _emis,
              decoration: fieldDecoration('School EMIS / College Code')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _address,
                    decoration: fieldDecoration('School Address'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _tehsil,
                    decoration: fieldDecoration('Tehsil'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _teacher,
                    decoration: fieldDecoration('Teacher Name'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _teacherPhone,
                    decoration:
                        fieldDecoration('Teacher Contact'))),
          ]),
          const SizedBox(height: 8),
          TextField(
              controller: _group,
              decoration: fieldDecoration('Group (optional)')),
          const SizedBox(height: 8),
          DropdownButtonFormField<bool>(
            value: _newAdmission,
            decoration: fieldDecoration('Admission status'),
            items: const [
              DropdownMenuItem(
                  value: true, child: Text('1. New Admission')),
              DropdownMenuItem(
                  value: false, child: Text('2. Old Admission')),
            ],
            onChanged: (v) =>
                setState(() => _newAdmission = v ?? true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _outOfSchool,
            decoration: fieldDecoration('Child Out of School'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('None')),
              DropdownMenuItem(
                  value: 1,
                  child: Text('1. Out of School (Delayed by 2 years)')),
              DropdownMenuItem(
                  value: 2,
                  child: Text('2. Dropped Out (1 Year gap)')),
              DropdownMenuItem(value: 3, child: Text('3. Regular')),
            ],
            onChanged: (v) =>
                setState(() => _outOfSchool = v ?? 3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 420,
            child: PdfPreview(
              build: _build,
              allowSharing: true,
              allowPrinting: true,
              canChangePageFormat: false,
            ),
          ),
        ],
      ),
    );
  }
}
