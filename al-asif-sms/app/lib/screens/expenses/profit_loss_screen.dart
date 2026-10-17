import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/expenses_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/role_gate.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Profit & Loss: fee collected, expenses by category, salaries, net profit.
/// Profit figures are visible to principal/administrator/accountant only.
class ProfitLossScreen extends StatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() => context
      .read<ExpensesProvider>()
      .loadProfitLoss(month: _month, year: _year);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Profit & Loss'),
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
              ],
            ),
          ),
          Expanded(
            child: Consumer<ExpensesProvider>(
              builder: (_, p, __) {
                if (p.loading) return const LoadingView();
                if (p.error != null) {
                  return EmptyState(
                      message: p.error!, icon: Icons.cloud_off_outlined);
                }
                final r = p.profitLoss;
                if (r == null) {
                  return const EmptyState(
                      message: 'No data for this period.');
                }
                return RoleGate(
                  roles: const [
                    'principal',
                    'administrator',
                    'accountant'
                  ],
                  fallback: const EmptyState(
                      message:
                          'You do not have permission to view profit & loss.',
                      icon: Icons.lock_outline),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Net profit — prominent
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: r.netProfit >= 0
                              ? AppColors.success
                              : AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('NET PROFIT',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 6),
                            Text(fmtMoney(r.netProfit),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold)),
                            Text('${monthName(r.month)} ${r.year}',
                                style: const TextStyle(
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      InfoCard(title: 'Income', children: [
                        InfoRow(
                            label: 'Fee collected',
                            value: fmtMoney(r.feeCollected)),
                      ]),
                      InfoCard(title: 'Outgoing', children: [
                        InfoRow(
                            label: 'Salaries',
                            value: fmtMoney(r.salariesTotal)),
                        InfoRow(
                            label: 'Other expenses',
                            value: fmtMoney(r.expensesTotal)),
                        const Divider(),
                        InfoRow(
                            label: 'Total outgoing',
                            value: fmtMoney(r.totalOutgoing)),
                      ]),
                      if (r.expensesByCategory.isNotEmpty)
                        InfoCard(
                            title: 'Expenses by category',
                            children: r.expensesByCategory
                                .map((c) => InfoRow(
                                    label: c.category,
                                    value: fmtMoney(c.amount)))
                                .toList()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
