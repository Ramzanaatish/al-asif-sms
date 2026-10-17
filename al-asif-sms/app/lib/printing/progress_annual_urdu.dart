import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/exam.dart';
import 'pdf_assets.dart';
import 'urdu_text.dart';

/// Urdu RTL annual progress report: سالانہ ترقی رپورٹ.
///
/// Per-student one-page report with subject-wise marks, attendance %,
/// conduct (اخلاق و سیرت), teacher remarks (استاد کی رائے) and signatures.
class AnnualProgressUrduPdf {
  static Future<List<int>> build({
    required ClassResult result,
    Map<int, double> attendancePct = const {},
    Map<int, String> remarks = const {},
    String conductDefault = 'بہت اچھا',
  }) async {
    final logo = await PdfAssets.logo();
    final font = await PdfAssets.urduFont();
    final pdf = pw.Document();

    // Subject totals: derive per-subject max from the top obtained mark.
    final subjectTotals = <String, double>{};
    for (final sub in result.subjects) {
      var mx = 0.0;
      for (final s in result.students) {
        final v = s.marks[sub] ?? 0;
        if (v > mx) mx = v;
      }
      subjectTotals[sub] = mx > 0 ? mx : 100;
    }

    for (final s in result.students) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              PdfAssets.urduLetterhead(logo, font),
              PdfAssets.urduText('سالانہ ترقی رپورٹ', font,
                  size: 20,
                  bold: true,
                  color: PdfAssets.navy,
                  align: pw.TextAlign.center),
              pw.SizedBox(height: 8),
              _info('نام', s.name, font),
              _info('جماعت', result.className, font),
              _info('پوزیشن',
                  s.position == 0 ? '-' : '${s.position}', font),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey500, width: 0.6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.4),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(0.9),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFE8EAF6)),
                    children: [
                      _h('مضمون', font),
                      _h('کل نمبر', font),
                      _h('حاصل کردہ نمبر', font),
                      _h('فیصد', font),
                      _h('گریڈ', font),
                    ],
                  ),
                  ...result.subjects.map((sub) {
                    final total = subjectTotals[sub] ?? 100;
                    final obt = s.marks[sub] ?? 0;
                    final pct = total > 0 ? obt / total * 100 : 0.0;
                    return pw.TableRow(
                      children: [
                        _cell(sub, font, bold: true),
                        _num(total.toStringAsFixed(0)),
                        _num(obt.toStringAsFixed(0)),
                        _num('${pct.toStringAsFixed(1)}%'),
                        _num(_grade(pct)),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF5E9C8)),
                    children: [
                      _cell('کل', font, bold: true),
                      _num(result.subjects
                          .fold<double>(
                              0, (p, sub) => p + (subjectTotals[sub] ?? 100))
                          .toStringAsFixed(0)),
                      _num(s.obtained.toStringAsFixed(0)),
                      _num('${s.pct.toStringAsFixed(1)}%'),
                      _num(_grade(s.pct)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              _info(
                  'حاضری',
                  attendancePct.containsKey(s.studentId)
                      ? '${attendancePct[s.studentId]!.toStringAsFixed(1)} %'
                      : '-',
                  font),
              _info('اخلاق و سیرت', conductDefault, font),
              pw.SizedBox(height: 4),
              PdfAssets.urduText('استاد کی رائے :', font,
                  size: 11, color: PdfAssets.grey),
              pw.Container(
                height: 52,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.grey400, width: 0.6)),
                padding: const pw.EdgeInsets.all(6),
                child: PdfAssets.urduText(
                    remarks[s.studentId] ?? '', font,
                    size: 11),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 36),
                      pw.Container(
                          width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      PdfAssets.urduText('دستخط استاد', font, size: 10),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 36),
                      pw.Container(
                          width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      PdfAssets.urduText('مسز حاجرہ اقبال', font,
                          size: 10, bold: true),
                      PdfAssets.urduText('پرنسپل', font, size: 10),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _info(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
              child: PdfAssets.urduText(value, font,
                  size: 11, bold: true)),
          pw.SizedBox(width: 10),
          PdfAssets.urduText('$label :', font,
              size: 11, color: PdfAssets.grey),
        ],
      ),
    );
  }

  static pw.Widget _h(String t, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: PdfAssets.urduText(t, font,
            size: 10, bold: true, align: pw.TextAlign.center),
      );

  static pw.Widget _cell(String t, pw.Font font, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: PdfAssets.urduText(t, font,
            size: 10, bold: bold),
      );

  static pw.Widget _num(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10)),
      );

  static String _grade(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    if (pct >= 40) return 'E';
    return 'F';
  }
}
