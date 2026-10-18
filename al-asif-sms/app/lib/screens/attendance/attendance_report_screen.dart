import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/academics_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int? _classId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
      _reload();
    });
  }

  void _reload() {
    context.read<AttendanceProvider>().loadMonthly(
        month: _month, year: _year, classId: _classId);
  }

  Color _pctColor(double pct) {
    if (pct >= 90) return AppColors.success;
    if (pct >= 75) return Colors.orange;
    return AppColors.danger;
  }

  Color _feeColor(String status) {
    if (status == 'Paid') return AppColors.success;
    if (status == 'Partial') return Colors.orange;
    return AppColors.danger;
  }

  Future<void> _showAddHoliday() async {
    final dateCtrl = TextEditingController(
        text: DateTime(_year, _month, 1).toString().substring(0, 10));
    final endCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String kind = 'unexpected';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Holiday / Vacation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kind,
                decoration: fieldDecoration('Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'unexpected',
                      child: Text('Unexpected Holiday')),
                  DropdownMenuItem(
                      value: 'summer', child: Text('Summer Vacation')),
                  DropdownMenuItem(
                      value: 'winter', child: Text('Winter Vacation')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => kind = v ?? kind,
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: dateCtrl,
                  decoration: fieldDecoration('Date (YYYY-MM-DD)')),
              const SizedBox(height: 8),
              TextField(
                  controller: endCtrl,
                  decoration: fieldDecoration(
                      'End date (optional, for vacations)')),
              const SizedBox(height: 8),
              TextField(
                  controller: descCtrl,
                  decoration: fieldDecoration('Description (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<AttendanceProvider>().repo.addHoliday(
            date: dateCtrl.text.trim(),
            endDate:
                endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
            kind: kind,
            description:
                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Holiday saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Monthly Attendance Report'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _month,
                    decoration: fieldDecoration('Month'),
                    items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(monthName(i + 1)))),
                    onChanged: (v) {
                      setState(() => _month = v ?? _month);
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    decoration: fieldDecoration('Year'),
                    items: [for (var y = _year - 2; y <= _year + 1; y++) y]
                        .map((y) => DropdownMenuItem(
                            value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _year = v ?? _year);
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
          if (_classId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Class Incharge: ${AppConfig.classTeacher(classes.firstWhere((c) => c.id == _classId, orElse: () => classes.first).name)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy),
                ),
              ),
            ),
          Expanded(
            child: Consumer<AttendanceProvider>(
              builder: (_, p, __) {
                if (p.loading) return const LoadingView();
                if (p.error != null) {
                  return EmptyState(
                      message: p.error!, icon: Icons.cloud_off_outlined);
                }
                final r = p.monthlyReport;
                if (r == null || r.students.isEmpty) {
                  return const EmptyState(
                      message: 'No attendance data for this period.');
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Text('School days: ${r.days}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showAddHoliday,
                            icon: const Icon(Icons.event_busy, size: 18),
                            label: const Text('Add Holiday'),
                          ),
                        ],
                      ),
                    ),
                    if (r.holidays.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: r.holidays
                                .map((h) => Chip(
                                      label: Text(
                                          '${h.date} · ${h.kindLabel}',
                                          style: const TextStyle(
                                              fontSize: 12)),
                                      visualDensity:
                                          VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(
                                  label: Text('Student',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold))),
                              DataColumn(
                                  label: Text('P',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold))),
                              DataColumn(
                                  label: Text('A',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold))),
                              DataColumn(
                                  label: Text('L',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold))),
                              DataColumn(
                                  label: Text('%',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold))),
                              DataColumn(
                                  label: Text('Fee',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold))),
                            ],
                            rows: r.students
                                .map((s) => DataRow(cells: [
                                      DataCell(Text(s.name)),
                                      DataCell(Text('${s.present}')),
                                      DataCell(Text('${s.absent}')),
                                      DataCell(Text('${s.leave}')),
                                      DataCell(Text(
                                        '${s.pct.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _pctColor(s.pct)),
                                      )),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _feeColor(s.feeStatus)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          s.feeStatus,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  _feeColor(s.feeStatus)),
                                        ),
                                      )),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
