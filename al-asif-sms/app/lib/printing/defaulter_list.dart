import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_assets.dart';

/// Defaulter list (Urdu), matching the HTML's defaulterList: student
/// (Urdu name when available), class, unpaid challan numbers, total due.
class DefaulterListPdf {
  static Future<List<int>> build(
      List<Map<String, dynamic>> defaulters) async {
    final font = await PdfAssets.urduFont();
    final logo = await PdfAssets.logo();
    final pdf = pw.Document();
    final navy = PdfAssets.navy;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            PdfAssets.urduLetterhead(logo, font),
            pw.Center(
              child: PdfAssets.urduText('بقایا جات فہرست', font,
                  size: 15, bold: true, color: navy),
            ),
            pw.SizedBox(height: 10),
            if (defaulters.isEmpty)
              PdfAssets.urduText(
                  'کوئی بقایا نہیں — تمام فیس ادا ہو چکی ہے۔', font,
                  size: 11)
            else
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(2.5),
                  3: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFE8EAF6)),
                    children: [
                      PdfAssets.urduText('طالب علم', font,
                          size: 10, bold: true, color: navy),
                      PdfAssets.urduText('جماعت', font,
                          size: 10, bold: true, color: navy),
                      PdfAssets.urduText('بقایا چالان', font,
                          size: 10, bold: true, color: navy),
                      PdfAssets.urduText('کل بقایا', font,
                          size: 10, bold: true, color: navy),
                    ],
                  ),
                  for (final d in defaulters)
                    pw.TableRow(children: [
                      PdfAssets.urduText(
                          (d['name_urdu']?.toString().isNotEmpty == true)
                              ? d['name_urdu'].toString()
                              : (d['name']?.toString() ?? ''),
                          font,
                          size: 10),
                      PdfAssets.urduText(
                          d['class_name']?.toString() ?? '', font,
                          size: 10),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            (d['challan_nos'] as List? ?? []).join(', '),
                            style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            'Rs ${(d['due'] as num?)?.toStringAsFixed(0) ?? '0'}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ]),
                ],
              ),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
