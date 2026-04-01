import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void _fireAndForget(Future<void> f) {}

enum _HomeMenuAction { profile, logout }

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
  String? _locationName;
  List<Map<String, dynamic>> _nearestRivers = [];
  bool _isLoadingLocation = false;
  bool _isLoadingRivers = false;

  // Bottom Navigation
  int _selectedIndex = 0;
  final List<String> _pageTitles = [
    'Jal Rakshak',
    'River Map',
    'All Rivers',
    'Take Action',
  ];

  // ====================== MAP (GANGA) ======================
  static const LatLng _defaultIndiaCamera = LatLng(25.3176, 83.0107); // near Varanasi
  static const double _defaultZoom = 5.4;

  static const List<Map<String, dynamic>> _gangaConditionPoints = [
    {"name": "Haridwar", "lat": 29.9457, "lng": 78.1642, "status": "Moderately Polluted"},
    {"name": "Kanpur", "lat": 26.4499, "lng": 80.3319, "status": "Highly Polluted"},
    {"name": "Prayagraj", "lat": 25.4358, "lng": 81.8463, "status": "Moderately Polluted"},
    {"name": "Varanasi", "lat": 25.3176, "lng": 83.0107, "status": "Highly Polluted"},
    {"name": "Patna", "lat": 25.5941, "lng": 85.1376, "status": "Moderately Polluted"},
    {"name": "Kolkata", "lat": 22.5726, "lng": 88.3639, "status": "Moderately Polluted"},
  ];

  // Example “Jal Sankalpa Machines” point (edit lat/lng anytime)
  static const LatLng _jalSankalpaMachine = LatLng(25.3220, 83.0050);

  // ====================== CLOCK & DATA ======================
  static const List<String> MESSAGES = [
    "296 polluted stretches left. We reduced from 351 (2018). Accelerate now!",
    "India’s rivers need action: stop sewage, treat waste, protect wetlands.",
    "One clock. One mission: Healthy Rivers by 2055.",
    "Climate Clock warned us. Now River Revival Clock demands ACTION!"
  ];

  static const List<Map<String, dynamic>> RIVER_DATA = [
    {
      "name": "Ganga",
      "bod": "5.8",
      "status": "Highly Polluted",
      "fact": "Sacred river, but 351 stretches were polluted in 2018"
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
      "fact": "Lifeline of South India – now fighting industrial waste"
    },
    {
      "name": "Krishna",
      "bod": "4.5",
      "status": "Moderately Polluted",
      "fact": "Major irrigation river facing rising BOD levels"
    },
    {
      "name": "Narmada",
      "bod": "2.4",
      "status": "Clean in stretches",
      "fact": "One of the cleaner rivers – we must protect it"
    },
    {
      "name": "Cauvery",
      "bod": "3.8",
      "status": "Moderately Polluted",
      "fact": "Dispute over water sharing, facing pollution from cities"
    },
    {
      "name": "Brahmaputra",
      "bod": "2.1",
      "status": "Clean in stretches",
      "fact": "Mighty river from Himalayas, vital for Northeast India"
    },
    {
      "name": "Mahanadi",
      "bod": "4.2",
      "status": "Moderately Polluted",
      "fact": "Chhattisgarh and Odisha depend on it for irrigation"
    },
  ];

  static final DateTime TARGET_DATE = DateTime(2055, 1, 1);
  static const int POLLUTED_STRETCHES = 296;

  static const String _inspirationText = '''
Why Jal Rakshak exists?

India’s rivers support drinking water, agriculture, ecosystems, and livelihoods — but many stretches remain polluted due to untreated sewage and industrial discharge.

This app is your daily reminder and action hub: learn, monitor, report pollution, and join local river-cleanup efforts.
''';

  // ====================== GEMINI API ======================
  static const String GEMINI_API_KEY = String.fromEnvironment(
    'GEMINI_API_KEY',
  );
  static const String GEMINI_MODEL = "gemini-1.5-flash-latest";
  static const List<String> _geminiModelFallbacks = <String>[
    GEMINI_MODEL,
    'gemini-2.0-flash',
    'gemini-1.5-pro',
  ];
  static const int _geminiMaxRetriesPerModel = 2;
  static const List<Map<String, dynamic>> _indiaRiverCatalog = [
    {
      "name": "Ganga",
      "lat": 25.3176,
      "lng": 83.0107,
      "bod": 5.8,
      "status": "Highly Polluted",
      "fact": "India's most sacred yet heavily polluted river."
    },
    {
      "name": "Yamuna",
      "lat": 28.6139,
      "lng": 77.2090,
      "bod": 8.2,
      "status": "Severely Polluted",
      "fact": "Suffering from massive urban sewage pollution."
    },
    {
      "name": "Godavari",
      "lat": 17.3850,
      "lng": 78.4867,
      "bod": 3.1,
      "status": "Moderately Polluted",
      "fact": "Important river of South India under stress."
    },
    {
      "name": "Krishna",
      "lat": 16.5062,
      "lng": 80.6480,
      "bod": 4.5,
      "status": "Moderately Polluted",
      "fact": "Major irrigation river with rising BOD levels."
    },
    {
      "name": "Narmada",
      "lat": 22.7196,
      "lng": 75.8577,
      "bod": 2.4,
      "status": "Clean in stretches",
      "fact": "One of the cleaner rivers, needs proactive protection."
    },
    {
      "name": "Cauvery",
      "lat": 11.0168,
      "lng": 76.9558,
      "bod": 3.8,
      "status": "Moderately Polluted",
      "fact": "Pressure from urban runoff and untreated waste."
    },
    {
      "name": "Brahmaputra",
      "lat": 26.1445,
      "lng": 91.7362,
      "bod": 2.1,
      "status": "Clean in stretches",
      "fact": "Mighty Himalayan river vital for Northeast India."
    },
    {
      "name": "Mahanadi",
      "lat": 20.2961,
      "lng": 85.8245,
      "bod": 4.2,
      "status": "Moderately Polluted",
      "fact": "Lifeline for irrigation across central-eastern India."
    },
    {
      "name": "Sabarmati",
      "lat": 23.0225,
      "lng": 72.5714,
      "bod": 5.1,
      "status": "Highly Polluted",
      "fact": "Urban corridor sections face heavy wastewater load."
    },
    {
      "name": "Tapi",
      "lat": 21.1702,
      "lng": 72.8311,
      "bod": 4.7,
      "status": "Moderately Polluted",
      "fact": "Industrial discharge remains a major concern."
    },
  ];

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
  void initState() {
    super.initState();
    _currentMessage = MESSAGES[0];
    _currentRiverInfo = _displayRiverInfo(0);
    _startRiverRevivalClock();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _getLocationAndNearestRivers());
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
      _locationName = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw Exception('Location services disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        throw Exception('Location permission permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() => _userPosition = position);
      _fireAndForget(
          _updateLocationName(position.latitude, position.longitude));

      await _callGeminiForNearestRivers(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Location error: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
      _loadFallbackRivers();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _isLoadingRivers = false;
        });
      }
    }
  }

  Future<void> _updateLocationName(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final res = await http.get(
        url,
        headers: const {
          'User-Agent': 'JalRakshak/1.0 (Flutter)',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final address = (json['address'] as Map?)?.cast<String, dynamic>();
      final city = (address?['city'] ??
              address?['town'] ??
              address?['village'] ??
              address?['hamlet'])
          ?.toString();
      final state = address?['state']?.toString();
      final country = address?['country']?.toString();

      final parts = <String>[
        if (city != null && city.trim().isNotEmpty) city.trim(),
        if (state != null && state.trim().isNotEmpty) state.trim(),
        if (country != null && country.trim().isNotEmpty) country.trim(),
      ];
      if (parts.isEmpty) return;
      if (!mounted) return;
      setState(() => _locationName = parts.take(3).join(', '));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _callGeminiForNearestRivers(double lat, double lng) async {
    try {
      final nearest = _indiaRiverCatalog
          .map((river) {
            final riverLat = (river['lat'] as num).toDouble();
            final riverLng = (river['lng'] as num).toDouble();
            final distance = _haversineDistanceKm(lat, lng, riverLat, riverLng);
            return {
              "name": river['name'],
              "distance_km": double.parse(distance.toStringAsFixed(1)),
              "bod": river['bod'],
              "status": river['status'],
              "fact": river['fact'],
            };
          })
          .toList()
        ..sort((a, b) =>
            (a['distance_km'] as num).compareTo(b['distance_km'] as num));

      if (!mounted) return;
      setState(() => _nearestRivers = nearest.take(5).toList());
    } catch (_) {
      _loadFallbackRivers();
    } finally {
      if (mounted) {
        setState(() => _isLoadingRivers = false);
      }
    }
  }

  double _haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double degrees) => degrees * (math.pi / 180.0);

  void _loadFallbackRivers() {
    setState(() {
      _nearestRivers = [
        {
          "name": "Ganga",
          "distance_km": 45.2,
          "bod": 5.8,
          "status": "Highly Polluted",
          "fact": "India's most sacred yet heavily polluted river."
        },
        {
          "name": "Yamuna",
          "distance_km": 78.5,
          "bod": 8.2,
          "status": "Severely Polluted",
          "fact": "Suffering from massive urban sewage pollution."
        },
        {
          "name": "Godavari",
          "distance_km": 132.0,
          "bod": 3.1,
          "status": "Moderately Polluted",
          "fact": "Important river of South India under stress."
        },
      ];
    });
  }

  void _showWhyClockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why the River Revival Clock?'),
        content: const Text(
            'This clock counts down to 2055 — our long-term target for healthier rivers across India. It builds daily urgency and helps keep river protection visible and actionable.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Got it!'))
        ],
      ),
    );
  }

  void _showWhyMessagesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why these messages?'),
        content: const Text(
            'Rotating facts and messages keep you motivated and informed about all major rivers.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Got it!'))
        ],
      ),
    );
  }

  // ====================== PAGE BUILDERS ======================
  Widget _buildMapPage() {
    final markers = <Marker>{};
    final polylinePoints = <LatLng>[];

    for (final p in _gangaConditionPoints) {
      final name = p["name"] as String;
      final status = p["status"] as String;
      final lat = (p["lat"] as num).toDouble();
      final lng = (p["lng"] as num).toDouble();
      final pos = LatLng(lat, lng);

      markers.add(
        Marker(
          markerId: MarkerId('ganga_$name'),
          position: pos,
          infoWindow: InfoWindow(
            title: 'Ganga • $name',
            snippet: 'Condition: $status',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            status.contains('Highly')
                ? BitmapDescriptor.hueRed
                : status.contains('Moderately')
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueGreen,
          ),
        ),
      );
      polylinePoints.add(pos);
    }

    // Jal Sankalpa Machines marker + 1km radius
    markers.add(
      const Marker(
        markerId: MarkerId('jal_sankalpa_machine'),
        position: _jalSankalpaMachine,
        infoWindow: InfoWindow(
          title: 'Jal Sankalpa Machines',
          snippet: '1 km monitoring radius',
        ),
      ),
    );

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('jal_sankalpa_1km'),
        center: _jalSankalpaMachine,
        radius: 1000, // meters
        strokeWidth: 2,
        strokeColor: const Color(0xFF0EA5E9),
        fillColor: const Color(0xFF0EA5E9).withOpacity(0.14),
      ),
    };

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('ganga_polyline'),
        points: polylinePoints,
        color: const Color(0xFF2563EB),
        width: 5,
      ),
    };

    final initialTarget = (_userPosition != null)
        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : _defaultIndiaCamera;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ganga River Map',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A3D62),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _legendDot(const Color(0xFFEF4444), 'Highly'),
                  _legendDot(const Color(0xFFF59E0B), 'Moderately'),
                  _legendDot(const Color(0xFF22C55E), 'Clean'),
                  _legendDot(const Color(0xFF0EA5E9), '1 km zone'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: _defaultZoom,
              ),
              markers: markers,
              polylines: polylines,
              circles: circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAllRiversPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('All Major Rivers of India',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A3D62))),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: RIVER_DATA.length,
            itemBuilder: (context, i) {
              final r = RIVER_DATA[i];
              final color = r['status'].contains('Highly')
                  ? Colors.red
                  : r['status'].contains('Moderately')
                      ? Colors.orange
                      : Colors.green;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['name'],
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Chip(
                              label: Text(r['status']),
                              backgroundColor: color.withOpacity(0.15),
                              labelStyle: TextStyle(color: color)),
                        ],
                      ),
                      Text('BOD: ${r['bod']} mg/L',
                          style: const TextStyle(color: Colors.grey)),
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
          const Text('Take Action Today',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A3D62))),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            children: [
              _buildTappableQuickAction('Monitor Rivers', Icons.map_outlined,
                  Colors.blue, 'Live river map coming soon'),
              _buildTappableQuickAction(
                  'Report Pollution',
                  Icons.report_problem_outlined,
                  Colors.red,
                  'Report pollution spot'),
              _buildTappableQuickAction(
                  'Join Campaign',
                  Icons.campaign_outlined,
                  Colors.green,
                  'Join a local river-cleanup campaign'),
              _buildTappableQuickAction('View Stats', Icons.bar_chart_outlined,
                  Colors.orange, 'National river health dashboard'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTappableQuickAction(
      String title, IconData icon, Color color, String message) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: color));
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
            Text(title,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }



  Widget _quickActionCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == 'Monitor Rivers') {
          Navigator.pushNamed(context, '/profile'); // Example of new routing
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$title clicked')));
        }
      },
      child: Container(
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _allRiversPreview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: RIVER_DATA
          .map((r) => Column(
                children: [
                  const Icon(Icons.water_drop, color: Colors.white70),
                  const SizedBox(height: 6),
                  Text(r['name'],
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ))
          .toList(),
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
        title: Text(_pageTitles[_selectedIndex],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Open chatbot',
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/chatbot');
            },
          ),
          PopupMenuButton<_HomeMenuAction>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (action) async {
              switch (action) {
                case _HomeMenuAction.profile:
                  if (!mounted) return;
                  Navigator.pushNamed(context, '/profile');
                  return;
                case _HomeMenuAction.logout:
                  await _logout();
                  return;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _HomeMenuAction.profile,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                ),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.logout,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
          )
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
                    const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFF00BFFF),
                        child:
                            Icon(Icons.person, color: Colors.white, size: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Namaste, ${widget.name}!',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A3D62))),
                          const Text('Let’s revive India’s rivers together',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
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
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0A3D62), Color(0xFF1E88E5)]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF0A3D62).withOpacity(0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 12))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(children: [
                            Icon(Icons.water_drop,
                                color: Colors.white, size: 46),
                            SizedBox(width: 14),
                            Text('RIVER REVIVAL CLOCK',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white))
                          ]),
                          IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: Colors.white),
                              onPressed: _showWhyClockDialog),
                        ],
                      ),
                      Text(_countdown,
                          style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('until 2055 • Healthy Rivers Mission',
                          style: const TextStyle(
                              fontSize: 17, color: Colors.white70)),
                      const SizedBox(height: 20),
                      Text('🌊 $POLLUTED_STRETCHES polluted stretches left',
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const Divider(color: Colors.white30, height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18)),
                        child: Text(_currentRiverInfo,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 20),
                      _allRiversPreview(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                              child: Text('💡 $_currentMessage',
                                  style: const TextStyle(
                                      fontSize: 17.5,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFFFFD700)))),
                          IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: Color(0xFFFFD700)),
                              onPressed: _showWhyMessagesDialog),
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
                    const Text('Nearest Rivers to You',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A3D62))),
                    ElevatedButton.icon(
                      onPressed: (_isLoadingLocation || _isLoadingRivers)
                          ? null
                          : _getLocationAndNearestRivers,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFFF),
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),

                if (_userPosition != null)
                  Text(
                    _locationName != null
                        ? '📍 $_locationName'
                        : '📍 ${_userPosition!.latitude.toStringAsFixed(3)}, ${_userPosition!.longitude.toStringAsFixed(3)}',
                    style: const TextStyle(color: Colors.grey),
                  ),

                if (_isLoadingRivers)
                  const Center(child: CircularProgressIndicator())
                else if (_nearestRivers.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _nearestRivers.length,
                    itemBuilder: (context, i) {
                      final r = _nearestRivers[i];
                      final color = r['status'].contains('Highly')
                          ? Colors.red
                          : r['status'].contains('Moderately')
                              ? Colors.orange
                              : Colors.green;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r['name'],
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  Chip(
                                      label: Text(r['status']),
                                      backgroundColor: color.withOpacity(0.15)),
                                ],
                              ),
                              Text(
                                  '${r['distance_km']} km away • BOD ${r['bod']} mg/L',
                                  style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),
                              Text(r['fact']),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 40),
                const Text('What would you like to do today?',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A3D62))),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _quickActionCard(
                        'Monitor Rivers', Icons.map_outlined, Colors.blue),
                    _quickActionCard('Report Pollution',
                        Icons.report_problem_outlined, Colors.red),
                    _quickActionCard(
                        'Join Campaign', Icons.campaign_outlined, Colors.green),
                    _quickActionCard(
                        'View Stats', Icons.bar_chart_outlined, Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          // Other Pages
          _buildMapPage(),
          _buildAllRiversPage(),
          _buildActPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0A3D62),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.water_drop_outlined),
              activeIcon: Icon(Icons.water_drop),
              label: 'Rivers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              activeIcon: Icon(Icons.campaign),
              label: 'Act'),
        ],
      ),
    );
  }
}
