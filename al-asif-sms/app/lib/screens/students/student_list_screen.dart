import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/academics.dart';
import '../../providers/academics_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';
import 'admission_screen.dart';
import 'promote_screen.dart';
import 'student_detail_screen.dart';

class StudentListScreen extends StatefulWidget {
  final bool readOnly;
  const StudentListScreen({super.key, this.readOnly = false});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  int? _classId;
  int? _sectionId;
  String _status = 'active';
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
          sectionId: _sectionId,
          status: _status == 'all' ? null : _status,
          search: _search.isEmpty ? null : _search,
        );
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

    // Note: used as a tab inside HomeShell (which already shows an app bar),
    // so this screen has no app bar of its own.
    return Scaffold(
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdmissionScreen()),
              ).then((_) => _reload()),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: fieldDecoration('Search name / admission no')
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
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
                const SizedBox(height: 8),
                if (!widget.readOnly)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_upward, size: 16),
                      label: const Text('Promote class'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PromoteScreen()),
                      ).then((_) => _reload()),
                    ),
                  ),
                Row(
                  children: ['all', 'active', 'left'].map((s) {
                    final selected = _status == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s[0].toUpperCase() + s.substring(1)),
                        selected: selected,
                        selectedColor: AppColors.navy,
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87),
                        onSelected: (_) {
                          setState(() => _status = s);
                          _reload();
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
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
                return ListView.builder(
                  itemCount: p.students.length,
                  itemBuilder: (_, i) {
                    final s = p.students[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.isActive
                              ? AppColors.navy
                              : Colors.grey,
                          child: Text(s.name.isEmpty ? '?' : s.name[0],
                              style:
                                  const TextStyle(color: Colors.white)),
                        ),
                        title: Text(s.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${s.admissionNo} - ${s.className}${s.sectionName.isNotEmpty ? ' (${s.sectionName})' : ''}'),
                        trailing: s.isActive
                            ? null
                            : const Chip(
                                label: Text('Left',
                                    style: TextStyle(fontSize: 11)),
                                backgroundColor: Colors.black12),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(
                                id: s.id, readOnly: widget.readOnly),
                          ),
                        ).then((_) => _reload()),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
