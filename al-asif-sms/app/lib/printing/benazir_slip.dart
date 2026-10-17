import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/student.dart';
import 'pdf_assets.dart';
import 'urdu_text.dart';

/// BISP "Benazir Taleemi Wazaif" SCHOOL/COLLEGE VERIFICATION SLIP.
/// Auto-filled from the student record; a few fields (mother name, EMIS code,
/// teacher, group, statuses) are supplied by the caller.
class BenazirSlipPdf {
  static Future<List<int>> build({
    required Student student,
    required String motherName,
    required String emisCode,
    required String schoolAddress,
    required String tehsil,
    required String teacherName,
    required String teacherContact,
    required String group,
    required bool isNewAdmission,
    required int outOfSchoolStatus, // 0=none,1=out,2=dropped,3=regular
    required String schoolType, // govt|private|semi|community
    required String shift, // morning|evening
  }) async {
    final logo = await PdfAssets.logo();
    final urduFont = await PdfAssets.urduFont();
    final pdf = pw.Document();
    final green = PdfColor.fromInt(0xFF1B7A2E);
    final darkGreen = PdfColor.fromInt(0xFF0E5A1F);

    pw.Widget tick(bool on) => pw.Container(
          width: 13,
          height: 13,
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1)),
          alignment: pw.Alignment.center,
          child: on
              ? pw.Text('✓',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold))
              : pw.SizedBox(),
        );

    pw.Widget line(String label, String value, {double flex = 1}) =>
        pw.Expanded(
          flex: flex.toInt(),
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 10, bottom: 7),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('$label: ',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(
                            bottom: pw.BorderSide(
                                color: PdfColors.black, width: 0.8))),
                    padding: const pw.EdgeInsets.only(bottom: 1, left: 2),
                    child: pw.Text(value,
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
        );

    pw.Widget checkRow(String text, bool on) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(text, style: const pw.TextStyle(fontSize: 9.5)),
            pw.SizedBox(width: 4),
            tick(on),
            pw.SizedBox(width: 10),
          ],
        );

    final isPrivate = schoolType == 'private';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(22),
        build: (ctx) => pw.Container(
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: green, width: 2)),
          padding: const pw.EdgeInsets.all(14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 74,
                    height: 74,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border:
                            pw.Border.all(color: darkGreen, width: 2)),
                    alignment: pw.Alignment.center,
                    child: pw.Image(logo, width: 62, height: 62),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          color: green,
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          child: pw.Text(
                            ar('بینظیر تعلیم وظائف'),
                            style: pw.TextStyle(
                                font: urduFont,
                                fontSize: 15,
                                color: PdfColors.white),
                            textDirection: pw.TextDirection.ltr,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text('SCHOOL/COLLEGE VERIFICATION SLIP',
                            style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                decoration: pw.TextDecoration.underline)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 74),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(children: [
                line('Student Name', student.name, flex: 2),
                line('Father Name', student.guardianName, flex: 2),
                line('Mother Name', motherName, flex: 2),
              ]),
              pw.Row(children: [
                line('School Name', 'Al-Asif Public Middle School', flex: 3),
                line('School EMIS/College Code', emisCode, flex: 2),
              ]),
              pw.Row(children: [
                line('School/College Address', schoolAddress, flex: 3),
                line('Tehsil', tehsil, flex: 2),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Text('Type of School:  ',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                checkRow('1. Govt. School', schoolType == 'govt'),
                checkRow('2. Private', isPrivate),
                checkRow('3. Semi Private', schoolType == 'semi'),
                checkRow('4. Community School', schoolType == 'community'),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Spacer(),
                checkRow('a. Morning Shift', shift == 'morning'),
                checkRow('b. Evening Shift', shift == 'evening'),
              ]),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Text('Class: ',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                tick(true),
                pw.SizedBox(width: 6),
                pw.Text(student.className,
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(width: 14),
                line('Section', student.sectionName),
                line('Group', group),
                line('GER/Admission #', student.admissionNo, flex: 2),
              ]),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Text('Admission status at the time of enrollment:  ',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                checkRow('1. New Admission', isNewAdmission),
                checkRow('2. Old Admission', !isNewAdmission),
              ]),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Text('Child Out of School:  ',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                checkRow('1. Out of School\n(Delayed Admission by 2 years)',
                    outOfSchoolStatus == 1),
                checkRow('2. Dropped Out\n(1 Year gap)',
                    outOfSchoolStatus == 2),
                checkRow('3. Regular', outOfSchoolStatus == 3),
              ]),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                line('Teacher Name', teacherName, flex: 2),
                line('Teacher Contact', teacherContact, flex: 2),
              ]),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 190,
                    height: 90,
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColors.black, width: 1)),
                    alignment: pw.Alignment.bottomCenter,
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text('Signature:',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return pdf.save();
  }
}
