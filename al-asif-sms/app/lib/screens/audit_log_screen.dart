import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/audit_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_view.dart';
import '../widgets/ui_helpers.dart';

/// Tab screen (inside HomeShell) — no app bar of its own. Principal only.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuditProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuditProvider>(
      builder: (_, p, __) {
        if (p.loading && p.entries.isEmpty) return const LoadingView();
        if (p.error != null && p.entries.isEmpty) {
          return EmptyState(
              message: p.error!, icon: Icons.cloud_off_outlined);
        }
        if (p.entries.isEmpty) {
          return const EmptyState(message: 'No audit entries.');
        }
        return RefreshIndicator(
          onRefresh: () => p.load(),
          child: ListView.builder(
            itemCount: p.entries.length,
            itemBuilder: (_, i) {
              final e = p.entries[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.history,
                      size: 20, color: Colors.black54),
                  title: Text(e.action,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${e.user}${e.entity.isNotEmpty ? ' - ${e.entity}${e.entityId.isNotEmpty ? ' #${e.entityId}' : ''}' : ''}'),
                  trailing: Text(fmtDate(e.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
