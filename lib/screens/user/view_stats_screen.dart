import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/screens/user/user_screen_welcome.dart';
import 'package:priject_jalrakshak/widgets/water_body_stat_tile.dart';

/// Standalone screen: national / app-level stats.
class ViewStatsScreen extends StatelessWidget {
  const ViewStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: const Text('View stats'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const UserScreenWelcome(
            icon: Icons.bar_chart_outlined,
            title: 'Welcome to your impact dashboard',
            subtitle:
                'These numbers summarise community monitoring, reports, and participation — demo data for illustration.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const WaterBodyStatTile(
                  title: 'Active monitored water bodies',
                  value: '296',
                  subtitle: 'Across 22 states',
                  progress: 0.72,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(height: 12),
                const WaterBodyStatTile(
                  title: 'Verified pollution reports',
                  value: '1,284',
                  subtitle: 'Last 90 days',
                  progress: 0.81,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(height: 12),
                const WaterBodyStatTile(
                  title: 'Campaign participation',
                  value: '8,940',
                  subtitle: 'Community volunteers',
                  progress: 0.66,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(height: 12),
                const WaterBodyStatTile(
                  title: 'Average BOD improvement',
                  value: '11.8%',
                  subtitle: 'Compared to last year',
                  progress: 0.58,
                  color: Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
