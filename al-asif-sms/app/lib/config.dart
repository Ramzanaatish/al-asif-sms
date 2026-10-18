import 'package:flutter/material.dart';

/// Single source of truth for app-wide configuration.
class AppConfig {
  /// Base URL of the FastAPI backend. Change this to the server's LAN IP
  /// (e.g. 'http://192.168.1.50:8000') when running on a physical device.
  /// The default works on the Android emulator.
  static String apiBaseUrl = 'http://10.0.2.2:8000'; // overridden at runtime from Settings/login screen

  static const String schoolName = 'AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN';
  static const String schoolNameRegistered =
      'AL-ASIF PUBLIC MIDDLE SCHOOL BASTI SHAIKHAN \u00AE';
  static const String schoolShortName = 'Al-Asif Public Middle School';
  static const String principalName = 'Mrs. Hajra Iqbal';

  /// Class order used for dropdowns (matches backend level_order).
  static const List<String> classNames = [
    'Play Group',
    'Nursery',
    'Prep',
    '1st',
    '2nd',
    '3rd',
    '4th',
    '5th',
    '6th',
    '7th',
    '8th',
  ];
}

/// Brand palette.
class AppColors {
  static const Color navy = Color(0xFF1A237E);
  static const Color navyDark = Color(0xFF0D1442);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldLight = Color(0xFFF5E9C8);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
}
