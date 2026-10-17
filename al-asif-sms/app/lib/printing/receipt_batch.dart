import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import '../models/fee.dart';
import 'pdf_assets.dart';
import 'urdu_text.dart';

/// Compact Urdu fee receipts, 6 per A4 page (2 columns x 3 rows).
class ReceiptBatchPdf {
  static Future<List<int>> build(List<Receipt> receipts) async {
    final logo = await PdfAssets.logo();
    final font = await PdfAssets.urduFont();
    final pdf = pw.Document();

    pw.Widget cell(Receipt r) {
      pw.Widget line(String label, String value, {bool bold = false}) {
        return pw.Row(
          children: [
            pw.Expanded(
              child: PdfAssets.urduText(value, font,
                  size: 8.5, bold: bold),
            ),
            PdfAssets.urduText('$label:', font,
                size: 8.5, color: PdfAssets.grey),
          ],
        );
      }

      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Row(
              children: [
                pw.Expanded(
                  child: PdfAssets.urduText(
                    'الآصف پبلک مڈل سکول بستی شیخاں ®',
                    font,
                    size: 9.5,
                    bold: true,
                    color: PdfAssets.navy,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Image(logo, width: 26, height: 26),
              ],
            ),
            pw.Container(height: 1.2, color: PdfAssets.gold),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('No: ${r.receiptNo}',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                PdfAssets.urduText(r.date, font, size: 8),
              ],
            ),
            pw.SizedBox(height: 2),
            line('نام', r.studentName, bold: true),
            line('والد کا نام', r.fatherName),
            pw.Row(
              children: [
                pw.Expanded(
                    child: PdfAssets.urduText(
                        '${r.month}/${r.year}', font,
                        size: 8.5, bold: true)),
                PdfAssets.urduText('مہینہ:', font,
                    size: 8.5, color: PdfAssets.grey),
                pw.SizedBox(width: 8),
                pw.Expanded(
                    child: PdfAssets.urduText(r.className, font,
                        size: 8.5, bold: true)),
                PdfAssets.urduText('جماعت:', font,
                    size: 8.5, color: PdfAssets.grey),
              ],
            ),
            pw.Divider(height: 6, thickness: 0.5),
            pw.Row(
              children: [
                pw.Expanded(
                    child: pw.Text('Rs ${r.totalFee.toStringAsFixed(0)}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8.5))),
                PdfAssets.urduText('کل فیس:', font,
                    size: 8.5, color: PdfAssets.grey),
                pw.SizedBox(width: 8),
                pw.Expanded(
                    child: pw.Text('Rs ${r.discount.toStringAsFixed(0)}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8.5))),
                PdfAssets.urduText('رعایت:', font,
                    size: 8.5, color: PdfAssets.grey),
              ],
            ),
            pw.Row(
              children: [
                pw.Expanded(
                    child: pw.Text('Rs ${r.amountPaid.toStringAsFixed(0)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold))),
                PdfAssets.urduText('وصول شدہ:', font,
                    size: 8.5, color: PdfAssets.grey),
                pw.SizedBox(width: 8),
                pw.Expanded(
                    child: pw.Text('Rs ${r.balance.toStringAsFixed(0)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: r.balance > 0
                                ? PdfColors.red800
                                : PdfColors.green800))),
                PdfAssets.urduText('بقایا:', font,
                    size: 8.5, color: PdfAssets.grey),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                PdfAssets.urduText(urduPaymentMethod(r.paymentMethod), font,
                    size: 8),
                PdfAssets.urduText('دستخط: __________', font, size: 8),
              ],
            ),
          ],
        ),
      );
    }

    for (var i = 0; i < receipts.length; i += 6) {
      final chunk = receipts.sublist(
          i, i + 6 > receipts.length ? receipts.length : i + 6);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => pw.Column(
            children: [
              pw.Text(
                '${AppConfig.schoolNameRegistered} — Fee Receipts',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfAssets.navy),
              ),
              pw.SizedBox(height: 8),
              pw.Expanded(
                child: pw.GridView(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.02,
                  children: chunk.map(cell).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }
}
