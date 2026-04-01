import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/models/info_card_data.dart';
import 'package:priject_jalrakshak/widgets/role_home_scaffold.dart';

class IndustryAdminHome extends StatelessWidget {
  const IndustryAdminHome({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      title: 'Welcome, $name',
      subtitle: 'Industry Admin Dashboard',
      icon: Icons.factory_outlined,
      accent: const Color(0xFF005F99),
      cards: const [
        InfoCardData('Compliance', 'Upload and monitor compliance data'),
        InfoCardData('Emission Logs', 'Manage industrial discharge records'),
        InfoCardData('Admin Actions', 'Review and approve submissions'),
      ],
    );
  }
}

