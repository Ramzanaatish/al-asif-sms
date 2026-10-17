import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/comms_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/ui_helpers.dart';

/// Tab screen (inside HomeShell) — no app bar of its own.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  bool get _canPublish {
    final role = context.read<AuthProvider>().role;
    return role == 'principal' ||
        role == 'administrator' ||
        role == 'teacher' ||
        role == 'accountant';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommsProvider>().loadNotices();
    });
  }

  Future<void> _publish() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String audience = 'all';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Publish notice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleCtrl,
                    decoration: fieldDecoration('Title')),
                const SizedBox(height: 10),
                TextField(
                    controller: bodyCtrl,
                    decoration: fieldDecoration('Message'),
                    maxLines: 4),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: audience,
                  decoration: fieldDecoration('Audience'),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Everyone')),
                    DropdownMenuItem(
                        value: 'parents', child: Text('Parents')),
                    DropdownMenuItem(
                        value: 'staff', child: Text('Staff')),
                  ],
                  onChanged: (v) => setS(() => audience = v ?? 'all'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Publish')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
      showSnack(context, 'Title and message are required.', error: true);
      return;
    }
    try {
      await context.read<CommsProvider>().publishNotice({
        'title': titleCtrl.text.trim(),
        'body': bodyCtrl.text.trim(),
        'audience': audience,
      });
      if (!mounted) return;
      showSnack(context, 'Notice published.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canPublish
          ? FloatingActionButton(
              onPressed: _publish,
              child: const Icon(Icons.add),
            )
          : null,
      body: Consumer<CommsProvider>(
        builder: (_, p, __) {
          if (p.loading && p.notices.isEmpty) return const LoadingView();
          if (p.error != null && p.notices.isEmpty) {
            return EmptyState(
                message: p.error!, icon: Icons.cloud_off_outlined);
          }
          if (p.notices.isEmpty) {
            return const EmptyState(message: 'No notices yet.');
          }
          return RefreshIndicator(
            onRefresh: () => p.loadNotices(),
            child: ListView.builder(
              itemCount: p.notices.length,
              itemBuilder: (_, i) {
                final n = p.notices[i];
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
                              child: Text(n.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ),
                            Chip(
                              label: Text(n.audience,
                                  style: const TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(n.body),
                        const SizedBox(height: 8),
                        Text(
                          '${fmtDate(n.createdAt)}${n.createdBy.isNotEmpty ? ' - ${n.createdBy}' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
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
