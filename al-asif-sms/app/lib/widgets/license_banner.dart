import 'package:flutter/material.dart';

import '../services/license_service.dart';

/// Amber warning banner shown under the app bar when the license expires
/// within [LicenseService.warningDays] days. Hidden otherwise.
class LicenseBanner extends StatelessWidget {
  const LicenseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // The license is enforced only in the mobile app (APK). The desktop
    // software never shows this banner.
    if (!LicenseService.isLicenseEnforced) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: LicenseService.instance,
      builder: (_, __) {
        final service = LicenseService.instance;
        if (!service.needsWarning) return const SizedBox.shrink();
        final days = service.daysLeft ?? 0;
        return Container(
          width: double.infinity,
          color: Colors.amber.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.key_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'License $days din mein khatam ho rahi hai — nayi key '
                  'ke liye ${LicenseService.supportPhone} par rabta karein.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
