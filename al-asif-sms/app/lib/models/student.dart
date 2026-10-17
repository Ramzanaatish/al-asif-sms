class StudentDocument {
  final String name;
  final bool received;

  const StudentDocument({required this.name, required this.received});

  factory StudentDocument.fromJson(Map<String, dynamic> j) => StudentDocument(
        name: j['name']?.toString() ?? '',
        received: j['received'] == true,
      );

  Map<String, dynamic> toJson() => {'name': name, 'received': received};
}

class Student {
  final int id;
  final String admissionNo;
  final int? rollNumber;
  final String name;
  final String? dob;
  final String gender;
  final int? classId;
  final String className;
  final int? sectionId;
  final String sectionName;
  final String guardianName;
  final String guardianPhone;
  final String guardianRelation;
  final String address;
  final String status; // active | left
  final String? photoPath;
  final List<StudentDocument> documents;
  final double? attendancePct;
  final double? feeBalance;
  // Leaving-certificate fields (populated after mark-left)
  final String? leavingDate;
  final String? leavingReason;
  final String? admissionDate;

  const Student({
    required this.id,
    required this.admissionNo,
    this.rollNumber,
    required this.name,
    this.dob,
    this.gender = '',
    this.classId,
    this.className = '',
    this.sectionId,
    this.sectionName = '',
    this.guardianName = '',
    this.guardianPhone = '',
    this.guardianRelation = '',
    this.address = '',
    this.status = 'active',
    this.photoPath,
    this.documents = const [],
    this.attendancePct,
    this.feeBalance,
    this.leavingDate,
    this.leavingReason,
    this.admissionDate,
  });

  factory Student.fromJson(Map<String, dynamic> j) {
    final docs = (j['documents'] as List?) ?? const [];
    return Student(
      id: (j['id'] as num?)?.toInt() ?? 0,
      admissionNo: j['admission_no']?.toString() ?? '',
      rollNumber: (j['roll_number'] as num?)?.toInt(),
      name: j['name']?.toString() ?? '',
      dob: j['dob']?.toString(),
      gender: j['gender']?.toString() ?? '',
      classId: (j['class_id'] as num?)?.toInt(),
      className: j['class_name']?.toString() ?? '',
      sectionId: (j['section_id'] as num?)?.toInt(),
      sectionName: j['section_name']?.toString() ?? '',
      guardianName: j['guardian_name']?.toString() ?? '',
      guardianPhone: j['guardian_phone']?.toString() ?? '',
      guardianRelation: j['guardian_relation']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      status: j['status']?.toString() ?? 'active',
      photoPath: j['photo_path']?.toString(),
      documents: docs
          .map((d) => StudentDocument.fromJson((d as Map).cast<String, dynamic>()))
          .toList(),
      attendancePct: (j['attendance_pct'] as num?)?.toDouble(),
      feeBalance: (j['fee_balance'] as num?)?.toDouble(),
      leavingDate: j['leaving_date']?.toString(),
      leavingReason: j['leaving_reason']?.toString(),
      admissionDate: j['admission_date']?.toString(),
    );
  }

  bool get isActive => status == 'active';
}
