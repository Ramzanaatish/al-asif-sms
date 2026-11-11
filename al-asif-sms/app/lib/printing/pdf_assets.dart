import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config.dart';
import 'urdu_text.dart';

/// Shared PDF resources: logo, Urdu font, colours, letterheads.
///
/// NOTE on the Urdu font: the bundled NotoNastaliqUrdu.ttf does not contain
/// the Arabic Presentation Forms glyphs (verified by inspecting its cmap),
/// and the `pdf` package cannot do OpenType shaping — so raw Urdu would print
/// as disconnected letters. Urdu PDF text is therefore pre-shaped with
/// [ar] (arabic_reshaper) and rendered with Amiri (OFL, has full presentation
/// forms incl. Urdu-specific letters), loaded here via rootBundle.
class PdfAssets {
  static pw.MemoryImage? _logo;
  static pw.Font? _urduFont;

  static Future<pw.MemoryImage> logo() async {
    if (_logo != null) return _logo!;
    final data = await rootBundle.load('assets/logo.png');
    _logo = pw.MemoryImage(data.buffer.asUint8List());
    return _logo!;
  }

  static Future<pw.Font> urduFont() async {
    if (_urduFont != null) return _urduFont!;
    final data = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    _urduFont = pw.Font.ttf(data);
    return _urduFont!;
  }

  static PdfColor get navy => PdfColor.fromInt(0xFF1A237E);
  static PdfColor get gold => PdfColor.fromInt(0xFFC9A227);
  static PdfColor get grey => PdfColors.grey700;

  /// Urdu month names, in the HTML's MONTHS_URDU order.
  static const List<String> urduMonths = [
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
    'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
  ];

  /// Urdu name of month [month] (1-12), e.g. 11 -> 'نومبر'.
  static String urduMonthName(int month) =>
      (month >= 1 && month <= 12) ? urduMonths[month - 1] : '';

  /// English letterhead: logo left, registered school name centred.
  static pw.Widget letterhead(pw.MemoryImage logoImg, {double size = 13}) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logoImg, width: 58, height: 58),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    AppConfig.schoolNameRegistered,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: size,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Basti Shaikhan, Zafar Abad',
                    style: pw.TextStyle(fontSize: 9, color: grey),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 70), // balances the logo for centred text
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 2.5, color: gold),
        pw.SizedBox(height: 10),
      ],
    );
  }

  /// Urdu letterhead: reshaped RTL text, right aligned, logo at the right.
  static pw.Widget urduLetterhead(pw.MemoryImage logoImg, pw.Font font,
      {double size = 15}) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  urduText(
                    'الآصف پبلک مڈل سکول بستی شیخاں رجسٹرڈ',
                    font,
                    size: size,
                    bold: true,
                    color: navy,
                  ),
                  pw.SizedBox(height: 3),
                  urduText('بستی شیخاں، ظفر آباد', font,
                      size: 10, color: grey),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Image(logoImg, width: 58, height: 58),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 2.5, color: gold),
        pw.SizedBox(height: 10),
      ],
    );
  }

  /// A single Urdu text run: pre-shaped, right aligned, LTR visual order.
  static pw.Widget urduText(
    String text,
    pw.Font font, {
    double size = 12,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    return pw.Text(
      ar(text),
      textAlign: align,
      style: pw.TextStyle(
        font: font,
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColors.black,
      ),
    );
  }

  /// Label : value row for Urdu documents (label right, value left of it).
  static pw.Widget urduField(
      String label, String value, pw.Font font, double size) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: urduText(value, font, size: size, bold: true),
          ),
          pw.SizedBox(width: 10),
          urduText('$label :', font, size: size, color: grey),
        ],
      ),
    );
  }

  static pw.Widget signatureBlock(String name, String title,
      {double width = 160}) {
    return pw.SizedBox(
      width: width,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 34),
          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 4),
          pw.Text(name,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(title, style: pw.TextStyle(fontSize: 9, color: grey)),
        ],
      ),
    );
  }
}
