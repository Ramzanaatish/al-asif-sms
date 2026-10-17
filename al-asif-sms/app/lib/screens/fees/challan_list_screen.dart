import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/fees_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';
import 'collect_fee_screen.dart';

class ChallanListScreen extends StatefulWidget {
  const ChallanListScreen({super.key});

  @override
  State<ChallanListScreen> createState() => _ChallanListScreenState();
}

class _ChallanListScreenState extends State<ChallanListScreen> {
  String? _status;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() => context
      .read<FeesProvider>()
      .loadChallans(month: _month, year: _year, status: _status);

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return AppColors.success;
      case 'partial':
        return Colors.orange;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Challans'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
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
                        items:
                            [for (var y = _year - 2; y <= _year + 1; y++) y]
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip(null, 'All'),
                    const SizedBox(width: 8),
                    _chip('unpaid', 'Unpaid'),
                    const SizedBox(width: 8),
                    _chip('partial', 'Partial'),
                    const SizedBox(width: 8),
                    _chip('paid', 'Paid'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<FeesProvider>(
              builder: (_, p, __) {
                if (p.loading) return const LoadingView();
                if (p.error != null) {
                  return EmptyState(
                      message: p.error!, icon: Icons.cloud_off_outlined);
                }
                if (p.challans.isEmpty) {
                  return const EmptyState(
                      message: 'No challans for this period.');
                }
                return ListView.builder(
                  itemCount: p.challans.length,
                  itemBuilder: (_, i) {
                    final c = p.challans[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(c.studentName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Challan ${c.challanNo} - Balance ${fmtMoney(c.balance)}'),
                        trailing: Chip(
                          label: Text(c.status,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor: _statusColor(c.status),
                          visualDensity: VisualDensity.compact,
                        ),
                        onTap: c.status == 'paid'
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CollectFeeScreen(challan: c),
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
