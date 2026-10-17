import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_view.dart';
import '../widgets/role_gate.dart';
import '../widgets/ui_helpers.dart';

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
          return EmptyState(
              message: p.error!, icon: Icons.cloud_off_outlined);
        }
        final d = p.data;
        return RefreshIndicator(
          onRefresh: () => p.load(),
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(12),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _card(context, 'Total Students', '${d?.totalStudents ?? 0}',
                  Icons.people, AppColors.navy),
              _card(context, 'Fee Collected (Month)',
                  fmtMoney(d?.feeCollectedMonth ?? 0), Icons.payments,
                  AppColors.success),
              _card(
                  context,
                  "Today's Attendance",
                  '${(d?.attendancePctToday ?? 0).toStringAsFixed(1)}%',
                  Icons.fact_check,
                  Colors.indigo),
              _card(context, 'Staff Present Today',
                  '${d?.staffPresentToday ?? 0} / ${d?.totalStaff ?? 0}',
                  Icons.badge, Colors.teal),
              _card(context, 'Defaulters',
                  '${d?.defaultersCount ?? 0}', Icons.warning_amber,
                  AppColors.danger),
              RoleGate(
                roles: const ['principal', 'administrator'],
                child: _card(context, 'Month Profit',
                    fmtMoney(d?.profitMonth ?? 0), Icons.trending_up,
                    (d?.profitMonth ?? 0) >= 0
                        ? AppColors.success
                        : AppColors.danger),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, String title, String value, IconData icon,
      Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 2),
                Text(title,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
