import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/models/info_card_data.dart';

class RoleHomeScaffold extends StatelessWidget {
  const RoleHomeScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<InfoCardData> cards;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subtitle),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: accent.withOpacity(0.18),
                  child: Icon(icon, color: accent, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...cards.map(
            (card) => Card(
              child: ListTile(
                title: Text(card.title),
                subtitle: Text(card.subtitle),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

