import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/staff.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Tab-capable screen: pay salary per staff per month + list.
/// (Used as an accountant tab and pushed from StaffListScreen.)
class SalaryScreen extends StatefulWidget {
  /// When true the screen renders inside HomeShell's tab (no app bar).
  /// Pass false when pushed via Navigator so a back button shows.
  final bool embedded;
  const SalaryScreen({super.key, this.embedded = true});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaffProvider>().loadStaff();
      _reload();
    });
  }

  void _reload() =>
      context.read<StaffProvider>().loadSalaries(month: _month, year: _year);

  Future<void> _payDialog(StaffMember s) async {
    final allowCtrl = TextEditingController(text: '0');
    final deductCtrl = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Pay salary - ${s.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoRow(label: 'Basic', value: fmtMoney(s.salaryMonthly)),
            InfoRow(
                label: 'Month', value: '${monthName(_month)} $_year'),
            const SizedBox(height: 8),
            TextField(
                controller: allowCtrl,
                decoration: fieldDecoration('Allowances (Rs)'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(
                controller: deductCtrl,
                decoration: fieldDecoration('Deductions (Rs)'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Pay')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final rec = await context.read<StaffProvider>().paySalary({
        'staff_id': s.id,
        'month': _month,
        'year': _year,
        'allowances': double.tryParse(allowCtrl.text.trim()) ?? 0,
        'deductions': double.tryParse(deductCtrl.text.trim()) ?? 0,
      });
      if (!mounted) return;
      showSnack(context, 'Paid ${fmtMoney(rec.net)} to ${s.name}.');
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>().staff;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : const SchoolAppBar(title: 'Salaries'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                    items: [for (var y = _year - 2; y <= _year + 1; y++)
                      y].map((y) => DropdownMenuItem(
                        value: y, child: Text('$y'))).toList(),
                    onChanged: (v) {
                      setState(() => _year = v ?? _year);
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<StaffProvider>(
              builder: (_, p, __) {
                if (p.loading && p.salaries.isEmpty) {
                  return const LoadingView();
                }
                final paidIds =
                    p.salaries.map((s) => s.staffId).toSet();
                if (staff.isEmpty) {
                  return const EmptyState(message: 'No staff found.');
                }
                return ListView.builder(
                  itemCount: staff.length,
                  itemBuilder: (_, i) {
                    final s = staff[i];
                    final paid = paidIds.contains(s.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Basic ${fmtMoney(s.salaryMonthly)} - ${s.designation}'),
                        trailing: paid
                            ? const Chip(
                                label: Text('Paid',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white)),
                                backgroundColor: Colors.green)
                            : ElevatedButton(
                                onPressed: () => _payDialog(s),
                                child: const Text('Pay'),
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
}
