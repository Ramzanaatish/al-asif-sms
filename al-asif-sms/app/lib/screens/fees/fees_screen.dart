import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/academics.dart';
import '../../models/fee.dart';
import '../../models/student.dart';
import '../../printing/challan_batch.dart';
import '../../providers/fees_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Fees — one scrolling screen, matching the HTML v7 Fees screen:
/// Generate Challan (Single Student), Generate Bulk Challans, Generate
/// Student Charge, Add Fee Type, and the Challans table. Teachers cannot
/// open this screen (the HTML blocks it with an alert); the menu already
/// hides Fees for teachers.
class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeesProvider()..loadAll(),
      child: const _FeesView(),
    );
  }
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class _FeesView extends StatefulWidget {
  const _FeesView();

  @override
  State<_FeesView> createState() => _FeesViewState();
}

class _FeesViewState extends State<_FeesView> {
  // Single-student generate.
  int? _singleStudentId;
  int _singleMonth = DateTime.now().month;
  List<ReceiptLine> _singleDues = [];
  final _singleSelected = <String>{};
  // Bulk generate.
  int _bulkMonth = DateTime.now().month;
  int? _bulkClassId;
  final _bulkSelected = <String>{};
  // Student charge.
  int? _chargeStudentId;
  String? _chargeName;
  int _chargeMonth = DateTime.now().month;
  // Add fee type.
  final _feeName = TextEditingController();
  final _feeAmount = TextEditingController();
  // Stored frequency values match the HTML: monthly | onetime | annual.
  String _feeFreq = 'monthly';
  int? _feeClassId;
  // Message line (like the HTML's fee message area).
  String? _message;
  bool _messageError = false;

  @override
  void dispose() {
    _feeName.dispose();
    _feeAmount.dispose();
    super.dispose();
  }

  FeesProvider get _p => context.read<FeesProvider>();

  void _setMessage(String text, {bool error = false}) {
    setState(() {
      _message = text;
      _messageError = error;
    });
  }

  Future<void> _loadSingleDues(int studentId) async {
    final dues = await _p.duesForStudent(studentId);
    if (!mounted) return;
    setState(() {
      _singleDues = dues;
      _singleSelected.clear();
    });
  }

  /// The dues checklist (fee heads + charges) for the single-student card
  /// (class-filtered for that student) or the bulk card (all dues).
  List<ReceiptLine> _duesForKeys(Set<String> selected, List<ReceiptLine> all) {
    return all.where((d) => selected.contains(_dueKey(d))).toList();
  }

  String _dueKey(ReceiptLine d) {
    final head = _p.heads.where((h) => h.name == d.name).firstOrNull;
    if (head != null) return 'h:${head.id}';
    return 'c:${d.name}';
  }

