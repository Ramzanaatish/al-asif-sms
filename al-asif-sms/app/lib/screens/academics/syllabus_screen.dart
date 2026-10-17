import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/academics_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  int? _classId;
  int? _subjectId;

  static const statuses = ['planned', 'in_progress', 'completed'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  void _reload() {
    if (_classId != null) {
      context
          .read<AcademicsProvider>()
          .loadSyllabus(classId: _classId, subjectId: _subjectId);
    }
  }

  Future<void> _addTopic() async {
    if (_classId == null || _subjectId == null) {
      showSnack(context, 'Select class and subject first.', error: true);
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add syllabus topic'),
        content: TextField(
            controller: ctrl,
            decoration: fieldDecoration('Topic'),
            maxLines: 2),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !mounted || ctrl.text.trim().isEmpty) return;
    try {
      await context
          .read<AcademicsProvider>()
          .addSyllabusTopic(_classId!, _subjectId!, ctrl.text.trim());
      if (!mounted) return;
      showSnack(context, 'Topic added.');
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final acad = context.watch<AcademicsProvider>();
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Syllabus'),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTopic,
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
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _subjectId,
                    decoration: fieldDecoration('Subject'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All')),
                      ...acad.subjects.map((s) => DropdownMenuItem<int?>(
                          value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) {
                      setState(() => _subjectId = v);
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
                    message: 'Select a class to view its syllabus.')
                : acad.loading
                    ? const LoadingView()
                    : acad.syllabus.isEmpty
                        ? const EmptyState(
                            message: 'No syllabus topics yet.')
                        : ListView.builder(
                            itemCount: acad.syllabus.length,
                            itemBuilder: (_, i) {
                              final t = acad.syllabus[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: ListTile(
                                  title: Text(t.topic),
                                  subtitle: Text(t.subjectName),
                                  trailing: DropdownButton<String>(
                                    value: t.status,
                                    underline: const SizedBox(),
                                    icon: Icon(Icons.circle,
                                        size: 12,
                                        color: _statusColor(t.status)),
                                    items: statuses
                                        .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s.replaceAll(
                                                '_', ' '))))
                                        .toList(),
                                    onChanged: (v) async {
                                      if (v == null) return;
                                      try {
                                        await context
                                            .read<AcademicsProvider>()
                                            .setSyllabusStatus(t.id, v);
                                      } catch (e) {
                                        if (mounted) {
                                          showSnack(context,
                                              e.toString(),
                                              error: true);
                                        }
                                      }
                                    },
                                  ),
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
