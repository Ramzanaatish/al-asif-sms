import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/student.dart';
import '../../printing/leaving_certificate.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Print preview of the leaving certificate after the mark-left flow.
class LeavingCertificatePreviewScreen extends StatelessWidget {
  final Student student;
  final String certificateNo;
  final String leavingDate;
  final String reason;

  const LeavingCertificatePreviewScreen({
    super.key,
    required this.student,
    required this.certificateNo,
    required this.leavingDate,
    required this.reason,
  });

  Future<Uint8List> _build(PdfPageFormat format) async {
    final bytes = await LeavingCertificatePdf.build(
      student: student,
      certificateNo: certificateNo,
      leavingDate: leavingDate,
      reason: reason,
      issueDate: ymd(DateTime.now()),
    );
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Leaving Certificate'),
      body: PdfPreview(
        build: _build,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
      ),
    );
  }
}
