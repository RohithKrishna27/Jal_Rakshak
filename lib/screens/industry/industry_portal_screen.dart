import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:priject_jalrakshak/services/pollution_report_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:priject_jalrakshak/data/industry_nearby_nodes_demo.dart';
import 'package:priject_jalrakshak/industry/industry_portal_args.dart';

/// Full-screen industry workspace: registration, nearest IoT nodes, contamination, complaints.
/// Set [embedded] when hosting inside [IndustryAdminHome] bottom navigation (no own AppBar).
class IndustryPortalScreen extends StatefulWidget {
  const IndustryPortalScreen({
    super.key,
    required this.args,
    this.embedded = false,
    this.visibleTabIndex,
  });

  final IndustryPortalArgs args;
  final bool embedded;

  /// When [embedded] is true, parent drives the visible tab (0–3) from bottom nav.
  final int? visibleTabIndex;

  @override
  State<IndustryPortalScreen> createState() => _IndustryPortalScreenState();
}

class _IndustryComplaintRow {
  _IndustryComplaintRow({
    required this.id,
    required this.title,
    required this.status,
    required this.openedAt,
    required this.summary,
    required this.raisedBy,
    required this.trigger,
  });

  final String id;
  final String title;
  final String status;
  final String openedAt;
  final String summary;

  /// Who opened the ticket (e.g. citizen via app vs system from sensors).
  final String raisedBy;

  /// Why it was raised (e.g. over-pollution / threshold vs user observation).
  final String trigger;
}

