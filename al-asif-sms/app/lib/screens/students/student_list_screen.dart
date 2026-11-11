import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/student.dart';
import '../../providers/academics_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';
import 'admission_screen.dart';
import 'student_detail_screen.dart';

/// The Students screen, exactly like the HTML (Complete v7) Students
/// table: a search box, a class filter, a "+ Add Student" button, and a
/// table with Photo | Adm No | Name | Father | B-Form | Contact | Class |
/// Status | Edit / Delete. The old list tiles, the status chips, the
/// section filter and the "Promote class" button are gone — none of
/// those exist in the HTML.
class StudentListScreen extends StatefulWidget {
  final bool readOnly;
  const StudentListScreen({super.key, this.readOnly = false});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  int? _classId;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
      _reload();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    context.read<StudentProvider>().load(
          classId: _classId,
          status: 'all',
          search: _search.isEmpty ? null : _search,
        );
  }

  Future<void> _confirmDelete(Student s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
            'Delete ${s.name} (${s.admissionNo})? This removes the student from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<StudentProvider>().deleteStudent(s.id);
      if (mounted) showSnack(context, 'Student deleted.');
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  void _openAdmission([Student? s]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdmissionScreen(student: s)),
    ).then((_) => _reload());
  }

  Widget _photoCell(Student s) {
    final path = s.photoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(path),
          width: 36,
          height: 45,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('-'),
        ),
      );
    }
    return const Text('-');
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;

    // Note: used as a tab inside HomeShell (which already shows an app bar),
    // so this screen has no app bar of its own.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration:
                          fieldDecoration('Search name / admission no')
                              .copyWith(
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                  _reload();
                                },
                              ),
                      ),
                      onSubmitted: (v) {
                        setState(() => _search = v.trim());
                        _reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int?>(
                      value: _classId,
                      decoration: fieldDecoration('Class'),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('All classes')),
                        ...classes.map((c) => DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) {
                        setState(() => _classId = v);
                        _reload();
                      },
                    ),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('+ Add Student'),
                      onPressed: () => _openAdmission(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Search, filter, add ya delete karein.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<StudentProvider>(
            builder: (_, p, __) {
              if (p.loading) return const LoadingView();
              if (p.error != null) {
                return EmptyState(
                    message: p.error!, icon: Icons.cloud_off_outlined);
              }
              if (p.students.isEmpty) {
                return const EmptyState(message: 'No students found.');
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        AppColors.navy.withValues(alpha: 0.06)),
                    columns: const [
                      DataColumn(label: Text('Photo')),
                      DataColumn(label: Text('Adm No')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Father')),
                      DataColumn(label: Text('B-Form')),
                      DataColumn(label: Text('Contact')),
                      DataColumn(label: Text('Class')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('')),
                    ],
                    rows: p.students.map((s) {
                      return DataRow(
                        cells: [
                          DataCell(_photoCell(s)),
                          DataCell(Text(s.admissionNo)),
                          DataCell(
                            Text(s.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            onTap: widget.readOnly
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudentDetailScreen(
                                            id: s.id,
                                            readOnly: widget.readOnly),
                                      ),
                                    ).then((_) => _reload()),
                          ),
                          DataCell(Text(s.guardianName.isEmpty
                              ? '-'
                              : s.guardianName)),
                          DataCell(
                              Text(s.bForm.isEmpty ? '-' : s.bForm)),
                          DataCell(Text(s.guardianPhone.isEmpty
                              ? '-'
                              : s.guardianPhone)),
                          DataCell(Text(s.className.isEmpty
                              ? '-'
                              : s.className)),
                          DataCell(Text(s.isActive ? 'Active' : 'Left')),
                          DataCell(
                            widget.readOnly
                                ? const Text('')
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            size: 18),
                                        tooltip: 'Edit',
                                        onPressed: () =>
                                            _openAdmission(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 18),
                                        tooltip: 'Delete',
                                        onPressed: () =>
                                            _confirmDelete(s),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
