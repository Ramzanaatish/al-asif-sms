class FeeHead {
  final int id;
  final String name;
  final double amount;
  final String frequency; // monthly | annual | onetime
  final int? classId;

  const FeeHead({
    required this.id,
    required this.name,
    this.amount = 0,
    this.frequency = 'monthly',
    this.classId,
  });

  factory FeeHead.fromJson(Map<String, dynamic> j) => FeeHead(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        frequency: j['frequency']?.toString() ?? 'monthly',
        classId: (j['class_id'] as num?)?.toInt(),
      );
}

class Challan {
  final int id;
  final String challanNo;
  final int studentId;
  final String studentName;
  final int month;
  final int year;
  final double totalAmount;
  final double discount;
  final double amountPaid;
  final double balance;
  final String status; // unpaid | partial | paid

  const Challan({
    required this.id,
    this.challanNo = '',
    required this.studentId,
    this.studentName = '',
    required this.month,
    required this.year,
    this.totalAmount = 0,
    this.discount = 0,
    this.amountPaid = 0,
    this.balance = 0,
    this.status = 'unpaid',
  });

  factory Challan.fromJson(Map<String, dynamic> j) => Challan(
        id: (j['id'] as num?)?.toInt() ?? 0,
        challanNo: j['challan_no']?.toString() ?? '',
        studentId: (j['student_id'] as num?)?.toInt() ?? 0,
        studentName: j['student_name']?.toString() ?? '',
        month: (j['month'] as num?)?.toInt() ?? 0,
        year: (j['year'] as num?)?.toInt() ?? 0,
        totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        amountPaid: (j['amount_paid'] as num?)?.toDouble() ?? 0,
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        status: j['status']?.toString() ?? 'unpaid',
      );
}

class ReceiptLine {
  final String name;
  final double amount;

  const ReceiptLine({required this.name, this.amount = 0});

  factory ReceiptLine.fromJson(Map<String, dynamic> j) => ReceiptLine(
        name: j['name']?.toString() ?? j['head']?.toString() ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

/// Urdu fee receipt data (from collect response or /api/fees/receipts).
class Receipt {
  final String receiptNo;
  final String date;
  final String studentName;
  final String fatherName;
  final String admissionNo;
  final String className;
  final int month;
  final int year;
  final List<ReceiptLine> lines;
  final double totalFee;
  final double discount;
  final double amountPaid;
  final double balance;
  final String paymentMethod; // cash | bank | online
  final String collectedBy;

  const Receipt({
    this.receiptNo = '',
    this.date = '',
    this.studentName = '',
    this.fatherName = '',
    this.admissionNo = '',
    this.className = '',
    this.month = 0,
    this.year = 0,
    this.lines = const [],
    this.totalFee = 0,
    this.discount = 0,
    this.amountPaid = 0,
    this.balance = 0,
    this.paymentMethod = 'cash',
    this.collectedBy = '',
  });

  factory Receipt.fromJson(Map<String, dynamic> j) {
    final rawLines = (j['lines'] as List?) ??
        (j['heads'] as List?) ??
        (j['items'] as List?) ??
        const [];
    return Receipt(
      receiptNo: j['receipt_no']?.toString() ?? '',
      date: j['date']?.toString() ?? j['created_at']?.toString() ?? '',
      studentName:
          j['student_name']?.toString() ?? j['name']?.toString() ?? '',
      fatherName: j['father_name']?.toString() ??
          j['guardian_name']?.toString() ??
          '',
      admissionNo: j['admission_no']?.toString() ?? '',
      className: j['class_name']?.toString() ?? j['class']?.toString() ?? '',
      month: (j['month'] as num?)?.toInt() ?? 0,
      year: (j['year'] as num?)?.toInt() ?? 0,
      lines: rawLines
          .map((l) => ReceiptLine.fromJson((l as Map).cast<String, dynamic>()))
          .toList(),
      totalFee: (j['total_fee'] as num?)?.toDouble() ??
          (j['total_amount'] as num?)?.toDouble() ??
          0,
      discount: (j['discount'] as num?)?.toDouble() ?? 0,
      amountPaid: (j['amount_paid'] as num?)?.toDouble() ??
          (j['amount'] as num?)?.toDouble() ??
          0,
      balance: (j['balance'] as num?)?.toDouble() ?? 0,
      paymentMethod: j['payment_method']?.toString() ?? 'cash',
      collectedBy: j['collected_by']?.toString() ?? '',
    );
  }
}

class Defaulter {
  final int studentId;
  final String name;
  final String className;
  final String guardianPhone;
  final double balance;

  const Defaulter({
    required this.studentId,
    this.name = '',
    this.className = '',
    this.guardianPhone = '',
    this.balance = 0,
  });

  factory Defaulter.fromJson(Map<String, dynamic> j) => Defaulter(
        studentId: (j['student_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        className: j['class_name']?.toString() ?? '',
        guardianPhone: j['guardian_phone']?.toString() ?? '',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
      );
}

class ClassCollectionRow {
  final String className;
  final double expected;
  final double collected;
  final int defaulters;

  const ClassCollectionRow({
    this.className = '',
    this.expected = 0,
    this.collected = 0,
    this.defaulters = 0,
  });

  factory ClassCollectionRow.fromJson(Map<String, dynamic> j) =>
      ClassCollectionRow(
        className: j['class_name']?.toString() ?? '',
        expected: (j['expected'] as num?)?.toDouble() ?? 0,
        collected: (j['collected'] as num?)?.toDouble() ?? 0,
        defaulters: (j['defaulters'] as num?)?.toInt() ?? 0,
      );
}

class CollectionReport {
  final int month;
  final int year;
  final List<ClassCollectionRow> classes;
  final double expected;
  final double collected;
  final double pct;

  const CollectionReport({
    this.month = 0,
    this.year = 0,
    this.classes = const [],
    this.expected = 0,
    this.collected = 0,
    this.pct = 0,
  });

  factory CollectionReport.fromJson(Map<String, dynamic> j) {
    final rows = (j['classes'] as List?) ?? const [];
    final totals = (j['totals'] as Map?) ?? const {};
    return CollectionReport(
      month: (j['month'] as num?)?.toInt() ?? 0,
      year: (j['year'] as num?)?.toInt() ?? 0,
      classes: rows
          .map((r) =>
              ClassCollectionRow.fromJson((r as Map).cast<String, dynamic>()))
          .toList(),
      expected: (totals['expected'] as num?)?.toDouble() ?? 0,
      collected: (totals['collected'] as num?)?.toDouble() ?? 0,
      pct: (totals['pct'] as num?)?.toDouble() ?? 0,
    );
  }
}