class _IndustryPortalScreenState extends State<IndustryPortalScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final _companyName = TextEditingController();
  final _companyReg = TextEditingController();
  final _companyAddress = TextEditingController();
  String _sector = 'Chemical';

  static const _sectors = [
    'Chemical',
    'Textile',
    'Pharmaceutical',
    'Sugar Mill',
    'Paper',
    'Distillery',
    'Other',
  ];

  double? _companyLat;
  double? _companyLng;
  bool _loadingProfile = true;
  bool _savingProfile = false;
  bool _locating = false;

  GoogleMapController? _mapController;

  static const _defaultLat = 28.6139;
  static const _defaultLng = 77.2090;

  List<({IndustryNearbyNodeDemo node, double distanceM})> _nodesByDistance = [];

  final List<_IndustryComplaintRow> _complaintsDemo = [
    _IndustryComplaintRow(
      id: 'CMP-2401',
      title: 'Odour & effluent discharge (night hours)',
      status: 'In review',
      openedAt: '12 Mar 2026',
      raisedBy: 'Normal user (Jal Rakshak app)',
      trigger: 'Citizen report near your facility',
      summary:
          'A resident filed a pollution report from the “Report pollution” flow, ~1.2 km from your registered coordinates, citing smell and suspected night discharge.',
    ),
    _IndustryComplaintRow(
      id: 'CMP-2388',
      title: 'Foam & colour in drain line (storm outfall)',
      status: 'Action required',
      openedAt: '28 Feb 2026',
      raisedBy: 'Normal user + field photo',
      trigger: 'Visual pollution / drainage concern',
      summary:
          'Community user uploaded photos of foam and discoloration after rain; ticket auto-linked to nearest river buffer. Not yet attributed to a single outlet.',
    ),
    _IndustryComplaintRow(
      id: 'CMP-2395',
      title: 'IoT node: BOD / turbidity spike downstream',
      status: 'In review',
      openedAt: '5 Mar 2026',
      raisedBy: 'System (monitoring network)',
      trigger: 'Over-pollution / threshold breach',
      summary:
          'Nearest river IoT node logged elevated BOD and turbidity in the 48h window after your sector’s discharge window — flag for correlation review (demo linkage).',
    ),
    _IndustryComplaintRow(
      id: 'CMP-2355',
      title: 'Quarterly BOD sampling — compliance closure',
      status: 'Resolved',
      openedAt: '15 Jan 2026',
      raisedBy: 'Regulator / PCB follow-up',
      trigger: 'Scheduled compliance check',
      summary:
          'Lab reports uploaded; no breach confirmed at sampling point; complaint closed with compliance letter on file.',
    ),
  ];

  String get _uid =>
      widget.args.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    final start = widget.embedded
        ? (widget.visibleTabIndex ?? widget.args.initialTabIndex).clamp(0, 3)
        : widget.args.initialTabIndex;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: start,
    );
    _loadCompanyProfile();
  }

  @override
  void didUpdateWidget(IndustryPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.embedded || widget.visibleTabIndex == null) return;
    final t = widget.visibleTabIndex!.clamp(0, 3);
    if (oldWidget.visibleTabIndex != widget.visibleTabIndex &&
        _tabController.index != t) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.length == 4) {
          _tabController.animateTo(t);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyName.dispose();
    _companyReg.dispose();
    _companyAddress.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyProfile() async {
    setState(() => _loadingProfile = true);
    final uid = _uid;
    if (uid.isEmpty) {
      _companyName.text = widget.args.adminDisplayName;
      _companyLat = _defaultLat;
      _companyLng = _defaultLng;
      _recomputeNodes();
      setState(() => _loadingProfile = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = doc.data();
      if (d != null) {
        _companyName.text = (d['companyName'] as String?)?.trim().isNotEmpty == true
            ? d['companyName'] as String
            : (d['name'] as String? ?? widget.args.adminDisplayName);
        _companyReg.text = (d['companyRegistrationId'] as String?) ?? '';
        _companyAddress.text = (d['companyAddress'] as String?) ?? '';
        _sector = (d['companySector'] as String?) ?? _sector;
        final lat = d['companyLat'];
        final lng = d['companyLng'];
        if (lat is num && lng is num) {
          _companyLat = lat.toDouble();
          _companyLng = lng.toDouble();
        }
      } else {
        _companyName.text = widget.args.adminDisplayName;
      }
    } catch (_) {
      _companyName.text = widget.args.adminDisplayName;
    }

    _companyLat ??= _defaultLat;
    _companyLng ??= _defaultLng;
    _recomputeNodes();
    if (mounted) setState(() => _loadingProfile = false);
  }

  void _recomputeNodes() {
    final lat = _companyLat ?? _defaultLat;
    final lng = _companyLng ?? _defaultLng;
    final list = IndustryNearbyNodeDemo.all.map((node) {
      final m = Geolocator.distanceBetween(
        lat,
        lng,
        node.location.latitude,
        node.location.longitude,
      );
      return (node: node, distanceM: m);
    }).toList()
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    _nodesByDistance = list;
  }

  Future<void> _saveCompanyProfile() async {
    final uid = _uid;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in — profile saved locally only for this session.')),
      );
      _recomputeNodes();
      setState(() {});
      return;
    }

    setState(() => _savingProfile = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'companyName': _companyName.text.trim(),
          'companyRegistrationId': _companyReg.text.trim(),
          'companyAddress': _companyAddress.text.trim(),
          'companySector': _sector,
          'companyLat': _companyLat,
          'companyLng': _companyLng,
          'companyProfileUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _recomputeNodes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company registration saved to your profile.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _useDeviceLocationForCompany() async {
    setState(() => _locating = true);
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        throw Exception('Location services off');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      final p = await Geolocator.getCurrentPosition();
      setState(() {
        _companyLat = p.latitude;
        _companyLng = p.longitude;
        _recomputeNodes();
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 11),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facility location updated from GPS.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  IndustryNearbyNodeDemo? get _nearestNode =>
      _nodesByDistance.isEmpty ? null : _nodesByDistance.first.node;

  @override
  Widget build(BuildContext context) {
    final args = widget.args;

    final tabBody = _loadingProfile
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
            children: [
              _buildRegistrationTab(args),
              _buildNodesTab(),
              _buildContaminationTab(),
              _buildComplaintsTab(args),
            ],
          );

    if (widget.embedded) {
      return ColoredBox(
        color: const Color(0xFFF1F5F9),
        child: tabBody,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        foregroundColor: Colors.white,
        title: const Text('Industry portal'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Company', icon: Icon(Icons.apartment, size: 20)),
            Tab(text: 'Nearest nodes', icon: Icon(Icons.sensors, size: 20)),
            Tab(text: 'Contamination', icon: Icon(Icons.warning_amber, size: 20)),
            Tab(text: 'Complaints', icon: Icon(Icons.assignment, size: 20)),
          ],
        ),
      ),
      body: tabBody,
    );
  }

  Widget _buildRegistrationTab(IndustryPortalArgs args) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin: ${args.adminDisplayName}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (args.userId != null && args.userId!.isNotEmpty)
                  Text(
                    'User ID: ${args.userId}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Company registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Maps to Firestore `users/{uid}` fields: companyName, companySector, companyAddress, companyRegistrationId, companyLat, companyLng.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _companyName,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Registered company name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _companyReg,
          decoration: const InputDecoration(
            labelText: 'CIN / GST / PCB consent ID (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sector,
          decoration: const InputDecoration(
            labelText: 'Sector',
            border: OutlineInputBorder(),
          ),
          items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _sector = v ?? _sector),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _companyAddress,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Facility address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useDeviceLocationForCompany,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Set location from GPS'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Facility coordinates: ${_companyLat?.toStringAsFixed(5)}, ${_companyLng?.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _savingProfile ? null : _saveCompanyProfile,
          icon: _savingProfile
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save),
          label: Text(_savingProfile ? 'Saving…' : 'Save registration'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4C1D95),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  Widget _buildNodesTab() {
    final center = LatLng(_companyLat ?? _defaultLat, _companyLng ?? _defaultLng);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('facility'),
        position: center,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(title: 'Your facility (registered)'),
      ),
      ..._nodesByDistance.take(5).map(
            (e) => Marker(
              markerId: MarkerId(e.node.id),
              position: e.node.location,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(
                title: '${e.node.riverName} Node ${e.node.nodeIndex}',
                snippet: '${(e.distanceM / 1000).toStringAsFixed(1)} km away',
              ),
            ),
          ),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 6),
              markers: markers,
              onMapCreated: (c) {
                _mapController = c;
                c.animateCamera(CameraUpdate.newLatLngZoom(center, 6));
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nearest monitoring nodes to your saved facility location (demo network).',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ..._nodesByDistance.take(8).map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4C1D95).withValues(alpha: 0.12),
                    child: Text('${e.node.nodeIndex}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${e.node.riverName} • Node ${e.node.nodeIndex}'),
                  subtitle: Text(
                    '${(e.distanceM / 1000).toStringAsFixed(2)} km • DO ${e.node.dissolvedOxygenMgL} mg/L • BOD ${e.node.bodMgL} mg/L',
                  ),
                  trailing: Text(
                    e.node.riskLabel,
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildContaminationTab() {
    final n = _nearestNode;
    final nearKm = _nodesByDistance.isEmpty ? '—' : (_nodesByDistance.first.distanceM / 1000).toStringAsFixed(2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Risk near your facility',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on nearest IoT node ($nearKm km) and sector heuristics (demo).',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (n != null) ...[
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: const Icon(Icons.sensors, color: Colors.deepOrange),
              title: Text('Nearest node: ${n.riverName} Node ${n.nodeIndex}'),
              subtitle: Text(
                'DO ${n.dissolvedOxygenMgL} mg/L • BOD ${n.bodMgL} mg/L • pH ${n.ph} • ${n.riskLabel}',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _riskCard(
          'Downstream organic pulse',
          'If DO < 4 mg/L at nearest node, assume higher BOD slug risk during low-flow nights.',
          Icons.water_drop,
          Colors.red.shade700,
        ),
        _riskCard(
          'Storm overlap',
          'First flush after dry spell can move surficial contamination toward intake / drain paths.',
          Icons.thunderstorm,
          Colors.indigo,
        ),
        _riskCard(
          'Community visibility',
          'Foam, colour, or odour reports within 48h often correlate with complaint tickets (see Complaints tab).',
          Icons.visibility,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _riskCard(String title, String body, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(fontSize: 14, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// True when the citizen report names / matches the industry’s registered company (Compliance tab).
  bool _reportMatchesRegisteredCompany(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String registeredLower,
  ) {
    if (registeredLower.length < 2) return false;
    final data = doc.data();
    final suspected =
        (data['suspectedCompanyName'] as String?)?.toLowerCase().trim() ?? '';
    final addr = (data['companyAddress'] as String?)?.toLowerCase() ?? '';
    if (suspected.isEmpty && addr.isEmpty) return false;

    if (suspected.isNotEmpty) {
      if (suspected.contains(registeredLower) || registeredLower.contains(suspected)) {
        return true;
      }
      for (final w in registeredLower.split(RegExp(r'[\s,]+')).where((e) => e.length >= 3)) {
        if (suspected.contains(w)) return true;
      }
      for (final w in suspected.split(RegExp(r'[\s,]+')).where((e) => e.length >= 3)) {
        if (registeredLower.contains(w)) return true;
      }
    }
    if (addr.isNotEmpty && addr.contains(registeredLower)) return true;
    return false;
  }

  Widget _buildComplaintsTab(IndustryPortalArgs args) {
    final registered = _companyName.text.trim().toLowerCase();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Complaints — ${_companyName.text.isEmpty ? args.adminDisplayName : _companyName.text}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          registered.isEmpty
              ? 'Save your registered company name on the Compliance tab to split reports into yours vs other companies. Until then, all citizen reports are listed under All company-related reports.'
              : 'Reports that name or match “${_companyName.text.trim()}” appear first. Below that: all other company-related citizen reports.',
          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
          softWrap: true,
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: PollutionReportService.reportsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Could not load citizen reports. In Firebase Console, allow authenticated read/write on `pollution_reports`.\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  softWrap: true,
                ),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No citizen reports yet. When users submit from Report Pollution, they appear here with details.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              );
            }

            final mine = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final others = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final d in docs) {
              if (registered.isNotEmpty && _reportMatchesRegisteredCompany(d, registered)) {
                mine.add(d);
              } else {
                others.add(d);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (registered.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.business, color: Colors.green.shade800, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'About your company (${mine.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Citizen reports where the suspected company name or address matches your registration.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  if (mine.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No reports naming your company yet.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ...mine.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _citizenReportCard(d, isAboutOurCompany: true),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    Icon(Icons.corporate_fare_outlined, color: Colors.blue.shade900, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        registered.isEmpty
                            ? 'All company-related reports (${others.length})'
                            : 'Other companies (${others.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  registered.isEmpty
                      ? 'All pollution reports filed by normal users (other facilities / areas).'
                      : 'Reports naming other industries or not matching your registered name.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                ...others.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _citizenReportCard(d, isAboutOurCompany: false),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Divider(thickness: 2),
        const SizedBox(height: 12),
        Text(
          'Other tickets (demo)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ..._complaintsDemo.map(
          (c) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusChip(c.status),
                      _complaintMetaChip(Icons.person_outline, 'Raised by', c.raisedBy),
                      _complaintMetaChip(Icons.bubble_chart_outlined, 'Trigger', c.trigger),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${c.id} • Opened ${c.openedAt}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    softWrap: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.summary,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatReportTime(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      return '${d.day}/${d.month}/${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '—';
  }

  Widget _citizenReportCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    bool isAboutOurCompany = false,
  }) {
    final d = doc.data();
    final company = (d['suspectedCompanyName'] as String?)?.trim() ?? '—';
    final address = (d['companyAddress'] as String?)?.trim() ?? '—';
    final waste = (d['wasteType'] as String?)?.trim() ?? '—';
    final water = (d['waterBody'] as String?)?.trim() ?? '';
    final notes = (d['locationNotes'] as String?)?.trim() ?? '';
    final desc = (d['description'] as String?)?.trim() ?? '—';
    final photoUrl = d['photoUrl'] as String?;
    final status = (d['status'] as String?) ?? 'submitted';

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAboutOurCompany ? Colors.green.shade600 : Colors.transparent,
          width: isAboutOurCompany ? 2 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photoUrl != null && photoUrl.isNotEmpty)
            Image.network(
              photoUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: Colors.grey.shade300,
                child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statusChip(_mapCitizenStatus(status)),
                    if (isAboutOurCompany)
                      Chip(
                        label: const Text('Your registered company', style: TextStyle(fontSize: 11)),
                        backgroundColor: Colors.green.shade100,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _complaintMetaChip(Icons.factory_outlined, 'Address', address),
                    _complaintMetaChip(Icons.delete_outline, 'Waste type', waste),
                    if (water.isNotEmpty)
                      _complaintMetaChip(Icons.water, 'Water body', water),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Location notes: $notes',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    softWrap: true,
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  softWrap: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'ID ${doc.id} • ${_formatReportTime(d['createdAt'])} • Normal user report',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mapCitizenStatus(String s) {
    switch (s) {
      case 'submitted':
        return 'In review';
      case 'resolved':
        return 'Resolved';
      case 'action_required':
        return 'Action required';
      default:
        return s.replaceAll('_', ' ');
    }
  }

  Widget _complaintMetaChip(IconData icon, String label, String value) {
    return Builder(
      builder: (context) {
        final maxW = (MediaQuery.sizeOf(context).width - 48).clamp(120.0, 320.0);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Chip(
            avatar: Icon(icon, size: 18, color: const Color(0xFF4C1D95)),
            label: Text(
              '$label: $value',
              style: const TextStyle(fontSize: 11.5, height: 1.25),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
            backgroundColor: const Color(0xFFF1F5F9),
            side: BorderSide(color: Colors.purple.shade100),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'Resolved' => Colors.green,
      'In review' => Colors.orange,
      'Action required' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Chip(
      label: Text(
        status,
        style: const TextStyle(fontSize: 11, color: Colors.white),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
