import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/attendance.dart';
import '../../providers/academics_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';

/// Attendance — ONE screen, exactly like the HTML (Complete v7): date +
/// class, "Mark all as present", "Save Attendance", and a
/// Roll | Name | Class | Status table with Present / Absent / Leave
/// buttons per student. Default is Present; saved records for the
/// date+class pre-fill the table.
///
/// Classes load from the local database immediately (seeded offline);
/// the screen never waits on sync. A failed load shows a retry instead
/// of a silent empty dropdown.
class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime _date = DateTime.now();
  int? _classId;
  List<AttendanceMark> _marks = [];
  bool _loadingClasses = true;
  bool _loadingStudents = false;
  bool _saving = false;
  String? _message;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().init();
      _loadClasses();
    });
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _loadError = null;
    });
    await context.read<AcademicsProvider>().loadClasses();
    if (!mounted) return;
    final classes = context.read<AcademicsProvider>().classes;
    final err = context.read<AcademicsProvider>().error;
    setState(() => _loadingClasses = false);
    if (err != null) {
      setState(() => _loadError = err);
      return;
    }
    // The HTML defaults to the first class (Play Group) and loads it.
    if (classes.isNotEmpty && _classId == null) {
      setState(() => _classId = classes.first.id);
      _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    if (_classId == null) return;
    setState(() {
      _loadingStudents = true;
      _message = null;
    });
    try {
      await context
          .read<StudentProvider>()
          .load(classId: _classId, status: 'active');
      if (!mounted) return;
      final students = context.read<StudentProvider>().students;
      var existing = <int, String>{};
      try {
        final records = await context
            .read<AttendanceProvider>()
            .fetchStudentRecords(date: ymd(_date), classId: _classId);
        for (final r in records) {
          final id = (r['student_id'] as num?)?.toInt();
          final st = r['status']?.toString();
          if (id != null && st != null) existing[id] = st;
        }
      } catch (_) {}
      final sorted = students.toList()
        ..sort((a, b) {
          final ra = a.rollNumber ?? 1 << 30;
          final rb = b.rollNumber ?? 1 << 30;
          final c = ra.compareTo(rb);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
      _marks = sorted
          .map((s) => AttendanceMark(
                studentId: s.id,
                rollNumber: s.rollNumber,
                name: s.name,
                status: existing[s.id] ?? 'present',
              ))
          .toList();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _save() async {
    if (_marks.isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<AttendanceProvider>().saveStudentAttendance({
        'date': ymd(_date),
        'class_id': _classId,
        'records': _marks
            .map((m) => {
                  'student_id': m.studentId,
                  'status': m.status,
                })
            .toList(),
      });
      if (!mounted) return;
      setState(() => _message = 'Saved: ${_marks.length} students marked.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncNow() async {
    await context.read<AttendanceProvider>().syncPending();
    if (!mounted) return;
    showSnack(context, 'Sync complete.');
  }

  void _markAllPresent() {
    setState(() {
      for (final m in _marks) {
        m.status = 'present';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;
    final className = _classId == null
        ? ''
        : classes
            .where((c) => c.id == _classId)
            .map((c) => c.name)
            .firstOrNull ?? '';
    final pending = context.watch<AttendanceProvider>().pendingCount;
    final syncing = context.watch<AttendanceProvider>().syncing;

    return Column(
      children: [
        if (pending > 0)
          InkWell(
            onTap: syncing ? null : _syncNow,
            child: Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      syncing
                          ? 'Syncing...'
                          : '$pending attendance record(s) pending sync - tap to retry',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (syncing)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Class select karein, har student ke liye Present / Absent / Leave lagayein, phir Save karein.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 1)),
                        );
                        if (d != null) {
                          setState(() => _date = d);
                          _loadStudents();
                        }
                      },
                      child: InputDecorator(
                        decoration: fieldDecoration('Date'),
                        child: Text(ymd(_date)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _loadingClasses
                        ? const InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Class',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            child: Text('Loading...'),
                          )
                        : DropdownButtonFormField<int?>(
                            value: _classId,
                            decoration: fieldDecoration('Class'),
                            items: classes
                                .map((c) => DropdownMenuItem<int?>(
                                    value: c.id, child: Text(c.name)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _classId = v;
                                _marks = [];
                              });
                              _loadStudents();
                            },
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Mark all as present'),
                    onPressed:
                        _marks.isEmpty ? null : _markAllPresent,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 18),
                    label: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Attendance'),
                    onPressed:
                        (_marks.isEmpty || _saving) ? null : _save,
                  ),
                ],
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!,
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600)),
              ],
              if (_loadError != null) ...[
                const SizedBox(height: 8),
                Text('Classes load nahi hui: $_loadError',
                    style: const TextStyle(color: AppColors.danger)),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  onPressed: _loadClasses,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _loadingClasses || _loadingStudents
              ? const LoadingView()
              : _classId == null
                  ? const EmptyState(
                      message: 'Select a class to load its students.')
                  : _marks.isEmpty
                      ? const EmptyState(
                          message: 'Is class mein koi student nahi.')
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(
                                    label: Text('Roll',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold))),
                                DataColumn(
                                    label: Text('Name',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold))),
                                DataColumn(
                                    label: Text('Class',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold))),
                                DataColumn(
                                    label: Text('Status',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold))),
                              ],
                              rows: _marks
                                  .map((m) => DataRow(cells: [
                                        DataCell(Text(
                                          m.rollNumber?.toString() ?? '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.navy),
                                        )),
                                        DataCell(Text(m.name,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w500))),
                                        DataCell(Text(className)),
                                        DataCell(_StatusButtons(
                                          status: m.status,
                                          onPick: (v) => setState(
                                              () => m.status = v),
                                        )),
                                      ]))
                                  .toList(),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

/// Present / Absent / Leave toggle buttons. The selected one is filled
/// (green / red / amber, like the HTML); the rest are outlined.
class _StatusButtons extends StatelessWidget {
  final String status;
  final ValueChanged<String> onPick;
  const _StatusButtons({required this.status, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn('present', 'Present', AppColors.success),
        const SizedBox(width: 6),
        _btn('absent', 'Absent', AppColors.danger),
        const SizedBox(width: 6),
        _btn('leave', 'Leave', Colors.orange),
      ],
    );
  }

  Widget _btn(String value, String label, Color color) {
    final selected = status == value;
    return InkWell(
      onTap: () => onPick(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color)),
      ),
    );
  }
}
