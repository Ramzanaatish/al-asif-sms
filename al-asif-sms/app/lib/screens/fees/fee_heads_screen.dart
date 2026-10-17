import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/fees_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class FeeHeadsScreen extends StatefulWidget {
  const FeeHeadsScreen({super.key});

  @override
  State<FeeHeadsScreen> createState() => _FeeHeadsScreenState();
}

class _FeeHeadsScreenState extends State<FeeHeadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeesProvider>().loadHeads();
    });
  }

  Future<void> _addHead() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String frequency = 'monthly';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Add fee head'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: fieldDecoration('Name (e.g. Tuition Fee)')),
              const SizedBox(height: 10),
              TextField(
                  controller: amountCtrl,
                  decoration: fieldDecoration('Amount (Rs)'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: frequency,
                decoration: fieldDecoration('Frequency'),
                items: const [
                  DropdownMenuItem(
                      value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(
                      value: 'annual', child: Text('Annual')),
                  DropdownMenuItem(
                      value: 'onetime', child: Text('One-time')),
                ],
                onChanged: (v) => setS(() => frequency = v ?? 'monthly'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (nameCtrl.text.trim().isEmpty ||
        (double.tryParse(amountCtrl.text.trim()) ?? 0) <= 0) {
      showSnack(context, 'Enter a name and a valid amount.', error: true);
      return;
    }
    try {
      await context.read<FeesProvider>().createHead({
        'name': nameCtrl.text.trim(),
        'amount': double.parse(amountCtrl.text.trim()),
        'frequency': frequency,
      });
      if (!mounted) return;
      showSnack(context, 'Fee head added.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Fee Heads'),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHead,
        child: const Icon(Icons.add),
      ),
      body: Consumer<FeesProvider>(
        builder: (_, p, __) {
          if (p.loading && p.heads.isEmpty) return const LoadingView();
          if (p.error != null && p.heads.isEmpty) {
            return EmptyState(
                message: p.error!, icon: Icons.cloud_off_outlined);
          }
          if (p.heads.isEmpty) {
            return const EmptyState(message: 'No fee heads defined.');
          }
          return ListView.builder(
            itemCount: p.heads.length,
            itemBuilder: (_, i) {
              final h = p.heads[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.category, color: Colors.indigo),
                  title: Text(h.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(h.frequency),
                  trailing: Text(fmtMoney(h.amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
