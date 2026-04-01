import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/models/info_card_data.dart';
import 'package:priject_jalrakshak/widgets/role_home_scaffold.dart';

class NormalUserHome extends StatelessWidget {
  const NormalUserHome({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      title: 'Welcome, $name',
      subtitle: 'Normal User Dashboard',
      icon: Icons.eco_outlined,
      accent: const Color(0xFF0C8A43),
      cards: const [
        InfoCardData('Water Quality', 'Track local water pollution updates'),
        InfoCardData('Biodiversity', 'View nearby biodiversity insights'),
        InfoCardData('Report Issue', 'Submit public pollution reports'),
      ],
    );
  }
}

