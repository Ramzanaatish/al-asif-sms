import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../navigation.dart';
import '../providers/auth_provider.dart';
import '../widgets/license_banner.dart';
import '../widgets/school_app_bar.dart';
import '../widgets/sync_widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Wide window (desktop): the left bar is pinned open, always visible.
  /// Narrow window (phone): the classic slide-in drawer.
  static const double _wideWidth = 800;
  static const double _sidebarWidth = 260;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final menu = menuForRole(auth.role ?? '');
    if (menu.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No screens available for this role.')),
      );
    }
    if (_index >= menu.length) _index = 0;
    final entry = menu[_index];
    final wide = MediaQuery.sizeOf(context).width >= _wideWidth;

    final body = Column(
      children: [
        const OfflineBanner(),
        const LicenseBanner(),
        Expanded(child: entry.builder()),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: SchoolAppBar(
          title: entry.title,
          actions: const [SyncBadge()],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _sidebarWidth,
              child: _NavColumn(
                menu: menu,
                index: _index,
                auth: auth,
                onSelect: (i) => setState(() => _index = i),
                onLogout: () => context.read<AuthProvider>().logout(),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: SchoolAppBar(
        title: entry.title,
        actions: const [SyncBadge()],
      ),
      drawer: Drawer(
        child: _NavColumn(
          menu: menu,
          index: _index,
          auth: auth,
          onSelect: (i) {
            setState(() => _index = i);
            Navigator.pop(context);
          },
          onLogout: () async {
            Navigator.pop(context);
            await context.read<AuthProvider>().logout();
          },
        ),
      ),
      body: body,
    );
  }
}

/// The left navigation: school header, menu entries, Log Out at the bottom.
/// Used both as the pinned sidebar (wide window) and as the drawer content
/// (narrow window).
class _NavColumn extends StatelessWidget {
  final List<MenuEntry> menu;
  final int index;
  final AuthProvider auth;
  final void Function(int) onSelect;
  final VoidCallback onLogout;

  const _NavColumn({
    required this.menu,
    required this.index,
    required this.auth,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            color: AppColors.navy,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 56,
                  width: 56,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school,
                      size: 48, color: AppColors.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppConfig.schoolShortName,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${auth.user?.fullName ?? ''} (${auth.role ?? ''})',
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: menu.length,
              itemBuilder: (_, i) {
                final m = menu[i];
                final selected = i == index;
                return ListTile(
                  leading: Icon(m.icon,
                      color: selected ? AppColors.navy : Colors.black54),
                  title: Text(m.title,
                      style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          color:
                              selected ? AppColors.navy : Colors.black87)),
                  selected: selected,
                  selectedTileColor:
                      AppColors.goldLight.withValues(alpha: 0.5),
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Log Out'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
