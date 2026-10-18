import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/academics_provider.dart';
import '../../providers/exams_provider.dart';
import '../../providers/student_provider.dart';
import '../../repositories/exams_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  int? _termId;
  int? _classId;
  int? _subjectId;
  final _totalCtrl = TextEditingController(text: '100');
  List<_MarkRow> _rows = [];
  bool _loadingRows = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamsProvider>().loadTerms();
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    for (final r in _rows) {
      r.ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRows() async {
    if (_termId == null || _classId == null || _subjectId == null) {
      setState(() => _rows = []);
      return;
    }
    setState(() => _loadingRows = true);
    try {
      await context
          .read<StudentProvider>()
          .load(classId: _classId, status: 'active');
      if (!mounted) return;
      final students = context.read<StudentProvider>().students;
      var existing = <int, double>{};
      try {
        final marks = await ExamsRepository().marks(
            termId: _termId, classId: _classId, subjectId: _subjectId);
        for (final m in marks) {
          final id = (m['student_id'] as num?)?.toInt();
          final obt = (m['obtained_marks'] as num?)?.toDouble();
          if (id != null && obt != null) existing[id] = obt;
        }
      } catch (_) {}
      for (final r in _rows) {
        r.ctrl.dispose();
      }
      _rows = students.map((s) {
        final ctrl = TextEditingController(
            text: existing[s.id] != null
                ? existing[s.id]!.toStringAsFixed(0)
                : '');
        return _MarkRow(studentId: s.id, name: s.name, ctrl: ctrl);
      }).toList();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loadingRows = false);
    }
  }

  Future<void> _save() async {
    final total = double.tryParse(_totalCtrl.text.trim());
    if (total == null || total <= 0) {
      showSnack(context, 'Enter valid total marks.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final records = <Map<String, dynamic>>[];
      for (final r in _rows) {
        final v = double.tryParse(r.ctrl.text.trim());
        if (v != null) {
          records.add({'student_id': r.studentId, 'obtained_marks': v});
        }
      }
      final saved = await context.read<ExamsProvider>().saveMarks({
        'term_id': _termId,
        'class_id': _classId,
        'subject_id': _subjectId,
        'total_marks': total,
        'records': records,
      });
      if (!mounted) return;
      showSnack(context, 'Marks saved ($saved records).');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exams = context.watch<ExamsProvider>();
    final acad = context.watch<AcademicsProvider>();
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Marks Entry'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
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
                          _loadRows();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _classId,
                        decoration: fieldDecoration('Class'),
                        items: acad.classes
                            .map((c) => DropdownMenuItem<int?>(
                                value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) async {
                          setState(() {
                            _classId = v;
                            _subjectId = null;
                          });
                          if (v != null) {
                            await context
                                .read<AcademicsProvider>()
                                .loadSubjects(classId: v);
                          }
                          _loadRows();
                        },
                      ),
                    ),
                  ],
                ),
                if (_classId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Class Incharge: ${AppConfig.classTeacher(acad.classes.firstWhere((c) => c.id == _classId, orElse: () => acad.classes.first).name)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _subjectId,
                        decoration: fieldDecoration('Subject'),
                        items: acad.subjects
                            .map((s) => DropdownMenuItem<int?>(
                                value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _subjectId = v);
                          _loadRows();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _totalCtrl,
                        decoration: fieldDecoration('Total marks'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'))
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingRows
                ? const LoadingView()
                : _rows.isEmpty
                    ? const EmptyState(
                        message:
                            'Select term, class and subject to enter marks.')
                    : ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (_, i) {
                          final r = _rows[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 3),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(r.name,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w500))),
                                  SizedBox(
                                    width: 110,
                                    child: TextField(
                                      controller: r.ctrl,
                                      decoration: fieldDecoration(
                                          'Obtained'),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter
                                            .allow(RegExp(r'[0-9.]'))
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Marks'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkRow {
  final int studentId;
  final String name;
  final TextEditingController ctrl;
  _MarkRow(
      {required this.studentId, required this.name, required this.ctrl});
}
