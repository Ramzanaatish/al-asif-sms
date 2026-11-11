import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/reports_provider.dart';
import '../repositories/exams_repository.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_view.dart';
import '../widgets/school_app_bar.dart';
import '../widgets/ui_helpers.dart';

/// Reports — one screen, matching the HTML v7 Reports screen: a Report
/// Generator (9 types with conditional rows), the generated report's
/// output card, the Monthly Collection Report table, and the Class
/// Strength table. Report language follows v7: result / leaving /
/// character / monthly attendance / experience = English; fee
/// collection / defaulter / P&L = Urdu; Benazir = English.
class ReportsHomeScreen extends StatelessWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportsProvider()..loadBase(),
      child: const _ReportsView(),
    );
  }
}

const _reportTypes = [
  ('result', 'Result Card (Monthly / Quarterly / Annual)'),
  ('leaving', 'School Leaving Certificate'),
  ('character', 'Character Certificate'),
  ('benazir', 'Benazir Verification Slip'),
  ('attendance', 'Monthly Attendance Report (Class-wise)'),
  ('collection', 'Fee Collection Report'),
  ('defaulter', 'Defaulter List Report'),
  ('profitloss', 'Profit & Loss Report'),
  ('experience', 'Teacher Experience Certificate'),
];

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class _ReportsView extends StatefulWidget {
  const _ReportsView();

  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  String _type = 'result';
  int? _studentId;
  String _term = 'First Term';
  int? _classId;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String? _teacher;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _generating = false;
  String? _message;
  bool _messageError = false;

  ReportsProvider get _p => context.read<ReportsProvider>();

  bool get _showStudent =>
      _type == 'result' ||
      _type == 'leaving' ||
      _type == 'character' ||
      _type == 'benazir';
  bool get _showMonth =>
      _type == 'attendance' || _type == 'collection' || _type == 'profitloss';
  bool get _showTeacher => _type == 'experience';

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _message = null;
    });
    try {
      switch (_type) {
        case 'result':
          if (_studentId == null) throw Exception('Student select karein.');
          await _p.generateResultCard(_studentId!, _term);
        case 'leaving':
          if (_studentId == null) throw Exception('Student select karein.');
          await _p.generateLeaving(_studentId!);
        case 'character':
          if (_studentId == null) throw Exception('Student select karein.');
          await _p.generateCharacter(_studentId!);
        case 'benazir':
          if (_studentId == null) throw Exception('Student select karein.');
          await _p.generateBenazir(_studentId!);
        case 'attendance':
          if (_classId == null) throw Exception('Class select karein.');
          await _p.generateAttendance(_classId!, _month, _year);
        case 'collection':
          await _p.generateCollection(_month, _year);
        case 'defaulter':
          await _p.generateDefaulter();
        case 'profitloss':
          await _p.generateProfitLoss(_month, _year);
        case 'experience':
          if (_teacher == null) throw Exception('Teacher select karein.');
          await _p.generateExperience(
            _teacher!,
            _from.toIso8601String().substring(0, 10),
            _to.toIso8601String().substring(0, 10),
          );
      }
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageError = true;
      });
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _generateBulk() async {
    setState(() {
      _generating = true;
      _message = null;
    });
    try {
      await _p.generateBulkResultCards(_term);
    } catch (e) {
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageError = true;
      });
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _printGenerated() async {
    final bytes = _p.generatedPdf;
    if (bytes == null) return;
    await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes));
  }

  Future<void> _downloadGenerated() async {
    final bytes = _p.generatedPdf;
    final title = _p.generatedTitle;
    if (bytes == null || title == null) return;
    final safe = title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Download report (PDF)',
      fileName: '$safe.pdf',
      bytes: Uint8List.fromList(bytes),
    );
    if (path != null && mounted) {
      setState(() => _message = 'PDF saved: $path');
    }
  }

  Future<void> _printSummary() async {
    final bytes = await _p.printSummary();
    await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Reports'),
      body: Consumer<ReportsProvider>(
        builder: (context, p, _) {
          if (p.loading && p.students.isEmpty) return const LoadingView();
          if (p.error != null && p.students.isEmpty) {
            return EmptyState(message: p.error!);
          }
          // Sensible defaults once data arrives.
          _studentId ??= p.students.isNotEmpty ? p.students.first.id : null;
          _classId ??= p.classes.isNotEmpty ? p.classes.first.id : null;
          _teacher ??= p.students.isNotEmpty
              ? AppConfig.classTeacher(p.students.first.className)
              : null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Collection report, class strength, aur tamam certificates / reports — sab Urdu mein, school logo ke saath.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                if (p.generatedPdf == null) ...[
                  _card(
                    title: 'Report Generator',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _type,
                          decoration: const InputDecoration(
                              labelText: 'Report type',
                              border: OutlineInputBorder()),
                          items: _reportTypes
                              .map((t) => DropdownMenuItem<String>(
                                  value: t.$1, child: Text(t.$2)))
                              .toList(),
                          onChanged: (v) => setState(() => _type = v ?? 'result'),
                        ),
                        if (_showTeacher) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _teacher,
                                  decoration: const InputDecoration(
                                      labelText: 'Teacher',
                                      border: OutlineInputBorder()),
                                  items: AppConfig.classTeachers.values
                                      .toSet()
                                      .map((t) => DropdownMenuItem<String>(
                                          value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _teacher = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: _dateField('From', _from,
                                  (d) => setState(() => _from = d))),
                              const SizedBox(width: 10),
                              Expanded(child: _dateField('To', _to,
                                  (d) => setState(() => _to = d))),
                            ],
                          ),
                        ],
                        if (_showStudent) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _studentId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Student',
                                      border: OutlineInputBorder()),
                                  items: p.students
                                      .map((s) => DropdownMenuItem<int>(
                                          value: s.id,
                                          child: Text(
                                              '${s.name} — ${s.className} (${s.admissionNo})')))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _studentId = v),
                                ),
                              ),
                              if (_type == 'result') ...[
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 160,
                                  child: DropdownButtonFormField<String>(
                                    value: _term,
                                    decoration: const InputDecoration(
                                        labelText: 'Term',
                                        border: OutlineInputBorder()),
                                    items: ExamsRepository.htmlTerms
                                        .map((t) =>
                                            DropdownMenuItem<String>(
                                                value: t.$1,
                                                child: Text(t.$1)))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _term = v ?? 'First Term'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (_showMonth) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (_type == 'attendance')
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _classId,
                                    decoration: const InputDecoration(
                                        labelText: 'Class',
                                        border: OutlineInputBorder()),
                                    items: p.classes
                                        .map((c) => DropdownMenuItem<int>(
                                            value: c.id,
                                            child: Text(c.name)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _classId = v),
                                  ),
                                ),
                              if (_type == 'attendance')
                                const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _month,
                                  decoration: const InputDecoration(
                                      labelText: 'Month',
                                      border: OutlineInputBorder()),
                                  items: List.generate(
                                      12,
                                      (i) => DropdownMenuItem<int>(
                                          value: i + 1,
                                          child: Text(_months[i]))),
                                  onChanged: (v) => setState(
                                      () => _month = v ?? _month),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _generating ? null : _generate,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: Colors.black),
                              child: Text(_generating
                                  ? 'Generating...'
                                  : 'Generate Report'),
                            ),
                            if (_type == 'result') ...[
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed:
                                    _generating ? null : _generateBulk,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.navy,
                                    foregroundColor: Colors.white),
                                child: const Text(
                                    '📄 All School Result Cards (1 click)'),
                              ),
                            ],
                          ],
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 8),
                          Text(_message!,
                              style: TextStyle(
                                  color: _messageError
                                      ? Colors.red
                                      : Colors.green[800])),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  _card(
                    title: 'Generated Report',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(p.generatedTitle ?? '',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                            '${(p.generatedPdf?.length ?? 0) ~/ 1024} KB PDF — Print ya Download karein.',
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => p.clearGenerated(),
                              child: const Text('← New Report'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _printGenerated,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.navy,
                                  foregroundColor: Colors.white),
                              child: const Text('🖨️ Print'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: _downloadGenerated,
                              child: const Text('⬇ PDF Download'),
                            ),
                          ],
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 8),
                          Text(_message!,
                              style: const TextStyle(color: Colors.green)),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _card(
                  title:
                      'Monthly Collection Report — ${_months[DateTime.now().month - 1]} ${DateTime.now().year}',
                  child: p.perHead.isEmpty
                      ? const Text('Is month koi collection nahi.',
                          style: TextStyle(color: Colors.grey))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Fee Head')),
                              DataColumn(label: Text('Challans')),
                              DataColumn(label: Text('Paid')),
                              DataColumn(label: Text('Amount Collected')),
                            ],
                            rows: [
                              ...p.perHead.map((r) => DataRow(cells: [
                                    DataCell(
                                        Text(r['head']?.toString() ?? '')),
                                    DataCell(Text('${r['challans'] ?? 0}')),
                                    DataCell(Text('${r['paid'] ?? 0}')),
                                    DataCell(Text(fmtMoney(
                                        (r['amount'] as num?)?.toDouble() ??
                                            0))),
                                  ])),
                              DataRow(cells: [
                                const DataCell(Text('Total',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                                DataCell(Text(
                                    '${p.perHead.fold<int>(0, (s, r) => s + ((r['challans'] as num?)?.toInt() ?? 0))}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                                DataCell(Text(
                                    '${p.perHead.fold<int>(0, (s, r) => s + ((r['paid'] as num?)?.toInt() ?? 0))}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                                DataCell(Text(
                                    fmtMoney(p.perHead.fold<double>(
                                        0,
                                        (s, r) =>
                                            s +
                                            ((r['amount'] as num?)
                                                    ?.toDouble() ??
                                                0))),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                              ]),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Class Strength',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Class')),
                        DataColumn(label: Text('Teacher')),
                        DataColumn(label: Text('Students')),
                      ],
                      rows: p.classStrength
                          .map((r) => DataRow(cells: [
                                DataCell(Text(r['class']?.toString() ?? '')),
                                DataCell(
                                    Text(r['teacher']?.toString() ?? '')),
                                DataCell(
                                    Text('${r['students'] ?? 0}')),
                              ]))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _printSummary,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white),
                  child: const Text('🖨️ Print Report'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dateField(
      String label, DateTime value, ValueChanged<DateTime> onPicked) {
    return Row(
      children: [
        Text('$label: '),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onPicked(picked);
          },
          child: Text(value.toIso8601String().substring(0, 10)),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
