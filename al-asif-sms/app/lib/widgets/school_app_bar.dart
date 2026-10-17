import 'package:flutter/material.dart';

import '../config.dart';

/// App bar with the school logo and a navy/gold branded look.
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          if (showLogo)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Image.asset(
                'assets/logo.png',
                height: 36,
                width: 36,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.school, color: AppColors.gold),
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              overflow: TextOverflow.ellipsis,
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
