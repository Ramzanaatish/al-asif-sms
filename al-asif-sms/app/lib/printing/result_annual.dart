import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/exam.dart';
import 'pdf_assets.dart';

/// English annual result card: aggregated totals with grading-scale legend.
class AnnualResultPdf {
  static Future<List<int>> build(ClassResult result) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => ctx.pageNumber == 1
            ? PdfAssets.letterhead(logo, size: 11)
            : pw.SizedBox(),
        build: (ctx) => [
          pw.Center(
            child: pw.Text('Annual Result Card',
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: navy)),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text('Class: ${result.className}',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border:
                pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
            children: [
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
                children: ['Pos', 'Student Name', 'Total Marks',
                        'Obtained', '%', 'Grade']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navy)),
                        ))
                    .toList(),
              ),
              ...result.students.map(
                (s) => pw.TableRow(
                  children: [
                    _c(s.position == 0 ? '-' : '${s.position}', true),
                    _l(s.name, true),
                    _c(s.total.toStringAsFixed(0), false),
                    _c(s.obtained.toStringAsFixed(0), true),
                    _c('${s.pct.toStringAsFixed(1)}%', true),
                    _c(GradingScale.gradeFor(s.pct), true),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfAssets.gold, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Grading Scale',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: navy)),
                pw.SizedBox(height: 6),
                pw.Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: GradingScale.legend
                      .map((g) => pw.Text('${g[0]}  (${g[1]})',
                          style: const pw.TextStyle(fontSize: 9)))
                      .toList(),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfAssets.signatureBlock('Class Teacher', 'Class Teacher'),
              PdfAssets.signatureBlock('Mrs. Hajra Iqbal', 'Principal'),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _c(String t, bool bold) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _l(String t, bool bold) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );
}
