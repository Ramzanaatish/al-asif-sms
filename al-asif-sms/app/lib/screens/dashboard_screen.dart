import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/class_donut.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_view.dart';
import '../widgets/pro_cards.dart';
import '../widgets/ui_helpers.dart';

/// The dashboard, exactly like the HTML (Complete v7) dashboard:
/// "Aaj ka khulasa — <date>", the same 8 stat cards in the same order,
/// the Absent Today / On Leave Today name cards (only when someone is
/// absent or on leave), the Class-wise Strength donut, and the Fee Heads
/// table. No attendance %, no Defaulters, no Month Profit here — the
/// HTML keeps those in Fees / Reports, not on the dashboard.
class PrincipalDashboardScreen extends StatefulWidget {
  const PrincipalDashboardScreen({super.key});

  @override
  State<PrincipalDashboardScreen> createState() =>
      _PrincipalDashboardScreenState();
}

class _PrincipalDashboardScreenState extends State<PrincipalDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (_, p, __) {
        if (p.loading && p.data == null) return const LoadingView();
        if (p.error != null && p.data == null) {
          return EmptyState(message: p.error!, icon: Icons.cloud_off_outlined);
        }
        final d = p.data;
        final cards = [
          HtmlStatCard(
            label: 'Total Students',
            value: '${d?.totalStudents ?? 0}',
          ),
          HtmlStatCard(
            label: 'Classes',
            value: '${d?.totalClasses ?? 0}',
          ),
          HtmlStatCard(
            label: 'Present Today',
            value: '${d?.presentToday ?? 0}',
          ),
          HtmlStatCard(
            label: 'Absent Today',
            value: '${d?.absentToday ?? 0}',
          ),
          HtmlStatCard(
            label: 'On Leave Today',
            value: '${d?.onLeaveToday ?? 0}',
          ),
          HtmlStatCard(
            label: 'Fee Collected (this month)',
            value: fmtMoney(d?.feeCollectedMonth ?? 0),
          ),
          HtmlStatCard(
            label: 'Staff',
            value: '${d?.totalStaff ?? 0}',
          ),
          HtmlStatCard(
            label: 'Expenses (this month)',
            value: fmtMoney(d?.expensesMonth ?? 0),
          ),
        ];
        return RefreshIndicator(
          onRefresh: () => p.load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aaj ka khulasa — ${DateFormat('EEE MMM d yyyy').format(DateTime.now())}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (_, constraints) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          statColumnsForWidth(constraints.maxWidth),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 92,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (_, i) => cards[i],
                  ),
                ),
                if ((d?.absentToday ?? 0) > 0) ...[
                  const SizedBox(height: 18),
                  _NameCard(
                    title: 'Absent Today',
                    names: d?.absentNames ?? const [],
                  ),
                ],
                if ((d?.onLeaveToday ?? 0) > 0) ...[
                  const SizedBox(height: 18),
                  _NameCard(
                    title: 'On Leave Today',
                    names: d?.leaveNames ?? const [],
                  ),
                ],
                const SizedBox(height: 18),
                Card(
                  elevation: 2,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class-wise Strength',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClassDonut(
                          strength: d?.classStrength ?? const [],
                          total: d?.totalStudents ?? 0,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 2,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fee Heads',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 40,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('Fee Head')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('Frequency')),
                          ],
                          rows: (d?.feeHeads ?? const [])
                              .map(
                                (h) => DataRow(
                                  cells: [
                                    DataCell(Text(h.name)),
                                    DataCell(Text(fmtMoney(h.amount))),
                                    DataCell(Text(h.frequency)),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The HTML's Absent Today / On Leave Today card: a title and the
/// "Name (Class)" list, shown only when the list is non-empty.
class _NameCard extends StatelessWidget {
  final String title;
  final List<String> names;

  const _NameCard({required this.title, required this.names});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 8),
            Text(names.join(', '), style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
