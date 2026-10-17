import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/staff.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/staff_provider.dart';
import '../../repositories/attendance_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  DateTime _date = DateTime.now();
  List<_StaffMark> _marks = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final staffP = context.read<StaffProvider>();
      await staffP.loadStaff();
      final staff = staffP.staff;
      var existing = <int, String>{};
      try {
        final records =
            await AttendanceRepository().staffRecords(date: ymd(_date));
        for (final r in records) {
          final id = (r['staff_id'] as num?)?.toInt();
          final st = r['status']?.toString();
          if (id != null && st != null) existing[id] = st;
        }
      } catch (_) {}
      _marks = staff
          .map((s) => _StaffMark(
              staff: s, status: existing[s.id] ?? 'present'))
          .toList();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AttendanceProvider>().saveStaffAttendance(
          ymd(_date),
          _marks
              .map((m) =>
                  {'staff_id': m.staff.id, 'status': m.status})
              .toList());
      if (!mounted) return;
      final err = context.read<AttendanceProvider>().error;
      if (err != null) {
        showSnack(context, err, error: true);
      } else {
        showSnack(context, 'Staff attendance saved.');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Staff Attendance'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) {
                  setState(() => _date = d);
                  _load();
                }
              },
              child: InputDecorator(
                decoration: fieldDecoration('Date'),
                child: Text(ymd(_date)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _marks.isEmpty
                    ? const EmptyState(message: 'No staff found.')
                    : ListView.builder(
                        itemCount: _marks.length,
                        itemBuilder: (_, i) {
                          final m = _marks[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 3),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m.staff.name,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w500)),
                                        Text(m.staff.designation,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  _btn(m, 'present', 'P',
                                      AppColors.success),
                                  const SizedBox(width: 6),
                                  _btn(m, 'absent', 'A',
                                      AppColors.danger),
                                  const SizedBox(width: 6),
                                  _btn(m, 'leave', 'L', Colors.orange),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_marks.isNotEmpty)
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
                      : const Text('Save Staff Attendance'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _btn(_StaffMark m, String value, String label, Color color) {
    final selected = m.status == value;
    return InkWell(
      onTap: () => setState(() => m.status = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _StaffMark {
  final StaffMember staff;
  String status;
  _StaffMark({required this.staff, this.status = 'present'});
}
