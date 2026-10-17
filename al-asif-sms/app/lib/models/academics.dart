class Section {
  final int id;
  final String name;
  final int? classId;

  const Section({required this.id, required this.name, this.classId});

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        classId: (j['class_id'] as num?)?.toInt(),
      );
}

class ClassInfo {
  final int id;
  final String name;
  final int levelOrder;
  final int studentCount;
  final List<Section> sections;

  const ClassInfo({
    required this.id,
    required this.name,
    this.levelOrder = 0,
    this.studentCount = 0,
    this.sections = const [],
  });

  factory ClassInfo.fromJson(Map<String, dynamic> j) {
    final secs = (j['sections'] as List?) ?? const [];
    return ClassInfo(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      levelOrder: (j['level_order'] as num?)?.toInt() ?? 0,
      studentCount: (j['student_count'] as num?)?.toInt() ?? 0,
      sections: secs
          .map((s) => Section.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class Subject {
  final int id;
  final String name;
  final int? classId;

  const Subject({required this.id, required this.name, this.classId});

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        classId: (j['class_id'] as num?)?.toInt(),
      );
}

class SyllabusTopic {
  final int id;
  final int? classId;
  final int? subjectId;
  final String subjectName;
  final String topic;
  final String status; // planned | in_progress | completed

  const SyllabusTopic({
    required this.id,
    this.classId,
    this.subjectId,
    this.subjectName = '',
    this.topic = '',
    this.status = 'planned',
  });

  factory SyllabusTopic.fromJson(Map<String, dynamic> j) => SyllabusTopic(
        id: (j['id'] as num?)?.toInt() ?? 0,
        classId: (j['class_id'] as num?)?.toInt(),
        subjectId: (j['subject_id'] as num?)?.toInt(),
        subjectName: j['subject_name']?.toString() ?? '',
        topic: j['topic']?.toString() ?? '',
        status: j['status']?.toString() ?? 'planned',
      );
}

class TimetableEntry {
  final int id;
  final int? classId;
  final int? sectionId;
  final int dayOfWeek; // 0-6
  final int periodNo;
  final int? subjectId;
  final String subjectName;
  final int? teacherId;
  final String teacherName;
  final String room;

  const TimetableEntry({
    required this.id,
    this.classId,
    this.sectionId,
    this.dayOfWeek = 0,
    this.periodNo = 1,
    this.subjectId,
    this.subjectName = '',
    this.teacherId,
    this.teacherName = '',
    this.room = '',
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> j) => TimetableEntry(
        id: (j['id'] as num?)?.toInt() ?? 0,
        classId: (j['class_id'] as num?)?.toInt(),
        sectionId: (j['section_id'] as num?)?.toInt(),
        dayOfWeek: (j['day_of_week'] as num?)?.toInt() ?? 0,
        periodNo: (j['period_no'] as num?)?.toInt() ?? 1,
        subjectId: (j['subject_id'] as num?)?.toInt(),
        subjectName: j['subject_name']?.toString() ?? '',
        teacherId: (j['teacher_id'] as num?)?.toInt(),
        teacherName: j['teacher_name']?.toString() ?? '',
        room: j['room']?.toString() ?? '',
      );

  static const List<String> dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
}
