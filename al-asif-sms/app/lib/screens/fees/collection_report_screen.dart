import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/fee.dart';
import '../../printing/fee_collection_report.dart';
import '../../providers/fees_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class CollectionReportScreen extends StatefulWidget {
  const CollectionReportScreen({super.key});

  @override
  State<CollectionReportScreen> createState() => _CollectionReportScreenState();
}

class _CollectionReportScreenState extends State<CollectionReportScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() =>
      context.read<FeesProvider>().loadReport(month: _month, year: _year);

  Future<Uint8List> _buildPdf(
          PdfPageFormat f, CollectionReport r) async =>
      Uint8List.fromList(await FeeCollectionReportPdf.build(r));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SchoolAppBar(
        title: 'Collection Report',
        actions: [
          Consumer<FeesProvider>(
            builder: (_, p, __) => p.report == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.print),
                    tooltip: 'Print report',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: const SchoolAppBar(
                              title: 'Collection Report - Print'),
                          body: PdfPreview(
                            build: (f) => _buildPdf(f, p.report!),
                            allowSharing: true,
                            allowPrinting: true,
                            canChangePageFormat: false,
                          ),
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
                  child: DropdownButtonFormField<int>(
                    value: _month,
                    decoration: fieldDecoration('Month'),
                    items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(monthName(i + 1)))),
                    onChanged: (v) {
                      setState(() => _month = v ?? _month);
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    decoration: fieldDecoration('Year'),
                    items: [for (var y = _year - 2; y <= _year + 1; y++) y]
                        .map((y) => DropdownMenuItem(
                            value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _year = v ?? _year);
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<FeesProvider>(
              builder: (_, p, __) {
                if (p.loading) return const LoadingView();
                if (p.error != null) {
                  return EmptyState(
                      message: p.error!, icon: Icons.cloud_off_outlined);
                }
                final r = p.report;
                if (r == null || r.classes.isEmpty) {
                  return const EmptyState(
                      message: 'No collection data for this period.');
                }
                return ListView(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      color: AppColors.navy,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _total('Expected', fmtMoney(r.expected)),
                            _total('Collected', fmtMoney(r.collected)),
                            _total('Rate',
                                '${r.pct.toStringAsFixed(1)}%'),
                          ],
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(
                              label: Text('Class',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold))),
                          DataColumn(
                              label: Text('Expected',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold))),
                          DataColumn(
                              label: Text('Collected',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold))),
                          DataColumn(
                              label: Text('Defaulters',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold))),
                        ],
                        rows: r.classes
                            .map((c) => DataRow(cells: [
                                  DataCell(Text(c.className,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600))),
                                  DataCell(Text(fmtMoney(c.expected))),
                                  DataCell(Text(
                                      fmtMoney(c.collected),
                                      style: const TextStyle(
                                          color: AppColors.success,
                                          fontWeight:
                                              FontWeight.w600))),
                                  DataCell(Text('${c.defaulters}',
                                      style: TextStyle(
                                          color: c.defaulters > 0
                                              ? AppColors.danger
                                              : Colors.black54,
                                          fontWeight:
                                              FontWeight.w600))),
                                ]))
                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _total(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
