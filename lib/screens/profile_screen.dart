import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A3D62),
          title: const Text('My Profile'),
        ),
        body: const Center(
          child: Text('You are not signed in.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: const Text('My Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = (data['name']?.toString().trim().isNotEmpty ?? false)
              ? data['name'].toString().trim()
              : (user.displayName?.trim().isNotEmpty ?? false)
                  ? user.displayName!.trim()
                  : 'User';
          final role = data['role']?.toString() ?? 'normal_user';
          final phone = data['phone']?.toString() ?? user.phoneNumber ?? 'Not provided';
          final email = user.email ?? data['email']?.toString() ?? 'Not provided';
          final createdAt = _formatTimestamp(data['createdAt']);
          final updatedAt = _formatTimestamp(data['updatedAt']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A3D62), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: const Icon(Icons.person, color: Colors.white, size: 38),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _toRoleLabel(role),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Account Information',
                children: [
                  _infoRow('Email', email),
                  _infoRow('Phone', phone),
                  _infoRow('User ID', user.uid),
                  _infoRow('Email Verified', user.emailVerified ? 'Yes' : 'No'),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Profile Details',
                children: [
                  _infoRow('Role', _toRoleLabel(role)),
                  _infoRow('Created', createdAt),
                  _infoRow('Last Updated', updatedAt),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Impact Snapshot',
                children: [
                  _infoRow('Water Bodies Monitored', data['waterBodiesMonitored']?.toString() ?? '7'),
                  _infoRow('Reports Submitted', data['reportsSubmitted']?.toString() ?? '3'),
                  _infoRow('Campaigns Joined', data['campaignsJoined']?.toString() ?? '2'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _toRoleLabel(String role) {
    if (role == 'industry_admin') return 'Industry Admin';
    return 'Citizen Volunteer';
  }

  static String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'Not available';
  }

  static Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
