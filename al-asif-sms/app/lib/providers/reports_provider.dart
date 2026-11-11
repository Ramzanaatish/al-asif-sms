import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/academics.dart';
import '../models/student.dart';
import '../printing/attendance_register.dart';
import '../printing/benazir_slip.dart';
import '../printing/character_certificate.dart';
import '../printing/defaulter_list.dart';
import '../printing/experience_certificate.dart';
import '../printing/fee_collection_report.dart';
import '../printing/leaving_certificate.dart';
import '../printing/profit_loss_report.dart';
import '../printing/reports_summary.dart';
import '../printing/student_result.dart';
import '../repositories/academics_repository.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/exams_repository.dart';
import '../repositories/expenses_repository.dart';
import '../repositories/fees_repository.dart';
import '../repositories/school_info_repository.dart';
import '../repositories/staff_repository.dart';
import '../repositories/student_repository.dart';

/// Provider for the Reports screen (HTML parity): the 9-type Report
/// Generator plus the Monthly Collection Report and Class Strength
/// tables. Each generated report is a PDF (English Cambria for result
/// / leaving / character / attendance / experience, Urdu for fee
/// collection / defaulter / P&L, English for Benazir — as in v7).
class ReportsProvider extends ChangeNotifier {
  final _students = StudentRepository();
  final _academics = AcademicsRepository();
  final _exams = ExamsRepository();
  final _fees = FeesRepository();
  final _expenses = ExpensesRepository();
  final _attendance = AttendanceRepository();
  final _staff = StaffRepository();
  final _schoolInfo = SchoolInfoRepository();

  List<Student> students = [];
  List<ClassInfo> classes = [];
  List<Map<String, dynamic>> perHead = [];
  List<Map<String, dynamic>> classStrength = [];
  bool loading = false;
  String? error;

  /// The last generated report (title + PDF bytes) for the output card.
  String? generatedTitle;
  List<int>? generatedPdf;

