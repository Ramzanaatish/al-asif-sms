import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'providers/attendance_provider.dart';
import 'providers/audit_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/academics_provider.dart';
import 'providers/comms_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/exams_provider.dart';
import 'providers/expenses_provider.dart';
import 'providers/fees_provider.dart';
import 'providers/staff_provider.dart';
import 'providers/student_provider.dart';
import 'screens/boot_screen.dart';
import 'services/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Boot the UI immediately. Heavy init (database, backup, sync engine) runs
  // inside BootScreen with visible progress, so it can never white-screen
  // the app again.
  runApp(const AlAsifApp());
}

class AlAsifApp extends StatelessWidget {
  const AlAsifApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SyncService.instance),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => AcademicsProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => ExamsProvider()),
        ChangeNotifierProvider(create: (_) => FeesProvider()),
        ChangeNotifierProvider(create: (_) => ExpensesProvider()),
        ChangeNotifierProvider(create: (_) => CommsProvider()),
        ChangeNotifierProvider(create: (_) => AuditProvider()),
      ],
      child: MaterialApp(
        title: 'Al-Asif SMS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: AppColors.navy,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.navy,
            secondary: AppColors.gold,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
          ),
        ),
        home: const BootScreen(),
      ),
    );
  }
}
