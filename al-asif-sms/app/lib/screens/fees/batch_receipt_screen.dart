import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/fee.dart';
import '../../printing/receipt_batch.dart';
import '../../providers/academics_provider.dart';
import '../../providers/fees_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Batch printing: pick month/class, select receipts, preview 6-per-A4.
class BatchReceiptScreen extends StatefulWidget {
  const BatchReceiptScreen({super.key});

  @override
  State<BatchReceiptScreen> createState() => _BatchReceiptScreenState();
}

class _BatchReceiptScreenState extends State<BatchReceiptScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int? _classId;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
      _reload();
    });
  }

  void _reload() {
    _selected.clear();
    context
        .read<FeesProvider>()
        .loadReceipts(month: _month, year: _year, classId: _classId);
  }

  Future<Uint8List> _buildPdf(
      PdfPageFormat f, List<Receipt> receipts) async =>
      Uint8List.fromList(await ReceiptBatchPdf.build(receipts));

  void _preview(List<Receipt> selected) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar:
              const SchoolAppBar(title: 'Batch Receipts (6 per A4)'),
          body: PdfPreview(
            build: (f) => _buildPdf(f, selected),
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
    final classes = context.watch<AcademicsProvider>().classes;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Batch Receipts'),
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
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _classId,
                    decoration: fieldDecoration('Class'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All')),
                      ...classes.map((c) => DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.name))),
                    ],
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
            child: Consumer<FeesProvider>(
              builder: (_, p, __) {
                if (p.loading) return const LoadingView();
                if (p.error != null) {
                  return EmptyState(
                      message: p.error!, icon: Icons.cloud_off_outlined);
                }
                if (p.receipts.isEmpty) {
                  return const EmptyState(
                      message: 'No receipts for this period.');
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_selected.length} selected'),
                          TextButton(
                            onPressed: () => setState(() {
                              if (_selected.length ==
                                  p.receipts.length) {
                                _selected.clear();
                              } else {
                                _selected.addAll(p.receipts
                                    .map((r) => r.receiptNo));
                              }
                            }),
                            child: Text(_selected.length ==
                                    p.receipts.length
                                ? 'Clear all'
                                : 'Select all'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: p.receipts.length,
                        itemBuilder: (_, i) {
                          final r = p.receipts[i];
                          final sel =
                              _selected.contains(r.receiptNo);
                          return CheckboxListTile(
                            value: sel,
                            title: Text(r.studentName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                'Receipt ${r.receiptNo} - ${fmtMoney(r.amountPaid)}'),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(r.receiptNo);
                              } else {
                                _selected.remove(r.receiptNo);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Consumer<FeesProvider>(
            builder: (_, p, __) {
              final selected = p.receipts
                  .where((r) => _selected.contains(r.receiptNo))
                  .toList();
              if (selected.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: Text(
                        'Preview & Print ${selected.length} Receipts'),
                    onPressed: () => _preview(selected),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
