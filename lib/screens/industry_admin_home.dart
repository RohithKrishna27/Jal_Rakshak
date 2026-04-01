import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class IndustryAdminHome extends StatefulWidget {
  const IndustryAdminHome({super.key, required this.name});
  final String name;

  @override
  State<IndustryAdminHome> createState() => _IndustryAdminHomeState();
}

class _IndustryAdminHomeState extends State<IndustryAdminHome> {
  late Timer _clockTimer;
  int _riverIndex = 0;
  int _msgIndex = 0;

  String _countdown = "0000 DAYS 00:00:00";
  String _currentRiverInfo = "";
  String _currentMessage = "";

  Position? _industryPosition;
  bool _isLoadingLocation = false;
  bool _isAnalyzing = false;

  String _industryName = '';
  String _selectedSector = 'Chemical';

  final List<String> _sectors = [
    'Chemical',
    'Textile',
    'Pharmaceutical',
    'Sugar Mill',
    'Paper',
    'Distillery',
    'Other'
  ];

  // Gemini results
  String _potentialHarmText = '';
  List<String> _publicComplaints = [];

  // ====================== CLOCK DATA ======================
  static const List<String> MESSAGES = [
    "India still has 296 polluted river stretches (CPCB). From 351 in 2018 — progress, but not enough.",
    "Yamuna in Delhi carries nearly 70% sewage load. Urban pollution is choking our rivers.",
    "If pollution trends continue, several Indian rivers may face ecological tipping points by 2045.",
    "Industries + untreated sewage are the biggest threats to India's rivers.",
    "Healthy rivers mean safe drinking water, biodiversity, and food security.",
    "One clock. One mission: Revive India's rivers before it's too late.",
    "The countdown is not just time — it is the future of Ganga, Yamuna, Godavari and Krishna."
  ];

  static const List<Map<String, dynamic>> RIVER_DATA = [
    {
      "name": "Ganga",
      "bod": "5.8",
      "status": "Highly Polluted",
      "fact": "Sacred river, but many stretches remain polluted"
    },
    {
      "name": "Yamuna",
      "bod": "8.2",
      "status": "Severely Polluted",
      "fact": "Delhi’s sewage turns it into one of India’s most toxic rivers"
    },
    {
      "name": "Godavari",
      "bod": "3.1",
      "status": "Moderately Polluted",
      "fact": "Lifeline of South India facing industrial waste"
    },
    {
      "name": "Krishna",
      "bod": "4.5",
      "status": "Moderately Polluted",
      "fact": "Major irrigation river with rising pollution levels"
    },
    {
      "name": "Narmada",
      "bod": "2.4",
      "status": "Clean in stretches",
      "fact": "One of the cleaner rivers – we must protect it"
    },
  ];

  static final DateTime TARGET_DATE = DateTime(2055, 1, 1);
  static const int POLLUTED_STRETCHES = 296;

  @override
  void initState() {
    super.initState();
    _currentMessage = MESSAGES[0];
    _currentRiverInfo = _displayRiverInfo(0);
    _startRiverRevivalClock();
  }

  String _calculateCountdown() {
    final now = DateTime.now();
    final delta = TARGET_DATE.difference(now);
    if (delta.isNegative) return "MISSION COMPLETE! Rivers Revived?";

    final days = delta.inDays;
    final hours = delta.inHours.remainder(24);
    final minutes = delta.inMinutes.remainder(60);
    final seconds = delta.inSeconds.remainder(60);

    return "${days.toString().padLeft(4, '0')} DAYS "
        "${hours.toString().padLeft(2, '0')}:"
        "${minutes.toString().padLeft(2, '0')}:"
        "${seconds.toString().padLeft(2, '0')}";
  }

  String _displayRiverInfo(int index) {
    final river = RIVER_DATA[index % RIVER_DATA.length];
    return "${river['name']} | BOD: ${river['bod']} mg/L | ${river['status']}\n${river['fact']}";
  }

