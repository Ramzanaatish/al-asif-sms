import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comms_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';

/// Tab screen (inside HomeShell) — no app bar of its own.
/// Parents file complaints; staff resolve them.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  bool get _isParent => context.read<AuthProvider>().isParent == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommsProvider>().loadComplaints();
    });
  }

  Future<void> _file() async {
    // Parent picks one of their children for the complaint.
    final comms = context.read<CommsProvider>();
    await comms.loadParentSummary();
    if (!mounted) return;
    final children = comms.children;
    int? studentId = children.isNotEmpty ? children.first.studentId : null;
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('File a complaint'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (children.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: studentId,
                    decoration: fieldDecoration('Student'),
                    items: children
                        .map((ch) => DropdownMenuItem(
                            value: ch.studentId,
                            child: Text(ch.name)))
                        .toList(),
                    onChanged: (v) => setS(() => studentId = v),
                  ),
                if (children.isNotEmpty) const SizedBox(height: 10),
                TextField(
                    controller: subjectCtrl,
                    decoration: fieldDecoration('Subject')),
                const SizedBox(height: 10),
                TextField(
                    controller: bodyCtrl,
                    decoration: fieldDecoration('Details'),
                    maxLines: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (subjectCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
      showSnack(context, 'Subject and details are required.', error: true);
      return;
    }
    try {
      await context.read<CommsProvider>().fileComplaint({
        'student_id': studentId,
        'subject': subjectCtrl.text.trim(),
        'body': bodyCtrl.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Complaint submitted.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _resolve(int id, String status) async {
    final ok = await confirmDialog(
        context, 'Complaint', 'Mark this complaint as $status?');
    if (!ok || !mounted) return;
    try {
      await context.read<CommsProvider>().resolveComplaint(id, status);
      if (!mounted) return;
      showSnack(context, 'Complaint marked $status.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isParent
          ? FloatingActionButton(
              onPressed: _file,
              child: const Icon(Icons.add),
            )
          : null,
      body: Consumer<CommsProvider>(
        builder: (_, p, __) {
          if (p.loading && p.complaints.isEmpty) return const LoadingView();
          if (p.error != null && p.complaints.isEmpty) {
            return EmptyState(
                message: p.error!, icon: Icons.cloud_off_outlined);
          }
          if (p.complaints.isEmpty) {
            return const EmptyState(message: 'No complaints.');
          }
          return RefreshIndicator(
            onRefresh: () => p.loadComplaints(),
            child: ListView.builder(
              itemCount: p.complaints.length,
              itemBuilder: (_, i) {
                final c = p.complaints[i];
                final open = c.status == 'open';
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(c.subject,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ),
                            Chip(
                              label: Text(c.status,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white)),
                              backgroundColor: open
                                  ? Colors.orange
                                  : AppColors.success,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (c.studentName.isNotEmpty)
                          Text(c.studentName,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(c.body),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmtDate(c.createdAt),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54)),
                            if (!_isParent && open)
                              TextButton(
                                onPressed: () =>
                                    _resolve(c.id, 'resolved'),
                                child: const Text('Mark resolved'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