  Future<void> loadBase() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      students = await _students.list(status: 'all');
      classes = await _academics.classes();
      final now = DateTime.now();
      perHead = await _fees.perHeadCollection(
          month: now.month, year: now.year);
      classStrength = classes
          .map((c) => {
                'class': c.name,
                'teacher': AppConfig.classTeacher(c.name),
                'students': c.studentCount,
              })
          .toList();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  static String dateEn(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  Future<StudentResultCard> _resultCard(
      Student student, String termName) async {
    final classId = student.classId ?? 0;
    final term = await _exams.ensureTerm(termName);
    final subjects = await _academics.subjectsForClass(classId);
    final marks = <({String subject, int total, int? obtained})>[];
    for (final subject in subjects) {
      final stored =
          await _academics.ensureSubject(classId, subject.name);
      final total = await _exams.markTotal(
          classId: classId, subjectId: stored.id, termId: term.id);
      final rows = await _exams.marks(
          termId: term.id, classId: classId, subjectId: stored.id);
      final row = rows
          .where((r) => (r['student_id'] as num).toInt() == student.id)
          .firstOrNull;
      marks.add((
        subject: subject.name,
        total: total,
        obtained: row == null
            ? null
            : (row['obtained_marks'] as num?)?.toInt(),
      ));
    }
    return StudentResultPdf.fromMarks(
      studentName: student.name,
      fatherName: student.guardianName,
      className: student.className,
      admissionNo: student.admissionNo,
      rollNo: student.rollNumber?.toString() ?? '-',
      term: termName,
      marks: marks,
      date: dateEn(DateTime.now()),
    );
  }

  Future<void> generateResultCard(int studentId, String termName) async {
    final student =
        students.where((s) => s.id == studentId).firstOrNull;
    if (student == null) throw Exception('Student not found');
    final card = await _resultCard(student, termName);
    generatedPdf = await StudentResultPdf.buildSingle(card);
    generatedTitle =
        'Result Card — ${student.name} — $termName';
    notifyListeners();
  }

  Future<void> generateBulkResultCards(String termName) async {
    final active =
        students.where((s) => s.status == 'active').toList();
    final cards = <StudentResultCard>[];
    for (final s in active) {
      cards.add(await _resultCard(s, termName));
    }
    generatedPdf = await StudentResultPdf.buildBulk(cards);
    generatedTitle = 'All School Result Cards — $termName (${cards.length})';
    notifyListeners();
  }

  Future<void> generateLeaving(int studentId) async {
    final student =
        students.where((s) => s.id == studentId).firstOrNull;
    if (student == null) throw Exception('Student not found');
    generatedPdf = await LeavingCertificatePdf.build(
      student: student,
      certificateNo: 'LC-${student.admissionNo}',
      leavingDate: student.leavingDate ?? dateEn(DateTime.now()),
      reason: student.leavingReason ?? '',
      issueDate: dateEn(DateTime.now()),
    );
    generatedTitle = 'School Leaving Certificate — ${student.name}';
    notifyListeners();
  }

  Future<void> generateCharacter(int studentId) async {
    final student =
        students.where((s) => s.id == studentId).firstOrNull;
    if (student == null) throw Exception('Student not found');
    generatedPdf = await CharacterCertificatePdf.build(
      student: student,
      certificateNo: 'CC-${student.admissionNo}',
      date: dateEn(DateTime.now()),
    );
    generatedTitle = 'Character Certificate — ${student.name}';
    notifyListeners();
  }

  Future<void> generateBenazir(int studentId) async {
    final student =
        students.where((s) => s.id == studentId).firstOrNull;
    if (student == null) throw Exception('Student not found');
    final info = await _schoolInfo.get();
    generatedPdf = await BenazirSlipPdf.build(
      student: student,
      motherName: student.motherName,
      emisCode: info.emis,
      schoolAddress: info.address,
      tehsil: info.tehsil,
      teacherName: AppConfig.classTeacher(student.className),
      teacherContact: '',
      group: student.groupName,
      isNewAdmission: student.admStatus == 'New',
      outOfSchoolStatus: 0,
      schoolType: info.type.toLowerCase().startsWith('govt')
          ? 'govt'
          : info.type.toLowerCase().startsWith('semi')
              ? 'semi'
              : info.type.toLowerCase().startsWith('community')
                  ? 'community'
                  : 'private',
      shift: info.shift.toLowerCase(),
    );
    generatedTitle = 'Benazir Verification Slip — ${student.name}';
    notifyListeners();
  }

  Future<void> generateAttendance(
      int classId, int month, int year) async {
    final reg = await _attendance.register(
        classId: classId, month: month, year: year);
    final className = classes
            .where((c) => c.id == classId)
            .firstOrNull
            ?.name ??
        '';
    generatedPdf = await AttendanceRegisterPdf.build(
      className: className,
      monthName: _months[month - 1],
      year: year,
      daysInMonth: reg.daysInMonth,
      totalDays: reg.totalDays,
      students: reg.students,
      cells: reg.cells,
    );
    generatedTitle =
        'Monthly Attendance Report — $className — ${_months[month - 1]} $year';
    notifyListeners();
  }

  Future<void> generateCollection(int month, int year) async {
    final report =
        await _fees.collectionReport(month: month, year: year);
    generatedPdf = await FeeCollectionReportPdf.build(report);
    generatedTitle = 'Fee Collection Report — ${_months[month - 1]} $year';
    notifyListeners();
  }

  Future<void> generateDefaulter() async {
    final defaulters = await _fees.allDefaulters();
    // Attach Urdu names for the PDF.
    for (final d in defaulters) {
      final s = students
          .where((s) => s.id == d['student_id'])
          .firstOrNull;
      if (s != null) d['name_urdu'] = s.nameUrdu;
    }
    generatedPdf = await DefaulterListPdf.build(defaulters);
    generatedTitle = 'Defaulter List Report';
    notifyListeners();
  }

  Future<void> generateProfitLoss(int month, int year) async {
    final report =
        await _expenses.profitLoss(month: month, year: year);
    generatedPdf = await ProfitLossPdf.build(
        report: report, monthName: _months[month - 1], year: year);
    generatedTitle = 'Profit & Loss Report — ${_months[month - 1]} $year';
    notifyListeners();
  }

  Future<void> generateExperience(
      String teacherName, String fromDate, String toDate) async {
    final staff = await _staff.list(status: 'all');
    final teacher =
        staff.where((s) => s.name == teacherName).firstOrNull;
    if (teacher == null) throw Exception('Teacher not found');
    generatedPdf = await ExperienceCertificatePdf.build(
      teacher: teacher,
      fromDate: dateEn(DateTime.parse(fromDate)),
      toDate: dateEn(DateTime.parse(toDate)),
    );
    generatedTitle = 'Teacher Experience Certificate — $teacherName';
    notifyListeners();
  }

  Future<List<int>> printSummary() async {
    final now = DateTime.now();
    return ReportsSummaryPdf.build(
      monthName: _months[now.month - 1],
      year: now.year,
      perHead: perHead,
      classStrength: classStrength,
    );
  }

  void clearGenerated() {
    generatedTitle = null;
    generatedPdf = null;
    notifyListeners();
  }
}
