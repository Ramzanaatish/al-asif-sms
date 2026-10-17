import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Shows [child] only when the logged-in user's role is in [roles].
class RoleGate extends StatelessWidget {
  final List<String> roles;
  final Widget child;
  final Widget? fallback;

  const RoleGate({
    super.key,
    required this.roles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? '';
    if (roles.contains(role)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
