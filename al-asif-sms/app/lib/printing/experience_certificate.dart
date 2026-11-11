import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import '../models/staff.dart';
import 'pdf_assets.dart';

/// Teacher experience certificate (landscape, single A4, English),
/// matching the HTML's experienceCert.
class ExperienceCertificatePdf {
  static Future<List<int>> build({
    required StaffMember teacher,
    required String fromDate,
    required String toDate,
  }) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;
    final gold = PdfAssets.gold;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (ctx) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: navy, width: 2.5),
          ),
          padding: const pw.EdgeInsets.all(10),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: gold, width: 1),
            ),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 28, vertical: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                PdfAssets.letterhead(logo),
                pw.Center(
                  child: pw.Text(
                    'EXPERIENCE CERTIFICATE',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Date: $toDate',
                    style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 16),
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 12, height: 1.6),
                    children: [
                      const pw.TextSpan(
                          text: 'This is to certify that '),
                      pw.TextSpan(
                          text: teacher.name,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(text: ' worked as '),
                      pw.TextSpan(
                          text: teacher.roleLabel,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(
                          text:
                              ' at Al-Asif Public Middle School Basti Shaikhan® from '),
                      pw.TextSpan(
                          text: fromDate,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(text: ' to '),
                      pw.TextSpan(
                          text: toDate,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(text: '.'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 12, height: 1.6),
                    children: [
                      const pw.TextSpan(
                          text: 'During this period he/she taught Class '),
                      pw.TextSpan(
                          text: teacher.className.isEmpty
                              ? '-'
                              : teacher.className,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(
                          text:
                              '. His/Her character, conduct and teaching standard remained good.'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 12),
                    children: [
                      const pw.TextSpan(text: 'Monthly Salary: '),
                      pw.TextSpan(
                          text:
                              'Rs ${teacher.salaryMonthly.toStringAsFixed(0)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 150,
                      height: 90,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColors.grey500, width: 0.8),
                      ),
                      child: pw.Center(
                        child: pw.Text('School Stamp',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfAssets.grey)),
                      ),
                    ),
                    PdfAssets.signatureBlock(
                        AppConfig.principalName, 'Principal'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return pdf.save();
  }
}
