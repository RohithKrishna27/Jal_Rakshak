import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/auth/auth_screen.dart';
import 'package:priject_jalrakshak/auth/role_based_router.dart';
import 'package:priject_jalrakshak/widgets/loading_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen();
        }
        return RoleBasedRouter(uid: user.uid);
      },
    );
  }
}

