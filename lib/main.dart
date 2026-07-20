import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const EvidenceVaultApp());
}

class EvidenceVaultApp extends StatelessWidget {
  const EvidenceVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evidence Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B36F4),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}