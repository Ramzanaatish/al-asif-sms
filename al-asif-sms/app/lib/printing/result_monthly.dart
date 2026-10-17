import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/exam.dart';
import 'pdf_assets.dart';

/// English monthly test result: term, class, subject columns, totals, %, grade, position.
class MonthlyResultPdf {
  static Future<List<int>> build(ClassResult result) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;

    final headerCells = <String>[
      'Pos',
      'Student Name',
      ...result.subjects,
      'Total',
      '%',
      'Grade'
    ];

    List<pw.TableRow> rows() {
      final out = <pw.TableRow>[
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
          children: headerCells
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(h,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: navy)),
                  ))
              .toList(),
        ),
      ];
      for (final s in result.students) {
        out.add(
          pw.TableRow(
            children: [
              _c(s.position == 0 ? '-' : '${s.position}', bold: true),
              _l(s.name, bold: true),
              ...result.subjects.map((sub) => _c(
                  s.marks[sub]?.toStringAsFixed(0) ?? '-')),
              _c(s.obtained.toStringAsFixed(0), bold: true),
              _c('${s.pct.toStringAsFixed(1)}%', bold: true),
              _c(GradingScale.gradeFor(s.pct), bold: true),
            ],
          ),
        );
      }
      return out;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => ctx.pageNumber == 1
            ? PdfAssets.letterhead(logo, size: 11)
            : pw.SizedBox(),
        build: (ctx) => [
          pw.Center(
            child: pw.Text('Monthly Test Result',
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: navy)),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Term: ${result.term}    ',
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Class: ${result.className}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border:
                pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
            children: rows(),
          ),
          pw.SizedBox(height: 12),
          _legend(),
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

  static pw.Widget _c(String t, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(t,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _l(String t, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _legend() {
    return pw.Wrap(
      spacing: 10,
      children: GradingScale.legend
          .map((g) => pw.Text('${g[0]}: ${g[1]}',
              style: pw.TextStyle(fontSize: 8, color: PdfAssets.grey)))
          .toList(),
    );
  }
}
