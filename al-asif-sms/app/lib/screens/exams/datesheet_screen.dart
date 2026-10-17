import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/academics_provider.dart';
import '../../providers/exams_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class DateSheetScreen extends StatefulWidget {
  const DateSheetScreen({super.key});

  @override
  State<DateSheetScreen> createState() => _DateSheetScreenState();
}

class _DateSheetScreenState extends State<DateSheetScreen> {
  int? _termId;
  int? _classId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamsProvider>().loadTerms();
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  void _reload() {
    if (_termId != null) {
      context
          .read<ExamsProvider>()
          .loadDatesheets(termId: _termId, classId: _classId);
    }
  }

  Future<void> _addEntry() async {
    if (_termId == null || _classId == null) {
      showSnack(context, 'Select term and class first.', error: true);
      return;
    }
    final acad = context.read<AcademicsProvider>();
    await acad.loadSubjects(classId: _classId);
    if (!mounted) return;
    final subjects = acad.subjects;
    int? subjectId = subjects.isNotEmpty ? subjects.first.id : null;
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '09:00');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Add date sheet entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              TextField(
                  controller: dateCtrl,
                  decoration:
                      fieldDecoration('Exam date (YYYY-MM-DD)')),
              const SizedBox(height: 10),
              TextField(
                  controller: timeCtrl,
                  decoration: fieldDecoration('Start time (HH:MM)')),
            ],
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
    if (subjectId == null || dateCtrl.text.trim().isEmpty) {
      showSnack(context, 'Subject and date are required.', error: true);
      return;
    }
    try {
      await context.read<ExamsProvider>().addDatesheetEntry({
        'term_id': _termId,
        'class_id': _classId,
        'subject_id': subjectId,
        'exam_date': dateCtrl.text.trim(),
        'start_time': timeCtrl.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Date sheet entry added.');
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exams = context.watch<ExamsProvider>();
    final classes = context.watch<AcademicsProvider>().classes;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Date Sheets'),
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
                    value: _termId,
                    decoration: fieldDecoration('Term'),
                    items: exams.terms
                        .map((t) => DropdownMenuItem<int?>(
                            value: t.id, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _termId = v);
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _classId,
                    decoration: fieldDecoration('Class'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All')),
                      ...classes.map((c) => DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) {
                      setState(() => _classId = v);
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _termId == null
                ? const EmptyState(
                    message: 'Select a term to view its date sheet.')
                : exams.loading
                    ? const LoadingView()
                    : exams.datesheets.isEmpty
                        ? const EmptyState(
                            message: 'No date sheet entries yet.')
                        : ListView.builder(
                            itemCount: exams.datesheets.length,
                            itemBuilder: (_, i) {
                              final d = exams.datesheets[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: ListTile(
                                  leading: const Icon(
                                      Icons.calendar_today,
                                      color: Colors.indigo),
                                  title: Text(d.subjectName,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600)),
                                  subtitle: Text(
                                      '${fmtDate(d.examDate)} at ${d.startTime}'),
                                  trailing: Text(d.className,
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
