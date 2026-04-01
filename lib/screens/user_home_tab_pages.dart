import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/screens/user/join_campaign_screen.dart';
import 'package:priject_jalrakshak/screens/user/monitor_water_bodies_screen.dart';
import 'package:priject_jalrakshak/screens/user/report_pollution_screen.dart';
import 'package:priject_jalrakshak/screens/user/view_stats_screen.dart';

/// Bottom-nav: four **separate** screens (not the old single-tab shell).
class MonitorWaterBodiesPage extends StatelessWidget {
  const MonitorWaterBodiesPage({super.key});

  @override
  Widget build(BuildContext context) => const MonitorWaterBodiesScreen();
}

class ReportPollutionPage extends StatelessWidget {
  const ReportPollutionPage({super.key});

  @override
  Widget build(BuildContext context) => const ReportPollutionScreen();
}

class JoinCampaignPage extends StatelessWidget {
  const JoinCampaignPage({super.key});

  @override
  Widget build(BuildContext context) => const JoinCampaignScreen();
}

class ViewStatsPage extends StatelessWidget {
  const ViewStatsPage({super.key});

  @override
  Widget build(BuildContext context) => const ViewStatsScreen();
}
