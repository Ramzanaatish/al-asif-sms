import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/academics_provider.dart';
import '../../repositories/academics_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  Future<void> _addSection(int classId, String className) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Add section to $className'),
        content: TextField(
            controller: ctrl,
            decoration: fieldDecoration('Section name (e.g. A)')),
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
      await AcademicsRepository()
          .createSection(classId, ctrl.text.trim());
      if (!mounted) return;
      showSnack(context, 'Section added.');
      context.read<AcademicsProvider>().loadClasses();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _addSubject(int classId, String className) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Add subject to $className'),
        content: TextField(
            controller: ctrl,
            decoration: fieldDecoration('Subject name')),
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
          .addSubject(classId, ctrl.text.trim());
      if (!mounted) return;
      showSnack(context, 'Subject added.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Classes & Sections'),
      body: Consumer<AcademicsProvider>(
        builder: (_, p, __) {
          if (p.loading && p.classes.isEmpty) return const LoadingView();
          if (p.error != null && p.classes.isEmpty) {
            return EmptyState(
                message: p.error!, icon: Icons.cloud_off_outlined);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: p.classes.length,
            itemBuilder: (_, i) {
              final c = p.classes[i];
              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: ExpansionTile(
                  leading: const Icon(Icons.class_,
                      color: AppColors.navy),
                  title: Text(c.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${c.studentCount} students - ${c.sections.length} sections'),
                  children: [
                    if (c.sections.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('No sections yet.',
                            style: TextStyle(color: Colors.black54)),
                      ),
                    ...c.sections.map((s) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.group,
                              size: 18, color: Colors.black54),
                          title: Text('Section ${s.name}'),
                        )),
                    OverflowBar(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Section'),
                          onPressed: () =>
                              _addSection(c.id, c.name),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Subject'),
                          onPressed: () =>
                              _addSubject(c.id, c.name),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
