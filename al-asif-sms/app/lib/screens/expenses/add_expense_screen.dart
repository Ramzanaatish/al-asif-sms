import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expenses_provider.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _date = TextEditingController();
  final _description = TextEditingController();
  final _paidTo = TextEditingController();
  final _newCategory = TextEditingController();
  int? _categoryId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _date.text = ymd(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpensesProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    _description.dispose();
    _paidTo.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    if (_newCategory.text.trim().isEmpty) return;
    try {
      await context
          .read<ExpensesProvider>()
          .createCategory(_newCategory.text.trim());
      if (!mounted) return;
      _newCategory.clear();
      showSnack(context, 'Category added.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      showSnack(context, 'Select a category.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<ExpensesProvider>().addExpense({
        'category_id': _categoryId,
        'date': _date.text.trim(),
        'amount': double.parse(_amount.text.trim()),
        'description': _description.text.trim(),
        'paid_to': _paidTo.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Expense recorded.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<ExpensesProvider>().categories;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Add Expense'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _categoryId,
                    decoration: fieldDecoration('Category *'),
                    items: cats
                        .map((c) => DropdownMenuItem<int?>(
                            value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategory,
                    decoration: fieldDecoration('New category'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: _addCategory,
                    child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                      controller: _amount,
                      decoration:
                          fieldDecoration('Amount (Rs) *'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                      controller: _date,
                      decoration:
                          fieldDecoration('Date (YYYY-MM-DD) *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
                controller: _description,
                decoration: fieldDecoration('Description *'),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 10),
            TextFormField(
                controller: _paidTo,
                decoration: fieldDecoration('Paid to')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
