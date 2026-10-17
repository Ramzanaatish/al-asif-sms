import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import '../models/student.dart';
import 'pdf_assets.dart';

/// Formal English school leaving certificate.
class LeavingCertificatePdf {
  static Future<List<int>> build({
    required Student student,
    required String certificateNo,
    required String leavingDate,
    required String reason,
    required String issueDate,
  }) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;
    final gold = PdfAssets.gold;

    pw.Widget field(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('$label: ',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: navy)),
            pw.Expanded(
              child: pw.Text(value,
                  style: const pw.TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
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
                    'SCHOOL LEAVING CERTIFICATE',
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
                    pw.Text('Certificate No: $certificateNo',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date of Issue: $issueDate',
                        style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'This is to certify that the following student was on the rolls of this school:',
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 10),
                field('Student Name', student.name),
                field('Admission No', student.admissionNo),
                field('Class', student.className.isEmpty
                    ? '-'
                    : '${student.className}${student.sectionName.isNotEmpty ? ' (${student.sectionName})' : ''}'),
                field('Date of Birth', student.dob ?? '-'),
                field(
                    'Guardian',
                    student.guardianName.isEmpty
                        ? '-'
                        : '${student.guardianName} (${student.guardianRelation.isEmpty ? 'Guardian' : student.guardianRelation})'),
                field('Date of Admission', student.admissionDate ?? '-'),
                field('Date of Leaving', leavingDate),
                field('Reason for Leaving', reason),
                pw.SizedBox(height: 14),
                pw.Text(
                  'The student bears a good moral character to the best of our knowledge. '
                  'We wish him/her success in future endeavours.',
                  style: const pw.TextStyle(fontSize: 11, height: 1.5),
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
