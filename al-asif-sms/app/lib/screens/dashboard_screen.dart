import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_view.dart';
import '../widgets/pro_cards.dart';
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
        final cards = [
          StatCard(
            label: 'Total Students',
            value: '${d?.totalStudents ?? 0}',
            icon: Icons.people,
            color: AppColors.navy,
          ),
          StatCard(
            label: 'Fee Collected (Month)',
            value: fmtMoney(d?.feeCollectedMonth ?? 0),
            icon: Icons.payments,
            color: AppColors.success,
          ),
          StatCard(
            label: "Today's Attendance",
            value: '${(d?.attendancePctToday ?? 0).toStringAsFixed(1)}%',
            icon: Icons.fact_check,
            color: Colors.indigo,
          ),
          StatCard(
            label: 'Staff Present Today',
            value: '${d?.staffPresentToday ?? 0} / ${d?.totalStaff ?? 0}',
            icon: Icons.badge,
            color: Colors.teal,
          ),
          StatCard(
            label: 'Defaulters',
            value: '${d?.defaultersCount ?? 0}',
            icon: Icons.warning_amber,
            color: AppColors.danger,
          ),
          RoleGate(
            roles: const ['principal', 'administrator'],
            child: StatCard(
              label: 'Month Profit',
              value: fmtMoney(d?.profitMonth ?? 0),
              icon: Icons.trending_up,
              color: (d?.profitMonth ?? 0) >= 0
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ),
        ];
        return RefreshIndicator(
          onRefresh: () => p.load(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: statColumns(context),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 100,
            ),
            itemCount: cards.length,
            itemBuilder: (_, i) => cards[i],
          ),
        );
      },
    );
  }
}
