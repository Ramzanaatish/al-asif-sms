import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/comms.dart';
import '../../providers/comms_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';
import 'complaints_screen.dart';
import 'notices_screen.dart';

/// Parent home: summary cards per child (attendance %, fee balance,
/// last result %) + shortcuts to notices and complaints.
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommsProvider>().loadParentSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommsProvider>(
      builder: (_, p, __) {
        if (p.loading && p.children.isEmpty) return const LoadingView();
        if (p.error != null && p.children.isEmpty) {
          return EmptyState(
              message: p.error!, icon: Icons.cloud_off_outlined);
        }
        return RefreshIndicator(
          onRefresh: () => p.loadParentSummary(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (p.children.isEmpty)
                const EmptyState(
                    message: 'No children linked to this account.'),
              ...p.children.map(_childCard),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.campaign),
                      label: const Text('Notices'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NoticesScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.report_problem),
                      label: const Text('Complaints'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ComplaintsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _childCard(ChildSummary c) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: Text(c.name.isEmpty ? '?' : c.name[0],
                      style:
                          const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(c.className,
                          style: const TextStyle(
                              color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric('Attendance',
                    '${c.attendancePct.toStringAsFixed(1)}%',
                    c.attendancePct >= 90
                        ? AppColors.success
                        : c.attendancePct >= 75
                            ? Colors.orange
                            : AppColors.danger),
                _metric('Fee balance', fmtMoney(c.feeBalance),
                    c.feeBalance > 0
                        ? AppColors.danger
                        : AppColors.success),
                _metric('Last result',
                    '${c.lastResultPct.toStringAsFixed(1)}%',
                    AppColors.navy),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}
