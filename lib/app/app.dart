import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/app/theme/app_theme.dart';
import 'package:priject_jalrakshak/auth/auth_gate.dart';
import 'package:priject_jalrakshak/screens/chatbot_screen.dart';
import 'package:priject_jalrakshak/screens/globe_screen.dart';
import 'package:priject_jalrakshak/screens/profile_screen.dart';
import 'package:priject_jalrakshak/screens/user/join_campaign_screen.dart';
import 'package:priject_jalrakshak/screens/user/monitor_water_bodies_screen.dart';
import 'package:priject_jalrakshak/screens/user/report_pollution_screen.dart';
import 'package:priject_jalrakshak/screens/user/view_stats_screen.dart';
import 'package:priject_jalrakshak/industry/industry_portal_args.dart';
import 'package:priject_jalrakshak/screens/industry/industry_portal_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jal Rakshak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
      routes: {
        '/chatbot': (context) => const ChatbotScreen(),
        '/globe': (context) => const GlobeScreen(),
        '/profile': (context) => const UserProfileScreen(),
        '/monitor-water-bodies': (context) => const MonitorWaterBodiesScreen(),
        '/report-pollution': (context) => const ReportPollutionScreen(),
        '/join-campaign': (context) => const JoinCampaignScreen(),
        '/view-stats': (context) => const ViewStatsScreen(),
        '/industry-portal': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return IndustryPortalScreen(
            args: args is IndustryPortalArgs
                ? args
                : const IndustryPortalArgs(adminDisplayName: 'Industry'),
          );
        },
      },
    );
  }
}

