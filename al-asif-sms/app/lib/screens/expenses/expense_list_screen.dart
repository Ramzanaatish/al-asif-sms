import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/expenses_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

/// Expenses — one screen, matching the HTML v7 Expenses screen: inline
/// "Add Expense" card (category, amount, date, note), a "This Month:
/// Rs X" card, and the table Date | Category | Note | Amount | Delete.
/// No separate add screen and no year/month filters (the HTML has
/// neither). The "This Month" total is this month's expenses, matching
/// the card's label (the HTML's code sums all expenses — its label
/// wins, as on the v1.4.0 dashboard).
class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  int? _categoryId;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _message;
  bool _messageError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ExpensesProvider>();
      p.loadCategories();
      p.loadExpenses();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _message = 'Amount aur date zaroori hain.';
        _messageError = true;
      });
      return;
    }
    final p = context.read<ExpensesProvider>();
    await p.addExpense({
      'category_id': _categoryId,
      'amount': amount,
      'date': _date.toIso8601String().substring(0, 10),
      'description': _note.text.trim().isEmpty ? '-' : _note.text.trim(),
    });
    await p.loadExpenses();
    if (!mounted) return;
    setState(() {
      _message = 'Expense saved.';
      _messageError = false;
      _amount.clear();
      _note.clear();
    });
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this expense?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      final p = context.read<ExpensesProvider>();
      await p.deleteExpense(id);
      await p.loadExpenses();
    }
  }

  double _thisMonthTotal(ExpensesProvider p) {
    final now = DateTime.now();
    final prefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    var sum = 0.0;
    for (final e in p.expenses) {
      if (e.date.startsWith(prefix)) sum += e.amount;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Expenses'),
      body: Consumer<ExpensesProvider>(
        builder: (context, p, _) {
          if (p.loading && p.expenses.isEmpty && p.categories.isEmpty) {
            return const LoadingView();
          }
          if (p.error != null &&
              p.expenses.isEmpty &&
              p.categories.isEmpty) {
            return EmptyState(message: p.error!);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kharcha add karein — category, amount, date.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Add Expense',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _categoryId,
                              decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder()),
                              items: p.categories
                                  .map((c) => DropdownMenuItem<int>(
                                      value: c.id, child: Text(c.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _categoryId = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _amount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Amount (Rs)',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                const Text('Date: '),
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _date,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _date = picked);
                                    }
                                  },
                                  child: Text(_date
                                      .toIso8601String()
                                      .substring(0, 10)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _note,
                              decoration: const InputDecoration(
                                  labelText:
                                      'Note (e.g. Electricity bill)',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _addExpense,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: Colors.black),
                            child: const Text('Add Expense'),
                          ),
                        ],
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 8),
                        Text(_message!,
                            style: TextStyle(
                                color: _messageError
                                    ? Colors.red
                                    : Colors.green[800])),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'This Month: ${fmtMoney(_thisMonthTotal(p))}',
                  child: p.expenses.isEmpty
                      ? const Text('Koi expense nahi.',
                          style: TextStyle(color: Colors.grey))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Category')),
                              DataColumn(label: Text('Note')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('')),
                            ],
                            rows: p.expenses.map((e) {
                              return DataRow(cells: [
                                DataCell(Text(fmtDate(e.date))),
                                DataCell(Text(e.categoryName)),
                                DataCell(Text(e.description)),
                                DataCell(Text(fmtMoney(e.amount))),
                                DataCell(TextButton(
                                  onPressed: () => _delete(e.id),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
