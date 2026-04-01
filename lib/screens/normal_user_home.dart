import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jal Rakshak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
      ),
      home: const NormalUserHome(name: "User"), // Change name as needed
      routes: {
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

// ====================== PROFILE SCREEN (New Route) ======================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: const Text('My Profile'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFF00BFFF),
              child: Icon(Icons.person, size: 80, color: Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'Namaste!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              'You are part of the River Revival Mission',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 40),
            Text(
              'Total Actions Taken: 12\nRivers Monitored: 7\nReports Submitted: 3',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== MAIN HOME SCREEN ======================
class NormalUserHome extends StatefulWidget {
  const NormalUserHome({super.key, required this.name});
  final String name;

  @override
  State<NormalUserHome> createState() => _NormalUserHomeState();
}

class _NormalUserHomeState extends State<NormalUserHome> {
  late Timer _clockTimer;
  int _riverIndex = 0;
  int _msgIndex = 0;

  String _countdown = "0000 DAYS 00:00:00";
  String _currentRiverInfo = "";
  String _currentMessage = "";

  Position? _userPosition;
  List<Map<String, dynamic>> _nearestRivers = [];
  bool _isLoadingLocation = false;
  bool _isLoadingRivers = false;
  String? _locationError;

  // Bottom Navigation
  int _selectedIndex = 0;
  final List<String> _pageTitles = [
    'Jal Rakshak',
    'All Rivers',
    'Take Action',
    'Why Inspired',
  ];

  // ====================== CLOCK & DATA ======================
  static const List<String> MESSAGES = [
    "Energy Swaraj Yatra 2020-2030 → Solar Power + Clean Rivers!",
    "296 polluted stretches left. We reduced from 351 (2018). Accelerate now!",
    "Prof. Chetan Singh Solanki: 'I won't go home till 2030' – neither should pollution!",
    "One solar bus. One clock. One mission: Healthy Rivers by 2030.",
    "Climate Clock warned us. Now River Revival Clock demands ACTION!"
  ];

  static const List<Map<String, dynamic>> RIVER_DATA = [
    {"name": "Ganga", "bod": "5.8", "status": "Highly Polluted", "fact": "Sacred river, but 351 stretches were polluted in 2018"},
    {"name": "Yamuna", "bod": "8.2", "status": "Severely Polluted", "fact": "Delhi’s sewage turns it into one of India’s most toxic rivers"},
    {"name": "Godavari", "bod": "3.1", "status": "Moderately Polluted", "fact": "Lifeline of South India – now fighting industrial waste"},
    {"name": "Krishna", "bod": "4.5", "status": "Moderately Polluted", "fact": "Major irrigation river facing rising BOD levels"},
    {"name": "Narmada", "bod": "2.4", "status": "Clean in stretches", "fact": "One of the cleaner rivers – we must protect it"},
    {"name": "Cauvery", "bod": "3.8", "status": "Moderately Polluted", "fact": "Dispute over water sharing, facing pollution from cities"},
    {"name": "Brahmaputra", "bod": "2.1", "status": "Clean in stretches", "fact": "Mighty river from Himalayas, vital for Northeast India"},
    {"name": "Mahanadi", "bod": "4.2", "status": "Moderately Polluted", "fact": "Chhattisgarh and Odisha depend on it for irrigation"},
  ];

  static final DateTime TARGET_DATE = DateTime(2030, 1, 1);
  static const int POLLUTED_STRETCHES = 296;

  static const String _inspirationText = '''
Why is Jal Rakshak inspired by Energy Swaraj Yatra?

Prof. Chetan Singh Solanki (IIT Bombay) started the Energy Swaraj Yatra in 2020 — a 10-year solar journey across India. His vow: “I will not return home till 2030” until India achieves complete solar self-reliance.

We extend the same spirit: Solar Power + Clean Rivers!
Healthy rivers are as important as clean energy. This app is your digital Yatra in your pocket.
''';

  // ====================== GEMINI API ======================
  static const String GEMINI_API_KEY = "AIzaSyBd9J89PKKmH061tZ5X4GrAo8Zb2ZzTYeg";
  static const String GEMINI_MODEL = "gemini-flash-latest"; // Fixed for 404 error

  @override
  void initState() {
    super.initState();
    _currentMessage = MESSAGES[0];
    _currentRiverInfo = _displayRiverInfo(0);
    _startRiverRevivalClock();
    WidgetsBinding.instance.addPostFrameCallback((_) => _getLocationAndNearestRivers());
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
      setState(() => _countdown = _calculateCountdown());

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

  Future<void> _getLocationAndNearestRivers() async {
    setState(() {
      _isLoadingLocation = true;
      _isLoadingRivers = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _userPosition = position);

      await _callGeminiForNearestRivers(position.latitude, position.longitude);
    } catch (e) {
      setState(() => _locationError = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
      _loadFallbackRivers();
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _callGeminiForNearestRivers(double lat, double lng) async {
    _nearestRivers.clear();

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:generateContent?key=$GEMINI_API_KEY',
    );

    final prompt = '''
You are an expert on Indian rivers and real-time pollution data.
User location: Latitude $lat, Longitude $lng (focus only on India).

Return **only** a valid JSON array with maximum 5 nearest rivers. No extra text.

Example format:
[
  {"name": "River Name", "distance_km": 12.5, "bod": 4.8, "status": "Highly Polluted", "fact": "Short impactful sentence."}
]
''';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}],
          "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.7,
            "maxOutputTokens": 800,
          }
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        rawText = rawText.trim();
        if (rawText.contains('```')) {
          rawText = rawText.split('```')[1].trim();
          if (rawText.startsWith('json')) rawText = rawText.substring(4).trim();
        }

        final List<dynamic> parsed = jsonDecode(rawText);
        setState(() => _nearestRivers = List<Map<String, dynamic>>.from(parsed));
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Using fallback river data'), backgroundColor: Colors.orange),
        );
      }
      _loadFallbackRivers();
    } finally {
      setState(() => _isLoadingRivers = false);
    }
  }

  void _loadFallbackRivers() {
    setState(() {
      _nearestRivers = [
        {"name": "Ganga", "distance_km": 45.2, "bod": 5.8, "status": "Highly Polluted", "fact": "India's most sacred yet heavily polluted river."},
        {"name": "Yamuna", "distance_km": 78.5, "bod": 8.2, "status": "Severely Polluted", "fact": "Suffering from massive urban sewage pollution."},
        {"name": "Godavari", "distance_km": 132.0, "bod": 3.1, "status": "Moderately Polluted", "fact": "Important river of South India under stress."},
      ];
    });
  }

  void _showWhyClockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why the River Revival Clock?'),
        content: const Text('This clock counts down to 2030 — the target year for healthy rivers in India. It creates daily urgency inspired by Prof. Chetan Singh Solanki’s Energy Swaraj Yatra.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it!'))],
      ),
    );
  }

  void _showWhyMessagesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why these messages?'),
        content: const Text('Rotating facts and messages keep you motivated and informed about all major rivers.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it!'))],
      ),
    );
  }

  // ====================== PAGE BUILDERS ======================
  Widget _buildAllRiversPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('All Major Rivers of India', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0A3D62))),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: RIVER_DATA.length,
            itemBuilder: (context, i) {
              final r = RIVER_DATA[i];
              final color = r['status'].contains('Highly') ? Colors.red : r['status'].contains('Moderately') ? Colors.orange : Colors.green;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Chip(label: Text(r['status']), backgroundColor: color.withOpacity(0.15), labelStyle: TextStyle(color: color)),
                        ],
                      ),
                      Text('BOD: ${r['bod']} mg/L', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text(r['fact'], style: const TextStyle(height: 1.45)),
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

  Widget _buildActPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Take Action Today', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0A3D62))),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            children: [
              _buildTappableQuickAction('Monitor Rivers', Icons.map_outlined, Colors.blue, 'Live river map coming soon'),
              _buildTappableQuickAction('Report Pollution', Icons.report_problem_outlined, Colors.red, 'Report pollution spot'),
              _buildTappableQuickAction('Join Campaign', Icons.campaign_outlined, Colors.green, 'Join Energy Swaraj Yatra'),
              _buildTappableQuickAction('View Stats', Icons.bar_chart_outlined, Colors.orange, 'National river health dashboard'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTappableQuickAction(String title, IconData icon, Color color, String message) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildInspirePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why Inspired?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0A3D62))),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_inspirationText, style: const TextStyle(fontSize: 16.5, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == 'Monitor Rivers') {
          Navigator.pushNamed(context, '/profile'); // Example of new routing
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title clicked')));
        }
      },
      child: Container(
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _allRiversPreview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: RIVER_DATA.map((r) => Column(
        children: [
          const Icon(Icons.water_drop, color: Colors.white70),
          const SizedBox(height: 6),
          Text(r['name'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      )).toList(),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: Text(_pageTitles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // HOME PAGE
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 28, backgroundColor: Color(0xFF00BFFF), child: Icon(Icons.person, color: Colors.white, size: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Namaste, ${widget.name}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0A3D62))),
                          const Text('Let’s revive India’s rivers together', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // River Revival Clock
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0A3D62), Color(0xFF1E88E5)]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: const Color(0xFF0A3D62).withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 12))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(children: [Icon(Icons.water_drop, color: Colors.white, size: 46), SizedBox(width: 14), Text('RIVER REVIVAL CLOCK', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white))]),
                          IconButton(icon: const Icon(Icons.info_outline, color: Colors.white), onPressed: _showWhyClockDialog),
                        ],
                      ),
                      Text(_countdown, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('until 2030 • Healthy Rivers Mission', style: const TextStyle(fontSize: 17, color: Colors.white70)),
                      const SizedBox(height: 20),
                      Text('🌊 $POLLUTED_STRETCHES polluted stretches left', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700)),
                      const Divider(color: Colors.white30, height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(18)),
                        child: Text(_currentRiverInfo, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 20),
                      _allRiversPreview(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(child: Text('💡 $_currentMessage', style: const TextStyle(fontSize: 17.5, fontStyle: FontStyle.italic, color: Color(0xFFFFD700)))),
                          IconButton(icon: const Icon(Icons.info_outline, color: Color(0xFFFFD700)), onPressed: _showWhyMessagesDialog),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Nearest Rivers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Nearest Rivers to You', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0A3D62))),
                    ElevatedButton.icon(
                      onPressed: (_isLoadingLocation || _isLoadingRivers) ? null : _getLocationAndNearestRivers,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFFF), foregroundColor: Colors.white),
                    ),
                  ],
                ),

                if (_userPosition != null)
                  Text('📍 ${_userPosition!.latitude.toStringAsFixed(3)}, ${_userPosition!.longitude.toStringAsFixed(3)}', style: const TextStyle(color: Colors.grey)),

                if (_isLoadingRivers)
                  const Center(child: CircularProgressIndicator())
                else if (_nearestRivers.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _nearestRivers.length,
                    itemBuilder: (context, i) {
                      final r = _nearestRivers[i];
                      final color = r['status'].contains('Highly') ? Colors.red : r['status'].contains('Moderately') ? Colors.orange : Colors.green;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Chip(label: Text(r['status']), backgroundColor: color.withOpacity(0.15)),
                                ],
                              ),
                              Text('${r['distance_km']} km away • BOD ${r['bod']} mg/L', style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),
                              Text(r['fact']),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 40),
                const Text('What would you like to do today?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0A3D62))),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _quickActionCard('Monitor Rivers', Icons.map_outlined, Colors.blue),
                    _quickActionCard('Report Pollution', Icons.report_problem_outlined, Colors.red),
                    _quickActionCard('Join Campaign', Icons.campaign_outlined, Colors.green),
                    _quickActionCard('View Stats', Icons.bar_chart_outlined, Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          // Other Pages
          _buildAllRiversPage(),
          _buildActPage(),
          _buildInspirePage(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0A3D62),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop_outlined), activeIcon: Icon(Icons.water_drop), label: 'Rivers'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), activeIcon: Icon(Icons.campaign), label: 'Act'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outlined), activeIcon: Icon(Icons.lightbulb), label: 'Inspire'),
        ],
      ),
    );
  }
}