import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import '../models/student.dart';
import 'pdf_assets.dart';

/// Formal English character certificate (landscape, single A4),
/// matching the HTML's characterCert.
class CharacterCertificatePdf {
  static Future<List<int>> build({
    required Student student,
    required String certificateNo,
    required String date,
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
                    'CHARACTER CERTIFICATE',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('No.: $certificateNo',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: $date',
                        style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 12, height: 1.6),
                    children: [
                      const pw.TextSpan(
                          text: 'This is to certify that '),
                      pw.TextSpan(
                          text: student.name,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(text: ' son/daughter of '),
                      pw.TextSpan(
                          text: student.guardianName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(text: ' is a student of Class '),
                      pw.TextSpan(
                          text: student.className,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(text: ' at this school. Admission No. is '),
                      pw.TextSpan(
                          text: student.admissionNo,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      const pw.TextSpan(text: '.'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'His/Her character, conduct and behaviour in the school have remained good.',
                  style: const pw.TextStyle(fontSize: 12, height: 1.6),
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
