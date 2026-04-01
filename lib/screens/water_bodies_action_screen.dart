import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/screens/water_body_detail_screen.dart';

class WaterBodiesActionScreen extends StatefulWidget {
  const WaterBodiesActionScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<WaterBodiesActionScreen> createState() =>
      _WaterBodiesActionScreenState();
}

class _WaterBodiesActionScreenState extends State<WaterBodiesActionScreen> {
  final GlobalKey<FormState> _reportFormKey = GlobalKey<FormState>();
  final TextEditingController _waterBodyController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final Set<String> _joinedCampaignIds = <String>{};

  String _selectedIssueType = 'Sewage Discharge';

  static const List<Map<String, dynamic>> _monitorData = [
    {
      'name': 'Ganga - Varanasi',
      'status': 'High Risk',
      'bod': 5.8,
      'trend': '+9% this month',
      'color': Color(0xFFDC2626),
    },
    {
      'name': 'Yamuna - Delhi Stretch',
      'status': 'Critical',
      'bod': 8.2,
      'trend': '+14% this month',
      'color': Color(0xFFB91C1C),
    },
    {
      'name': 'Narmada - Central Belt',
      'status': 'Stable',
      'bod': 2.4,
      'trend': '-3% this month',
      'color': Color(0xFF15803D),
    },
    {
      'name': 'Godavari - Urban Segment',
      'status': 'Moderate',
      'bod': 3.1,
      'trend': '+4% this month',
      'color': Color(0xFFD97706),
    },
  ];

  static const List<Map<String, dynamic>> _campaigns = [
    {
      'id': 'cmp-01',
      'title': 'Weekend Lake Cleanup Drive',
      'place': 'Assi Ghat, Varanasi',
      'time': 'Sunday, 7:00 AM',
      'volunteers': 142,
    },
    {
      'id': 'cmp-02',
      'title': 'Canal Watch Volunteer Program',
      'place': 'Prayagraj Urban Canal',
      'time': 'Saturday, 8:30 AM',
      'volunteers': 89,
    },
    {
      'id': 'cmp-03',
      'title': 'Community Water Testing Camp',
      'place': 'Patna Riverfront',
      'time': 'Saturday, 10:00 AM',
      'volunteers': 56,
    },
  ];

  @override
  void dispose() {
    _waterBodyController.dispose();
    _issueController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (!_reportFormKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Report submitted successfully. Our team will verify and notify you.'),
        backgroundColor: Color(0xFF15803D),
      ),
    );

    _waterBodyController.clear();
    _issueController.clear();
    _locationController.clear();
    setState(() => _selectedIssueType = 'Sewage Discharge');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAFD),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A3D62),
          title: const Text('Water Bodies Action Center'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Monitor'),
              Tab(text: 'Report'),
              Tab(text: 'Campaigns'),
              Tab(text: 'Stats'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMonitorTab(),
            _buildReportTab(),
            _buildCampaignsTab(),
            _buildStatsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _monitorData.length,
      itemBuilder: (context, index) {
        final item = _monitorData[index];
        final Color color = item['color'] as Color;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withValues(alpha: 0.22)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WaterBodyDetailScreen(
                    name: item['name'].toString(),
                    status: item['status'].toString(),
                    bod: item['bod'].toString(),
                    trend: item['trend'].toString(),
                    fact:
                        'Live monitored segment for proactive intervention and local action.',
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item['status'] as String,
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'BOD: ${item['bod']} mg/L',
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trend: ${item['trend']}',
                    style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _reportFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Pollution Incident',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _waterBodyController,
                  decoration: const InputDecoration(
                    labelText: 'Water Body Name',
                    hintText: 'e.g. Yamuna - Wazirabad',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter water body name'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedIssueType,
                  decoration: const InputDecoration(labelText: 'Issue Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Sewage Discharge',
                        child: Text('Sewage Discharge')),
                    DropdownMenuItem(
                        value: 'Industrial Waste',
                        child: Text('Industrial Waste')),
                    DropdownMenuItem(
                        value: 'Plastic Dumping',
                        child: Text('Plastic Dumping')),
                    DropdownMenuItem(
                        value: 'Foam/Chemical Layer',
                        child: Text('Foam/Chemical Layer')),
                    DropdownMenuItem(
                        value: 'Oil Spill', child: Text('Oil Spill')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedIssueType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _issueController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Incident Details',
                    hintText: 'Describe what you observed',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 10)
                          ? 'Please add at least 10 characters'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'Nearby landmark or area',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A3D62),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitReport,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit Report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _campaigns.length,
      itemBuilder: (context, index) {
        final item = _campaigns[index];
        final id = item['id'] as String;
        final joined = _joinedCampaignIds.contains(id);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('Location: ${item['place']}',
                    style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 4),
                Text('Time: ${item['time']}',
                    style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 4),
                Text('Volunteers joined: ${item['volunteers']}',
                    style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (joined) {
                          _joinedCampaignIds.remove(id);
                        } else {
                          _joinedCampaignIds.add(id);
                        }
                      });
                    },
                    icon: Icon(
                        joined ? Icons.check_circle : Icons.volunteer_activism),
                    label: Text(joined ? 'Joined' : 'Join Campaign'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _StatTile(
          title: 'Active Monitored Water Bodies',
          value: '296',
          subtitle: 'Across 22 states',
          progress: 0.72,
          color: Color(0xFF0284C7),
        ),
        SizedBox(height: 12),
        _StatTile(
          title: 'Verified Pollution Reports',
          value: '1,284',
          subtitle: 'Last 90 days',
          progress: 0.81,
          color: Color(0xFFDC2626),
        ),
        SizedBox(height: 12),
        _StatTile(
          title: 'Campaign Participation',
          value: '8,940',
          subtitle: 'Community volunteers',
          progress: 0.66,
          color: Color(0xFF16A34A),
        ),
        SizedBox(height: 12),
        _StatTile(
          title: 'Average BOD Improvement',
          value: '11.8%',
          subtitle: 'Compared to last year',
          progress: 0.58,
          color: Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: color.withValues(alpha: 0.16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
