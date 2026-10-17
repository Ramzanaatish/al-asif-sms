import 'package:flutter/material.dart';

import '../../config.dart';
import 'batch_receipt_screen.dart';
import 'challan_generate_screen.dart';
import 'challan_list_screen.dart';
import 'collection_report_screen.dart';
import 'defaulters_screen.dart';
import 'fee_heads_screen.dart';

/// Tab hub for the Fees module.
class FeesHomeScreen extends StatelessWidget {
  const FeesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Fee Heads', Icons.category, const FeeHeadsScreen()),
      _Item('Generate Challans', Icons.receipt, const ChallanGenerateScreen()),
      _Item('Challans / Collect', Icons.payments, const ChallanListScreen()),
      _Item('Batch Receipts', Icons.print, const BatchReceiptScreen()),
      _Item('Defaulters', Icons.warning_amber, const DefaultersScreen()),
      _Item('Collection Report', Icons.bar_chart,
          const CollectionReportScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: items
          .map((it) => Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => it.screen),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(it.icon, size: 44, color: AppColors.navy),
                      const SizedBox(height: 10),
                      Text(it.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _Item {
  final String title;
  final IconData icon;
  final Widget screen;
  _Item(this.title, this.icon, this.screen);
}
