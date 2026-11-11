import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import '../repositories/exams_repository.dart';
import 'pdf_assets.dart';

/// One student's subject marks for one term (the HTML's resultCard data).
class StudentResultCard {
  final String studentName;
  final String fatherName;
  final String className;
  final String admissionNo;
  final String rollNo;
  final String term;
  final List<({String subject, int total, int? obtained, String grade})>
      subjects;
  final int totalMarks;
  final int obtainedMarks;
  final int pct;
  final String overallGrade;
  final String result; // Pass | Fail
  final String date;

  const StudentResultCard({
    required this.studentName,
    required this.fatherName,
    required this.className,
    required this.admissionNo,
    required this.rollNo,
    required this.term,
    required this.subjects,
    required this.totalMarks,
    required this.obtainedMarks,
    required this.pct,
    required this.overallGrade,
    required this.result,
    required this.date,
  });
}

/// Per-student Detailed Marks Certificate (BISE BWP style, English),
/// matching the HTML's resultCard. Single card = one page; bulk =
/// two cards per A4 page with a tear line, like the HTML.
class StudentResultPdf {
  static pw.Widget _card(StudentResultCard c, pw.MemoryImage logo) {
    final navy = PdfAssets.navy;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: navy, width: 1.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          PdfAssets.letterhead(logo, size: 11),
          pw.Center(
            child: pw.Text('Detailed Marks Certificate — ${c.term}',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: navy)),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(2.6),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(2.6),
            },
            children: [
              _infoRow('Student Name:', c.studentName, 'Admission No:',
                  c.admissionNo, bold: true),
              _infoRow('Father Name:', c.fatherName, 'Class:',
                  c.className),
              _infoRow('Roll No:', c.rollNo, 'Date:', c.date),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
                children: ['Sr', 'Subject', 'Total', 'Obtained', 'Grade']
                    .map((h) => _h(h))
                    .toList(),
              ),
              for (var i = 0; i < c.subjects.length; i++)
                pw.TableRow(children: [
                  _c('${i + 1}'),
                  _l(c.subjects[i].subject),
                  _c('${c.subjects[i].total}'),
                  _c(c.subjects[i].obtained?.toString() ?? '-'),
                  _c(c.subjects[i].grade),
                ]),
              pw.TableRow(children: [
                _c(''),
                _l('Total', bold: true),
                _c('${c.totalMarks}', bold: true),
                _c('${c.obtainedMarks}', bold: true),
                _c('', bold: true),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Percentage: ${c.pct}%',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Grade: ${c.overallGrade}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Result: ${c.result}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              PdfAssets.signatureBlock('Class Teacher', 'Class Teacher'),
              PdfAssets.signatureBlock(
                  AppConfig.principalName, 'Principal'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.TableRow _infoRow(
      String l1, String v1, String l2, String v2,
      {bool bold = false}) {
    final style = pw.TextStyle(
        fontSize: 11,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.TableRow(children: [
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(l1,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold))),
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(v1, style: style)),
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(l2,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold))),
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(v2, style: style)),
    ]);
  }

  static pw.Widget _h(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfAssets.navy)),
      );

  static pw.Widget _c(String t, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _l(String t, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static Future<List<int>> buildSingle(StudentResultCard card) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => _card(card, logo),
      ),
    );
    return pdf.save();
  }

  static Future<List<int>> buildBulk(List<StudentResultCard> cards) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    for (var i = 0; i < cards.length; i += 2) {
      final chunk = cards.sublist(
          i, i + 2 > cards.length ? cards.length : i + 2);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => pw.Column(
            children: [
              pw.Expanded(child: _card(chunk[0], logo)),
              if (chunk.length > 1) ...[
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Row(children: [
                    pw.Expanded(
                        child: pw.Divider(
                            borderStyle: pw.BorderStyle.dashed,
                            thickness: 0.8)),
                    pw.Padding(
                      padding:
                          const pw.EdgeInsets.symmetric(horizontal: 6),
                      child: pw.Text('✂',
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Expanded(
                        child: pw.Divider(
                            borderStyle: pw.BorderStyle.dashed,
                            thickness: 0.8)),
                  ]),
                ),
                pw.Expanded(child: _card(chunk[1], logo)),
              ],
            ],
          ),
        ),
      );
    }
    return pdf.save();
  }

  /// Build a card's data from one student's marks (grade via the same
  /// scale as the Exams screen).
  static StudentResultCard fromMarks({
    required String studentName,
    required String fatherName,
    required String className,
    required String admissionNo,
    required String rollNo,
    required String term,
    required List<({String subject, int total, int? obtained})> marks,
    required String date,
  }) {
    var total = 0, obtained = 0;
    final rows = <({String subject, int total, int? obtained, String grade})>[];
    for (final m in marks) {
      total += m.total;
      if (m.obtained != null) obtained += m.obtained!;
      rows.add((
        subject: m.subject,
        total: m.total,
        obtained: m.obtained,
        grade: m.obtained == null
            ? '-'
            : ExamsRepository.gradeFor(
                m.obtained!.toDouble(), m.total.toDouble()),
      ));
    }
    final pct = total > 0 ? (obtained * 100 / total).round() : 0;
    return StudentResultCard(
      studentName: studentName,
      fatherName: fatherName,
      className: className,
      admissionNo: admissionNo,
      rollNo: rollNo,
      term: term,
      subjects: rows,
      totalMarks: total,
      obtainedMarks: obtained,
      pct: pct,
      overallGrade: ExamsRepository.gradeFor(
          obtained.toDouble(), total.toDouble()),
      result: pct >= 40 ? 'Pass' : 'Fail',
      date: date,
    );
  }
}
