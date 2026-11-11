import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_assets.dart';

/// The Reports screen's summary tables as one printable page: the
/// Monthly Collection Report (per fee head) and the Class Strength
/// table, matching the HTML's summary cards.
class ReportsSummaryPdf {
  static Future<List<int>> build({
    required String monthName,
    required int year,
    required List<Map<String, dynamic>> perHead,
    required List<Map<String, dynamic>> classStrength,
  }) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;

    pw.Widget h(String t) => pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: navy)),
        );

    pw.Widget c(String t, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    var totCh = 0, totPaid = 0;
    var totAmt = 0.0;
    for (final r in perHead) {
      totCh += (r['challans'] as num?)?.toInt() ?? 0;
      totPaid += (r['paid'] as num?)?.toInt() ?? 0;
      totAmt += (r['amount'] as num?)?.toDouble() ?? 0;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            PdfAssets.letterhead(logo, size: 11),
            pw.Center(
              child: pw.Text('Monthly Collection Report — $monthName $year',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: navy)),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8EAF6)),
                  children: [
                    h('Fee Head'), h('Challans'), h('Paid'),
                    h('Amount Collected'),
                  ],
                ),
                for (final r in perHead)
                  pw.TableRow(children: [
                    c(r['head']?.toString() ?? ''),
                    c('${r['challans'] ?? 0}'),
                    c('${r['paid'] ?? 0}'),
                    c('Rs ${(r['amount'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                  ]),
                pw.TableRow(children: [
                  c('Total', bold: true),
                  c('$totCh', bold: true),
                  c('$totPaid', bold: true),
                  c('Rs ${totAmt.toStringAsFixed(0)}', bold: true),
                ]),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text('Class Strength',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: navy)),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8EAF6)),
                  children: [
                    h('Class'), h('Teacher'), h('Students'),
                  ],
                ),
                for (final r in classStrength)
                  pw.TableRow(children: [
                    c(r['class']?.toString() ?? ''),
                    c(r['teacher']?.toString() ?? ''),
                    c('${r['students'] ?? 0}'),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
