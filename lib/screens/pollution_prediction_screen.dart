import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:priject_jalrakshak/services/prediction_service.dart';
import 'package:priject_jalrakshak/utils/environmental_data_generator.dart';

class PollutionPredictionScreen extends StatefulWidget {
  const PollutionPredictionScreen({super.key});

  @override
  State<PollutionPredictionScreen> createState() =>
      _PollutionPredictionScreenState();
}

class _PollutionPredictionScreenState extends State<PollutionPredictionScreen> {
  final PredictionService _predictionService = PredictionService();
  final Set<Marker> _predictionMarkers = <Marker>{};

  static const LatLng _defaultMapCenter = LatLng(22.9734, 78.6569);
  static const double _defaultMapZoom = 4.8;

  bool _isLoading = true;
  String? _pollutionLevel;
  double? _riskScore;
  String? _errorMessage;
  int _predictionIndex = 0;

  @override
  void initState() {
    super.initState();
    _autoPredictOnLoad();
  }

  @override
  void dispose() {
    _predictionService.dispose();
    super.dispose();
  }

  Future<void> _autoPredictOnLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final position = await _getCurrentPosition();
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to access location for prediction.';
          _isLoading = false;
        });
        return;
      }

      final payload = generateEnvironmentalData()
        ..addAll(<String, dynamic>{
          'Latitude': position.latitude,
          'Longitude': position.longitude,
        });
      final result = await _predictionService.predictPollution(payload);

      final pollutionLevel = _extractPollutionLevel(result);
      final riskScore = _extractRiskScore(result);

      if (!mounted) return;
      setState(() {
        _pollutionLevel = pollutionLevel;
        _riskScore = riskScore;
      });

      _addPredictionMarker(
        latLng: LatLng(position.latitude, position.longitude),
        pollutionLevel: pollutionLevel,
        riskScore: riskScore,
      );

      final riskPercent = _toRiskPercent(riskScore);
      if (_isCriticalRisk(riskPercent)) {
        await _showCriticalRiskAlert();
      }
    } on PredictionServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Prediction failed: ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unexpected error while fetching prediction. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _extractPollutionLevel(Map<String, dynamic> result) {
    final dynamic value = result['pollution_level'] ??
        result['pollutionLevel'] ??
        result['level'] ??
        result['prediction'];

    if (value == null) {
      return 'Unknown';
    }
    return value.toString().trim();
  }

  double? _extractRiskScore(Map<String, dynamic> result) {
    final dynamic value = result['risk_score'] ??
        result['riskScore'] ??
        result['score'] ??
        result['probability'];

    if (value == null) return null;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  double? _toRiskPercent(double? score) {
    if (score == null) return null;
    if (score <= 1) return score * 100;
    return score;
  }

  bool _isCriticalRisk(double? riskPercent) {
    return riskPercent != null && riskPercent > 80;
  }

  bool _isWarningRisk(double? riskPercent) {
    return riskPercent != null && riskPercent >= 50 && riskPercent <= 80;
  }

  bool _isSafeRisk(double? riskPercent) {
    return riskPercent != null && riskPercent < 50;
  }

  Future<Position?> _getCurrentPosition() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to place markers.'),
          ),
        );
      }
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  void _addPredictionMarker({
    required LatLng latLng,
    required String pollutionLevel,
    required double? riskScore,
  }) {
    final color = _riskColor(pollutionLevel, riskScore);
    final hue = _markerHue(color);
    final markerId = MarkerId(
        'prediction_${DateTime.now().millisecondsSinceEpoch}_${_predictionIndex++}');

    final marker = Marker(
      markerId: markerId,
      position: latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: 'Pollution: $pollutionLevel',
        snippet: riskScore == null
            ? 'Risk Score: Not available'
            : 'Risk Score: ${riskScore.toStringAsFixed(2)}',
      ),
    );

    setState(() {
      _predictionMarkers.add(marker);
      if (_predictionMarkers.length > 100) {
        _predictionMarkers.remove(_predictionMarkers.first);
      }
    });
  }

  double _markerHue(Color color) {
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.amber) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueGreen;
  }

  Color _riskColor(String? pollutionLevel, double? riskScore) {
    final riskPercent = _toRiskPercent(riskScore);
    final normalized = (pollutionLevel ?? '').toLowerCase();

    if (normalized.contains('high') || _isCriticalRisk(riskPercent)) {
      return Colors.red;
    }
    if (normalized.contains('medium') || _isWarningRisk(riskPercent)) {
      return Colors.amber;
    }
    return Colors.green;
  }

  Future<void> _showCriticalRiskAlert() async {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          title: const Text('Critical pollution risk detected'),
          content: const Text('Critical pollution risk detected'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final riskPercent = _toRiskPercent(_riskScore);
    final riskColor = _riskColor(_pollutionLevel, _riskScore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pollution Prediction'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Prediction is triggered automatically when this screen loads using current location and generated environmental values.',
                  ),
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              if (_pollutionLevel != null) ...[
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prediction Result',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: riskColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _pollutionLevel ?? 'Unknown',
                              style: TextStyle(
                                color: riskColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _riskScore == null
                              ? 'Risk Score: Not available'
                              : 'Risk Score: ${riskPercent!.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (riskPercent != null) ...[
                const SizedBox(height: 12),
                _buildSmartRiskMessage(riskPercent),
              ],
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prediction Map',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Each prediction adds a marker at your location.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 300,
                          child: GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: _defaultMapCenter,
                              zoom: _defaultMapZoom,
                            ),
                            markers: _predictionMarkers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            compassEnabled: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartRiskMessage(double riskPercent) {
    if (_isWarningRisk(riskPercent)) {
      return Material(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
          title: const Text('Warning risk level'),
          subtitle: Text(
              'Risk score is ${riskPercent.toStringAsFixed(1)}. Please monitor closely.'),
        ),
      );
    }

    if (_isSafeRisk(riskPercent)) {
      return Material(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: const Icon(Icons.verified_rounded, color: Colors.green),
          title: const Text('Safe risk level'),
          subtitle: Text(
              'Risk score is ${riskPercent.toStringAsFixed(1)}. Conditions look safe.'),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
