import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/exam.dart';
import '../../printing/result_monthly.dart';
import '../../providers/academics_provider.dart';
import '../../providers/exams_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class MonthlyResultScreen extends StatefulWidget {
  const MonthlyResultScreen({super.key});

  @override
  State<MonthlyResultScreen> createState() => _MonthlyResultScreenState();
}

class _MonthlyResultScreenState extends State<MonthlyResultScreen> {
  int? _termId;
  int? _classId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamsProvider>().loadTerms();
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  void _reload() {
    if (_termId != null && _classId != null) {
      context
          .read<ExamsProvider>()
          .loadMonthlyResult(termId: _termId, classId: _classId);
    }
  }

  Future<Uint8List> _buildPdf(PdfPageFormat f, ClassResult r) async =>
      Uint8List.fromList(await MonthlyResultPdf.build(r));

  @override
  Widget build(BuildContext context) {
    final exams = context.watch<ExamsProvider>();
    final classes = context.watch<AcademicsProvider>().classes;
    final result = exams.monthlyResult;
    return Scaffold(
      appBar: SchoolAppBar(
        title: 'Monthly Result',
        actions: [
          if (result != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print result',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar:
                        const SchoolAppBar(title: 'Monthly Result - Print'),
                    body: PdfPreview(
                      build: (f) => _buildPdf(f, result),
                      allowSharing: true,
                      allowPrinting: true,
                      canChangePageFormat: false,
                    ),
                  ),
                ),
              ),
            ),
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
                    value: _termId,
                    decoration: fieldDecoration('Term'),
                    items: exams.terms
                        .map((t) => DropdownMenuItem<int?>(
                            value: t.id, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _termId = v);
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
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
              ],
            ),
          ),
          Expanded(
            child: exams.loading
                ? const LoadingView()
                : result == null
                    ? const EmptyState(
                        message: 'Select term and class to view results.')
                    : result.students.isEmpty
                        ? const EmptyState(
                            message: 'No results for this selection.')
                        : _table(result),
          ),
        ],
      ),
    );
  }

  Widget _table(ClassResult result) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            const DataColumn(
                label:
                    Text('Pos', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(
                label: Text('Student',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            ...result.subjects.map((s) => DataColumn(
                label: Text(s,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)))),
            const DataColumn(
                label:
                    Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(
                label:
                    Text('%', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(
                label: Text('Grade',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: result.students
              .map((s) => DataRow(cells: [
                    DataCell(Text(s.position == 0 ? '-' : '${s.position}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                    DataCell(Text(s.name)),
                    ...result.subjects.map((sub) => DataCell(Text(
                        s.marks[sub]?.toStringAsFixed(0) ?? '-'))),
                    DataCell(Text(s.obtained.toStringAsFixed(0))),
                    DataCell(Text('${s.pct.toStringAsFixed(1)}%')),
                    DataCell(Text(GradingScale.gradeFor(s.pct),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold))),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}
