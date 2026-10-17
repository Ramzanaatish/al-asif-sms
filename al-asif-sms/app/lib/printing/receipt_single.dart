import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/fee.dart';
import 'pdf_assets.dart';
import 'urdu_text.dart';

/// Full-size Urdu fee receipt (one per A4 page), RTL.
///
/// Fields: رسید نمبر، تاریخ، نام، والد کا نام، جماعت، داخلہ نمبر، مہینہ،
/// کل فیس، رعایت، وصول شدہ رقم، بقایا، بذریعہ، وصول کنندہ + دستخط.
class ReceiptSinglePdf {
  static Future<List<int>> build(Receipt r) async {
    final logo = await PdfAssets.logo();
    final font = await PdfAssets.urduFont();
    final pdf = pw.Document();

    const labelSize = 12.0;

    pw.Widget row(String label, String value, {bool boldValue = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: PdfAssets.urduText(value, font,
                  size: labelSize, bold: boldValue),
            ),
            pw.SizedBox(width: 12),
            PdfAssets.urduText('$label :', font,
                size: labelSize, color: PdfAssets.grey),
          ],
        ),
      );
    }

    pw.Widget moneyRow(String label, double amount, {bool big = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Rs ${amount.toStringAsFixed(0)}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: big ? 15 : labelSize,
                  fontWeight:
                      big ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            PdfAssets.urduText('$label :', font,
                size: labelSize, color: PdfAssets.grey),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            PdfAssets.urduLetterhead(logo, font),
            pw.SizedBox(height: 6),
            PdfAssets.urduText('فیس رسید', font,
                size: 22, bold: true, color: PdfAssets.navy, align: pw.TextAlign.center),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('No: ${r.receiptNo}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                PdfAssets.urduText('تاریخ : ${r.date}', font, size: 11),
              ],
            ),
            pw.Divider(color: PdfAssets.gold, thickness: 1),
            pw.SizedBox(height: 6),
            row('نام', r.studentName, boldValue: true),
            row('والد کا نام', r.fatherName),
            row('جماعت', r.className),
            row('داخلہ نمبر', r.admissionNo),
            row('مہینہ', '${r.month} / ${r.year}'),
            pw.SizedBox(height: 8),
            if (r.lines.isNotEmpty) ...[
              PdfAssets.urduText('تفصیل', font,
                  size: 13, bold: true, color: PdfAssets.navy),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey500, width: 0.6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.4),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: PdfAssets.urduText('رقم', font,
                            size: 11, bold: true, align: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: PdfAssets.urduText('مد', font,
                            size: 11, bold: true, align: pw.TextAlign.center),
                      ),
                    ],
                  ),
                  ...r.lines.map(
                    (l) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Rs ${l.amount.toStringAsFixed(0)}',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: PdfAssets.urduText(l.name, font, size: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
            moneyRow('کل فیس', r.totalFee),
            moneyRow('رعایت', r.discount),
            moneyRow('وصول شدہ رقم', r.amountPaid, big: true),
            moneyRow('بقایا', r.balance, big: true),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(
                  child: PdfAssets.urduText(
                      urduPaymentMethod(r.paymentMethod), font,
                      size: labelSize, bold: true),
                ),
                pw.SizedBox(width: 12),
                PdfAssets.urduText('بذریعہ :', font,
                    size: labelSize, color: PdfAssets.grey),
              ],
            ),
            row('وصول کنندہ', r.collectedBy),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.SizedBox(height: 40),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    PdfAssets.urduText('دستخط وصول کنندہ', font, size: 10),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(
                      width: 150,
                      height: 70,
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                              color: PdfColors.grey500, width: 0.8)),
                      child: pw.Center(
                        child: PdfAssets.urduText('مہر', font,
                            size: 12, color: PdfAssets.grey),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    PdfAssets.urduText('دستخط پرنسپل', font, size: 10),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'This is a computer generated receipt.',
                style: pw.TextStyle(fontSize: 8, color: PdfAssets.grey),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
