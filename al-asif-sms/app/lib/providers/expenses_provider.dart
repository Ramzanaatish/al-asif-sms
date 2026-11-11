import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../repositories/expenses_repository.dart';

class ExpensesProvider extends ChangeNotifier {
  final _repo = ExpensesRepository();

  List<ExpenseCategory> categories = [];
  List<Expense> expenses = [];
  ProfitLoss? profitLoss;
  bool loading = false;
  String? error;

  Future<void> loadCategories() async {
    try {
      categories = await _repo.categories();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> createCategory(String name) async {
    await _repo.createCategory(name);
    await loadCategories();
  }

  Future<void> loadExpenses({int? month, int? year, int? categoryId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      expenses =
          await _repo.list(month: month, year: year, categoryId: categoryId);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> addExpense(Map<String, dynamic> body) async {
    await _repo.create(body);
    notifyListeners();
  }

  Future<void> deleteExpense(int id) async {
    await _repo.delete(id);
    notifyListeners();
  }

  Future<void> loadProfitLoss({int? month, int? year}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profitLoss = await _repo.profitLoss(month: month, year: year);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}
