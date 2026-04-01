import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/data/water_bodies_demo_data.dart';
import 'package:priject_jalrakshak/screens/user/user_screen_welcome.dart';

/// Standalone screen: campaigns list with join state.
class JoinCampaignScreen extends StatefulWidget {
  const JoinCampaignScreen({super.key});

  @override
  State<JoinCampaignScreen> createState() => _JoinCampaignScreenState();
}

class _JoinCampaignScreenState extends State<JoinCampaignScreen> {
  final Set<String> _joinedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: const Text('Join a campaign'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const UserScreenWelcome(
            icon: Icons.campaign_outlined,
            title: 'Welcome, changemaker',
            subtitle:
                'Pick a nearby drive, show up, and help restore rivers and lakes one action at a time.',
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: WaterBodiesDemoData.campaigns.length,
            itemBuilder: (context, index) {
              final item = WaterBodiesDemoData.campaigns[index];
              final id = item['id'] as String;
              final joined = _joinedIds.contains(id);
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Location: ${item['place']}',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time: ${item['time']}',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Volunteers: ${item['volunteers']}',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              if (joined) {
                                _joinedIds.remove(id);
                              } else {
                                _joinedIds.add(id);
                              }
                            });
                          },
                          icon: Icon(
                            joined
                                ? Icons.check_circle
                                : Icons.volunteer_activism,
                          ),
                          label: Text(joined ? 'Joined' : 'Join campaign'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
