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
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/backend_client.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendClient.instance.init();
  // Open the local database (seeds first-run data) and start the sync engine
  // before the UI boots, so every screen works offline from the first frame.
  await SyncService.instance.init();
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
        home: Consumer<AuthProvider>(
          builder: (_, auth, __) {
            if (auth.isChecking) return const SplashScreen();
            if (auth.isLoggedIn) return const HomeShell();
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
