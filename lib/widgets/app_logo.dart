// lib/widgets/app_logo.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/app_logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class DuluinHeader extends StatelessWidget {
  const DuluinHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Duluin',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w900,
        fontSize: 26,
        letterSpacing: 0.5,
      ),
    );
  }
}
