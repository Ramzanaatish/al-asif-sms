import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/academics.dart';
import '../../providers/academics_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int? _classId;
  int? _sectionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
      context.read<StaffProvider>().loadStaff();
    });
  }

  void _reload() {
    if (_classId != null) {
      context
          .read<AcademicsProvider>()
          .loadTimetable(classId: _classId, sectionId: _sectionId);
    }
  }

  Future<void> _addEntry() async {
    if (_classId == null) {
      showSnack(context, 'Select a class first.', error: true);
      return;
    }
    final acad = context.read<AcademicsProvider>();
    await acad.loadSubjects(classId: _classId);
    if (!mounted) return;
    final subjects = acad.subjects;
    final teachers = context.read<StaffProvider>().staff;
    int? subjectId = subjects.isNotEmpty ? subjects.first.id : null;
    int? teacherId;
    int day = 0;
    int period = 1;
    final roomCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Add timetable entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: day,
                  decoration: fieldDecoration('Day'),
                  items: List.generate(
                      7,
                      (i) => DropdownMenuItem(
                          value: i,
                          child: Text(TimetableEntry.dayNames[i]))),
                  onChanged: (v) => setS(() => day = v ?? 0),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: period,
                  decoration: fieldDecoration('Period'),
                  items: List.generate(
                      8,
                      (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('Period ${i + 1}'))),
                  onChanged: (v) => setS(() => period = v ?? 1),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: subjectId,
                  decoration: fieldDecoration('Subject'),
                  items: subjects
                      .map((s) => DropdownMenuItem<int?>(
                          value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setS(() => subjectId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: teacherId,
                  decoration: fieldDecoration('Teacher (optional)'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('None')),
                    ...teachers.map((t) => DropdownMenuItem<int?>(
                        value: t.id, child: Text(t.name))),
                  ],
                  onChanged: (v) => setS(() => teacherId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: roomCtrl,
                    decoration: fieldDecoration('Room (optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await acad.addTimetableEntry({
        'class_id': _classId,
        'section_id': _sectionId,
        'day_of_week': day,
        'period_no': period,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'room': roomCtrl.text.trim(),
      });
      showSnack(context, 'Timetable entry added.');
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;
    final sections = _classId == null
        ? <Section>[]
        : classes
            .firstWhere((c) => c.id == _classId,
                orElse: () => const ClassInfo(id: 0, name: ''))
            .sections;
    final entries = context.watch<AcademicsProvider>().timetable;
    final loading = context.watch<AcademicsProvider>().loading;

    final maxPeriod = entries.isEmpty
        ? 0
        : entries.map((e) => e.periodNo).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: const SchoolAppBar(title: 'Timetable'),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _classId,
                    decoration: fieldDecoration('Class'),
                    items: classes
                        .map((c) => DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _classId = v;
                        _sectionId = null;
                      });
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _sectionId,
                    decoration: fieldDecoration('Section'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All')),
                      ...sections.map((s) => DropdownMenuItem<int?>(
                          value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) {
                      setState(() => _sectionId = v);
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _classId == null
                ? const EmptyState(
                    message: 'Select a class to view its timetable.')
                : loading
                    ? const LoadingView()
                    : entries.isEmpty
                        ? const EmptyState(
                            message: 'No timetable entries yet.')
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: [
                                  const DataColumn(
                                      label: Text('Day',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.bold))),
                                  for (var p = 1; p <= maxPeriod; p++)
                                    DataColumn(
                                        label: Text('P$p',
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold))),
                                ],
                                rows: List.generate(7, (d) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                          TimetableEntry
                                              .dayNames[d]
                                              .substring(0, 3),
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold))),
                                      for (var p = 1; p <= maxPeriod; p++)
                                        DataCell(_cellFor(entries
                                            .where((e) =>
                                                e.dayOfWeek == d &&
                                                e.periodNo == p)
                                            .toList())),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _cellFor(List<TimetableEntry> list) {
    if (list.isEmpty) return const Text('-');
    final e = list.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.subjectName.isEmpty ? '?' : e.subjectName,
            style: const TextStyle(fontSize: 12)),
        if (e.teacherName.isNotEmpty)
          Text(e.teacherName,
              style:
                  const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}
