import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/exams_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/role_gate.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamsProvider>().loadTerms();
    });
  }

  Future<void> _addTerm() async {
    final nameCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    String type = 'monthly';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Add term'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        fieldDecoration('Name (e.g. March Test)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: fieldDecoration('Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                        value: 'annual', child: Text('Annual')),
                  ],
                  onChanged: (v) => setS(() => type = v ?? 'monthly'),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: startCtrl,
                    decoration: fieldDecoration(
                        'Start date (YYYY-MM-DD)')),
                const SizedBox(height: 10),
                TextField(
                    controller: endCtrl,
                    decoration:
                        fieldDecoration('End date (YYYY-MM-DD)')),
              ],
            ),
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
    if (ok != true || !mounted || nameCtrl.text.trim().isEmpty) return;
    try {
      await context.read<ExamsProvider>().createTerm({
        'name': nameCtrl.text.trim(),
        'term_type': type,
        'start_date':
            startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
        'end_date': endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Term added.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Exam Terms'),
      floatingActionButton: RoleGate(
        roles: const ['principal', 'administrator'],
        child: FloatingActionButton(
          onPressed: _addTerm,
          child: const Icon(Icons.add),
        ),
      ),
      body: Consumer<ExamsProvider>(
        builder: (_, p, __) {
          if (p.loading && p.terms.isEmpty) return const LoadingView();
          if (p.error != null && p.terms.isEmpty) {
            return EmptyState(
                message: p.error!, icon: Icons.cloud_off_outlined);
          }
          if (p.terms.isEmpty) {
            return const EmptyState(message: 'No terms yet.');
          }
          return ListView.builder(
            itemCount: p.terms.length,
            itemBuilder: (_, i) {
              final t = p.terms[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Icon(
                      t.termType == 'annual'
                          ? Icons.emoji_events
                          : Icons.event_note,
                      color: AppColors.navy),
                  title: Text(t.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${t.termType}${t.startDate != null && t.startDate!.isNotEmpty ? ' - ${fmtDate(t.startDate)} to ${fmtDate(t.endDate)}' : ''}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
