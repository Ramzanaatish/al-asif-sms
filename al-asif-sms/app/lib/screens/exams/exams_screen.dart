import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/academics.dart';
import '../../models/exam.dart';
import '../../repositories/exams_repository.dart';
import '../../providers/exams_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';

/// Exams & Marks — one screen, matching the HTML v7 Exams screen:
/// Grading Scale card + Marks Entry (subject-wise). Teacher filter
/// narrows the class list to that teacher's classes and the subject
/// list to their assigned subjects; marks auto-save on change and the
/// grade updates live.
class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExamsProvider()..loadBase(),
      child: const _ExamsView(),
    );
  }
}

class _ExamsView extends StatefulWidget {
  const _ExamsView();

  @override
  State<_ExamsView> createState() => _ExamsViewState();
}

class _ExamsViewState extends State<_ExamsView> {
  String? _teacher;
  int? _classId;
  String? _subjectName;
  String _termName = 'First Term';
  int _total = 100;
  List<ClassInfo> _visibleClasses = [];
  List<Subject> _visibleSubjects = [];
  // Live marks (studentId -> obtained) for the grade column; seeded
  // from the provider whenever the selection changes.
  Map<int, double> _liveMarks = {};
  int _marksVersion = 0;
  bool _ready = false;

  ExamsProvider get _p => context.read<ExamsProvider>();

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    // Wait for the base load (classes + terms) to finish.
    while (_p.classes.isEmpty && _p.error == null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    if (!mounted || _p.classes.isEmpty) return;
    final firstClass = _p.classes.first;
    final subjects = await _p.subjectsFor(classId: firstClass.id);
    final term = await _p.ensureTerm(_termName);
    final subject = subjects.isNotEmpty
        ? await _p.ensureSubject(firstClass.id, subjects.first.name)
        : null;
    if (!mounted) return;
    setState(() {
      _classId = firstClass.id;
      _visibleClasses = _p.classes;
      _visibleSubjects = subjects;
      _subjectName = subject?.name;
    });
    if (subject != null) {
      await _loadMarks(termId: term.id, subjectId: subject.id);
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _loadMarks(
      {required int termId, required int subjectId}) async {
    if (_classId == null) return;
    await _p.loadMarks(
        termId: termId, classId: _classId!, subjectId: subjectId);
    if (!mounted) return;
    setState(() {
      _liveMarks = Map<int, double>.from(_p.marks);
      _total = _p.markTotal;
      _marksVersion++;
    });
  }

  Future<void> _onTeacherChanged(String? teacher) async {
    setState(() {
      _teacher = teacher;
      _ready = false;
    });
    final classes = await _p.classesFor(teacher);
    final classId = classes.isNotEmpty ? classes.first.id : null;
    List<Subject> subjects = [];
    String? subjectName;
    if (classId != null) {
      subjects = await _p.subjectsFor(classId: classId, teacher: teacher);
      if (subjects.isNotEmpty) {
        final subject = await _p.ensureSubject(classId, subjects.first.name);
        subjectName = subject.name;
      }
    }
    if (!mounted) return;
    setState(() {
      _visibleClasses = classes;
      _classId = classId;
      _visibleSubjects = subjects;
      _subjectName = subjectName;
    });
    if (classId != null && subjectName != null) {
      final term = await _p.ensureTerm(_termName);
      final subject = await _p.ensureSubject(classId, subjectName);
      await _loadMarks(termId: term.id, subjectId: subject.id);
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _onClassChanged(int? classId) async {
    if (classId == null) return;
    setState(() => _ready = false);
    final subjects =
        await _p.subjectsFor(classId: classId, teacher: _teacher);
    String? subjectName;
    if (subjects.isNotEmpty) {
      final subject = await _p.ensureSubject(classId, subjects.first.name);
      subjectName = subject.name;
    }
    if (!mounted) return;
    setState(() {
      _classId = classId;
      _visibleSubjects = subjects;
      _subjectName = subjectName;
    });
    if (subjectName != null) {
      final term = await _p.ensureTerm(_termName);
      final subject = await _p.ensureSubject(classId, subjectName);
      await _loadMarks(termId: term.id, subjectId: subject.id);
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _onSubjectChanged(String? name) async {
    if (name == null || _classId == null) return;
    setState(() => _ready = false);
    final subject = await _p.ensureSubject(_classId!, name);
    final term = await _p.ensureTerm(_termName);
    if (!mounted) return;
    setState(() => _subjectName = subject.name);
    await _loadMarks(termId: term.id, subjectId: subject.id);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _onTermChanged(String? name) async {
    if (name == null || _classId == null || _subjectName == null) return;
    setState(() => _ready = false);
    final term = await _p.ensureTerm(name);
    final subject = await _p.ensureSubject(_classId!, _subjectName!);
    if (!mounted) return;
    setState(() => _termName = term.name);
    await _loadMarks(termId: term.id, subjectId: subject.id);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _onTotalChanged(String value) async {
    final total = int.tryParse(value);
    if (total == null || total < 1 || total > 500) return;
    if (_classId == null || _subjectName == null) return;
    final term = await _p.ensureTerm(_termName);
    final subject = await _p.ensureSubject(_classId!, _subjectName!);
    await _p.setMarkTotal(
        termId: term.id,
        classId: _classId!,
        subjectId: subject.id,
        total: total);
    if (mounted) setState(() => _total = total);
  }

  Future<void> _saveMark(int studentId, double obtained) async {
    if (_classId == null || _subjectName == null) return;
    final clamped =
        obtained.clamp(0, _total.toDouble()).toDouble();
    await _p.saveMark(
      termName: _termName,
      classId: _classId!,
      subjectName: _subjectName!,
      studentId: studentId,
      obtained: clamped,
    );
    if (mounted) {
      setState(() => _liveMarks[studentId] = clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Exams & Marks'),
      body: Consumer<ExamsProvider>(
        builder: (context, p, _) {
          if (p.loading && p.classes.isEmpty) return const LoadingView();
          if (p.error != null && p.classes.isEmpty) {
            return Center(child: Text(p.error!));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Grading scale aur marks entry. Grade number likhte hi ban jata hai.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Grading Scale',
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Grade')),
                      DataColumn(label: Text('A+')),
                      DataColumn(label: Text('A')),
                      DataColumn(label: Text('B')),
                      DataColumn(label: Text('C')),
                      DataColumn(label: Text('D')),
                      DataColumn(label: Text('E')),
                      DataColumn(label: Text('F')),
                    ],
                    rows: const [
                      DataRow(cells: [
                        DataCell(Text('Marks',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('90+')),
                        DataCell(Text('80+')),
                        DataCell(Text('70+')),
                        DataCell(Text('60+')),
                        DataCell(Text('50+')),
                        DataCell(Text('40+')),
                        DataCell(Text('Below 40')),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Marks Entry — Subject-wise',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              value: _teacher,
                              decoration: const InputDecoration(
                                  labelText: 'Teacher',
                                  border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All teachers')),
                                ...p.teachers.map((t) =>
                                    DropdownMenuItem<String>(
                                        value: t, child: Text(t))),
                              ],
                              onChanged: _onTeacherChanged,
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<int>(
                              value: _classId,
                              decoration: const InputDecoration(
                                  labelText: 'Class',
                                  border: OutlineInputBorder()),
                              items: _visibleClasses
                                  .map((c) => DropdownMenuItem<int>(
                                      value: c.id,
                                      child: Text(
                                          '${c.name} — ${AppConfig.classTeacher(c.name)}')))
                                  .toList(),
                              onChanged: _onClassChanged,
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              value: _subjectName,
                              decoration: const InputDecoration(
                                  labelText: 'Subject',
                                  border: OutlineInputBorder()),
                              items: _visibleSubjects
                                  .map((s) => DropdownMenuItem<String>(
                                      value: s.name, child: Text(s.name)))
                                  .toList(),
                              onChanged: _onSubjectChanged,
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<String>(
                              value: _termName,
                              decoration: const InputDecoration(
                                  labelText: 'Term',
                                  border: OutlineInputBorder()),
                              items: ExamsRepository.htmlTerms
                                  .map((t) => DropdownMenuItem<String>(
                                      value: t.$1, child: Text(t.$1)))
                                  .toList(),
                              onChanged: _onTermChanged,
                            ),
                          ),
                          SizedBox(
                            width: 130,
                            child: TextFormField(
                              key: ValueKey('total_$_marksVersion'),
                              initialValue: _total.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Total marks',
                                  border: OutlineInputBorder()),
                              onFieldSubmitted: _onTotalChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_ready)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (p.students.isEmpty)
                        const Text('Is class mein koi student nahi.',
                            style: TextStyle(color: Colors.grey))
                      else
                        DataTable(
                          columns: [
                            const DataColumn(label: Text('Student')),
                            DataColumn(
                                label: Text('Marks (out of $_total)')),
                            const DataColumn(label: Text('Grade')),
                          ],
                          rows: p.students.map((s) {
                            final obtained = _liveMarks[s.id];
                            final grade = obtained == null
                                ? '-'
                                : ExamsRepository.gradeFor(
                                    obtained, _total.toDouble());
                            return DataRow(cells: [
                              DataCell(Text(s.name)),
                              DataCell(_MarkField(
                                key: ValueKey(
                                    'mark_${s.id}_$_marksVersion'),
                                initialValue: obtained == null
                                    ? ''
                                    : obtained.toStringAsFixed(
                                        obtained.truncateToDouble() == obtained
                                            ? 0
                                            : 1),
                                max: _total,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == null) {
                                      _liveMarks.remove(s.id);
                                    } else {
                                      _liveMarks[s.id] = v;
                                    }
                                  });
                                },
                                onSave: (v) {
                                  if (v != null) _saveMark(s.id, v);
                                },
                              )),
                              DataCell(Text(grade,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                            ]);
                          }).toList(),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Marks badalne par grade khud update hota hai aur save ho jata hai. Teacher select karein to sirf uski assigned class/subject dikhegi.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// One marks input: the grade updates live on every keystroke (via
/// onChanged), and the value auto-saves when the field loses focus or
/// the user submits it (the HTML's onchange behaviour).
class _MarkField extends StatefulWidget {
  final String initialValue;
  final int max;
  final ValueChanged<double?> onChanged;
  final ValueChanged<double?> onSave;

  const _MarkField({
    super.key,
    required this.initialValue,
    required this.max,
    required this.onChanged,
    required this.onSave,
  });

  @override
  State<_MarkField> createState() => _MarkFieldState();
}

class _MarkFieldState extends State<_MarkField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String _savedValue = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _savedValue = widget.initialValue;
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _controller.text != _savedValue) {
        _save();
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    _savedValue = _controller.text;
    widget.onSave(double.tryParse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        onChanged: (v) => widget.onChanged(double.tryParse(v)),
        onSubmitted: (_) => _save(),
      ),
    );
  }
}
