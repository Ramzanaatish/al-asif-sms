import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../services/sync_service.dart';

/// App-wide sync indicator shown in the home shell app bar.
///
/// * green cloud  -> online, nothing pending
/// * amber badge  -> N changes waiting to sync (tap to force a sync)
/// * grey cloud   -> offline (tap does nothing)
/// While a sync is running a small spinner replaces the icon.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (_, sync, __) {
        final online = sync.isOnline;
        final pending = sync.pendingCount;
        final syncing = sync.isSyncing;
        final color = !online
            ? Colors.grey
            : pending > 0
                ? AppColors.gold
                : Colors.greenAccent;
        return IconButton(
          tooltip: !online
              ? 'Offline — changes will sync when connected'
              : pending > 0
                  ? '$pending change(s) waiting — tap to sync now'
                  : 'All changes synced',
          onPressed: (online && !syncing) ? () => sync.syncNow() : null,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              if (syncing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              else
                Icon(
                    online
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: color),
              if (pending > 0 && !syncing)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      pending > 99 ? '99+' : '$pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Slim banner shown above every screen while the device is offline or the
/// current session was established offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final offlineMode = context.select<AuthProvider, bool>((a) => a.offlineMode);
    return Consumer<SyncService>(
      builder: (_, sync, __) {
        if (sync.isOnline && !offlineMode) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Colors.amber.shade800,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offlineMode
                      ? 'Offline mode — working from saved data'
                      : 'No internet — working offline, will sync automatically',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (sync.pendingCount > 0)
                Text(
                  '${sync.pendingCount} pending',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }
}
