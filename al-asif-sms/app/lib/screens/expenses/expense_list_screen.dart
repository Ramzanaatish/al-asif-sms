import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expenses_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';
import 'add_expense_screen.dart';

/// Tab screen (inside HomeShell) — no app bar of its own.
class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpensesProvider>().loadCategories();
      _reload();
    });
  }

  void _reload() => context.read<ExpensesProvider>().loadExpenses(
      month: _month, year: _year, categoryId: _categoryId);

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<ExpensesProvider>().categories;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        tooltip: 'Add expense',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AddExpenseScreen()),
        ).then((_) => _reload()),
        child: const Icon(Icons.add),
      ),
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
                    value: _categoryId,
                    decoration: fieldDecoration('Category'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All')),
                      ...cats.map((c) => DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) {
                      setState(() => _categoryId = v);
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
                if (p.expenses.isEmpty) {
                  return const EmptyState(
                      message: 'No expenses for this period.');
                }
                final total = p.expenses
                    .fold<double>(0, (s, e) => s + e.amount);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(fmtMoney(total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: p.expenses.length,
                        itemBuilder: (_, i) {
                          final e = p.expenses[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.money_off,
                                  color: Colors.red),
                              title: Text(e.description.isEmpty
                                  ? e.categoryName
                                  : e.description),
                              subtitle: Text(
                                  '${e.categoryName} - ${fmtDate(e.date)}${e.paidTo.isNotEmpty ? ' - to ${e.paidTo}' : ''}'),
                              trailing: Text(fmtMoney(e.amount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
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
