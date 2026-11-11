class StaffMember {
  final int id;
  final String name;
  final String staffType; // teaching | non_teaching
  final String designation;
  final String phone;
  final String cnic;
  final double salaryMonthly;
  final String? joiningDate;
  final String status;
  // HTML staff fields (Complete v7 Add Staff popup): Urdu name, assigned
  // class and login password ride in the data JSON — the server's staff
  // record has no such fields, so they are local-only.
  final String nameUrdu;
  final String className;
  final String password;

  const StaffMember({
    required this.id,
    required this.name,
    this.staffType = 'teaching',
    this.designation = '',
    this.phone = '',
    this.cnic = '',
    this.salaryMonthly = 0,
    this.joiningDate,
    this.status = 'active',
    this.nameUrdu = '',
    this.className = '',
    this.password = '',
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        staffType: j['staff_type']?.toString() ?? 'teaching',
        designation: j['designation']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        cnic: j['cnic']?.toString() ?? '',
        salaryMonthly: (j['salary_monthly'] as num?)?.toDouble() ?? 0,
        joiningDate: j['joining_date']?.toString(),
        status: j['status']?.toString() ?? 'active',
        nameUrdu: j['name_urdu']?.toString() ?? '',
        className: j['class_name']?.toString() ?? '',
        password: j['password']?.toString() ?? '',
      );

  /// Role label for the table (the HTML's role column): the designation
  /// when set, otherwise Teacher / Staff by type.
  String get roleLabel =>
      designation.isNotEmpty
          ? designation
          : (staffType == 'teaching' ? 'Teacher' : 'Staff');
}

class StaffLeave {
  final int id;
  final int staffId;
  final String staffName;
  final String fromDate;
  final String toDate;
  final String reason;
  final String status; // pending | approved | rejected

  const StaffLeave({
    required this.id,
    required this.staffId,
    this.staffName = '',
    this.fromDate = '',
    this.toDate = '',
    this.reason = '',
    this.status = 'pending',
  });

  factory StaffLeave.fromJson(Map<String, dynamic> j) => StaffLeave(
        id: (j['id'] as num?)?.toInt() ?? 0,
        staffId: (j['staff_id'] as num?)?.toInt() ?? 0,
        staffName: j['staff_name']?.toString() ?? '',
        fromDate: j['from_date']?.toString() ?? '',
        toDate: j['to_date']?.toString() ?? '',
        reason: j['reason']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pending',
      );
}

class SalaryRecord {
  final int id;
  final int staffId;
  final String staffName;
  final int month;
  final int year;
  final double basic;
  final double allowances;
  final double deductions;
  final double net;

  const SalaryRecord({
    required this.id,
    required this.staffId,
    this.staffName = '',
    required this.month,
    required this.year,
    this.basic = 0,
    this.allowances = 0,
    this.deductions = 0,
    this.net = 0,
  });

  factory SalaryRecord.fromJson(Map<String, dynamic> j) => SalaryRecord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        staffId: (j['staff_id'] as num?)?.toInt() ?? 0,
        staffName: j['staff_name']?.toString() ?? '',
        month: (j['month'] as num?)?.toInt() ?? 0,
        year: (j['year'] as num?)?.toInt() ?? 0,
        basic: _d(j['basic'] ?? j['basic_amount']),
        allowances: _d(j['allowances']),
        deductions: _d(j['deductions']),
        net: _d(j['net'] ?? j['net_amount']),
      );
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
