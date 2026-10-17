import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';
import 'add_staff_screen.dart';
import 'leave_list_screen.dart';
import 'salary_screen.dart';
import 'staff_detail_screen.dart';

/// Tab screen (inside HomeShell) — no app bar of its own.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  String? _type; // null = all, teaching, non_teaching

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() =>
      context.read<StaffProvider>().loadStaff(staffType: _type);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'leaves',
            tooltip: 'Leave requests',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const LeaveListScreen()),
            ).then((_) => _reload()),
            child: const Icon(Icons.event_busy),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'salaries',
            tooltip: 'Salaries',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SalaryScreen(embedded: false)),
            ),
            child: const Icon(Icons.payments),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            tooltip: 'Add staff',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddStaffScreen()),
            ).then((_) => _reload()),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                _typeChip(null, 'All'),
                const SizedBox(width: 8),
                _typeChip('teaching', 'Teaching'),
                const SizedBox(width: 8),
                _typeChip('non_teaching', 'Non-teaching'),
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
                if (p.staff.isEmpty) {
                  return const EmptyState(message: 'No staff found.');
                }
                return ListView.builder(
                  itemCount: p.staff.length,
                  itemBuilder: (_, i) {
                    final s = p.staff[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.staffType == 'teaching'
                              ? AppColors.navy
                              : Colors.teal,
                          child: Text(s.name.isEmpty ? '?' : s.name[0],
                              style:
                                  const TextStyle(color: Colors.white)),
                        ),
                        title: Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${s.designation} - ${fmtMoney(s.salaryMonthly)}/mo'),
                        trailing: Text(
                            s.staffType == 'teaching'
                                ? 'Teaching'
                                : 'Non-teaching',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StaffDetailScreen(id: s.id),
                          ),
                        ).then((_) => _reload()),
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

  Widget _typeChip(String? value, String label) {
    final selected = _type == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.navy,
      labelStyle:
          TextStyle(color: selected ? Colors.white : Colors.black87),
      onSelected: (_) {
        setState(() => _type = value);
        _reload();
      },
    );
  }
}
