import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/exam.dart';
import '../../printing/progress_annual_urdu.dart';
import '../../printing/result_annual.dart';
import '../../providers/academics_provider.dart';
import '../../providers/exams_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class AnnualResultScreen extends StatefulWidget {
  const AnnualResultScreen({super.key});

  @override
  State<AnnualResultScreen> createState() => _AnnualResultScreenState();
}

class _AnnualResultScreenState extends State<AnnualResultScreen> {
  int? _classId;
  final _sessionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  @override
  void dispose() {
    _sessionCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    if (_classId != null) {
      final digits =
          _sessionCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final sessionId =
          digits.length >= 4 ? int.tryParse(digits.substring(0, 4)) : null;
      context
          .read<ExamsProvider>()
          .loadAnnualResult(classId: _classId, sessionId: sessionId);
    }
  }

  Future<Uint8List> _englishPdf(PdfPageFormat f, ClassResult r) async =>
      Uint8List.fromList(await AnnualResultPdf.build(r));

  Future<Uint8List> _urduPdf(PdfPageFormat f, ClassResult r) async =>
      Uint8List.fromList(await AnnualProgressUrduPdf.build(result: r));

  void _preview(String title, Future<Uint8List> Function(PdfPageFormat) build) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: SchoolAppBar(title: title),
          body: PdfPreview(
            build: build,
            allowSharing: true,
            allowPrinting: true,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exams = context.watch<ExamsProvider>();
    final classes = context.watch<AcademicsProvider>().classes;
    final result = exams.annualResult;
    return Scaffold(
      appBar: SchoolAppBar(
        title: 'Annual Result',
        actions: [
          if (result != null) ...[
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print English result card',
              onPressed: () => _preview(
                  'Annual Result Card', (f) => _englishPdf(f, result)),
            ),
            IconButton(
              icon: const Icon(Icons.translate),
              tooltip: 'Print Urdu progress report',
              onPressed: () => _preview(
                  'Annual Progress Report (Urdu)',
                  (f) => _urduPdf(f, result)),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _classId,
                    decoration: fieldDecoration('Class'),
                    items: classes
                        .map((c) => DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _classId = v);
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _sessionCtrl,
                    decoration: fieldDecoration(
                        'Session (e.g. 2026-27, optional)'),
                    onSubmitted: (_) => _reload(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: exams.loading
                ? const LoadingView()
                : result == null
                    ? const EmptyState(
                        message: 'Select a class to view the annual result.')
                    : result.students.isEmpty
                        ? const EmptyState(
                            message: 'No annual results for this class.')
                        : ListView.builder(
                            itemCount: result.students.length,
                            itemBuilder: (_, i) {
                              final s = result.students[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: s.position <= 3 &&
                                            s.position > 0
                                        ? Colors.amber
                                        : Colors.indigo,
                                    child: Text(
                                        s.position == 0
                                            ? '-'
                                            : '${s.position}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold)),
                                  ),
                                  title: Text(s.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      'Obtained ${s.obtained.toStringAsFixed(0)} / ${s.total.toStringAsFixed(0)}'),
                                  trailing: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                          '${s.pct.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold)),
                                      Text(GradingScale.gradeFor(s.pct),
                                          style: const TextStyle(
                                              color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
