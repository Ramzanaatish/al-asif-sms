import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fee.dart';
import '../../providers/fees_provider.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';
import 'receipt_preview_screen.dart';

/// Collect a single challan's fee, then show the full-size Urdu receipt.
class CollectFeeScreen extends StatefulWidget {
  final Challan challan;
  const CollectFeeScreen({super.key, required this.challan});

  @override
  State<CollectFeeScreen> createState() => _CollectFeeScreenState();
}

class _CollectFeeScreenState extends State<CollectFeeScreen> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _discountCtrl;
  String _method = 'cash';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.challan.balance.toStringAsFixed(0));
    _discountCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _collect() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    if (amount == null || amount <= 0) {
      showSnack(context, 'Enter a valid amount.', error: true);
      return;
    }
    final ok = await confirmDialog(context, 'Collect fee',
        'Collect ${fmtMoney(amount)} from ${widget.challan.studentName} via $_method?');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final receipt = await context.read<FeesProvider>().collect(
            widget.challan.id,
            amount: amount,
            discount: discount,
            paymentMethod: _method,
          );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptPreviewScreen(receipt: receipt),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challan;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Collect Fee'),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          InfoCard(title: 'Challan', children: [
            InfoRow(label: 'Challan no', value: c.challanNo),
            InfoRow(label: 'Student', value: c.studentName),
            InfoRow(
                label: 'Month', value: '${monthName(c.month)} ${c.year}'),
            InfoRow(label: 'Total', value: fmtMoney(c.totalAmount)),
            InfoRow(label: 'Paid so far', value: fmtMoney(c.amountPaid)),
            InfoRow(
                label: 'Balance',
                value: fmtMoney(c.balance)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: fieldDecoration('Amount to collect (Rs) *'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _discountCtrl,
            decoration: fieldDecoration('Discount (Rs)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _method,
            decoration: fieldDecoration('Payment method'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
              DropdownMenuItem(value: 'online', child: Text('Online')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Collect & Show Receipt'),
              onPressed: _busy ? null : _collect,
            ),
          ),
        ],
      ),
    );
  }
}
