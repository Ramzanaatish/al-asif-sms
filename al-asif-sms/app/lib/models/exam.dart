class Term {
  final int id;
  final String name;
  final String termType; // monthly | annual
  final int? sessionId;
  final String? startDate;
  final String? endDate;

  const Term({
    required this.id,
    required this.name,
    this.termType = 'monthly',
    this.sessionId,
    this.startDate,
    this.endDate,
  });

  factory Term.fromJson(Map<String, dynamic> j) => Term(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        termType: j['term_type']?.toString() ?? 'monthly',
        sessionId: (j['session_id'] as num?)?.toInt(),
        startDate: j['start_date']?.toString(),
        endDate: j['end_date']?.toString(),
      );
}

class DateSheetEntry {
  final int id;
  final int? termId;
  final int? classId;
  final String className;
  final int? subjectId;
  final String subjectName;
  final String examDate;
  final String startTime;

  const DateSheetEntry({
    required this.id,
    this.termId,
    this.classId,
    this.className = '',
    this.subjectId,
    this.subjectName = '',
    this.examDate = '',
    this.startTime = '',
  });

  factory DateSheetEntry.fromJson(Map<String, dynamic> j) => DateSheetEntry(
        id: (j['id'] as num?)?.toInt() ?? 0,
        termId: (j['term_id'] as num?)?.toInt(),
        classId: (j['class_id'] as num?)?.toInt(),
        className: j['class_name']?.toString() ?? '',
        subjectId: (j['subject_id'] as num?)?.toInt(),
        subjectName: j['subject_name']?.toString() ?? '',
        examDate: j['exam_date']?.toString() ?? '',
        startTime: j['start_time']?.toString() ?? '',
      );
}

class ResultStudent {
  final int studentId;
  final String name;
  final Map<String, double> marks; // subject -> obtained
  final double total;
  final double obtained;
  final double pct;
  final int position;

  const ResultStudent({
    required this.studentId,
    required this.name,
    this.marks = const {},
    this.total = 0,
    this.obtained = 0,
    this.pct = 0,
    this.position = 0,
  });

  factory ResultStudent.fromJson(Map<String, dynamic> j) {
    final m = <String, double>{};
    final raw = (j['marks'] as Map?) ?? const {};
    raw.forEach((k, v) => m[k.toString()] = (v as num?)?.toDouble() ?? 0);
    return ResultStudent(
      studentId: (j['student_id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      marks: m,
      total: (j['total'] as num?)?.toDouble() ?? 0,
      obtained: (j['obtained'] as num?)?.toDouble() ?? 0,
      pct: (j['pct'] as num?)?.toDouble() ?? 0,
      position: (j['position'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClassResult {
  final String term;
  final String className;
  final List<String> subjects;
  final List<ResultStudent> students;

  const ClassResult({
    this.term = '',
    this.className = '',
    this.subjects = const [],
    this.students = const [],
  });

  factory ClassResult.fromJson(Map<String, dynamic> j) {
    final subs = (j['subjects'] as List?) ?? const [];
    final studs = (j['students'] as List?) ?? const [];
    return ClassResult(
      term: j['term']?.toString() ?? '',
      className: j['class']?.toString() ?? j['class_name']?.toString() ?? '',
      subjects: subs.map((s) => s.toString()).toList(),
      students: studs
          .map((s) => ResultStudent.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class SubjectAverage {
  final String subject;
  final double avgPct;

  const SubjectAverage({required this.subject, this.avgPct = 0});

  factory SubjectAverage.fromJson(Map<String, dynamic> j) => SubjectAverage(
        subject: j['subject']?.toString() ?? '',
        avgPct: (j['avg_pct'] as num?)?.toDouble() ?? 0,
      );
}

class ExamAnalytics {
  final List<SubjectAverage> subjectAverages;
  final double passPct;
  final List<ResultStudent> topStudents;

  const ExamAnalytics({
    this.subjectAverages = const [],
    this.passPct = 0,
    this.topStudents = const [],
  });

  factory ExamAnalytics.fromJson(Map<String, dynamic> j) {
    final avgs = (j['subject_averages'] as List?) ?? const [];
    final tops = (j['top_students'] as List?) ?? const [];
    return ExamAnalytics(
      subjectAverages: avgs
          .map((a) => SubjectAverage.fromJson((a as Map).cast<String, dynamic>()))
          .toList(),
      passPct: (j['pass_pct'] as num?)?.toDouble() ?? 0,
      topStudents: tops
          .map((s) => ResultStudent.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Standard grading scale used on printed result cards.
class GradingScale {
  static String gradeFor(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    if (pct >= 40) return 'E';
    return 'F';
  }

  static const List<List<String>> legend = [
    ['A+', '90 - 100'],
    ['A', '80 - 89'],
    ['B', '70 - 79'],
    ['C', '60 - 69'],
    ['D', '50 - 59'],
    ['E', '40 - 49'],
    ['F', 'Below 40'],
  ];
}