  void _startRiverRevivalClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown = _calculateCountdown();
      });

      if (timer.tick % 20 == 0) {
        setState(() {
          _riverIndex++;
          _currentRiverInfo = _displayRiverInfo(_riverIndex);
        });
      }
      if (timer.tick % 40 == 0) {
        setState(() {
          _msgIndex++;
          _currentMessage = MESSAGES[_msgIndex % MESSAGES.length];
        });
      }
    });
  }

  // ====================== LOCATION & GEMINI ANALYSIS ======================
  Future<void> _getLocationAndAnalyzeImpact() async {
    setState(() => _isLoadingLocation = true);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')));
      setState(() => _isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')));
      setState(() => _isLoadingLocation = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _industryPosition = position;
      _isLoadingLocation = false;
    });

    await _callGeminiForIndustrialImpact();
  }

  Future<void> _callGeminiForIndustrialImpact() async {
    setState(() => _isAnalyzing = true);
    _potentialHarmText = '';
    _publicComplaints.clear();

    const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing GEMINI_API_KEY. Run with: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY',
          ),
        ),
      );
      setState(() => _isAnalyzing = false);
      return;
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey',
    );

    final prompt = '''
Industry: $_industryName (${_selectedSector} sector)
Location: Latitude ${_industryPosition?.latitude ?? 0}, Longitude ${_industryPosition?.longitude ?? 0}

Analyze:
1. Potential harm to any river surface within 500 meters (pollution pathways, BOD impact, ecological risk).
2. Any known public complaints / NGO / CPCB reports for similar industries in this area.

Return ONLY valid JSON (no extra text):
{
  "potential_harm": "Detailed paragraph about risks within 500m",
  "public_complaints": ["complaint 1", "complaint 2", ...]
}
''';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {"parts": [{"text": prompt}]}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data['candidates'][0]['content']['parts'][0]['text'];

        if (rawText.contains('```json')) {
          rawText = rawText.split('```json')[1].split('```')[0].trim();
        }

        final jsonMap = jsonDecode(rawText) as Map<String, dynamic>;
        setState(() {
          _potentialHarmText = jsonMap['potential_harm'] ?? 'No data available';
          _publicComplaints = List<String>.from(jsonMap['public_complaints'] ?? []);
        });
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        elevation: 0,
        title: const Text('Jal Rakshak • Industry',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.name}',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A3D62)),
            ),
            const Text('Industry Dashboard – Monitor your river impact',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 28),

            // River Revival Clock
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0A3D62), Color(0xFF1E5A8C)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF0A3D62).withOpacity(0.3),
                      blurRadius: 20)
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.water_drop, color: Colors.white, size: 42),
                      SizedBox(width: 12),
                      Text('RIVER REVIVAL CLOCK',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_countdown,
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('until 2055 • Healthy Rivers Mission',
                      style: TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 20),
                  Text(
                      '🌊 $POLLUTED_STRETCHES polluted stretches left in India',
                      style: const TextStyle(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  const Divider(color: Colors.white30, height: 30),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(_currentRiverInfo,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 14),
                  _allRiversPreview(),
                  const SizedBox(height: 16),
                  Text('💡 $_currentMessage',
                      style: const TextStyle(
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFFFD700)),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Industry Details
            const Text('Your Industry Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => _industryName = v,
              decoration: InputDecoration(
                labelText: 'Industry Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSector,
              decoration: InputDecoration(
                labelText: 'Sector',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: _sectors
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSector = val!),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: (_isLoadingLocation || _isAnalyzing)
                  ? null
                  : _getLocationAndAnalyzeImpact,
              icon: const Icon(Icons.analytics),
              label: const Text('Analyze 500m River Impact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A3D62),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),

            if (_industryPosition != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    '📍 ${_industryPosition!.latitude.toStringAsFixed(2)}, ${_industryPosition!.longitude.toStringAsFixed(2)}'),
              ),

            const SizedBox(height: 30),

            // Analysis Results
            if (_potentialHarmText.isNotEmpty) ...[
              const Text('Potential Harm within 500m of river surface',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_potentialHarmText, style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Public Complaints / Reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._publicComplaints.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber, color: Colors.red),
                      title: Text(c),
                    ),
                  )),
            ] else if (_isAnalyzing)
              const Center(child: CircularProgressIndicator()),

            const SizedBox(height: 40),

            // Quick Actions
            const Text('Industry Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _quickActionCard('Self Monitoring', Icons.monitor_heart_outlined, Colors.blue),
                _quickActionCard('Submit Compliance', Icons.assignment_turned_in_outlined, Colors.green),
                _quickActionCard('View Public Feedback', Icons.feedback_outlined, Colors.orange),
                _quickActionCard('River 500m Buffer', Icons.security_outlined, Colors.purple),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0A3D62),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _quickActionCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$title clicked'))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _allRiversPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'All Rivers (snapshot)',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: RIVER_DATA.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final river = RIVER_DATA[i];
              final status = (river['status'] as String?) ?? '';
              final Color chipColor = status.contains('Severely')
                  ? const Color(0xFFFFE0E0)
                  : status.contains('Highly')
                      ? const Color(0xFFFFE8D6)
                      : status.contains('Moderately')
                          ? const Color(0xFFFFF5D6)
                          : const Color(0xFFE7F9EE);

              final Color textColor = status.contains('Severely') || status.contains('Highly')
                  ? const Color(0xFF8A1C1C)
                  : status.contains('Moderately')
                      ? const Color(0xFF7A5B00)
                      : const Color(0xFF0F5B2E);

              return Container(
                width: 210,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.waves, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${river['name']}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'BOD ${river['bod']} mg/L',
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${river['status']}',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}