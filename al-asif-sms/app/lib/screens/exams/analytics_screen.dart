import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/academics_provider.dart';
import '../../providers/exams_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
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
          .loadAnalytics(termId: _termId, classId: _classId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exams = context.watch<ExamsProvider>();
    final classes = context.watch<AcademicsProvider>().classes;
    final a = exams.analytics;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Result Analytics'),
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
            child: exams.loading
                ? const LoadingView()
                : a == null
                    ? const EmptyState(
                        message: 'Select a term to view analytics.')
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _stat('Pass %',
                                      '${a.passPct.toStringAsFixed(1)}%',
                                      AppColors.success),
                                  _stat(
                                      'Subjects',
                                      '${a.subjectAverages.length}',
                                      AppColors.navy),
                                  _stat('Top students',
                                      '${a.topStudents.length}',
                                      AppColors.gold),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Subject averages',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...a.subjectAverages.map((s) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Text(s.subject,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w500)),
                                        Text(
                                            '${s.avgPct.toStringAsFixed(1)}%'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (s.avgPct / 100)
                                            .clamp(0.0, 1.0),
                                        minHeight: 10,
                                        backgroundColor:
                                            Colors.black12,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                AppColors.navy),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 16),
                          const Text('Top 5 students',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...a.topStudents.take(5).map((s) => Card(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 3),
                                child: ListTile(
                                  leading: const Icon(
                                      Icons.emoji_events,
                                      color: AppColors.gold),
                                  title: Text(s.name),
                                  trailing: Text(
                                      '${s.pct.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold)),
                                ),
                              )),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}
