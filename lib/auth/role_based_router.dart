import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/auth/auth_screen.dart';
import 'package:priject_jalrakshak/screens/industry_admin_home.dart';
import 'package:priject_jalrakshak/screens/normal_user_home.dart';
import 'package:priject_jalrakshak/widgets/loading_screen.dart';

class RoleBasedRouter extends StatelessWidget {
  const RoleBasedRouter({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const AuthScreen(
            infoMessage:
                'Profile not found for this account. Please sign up again.',
          );
        }

        final role = snapshot.data!.data()?['role'] as String?;
        final name = snapshot.data!.data()?['name'] as String? ?? 'User';

        if (role == 'industry_admin') {
          return IndustryAdminHome(name: name);
        }
        return NormalUserHome(name: name);
      },
    );
  }
}

