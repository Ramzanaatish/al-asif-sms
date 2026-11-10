import 'package:flutter/material.dart';

import '../config.dart';

/// App bar with the school logo and a navy/gold branded look.
/// Shows the school name above the screen title, so every screen carries
/// the brand — the same header the HTML app uses.
class SchoolAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;

  const SchoolAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          if (showLogo)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school,
                      color: AppColors.gold,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConfig.schoolShortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(height: 3, color: AppColors.gold),
      ),
    );
  }
}
