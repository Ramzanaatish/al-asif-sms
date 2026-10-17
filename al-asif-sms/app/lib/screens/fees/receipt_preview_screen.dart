import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/fee.dart';
import '../../printing/receipt_single.dart';
import '../../widgets/school_app_bar.dart';

/// Full-size Urdu receipt preview shown right after a single fee collection,
/// with Print and Share buttons (via PdfPreview).
class ReceiptPreviewScreen extends StatelessWidget {
  final Receipt receipt;
  const ReceiptPreviewScreen({super.key, required this.receipt});

  Future<Uint8List> _build(PdfPageFormat format) async =>
      Uint8List.fromList(await ReceiptSinglePdf.build(receipt));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Fee Receipt'),
      body: PdfPreview(
        build: _build,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
      ),
    );
  }
}