  Future<void> _generateSingle() async {
    if (_singleStudentId == null || _singleSelected.isEmpty) {
      _setMessage('Student aur kam se kam aik due select karein.',
          error: true);
      return;
    }
    final headIds = <int>[];
    final chargeNames = <String>[];
    for (final key in _singleSelected) {
      if (key.startsWith('h:')) {
        headIds.add(int.parse(key.substring(2)));
      } else {
        chargeNames.add(key.substring(2));
      }
    }
    try {
      final c = await _p.generateSingle(
        studentId: _singleStudentId!,
        month: _singleMonth,
        year: DateTime.now().year,
        headIds: headIds,
        chargeNames: chargeNames,
      );
      _setMessage(
          'Challan generated: ${c.challanNo} (${fmtMoney(c.totalAmount)})');
    } catch (e) {
      _setMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _generateBulk({int? classId}) async {
    if (_bulkSelected.isEmpty) {
      _setMessage('Kam se kam aik due select karein.', error: true);
      return;
    }
    final headIds = <int>[];
    final chargeNames = <String>[];
    for (final key in _bulkSelected) {
      if (key.startsWith('h:')) {
        headIds.add(int.parse(key.substring(2)));
      } else {
        chargeNames.add(key.substring(2));
      }
    }
    try {
      final res = await _p.generateBulk(
        classId: classId,
        month: _bulkMonth,
        year: DateTime.now().year,
        headIds: headIds,
        chargeNames: chargeNames,
      );
      _setMessage('Generated: ${res.created} challans'
          '${res.skipped > 0 ? ' (${res.skipped} skipped — pehle se mojood ya koi due nahi)' : ''}');
    } catch (e) {
      _setMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _generateCharge() async {
    if (_chargeStudentId == null || _chargeName == null) {
      _setMessage('Student aur charge select karein.', error: true);
      return;
    }
    try {
      final c = await _p.generateCharge(
        studentId: _chargeStudentId!,
        chargeName: _chargeName!,
        month: _chargeMonth,
        year: DateTime.now().year,
      );
      _setMessage('Charge challan generated: ${c.challanNo}');
    } catch (e) {
      _setMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _addFeeType() async {
    final name = _feeName.text.trim();
    final amount = double.tryParse(_feeAmount.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) {
      _setMessage('Fee name aur amount zaroori hain.', error: true);
      return;
    }
    if (_p.heads.any((h) => h.name.toLowerCase() == name.toLowerCase())) {
      _setMessage('Ye fee type pehle se hai.', error: true);
      return;
    }
    await _p.createHead({
      'name': name,
      'amount': amount,
      'frequency': _feeFreq,
      'class_id': _feeClassId,
    });
    _feeName.clear();
    _feeAmount.clear();
    _setMessage('Fee type added: $name — ${fmtMoney(amount)}');
  }

  Future<void> _deleteFeeHead(FeeHead head) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete fee type?'),
        content: Text('${head.name} — ${fmtMoney(head.amount)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _p.deleteHead(head.id);
      _setMessage('Fee type deleted: ${head.name}');
    }
  }

  Future<void> _markPaid(Challan c) async {
    try {
      await _p.markPaid(c.id);
    } catch (e) {
      _setMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _dedupe() async {
    final removed = await _p.dedupeChallans();
    _setMessage(removed > 0
        ? '$removed duplicate challan(s) remove kar diye gaye.'
        : 'Koi duplicate challan nahi mila.');
  }

  /// Arrears for one student: other unpaid challans (the batch CSV's
  /// arrears column and the printed card's بقایا جات).
  double _arrearsFor(FeesProvider p, Challan c) {
    var sum = 0.0;
    for (final other in p.challans) {
      if (other.studentId == c.studentId &&
          other.id != c.id &&
          other.status != 'paid') {
        sum += other.totalAmount - other.amountPaid;
      }
    }
    return sum;
  }

  Map<int, Map<String, dynamic>> _studentMap(FeesProvider p) {
    final out = <int, Map<String, dynamic>>{};
    for (final s in p.students) {
      out[s.id] = {
        'name_urdu': s.nameUrdu,
        'father_urdu': s.fatherUrdu,
        'father': s.guardianName,
        'class': s.className,
        'admission_no': s.admissionNo,
        'b_form': s.bForm,
        'contact': s.guardianPhone,
      };
    }
    return out;
  }

  Future<void> _downloadBatchCsv(FeesProvider p) async {
    if (p.lastBatch.isEmpty) {
      _setMessage('Pehle challan generate karein.', error: true);
      return;
    }
    final byId = {for (final s in p.students) s.id: s};
    final rows = <List<dynamic>>[
      [
        'challan_no', 'admission_no', 'student', 'father', 'class',
        'fee_head', 'items', 'month', 'amount', 'arrears', 'total_due',
        'status',
      ],
    ];
    for (final c in p.lastBatch) {
      final s = byId[c.studentId];
      final arrears = _arrearsFor(p, c);
      rows.add([
        c.challanNo,
        s?.admissionNo ?? '',
        c.studentName,
        s?.guardianName ?? '',
        s?.className ?? '',
        c.head,
        c.items.map((i) => '${i.name}: ${i.amount}').join('; '),
        c.month,
        c.totalAmount,
        arrears,
        c.totalAmount + arrears,
        c.status,
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Download challans (CSV)',
      fileName:
          'challans-${DateTime.now().year}-${_bulkMonth.toString().padLeft(2, '0')}.csv',
      bytes: bytes,
    );
    if (path != null) _setMessage('CSV saved: $path');
  }

  Future<void> _printChallans(FeesProvider p, List<Challan> list) async {
    if (list.isEmpty) {
      _setMessage('Pehle challan generate karein.', error: true);
      return;
    }
    final arrears = <int, double>{};
    for (final c in list) {
      arrears[c.studentId] = _arrearsFor(p, c);
    }
    final bytes = await ChallanBatchPdf.build(
      list,
      students: _studentMap(p),
      arrearsByStudent: arrears,
    );
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Fees'),
      body: Consumer<FeesProvider>(
        builder: (context, p, _) {
          if (p.loading && p.heads.isEmpty) return const LoadingView();
          if (p.error != null && p.heads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => p.loadAll(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Challan banayein, paid mark karein. Monthly Tuition Rs 800 · Monthly Test Rs 200 · Admission Rs 2,000 · Annual Exam Rs 1,200.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _messageError
                          ? Colors.red[50]
                          : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _messageError
                              ? Colors.red[200]!
                              : Colors.green[200]!),
                    ),
                    child: Text(_message!,
                        style: TextStyle(
                            color: _messageError
                                ? Colors.red[800]
                                : Colors.green[800])),
                  ),
                ],
                const SizedBox(height: 12),
                _card(
                  title: 'Generate Challan (Single Student)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _studentDropdown(
                        value: _singleStudentId,
                        students: p.students,
                        onChanged: (id) {
                          setState(() => _singleStudentId = id);
                          if (id != null) _loadSingleDues(id);
                        },
                      ),
                      const SizedBox(height: 10),
                      _monthDropdown(
                        value: _singleMonth,
                        onChanged: (m) =>
                            setState(() => _singleMonth = m ?? _singleMonth),
                      ),
                      const SizedBox(height: 10),
                      const Text('Dues select karein (aik se ziada bhi — aik hi challan banega):',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      if (_singleStudentId == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Pehle student select karein.',
                              style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._singleDues.map((d) => CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('${d.name} — ${fmtMoney(d.amount)}'),
                              value: _singleSelected.contains(_dueKey(d)),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _singleSelected.add(_dueKey(d));
                                } else {
                                  _singleSelected.remove(_dueKey(d));
                                }
                              }),
                            )),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _generateSingle,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white),
                        child: const Text('Generate'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Generate Bulk Challans',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Dues select karein (fee schedule ke mutabik — Monthly Tuition har class ki apni fee se):',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      ..._bulkDues(p).map((d) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${d.name} — ${fmtMoney(d.amount)}'),
                            value: _bulkSelected.contains(_dueKey(d)),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _bulkSelected.add(_dueKey(d));
                              } else {
                                _bulkSelected.remove(_dueKey(d));
                              }
                            }),
                          )),
                      const SizedBox(height: 8),
                      _monthDropdown(
                        value: _bulkMonth,
                        onChanged: (m) =>
                            setState(() => _bulkMonth = m ?? _bulkMonth),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _generateBulk(),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.navy,
                                  foregroundColor: Colors.white),
                              child: const Text('Generate All School'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _bulkClassId,
                              decoration: const InputDecoration(
                                  labelText: 'Class', border: OutlineInputBorder()),
                              items: p.classes
                                  .map((c) => DropdownMenuItem<int>(
                                      value: c.id, child: Text(c.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _bulkClassId = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _bulkClassId == null
                                ? null
                                : () => _generateBulk(classId: _bulkClassId),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white),
                            child: const Text('Generate by Class'),
                          ),
                        ],
                      ),
                      if (p.lastBatch.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Text('${p.lastBatch.length} challan(s) — batch',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _downloadBatchCsv(p),
                                child: const Text(
                                    '⬇ Download challans (CSV)'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _printChallans(p, p.lastBatch),
                                child: const Text(
                                    '🖨️ Print challans (A4 — 6 per page)'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Generate Student Charge',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _studentDropdown(
                        value: _chargeStudentId,
                        students: p.students,
                        onChanged: (id) =>
                            setState(() => _chargeStudentId = id),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _chargeName,
                        decoration: const InputDecoration(
                            labelText: 'Charge', border: OutlineInputBorder()),
                        items: p.charges
                            .map((c) => DropdownMenuItem<String>(
                                value: c.name,
                                child: Text(
                                    '${c.name} — ${fmtMoney(c.amount)}')))
                            .toList(),
                        onChanged: (v) => setState(() => _chargeName = v),
                      ),
                      const SizedBox(height: 10),
                      _monthDropdown(
                        value: _chargeMonth,
                        onChanged: (m) =>
                            setState(() => _chargeMonth = m ?? _chargeMonth),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _generateCharge,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white),
                        child: const Text('Generate Charge'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Add Fee Type',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _feeName,
                        decoration: const InputDecoration(
                            labelText: 'Fee name',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _feeAmount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Amount (Rs)',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _feeFreq,
                              decoration: const InputDecoration(
                                  labelText: 'Frequency',
                                  border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem<String>(
                                    value: 'monthly', child: Text('Monthly')),
                                DropdownMenuItem<String>(
                                    value: 'onetime',
                                    child: Text('One time')),
                                DropdownMenuItem<String>(
                                    value: 'annual', child: Text('Annual')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _feeFreq = v ?? 'monthly'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _feeClassId,
                              decoration: const InputDecoration(
                                  labelText: 'Class',
                                  border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('All classes')),
                                ...p.classes.map((c) => DropdownMenuItem<int>(
                                    value: c.id, child: Text(c.name))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _feeClassId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _addFeeType,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white),
                        child: const Text('Add Fee Type'),
                      ),
                      const SizedBox(height: 10),
                      ...p.heads.map((h) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${h.name} — ${fmtMoney(h.amount)} (${h.frequency}, ${_classLabel(p, h.classId)})',
                                      style: const TextStyle(fontSize: 13)),
                                ),
                                TextButton(
                                  onPressed: () => _deleteFeeHead(h),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Challans',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _printChallans(p, p.challans),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white),
                            child: const Text('🖨 Print All Challans (A4)'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _dedupe,
                            child: const Text('Remove duplicate challans'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (p.challans.isEmpty)
                        const Text('Koi challan nahi.',
                            style: TextStyle(color: Colors.grey))
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Challan No')),
                              DataColumn(label: Text('Student')),
                              DataColumn(label: Text('Fee Head')),
                              DataColumn(label: Text('Month')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('')),
                            ],
                            rows: p.challans.map((c) {
                              return DataRow(cells: [
                                DataCell(Text(c.challanNo)),
                                DataCell(Text(c.studentName)),
                                DataCell(Text(c.headLabel)),
                                DataCell(Text('${c.month}')),
                                DataCell(Text(fmtMoney(c.totalAmount))),
                                DataCell(_statusPill(c.status)),
                                DataCell(c.status == 'unpaid'
                                    ? ElevatedButton(
                                        onPressed: () => _markPaid(c),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.navy,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10)),
                                        child: const Text('Mark paid'),
                                      )
                                    : const Text('')),
                              ]);
                            }).toList(),
                          ),
                        ),
                    ],
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

  /// All dues for the bulk card: every fee head + every charge, at the
  /// head's own amount (the per-class tuition override is applied per
  /// student when generating).
  List<ReceiptLine> _bulkDues(FeesProvider p) {
    final out = <ReceiptLine>[];
    for (final h in p.heads) {
      out.add(ReceiptLine(name: h.name, amount: h.amount));
    }
    for (final c in p.charges) {
      out.add(ReceiptLine(name: c.name, amount: c.amount));
    }
    return out;
  }

  String _classLabel(FeesProvider p, int? classId) {
    if (classId == null) return 'all classes';
    return p.classes
            .where((c) => c.id == classId)
            .firstOrNull
            ?.name ??
        'Class $classId';
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

  Widget _studentDropdown({
    required int? value,
    required List<Student> students,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Student', border: OutlineInputBorder()),
      items: students
          .map((s) => DropdownMenuItem<int>(
              value: s.id,
              child: Text('${s.name} — ${s.className} (${s.admissionNo})')))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _monthDropdown({
    required int value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: const InputDecoration(
          labelText: 'Month', border: OutlineInputBorder()),
      items: List.generate(
          12,
          (i) => DropdownMenuItem<int>(
              value: i + 1, child: Text(_months[i]))),
      onChanged: onChanged,
    );
  }

  Widget _statusPill(String status) {
    final paid = status == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: paid ? Colors.green[100] : Colors.amber[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: paid ? Colors.green[800] : Colors.amber[800])),
    );
  }
}
