import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/expense.dart';
import 'pdf_assets.dart';

/// Profit & Loss report (Urdu), matching the HTML's profitLossReport:
/// fee income, expense rows by category, total expenses, net profit/loss.
class ProfitLossPdf {
  static Future<List<int>> build({
    required ProfitLoss report,
    required String monthName,
    required int year,
  }) async {
    final font = await PdfAssets.urduFont();
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;

    pw.Widget row(String label, String value, {bool bold = false}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          PdfAssets.urduText(label, font,
              size: 10, bold: bold),
        ],
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            PdfAssets.urduLetterhead(logo, font),
            pw.Center(
              child: PdfAssets.urduText(
                  'نفع و نقصان رپورٹ — ${PdfAssets.urduMonthName(report.month)} $year',
                  font,
                  size: 15, bold: true, color: navy),
            ),
            pw.SizedBox(height: 12),
            row('آمدنی (فیس وصولی)',
                'Rs ${report.feeCollected.toStringAsFixed(0)}',
                bold: true),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8EAF6)),
                  children: [
                    PdfAssets.urduText('اخراجات', font,
                        size: 10, bold: true, color: navy),
                    PdfAssets.urduText('رقم', font,
                        size: 10, bold: true, color: navy),
                  ],
                ),
                if (report.expensesByCategory.isEmpty)
                  pw.TableRow(children: [
                    PdfAssets.urduText('کوئی اخراجات نہیں', font, size: 10),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Rs 0',
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ])
                else
                  for (final c in report.expensesByCategory)
                    pw.TableRow(children: [
                      PdfAssets.urduText(c.category, font, size: 10),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            'Rs ${c.amount.toStringAsFixed(0)}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ]),
                pw.TableRow(children: [
                  PdfAssets.urduText('کل اخراجات', font,
                      size: 10, bold: true),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                        'Rs ${report.totalOutgoing.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ]),
              ],
            ),
            pw.SizedBox(height: 10),
            row(report.netProfit >= 0 ? 'خالص نفع' : 'خالص نقصان',
                'Rs ${report.netProfit.toStringAsFixed(0)}',
                bold: true),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
