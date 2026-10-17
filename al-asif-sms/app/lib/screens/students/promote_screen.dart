import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/academics_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class PromoteScreen extends StatefulWidget {
  const PromoteScreen({super.key});

  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> {
  int? _fromClassId;
  int? _toClassId;
  final _sessionCtrl =
      TextEditingController(text: '2026-27');
  List<Student> _students = [];
  final Set<int> _promoteIds = {};
  bool _loadingStudents = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
    });
  }

  @override
  void dispose() {
    _sessionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_fromClassId == null) return;
    setState(() => _loadingStudents = true);
    try {
      await context.read<StudentProvider>().load(
          classId: _fromClassId, status: 'active');
      _students = context.read<StudentProvider>().students;
      _promoteIds
        ..clear()
        ..addAll(_students.map((s) => s.id));
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _submit() async {
    if (_fromClassId == null || _toClassId == null) {
      showSnack(context, 'Select both classes.', error: true);
      return;
    }
    if (_fromClassId == _toClassId) {
      showSnack(context, 'From and To classes must differ.', error: true);
      return;
    }
    final digits = _sessionCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final sessionId =
        digits.length >= 4 ? int.tryParse(digits.substring(0, 4)) ?? 0 : 0;
    final ok = await confirmDialog(context, 'Promote students',
        'Promote ${_promoteIds.length} and retain ${_students.length - _promoteIds.length} students?');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final retained =
          _students.map((s) => s.id).where((id) => !_promoteIds.contains(id)).toList();
      final res = await context.read<StudentProvider>().promote(
            fromClassId: _fromClassId!,
            toClassId: _toClassId!,
            promotedIds: _promoteIds.toList(),
            retainedIds: retained,
            sessionId: sessionId,
          );
      if (!mounted) return;
      showSnack(context,
          'Promoted: ${res['promoted'] ?? 0}, Retained: ${res['retained'] ?? 0}');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Promote Students'),
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
                        value: _fromClassId,
                        decoration: fieldDecoration('From class'),
                        items: classes
                            .map((c) => DropdownMenuItem<int?>(
                                value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _fromClassId = v;
                            _students = [];
                            _promoteIds.clear();
                          });
                          _loadStudents();
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _toClassId,
                        decoration: fieldDecoration('To class'),
                        items: classes
                            .map((c) => DropdownMenuItem<int?>(
                                value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _toClassId = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: _sessionCtrl,
                    decoration:
                        fieldDecoration('Session (e.g. 2026-27)')),
                const SizedBox(height: 8),
                if (_students.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '${_promoteIds.length} promote, ${_students.length - _promoteIds.length} retain'),
                      TextButton(
                        onPressed: () => setState(() {
                          if (_promoteIds.length == _students.length) {
                            _promoteIds.clear();
                          } else {
                            _promoteIds.addAll(
                                _students.map((s) => s.id));
                          }
                        }),
                        child: Text(_promoteIds.length == _students.length
                            ? 'Unselect all'
                            : 'Select all'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loadingStudents
                ? const LoadingView()
                : _students.isEmpty
                    ? const EmptyState(
                        message: 'Select a class to list its students.')
                    : ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          final checked = _promoteIds.contains(s.id);
                          return CheckboxListTile(
                            value: checked,
                            title: Text(s.name),
                            subtitle: Text(
                                '${s.admissionNo}${s.sectionName.isNotEmpty ? ' - ${s.sectionName}' : ''}'),
                            secondary: Icon(
                                checked
                                    ? Icons.arrow_upward
                                    : Icons.pause_circle_outline,
                                color: checked
                                    ? Colors.green
                                    : Colors.orange),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _promoteIds.add(s.id);
                              } else {
                                _promoteIds.remove(s.id);
                              }
                            }),
                          );
                        },
                      ),
          ),
          if (_students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Apply Promotion'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
