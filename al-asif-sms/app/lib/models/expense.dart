class ExpenseCategory {
  final int id;
  final String name;

  const ExpenseCategory({required this.id, required this.name});

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
      );
}

class Expense {
  final int id;
  final int? categoryId;
  final String categoryName;
  final String date;
  final double amount;
  final String description;
  final String paidTo;

  const Expense({
    required this.id,
    this.categoryId,
    this.categoryName = '',
    this.date = '',
    this.amount = 0,
    this.description = '',
    this.paidTo = '',
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: (j['id'] as num?)?.toInt() ?? 0,
        categoryId: (j['category_id'] as num?)?.toInt(),
        categoryName: j['category_name']?.toString() ??
            j['category']?.toString() ??
            '',
        date: j['date']?.toString() ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        description: j['description']?.toString() ?? '',
        paidTo: j['paid_to']?.toString() ?? '',
      );
}

class CategoryTotal {
  final String category;
  final double amount;

  const CategoryTotal({this.category = '', this.amount = 0});

  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(
        category: j['category']?.toString() ??
            j['category_name']?.toString() ??
            '',
        amount: (j['amount'] as num?)?.toDouble() ??
            (j['total'] as num?)?.toDouble() ??
            0,
      );
}

class ProfitLoss {
  final int month;
  final int year;
  final double feeCollected;
  final double expensesTotal;
  final double salariesTotal;
  final double totalOutgoing;
  final double netProfit;
  final List<CategoryTotal> expensesByCategory;

  const ProfitLoss({
    this.month = 0,
    this.year = 0,
    this.feeCollected = 0,
    this.expensesTotal = 0,
    this.salariesTotal = 0,
    this.totalOutgoing = 0,
    this.netProfit = 0,
    this.expensesByCategory = const [],
  });

  factory ProfitLoss.fromJson(Map<String, dynamic> j) {
    final cats = (j['expenses_by_category'] as List?) ?? const [];
    return ProfitLoss(
      month: (j['month'] as num?)?.toInt() ?? 0,
      year: (j['year'] as num?)?.toInt() ?? 0,
      feeCollected: (j['fee_collected'] as num?)?.toDouble() ?? 0,
      expensesTotal: (j['expenses_total'] as num?)?.toDouble() ?? 0,
      salariesTotal: (j['salaries_total'] as num?)?.toDouble() ?? 0,
      totalOutgoing: (j['total_outgoing'] as num?)?.toDouble() ?? 0,
      netProfit: (j['net_profit'] as num?)?.toDouble() ?? 0,
      expensesByCategory: cats
          .map((c) => CategoryTotal.fromJson((c as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
