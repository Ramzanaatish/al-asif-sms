import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../services/backend_client.dart';
import '../services/license_service.dart';
import '../services/sync_service.dart';
import 'home_shell.dart';
import 'license_screen.dart';
import 'login_screen.dart';

/// First screen: boots local services (database, backup, sync engine) with
/// visible progress. The UI renders FIRST, so a slow or failing init can never
/// white-screen the app again — failures show here with a Retry button.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  String _status = 'Starting...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _error = null;
      _status = 'Preparing...';
    });
    try {
      await BackendClient.instance.init().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _status = 'Opening local database...');
      await SyncService.instance.init().timeout(const Duration(seconds: 60));
      if (!mounted) return;
      setState(() => _status = 'Checking license...');
      await LicenseService.instance.load();
    } on TimeoutException {
      if (!mounted) return;
      setState(() =>
          _error = 'Startup timed out. Please check storage and tap Retry.');
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Startup failed: $e');
      return;
    }
    if (!mounted) return;
    if (LicenseService.isLicenseEnforced &&
        !LicenseService.instance.isLicensed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LicenseScreen()),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 130,
              width: 130,
              errorBuilder: (_, __, ___) => const Icon(Icons.school,
                  size: 100, color: AppColors.gold),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                AppConfig.schoolNameRegistered,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'School Management System',
              style: TextStyle(color: AppColors.gold, fontSize: 15),
            ),
            const SizedBox(height: 36),
            if (_error == null) ...[
              const CircularProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 16),
              Text(_status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _boot,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Post-boot gate: shows splash while auth resolves, then home or login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.isChecking) {
          return const Scaffold(
            backgroundColor: AppColors.navy,
            body: Center(
                child:
                    CircularProgressIndicator(color: AppColors.gold)),
          );
        }
        if (auth.isLoggedIn) return const HomeShell();
        return const LoginScreen();
      },
    );
  }
}
