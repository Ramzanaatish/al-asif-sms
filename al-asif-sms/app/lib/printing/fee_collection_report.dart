import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/fee.dart';
import '../widgets/ui_helpers.dart' show monthName;
import 'pdf_assets.dart';

/// English whole-school fee collection report: class-wise expected /
/// collected / defaulters table + totals.
class FeeCollectionReportPdf {
  static Future<List<int>> build(CollectionReport report) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;

    pw.Widget cell(String t,
        {bool bold = false, pw.TextAlign align = pw.TextAlign.center}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => ctx.pageNumber == 1
            ? PdfAssets.letterhead(logo, size: 11)
            : pw.SizedBox(),
        build: (ctx) => [
          pw.Center(
            child: pw.Text('Fee Collection Report',
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: navy)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
                '${monthName(report.month)} ${report.year}',
                style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border:
                pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
                children: ['Class', 'Expected (Rs)', 'Collected (Rs)',
                        'Defaulters']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navy)),
                        ))
                    .toList(),
              ),
              ...report.classes.map(
                (c) => pw.TableRow(
                  children: [
                    cell(c.className, bold: true,
                        align: pw.TextAlign.left),
                    cell(c.expected.toStringAsFixed(0)),
                    cell(c.collected.toStringAsFixed(0)),
                    cell('${c.defaulters}'),
                  ],
                ),
              ),
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5E9C8)),
                children: [
                  cell('TOTAL', bold: true, align: pw.TextAlign.left),
                  cell(report.expected.toStringAsFixed(0), bold: true),
                  cell(report.collected.toStringAsFixed(0), bold: true),
                  cell(
                      '${report.classes.fold<int>(0, (p, c) => p + c.defaulters)}',
                      bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
              'Collection rate: ${report.pct.toStringAsFixed(1)}%',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfAssets.signatureBlock('Accountant', 'Accountant'),
              PdfAssets.signatureBlock('Mrs. Hajra Iqbal', 'Principal'),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
