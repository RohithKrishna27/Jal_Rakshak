import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/app/theme/app_theme.dart';
import 'package:priject_jalrakshak/auth/auth_gate.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jal Rakshak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}

