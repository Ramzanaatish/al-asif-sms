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

    return Scaffold(
      appBar: SchoolAppBar(
        title: entry.title,
        actions: const [SyncBadge()],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.navy),
              margin: EdgeInsets.zero,
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
                  final selected = i == _index;
                  return ListTile(
                    leading: Icon(m.icon,
                        color:
                            selected ? AppColors.navy : Colors.black54),
                    title: Text(m.title,
                        style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected
                                ? AppColors.navy
                                : Colors.black87)),
                    selected: selected,
                    selectedTileColor: AppColors.goldLight.withValues(alpha: 0.5),
                    onTap: () {
                      setState(() => _index = i);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Log Out'),
              onTap: () async {
                final authProvider = context.read<AuthProvider>();
                Navigator.pop(context);
                await authProvider.logout();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const LicenseBanner(),
          Expanded(child: entry.builder()),
        ],
      ),
    );
  }
}
