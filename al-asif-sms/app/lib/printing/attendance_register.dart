import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_assets.dart';

/// Monthly attendance register (landscape, English), matching the
/// HTML's attendanceReport: one column per day of the month with P/A/L
/// cells, then Present / Absent / Leave / % totals per student.
class AttendanceRegisterPdf {
  static Future<List<int>> build({
    required String className,
    required String monthName,
    required int year,
    required int daysInMonth,
    required int totalDays,
    required List<Map<String, dynamic>> students,
    required Map<int, Map<int, String>> cells,
  }) async {
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;

    pw.Widget cell(String t, {bool bold = false, bool header = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(2),
          child: pw.Text(t,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: (bold || header)
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: header ? navy : PdfColors.black)),
        );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) {
          if (totalDays == 0) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                PdfAssets.letterhead(logo, size: 11),
                pw.Center(
                  child: pw.Text(
                      'Monthly Attendance Register — $className — $monthName $year',
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: navy)),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Attendance for this month has not been recorded yet. Please save attendance on the Attendance page first.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            );
          }
          final headerRow = pw.TableRow(
            decoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
            children: [
              cell('Student', header: true),
              for (var d = 1; d <= daysInMonth; d++)
                cell('$d', header: true),
              cell('Present', header: true),
              cell('Absent', header: true),
              cell('Leave', header: true),
              cell('%', header: true),
            ],
          );
          final rows = <pw.TableRow>[];
          for (final s in students) {
            final sid = (s['id'] as num).toInt();
            final dayCells = cells[sid] ?? {};
            var p = 0, a = 0, l = 0;
            for (final v in dayCells.values) {
              if (v == 'P') p++;
              if (v == 'A') a++;
              if (v == 'L') l++;
            }
            final pct =
                totalDays > 0 ? (p * 100 / totalDays).round() : 0;
            rows.add(pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: pw.Text(s['name']?.toString() ?? '',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              for (var d = 1; d <= daysInMonth; d++)
                cell(dayCells[d] ?? ''),
              cell('$p', bold: true),
              cell('$a', bold: true),
              cell('$l', bold: true),
              cell('$pct%', bold: true),
            ]));
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              PdfAssets.letterhead(logo, size: 11),
              pw.Center(
                child: pw.Text(
                    'Monthly Attendance Register — $className — $monthName $year',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: navy)),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Total Days: $totalDays    (P = Present, A = Absent, L = Leave)',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [headerRow, ...rows],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
