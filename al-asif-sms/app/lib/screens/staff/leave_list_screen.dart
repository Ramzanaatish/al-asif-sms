import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class LeaveListScreen extends StatefulWidget {
  const LeaveListScreen({super.key});

  @override
  State<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends State<LeaveListScreen> {
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() => context.read<StaffProvider>().loadLeaves(status: _status);

  Future<void> _decide(int id, String decision) async {
    final ok = await confirmDialog(context, 'Leave request',
        'Mark this leave as $decision?');
    if (!ok || !mounted) return;
    try {
      await context.read<StaffProvider>().decideLeave(id, decision);
      if (!mounted) return;
      showSnack(context, 'Leave $decision.');
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Color _color(String s) {
    switch (s) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Leave Requests'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                _chip(null, 'All'),
                const SizedBox(width: 8),
                _chip('pending', 'Pending'),
                const SizedBox(width: 8),
                _chip('approved', 'Approved'),
                const SizedBox(width: 8),
                _chip('rejected', 'Rejected'),
              ],
            ),
          ),
          Expanded(
            child: Consumer<StaffProvider>(
              builder: (_, p, __) {
                if (p.loading) return const LoadingView();
                if (p.error != null) {
                  return EmptyState(
                      message: p.error!, icon: Icons.cloud_off_outlined);
                }
                if (p.leaves.isEmpty) {
                  return const EmptyState(
                      message: 'No leave requests.');
                }
                return ListView.builder(
                  itemCount: p.leaves.length,
                  itemBuilder: (_, i) {
                    final l = p.leaves[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(l.staffName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                ),
                                Chip(
                                  label: Text(l.status,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white)),
                                  backgroundColor: _color(l.status),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                                '${fmtDate(l.fromDate)} to ${fmtDate(l.toDate)}',
                                style: const TextStyle(
                                    color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(l.reason),
                            if (l.status == 'pending')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _decide(l.id, 'rejected'),
                                    child: const Text('Reject',
                                        style: TextStyle(
                                            color: AppColors.danger)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _decide(l.id, 'approved'),
                                    child: const Text('Approve'),
                                  ),
                                ],
                              ),
                          ],
                        ),
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

  Widget _chip(String? value, String label) {
    final selected = _status == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.navy,
      labelStyle:
          TextStyle(color: selected ? Colors.white : Colors.black87),
      onSelected: (_) {
        setState(() => _status = value);
        _reload();
      },
    );
  }
}
