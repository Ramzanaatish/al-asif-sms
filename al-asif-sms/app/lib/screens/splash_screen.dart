import 'package:flutter/material.dart';

import '../config.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
            const CircularProgressIndicator(color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
