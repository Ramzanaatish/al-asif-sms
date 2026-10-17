import 'package:flutter/material.dart';

import '../config.dart';

class LoadingView extends StatelessWidget {
  final String message;
  const LoadingView({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.navy),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
