import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import '../models/fee.dart';
import 'pdf_assets.dart';

/// Prints fee challans 6 per A4 page (2 columns x 3 rows), mirroring the
/// HTML's printed challan card: Urdu header, student + class + B-Form +
/// contact, item rows, arrears, due date, and the total due.
class ChallanBatchPdf {
  static Future<List<int>> build(
    List<Challan> challans, {
    required Map<int, Map<String, dynamic>> students,
    required Map<int, double> arrearsByStudent,
  }) async {
    final font = await PdfAssets.urduFont();
    final pdf = pw.Document();

    pw.Widget cell(Challan c) {
      final s = students[c.studentId] ?? {};
      final arrears = arrearsByStudent[c.studentId] ?? 0;
      final urduMonth = PdfAssets.urduMonthName(c.month);
      final lines = c.items.isEmpty
          ? [ReceiptLine(name: c.head, amount: c.totalAmount)]
          : c.items;
      pw.Widget line(String label, String value, {bool bold = false}) {
        return pw.Row(
          children: [
            pw.Expanded(
                child: pw.Text(value,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight:
                            bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
            PdfAssets.urduText('$label:', font,
                size: 8.5, color: PdfAssets.grey),
          ],
        );
      }

      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                PdfAssets.urduText(
                    '${AppConfig.schoolNameUrdu}®', font,
                    size: 10, bold: true, color: PdfAssets.navy),
                pw.Text('No: ${c.challanNo}',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            PdfAssets.urduText(
                'فیس چالان — $urduMonth  ·  سیشن 2025-26', font,
                size: 8, color: PdfAssets.grey),
            pw.Divider(height: 6, thickness: 0.5),
            line('نام', s['name_urdu']?.toString().isNotEmpty == true
                ? s['name_urdu'].toString()
                : c.studentName, bold: true),
            line('والد کا نام', s['father_urdu']?.toString().isNotEmpty == true
                ? s['father_urdu'].toString()
                : (s['father']?.toString() ?? '')),
            line('جماعت', s['class']?.toString() ?? ''),
            line('داخلہ نمبر', s['admission_no']?.toString() ?? ''),
            line('بی فارم', s['b_form']?.toString() ?? ''),
            line('رابطہ', s['contact']?.toString() ?? ''),
            pw.Divider(height: 6, thickness: 0.5),
            for (final item in lines)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rs ${item.amount.toStringAsFixed(0)}',
                      style: const pw.TextStyle(fontSize: 8.5)),
                  PdfAssets.urduText(item.name, font, size: 8.5),
                ],
              ),
            if (arrears > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rs ${arrears.toStringAsFixed(0)}',
                      style: const pw.TextStyle(fontSize: 8.5)),
                  PdfAssets.urduText('بقایا جات', font, size: 8.5),
                ],
              ),
            pw.Divider(height: 6, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Rs ${(c.totalAmount + arrears).toStringAsFixed(0)}',
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                PdfAssets.urduText('کل واجب الادا', font,
                    size: 8.5, bold: true),
              ],
            ),
            pw.SizedBox(height: 2),
            PdfAssets.urduText(
                'آخری تاریخ: 10 $urduMonth', font,
                size: 8, color: PdfAssets.grey),
          ],
        ),
      );
    }

    for (var i = 0; i < challans.length; i += 6) {
      final chunk = challans.sublist(
          i, i + 6 > challans.length ? challans.length : i + 6);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => pw.Column(
            children: [
              pw.Text(
                '${AppConfig.schoolNameRegistered} — Fee Challans',
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
