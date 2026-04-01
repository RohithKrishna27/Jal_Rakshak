import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Demo IoT monitoring points (same conceptual network as citizen monitor map).
class IndustryNearbyNodeDemo {
  const IndustryNearbyNodeDemo({
    required this.id,
    required this.riverName,
    required this.nodeIndex,
    required this.location,
    required this.dissolvedOxygenMgL,
    required this.bodMgL,
    required this.turbidityNtu,
    required this.ph,
    required this.riskLabel,
  });

  final String id;
  final String riverName;
  final int nodeIndex;
  final LatLng location;
  final double dissolvedOxygenMgL;
  final double bodMgL;
  final double turbidityNtu;
  final double ph;
  final String riskLabel;

  static const List<IndustryNearbyNodeDemo> all = [
    IndustryNearbyNodeDemo(
      id: 'ganga_n1',
      riverName: 'Ganga',
      nodeIndex: 1,
      location: LatLng(25.3108, 82.9905),
      dissolvedOxygenMgL: 4.2,
      bodMgL: 5.2,
      turbidityNtu: 45,
      ph: 7.8,
      riskLabel: 'Elevated organic load',
    ),
    IndustryNearbyNodeDemo(
      id: 'ganga_n2',
      riverName: 'Ganga',
      nodeIndex: 2,
      location: LatLng(25.3095, 83.0120),
      dissolvedOxygenMgL: 3.8,
      bodMgL: 6.1,
      turbidityNtu: 52,
      ph: 8.1,
      riskLabel: 'DO stress downstream',
    ),
    IndustryNearbyNodeDemo(
      id: 'yamuna_n1',
      riverName: 'Yamuna',
      nodeIndex: 1,
      location: LatLng(28.7200, 77.2400),
      dissolvedOxygenMgL: 2.8,
      bodMgL: 8.2,
      turbidityNtu: 85,
      ph: 8.5,
      riskLabel: 'Severe urban-industrial stretch',
    ),
    IndustryNearbyNodeDemo(
      id: 'yamuna_n2',
      riverName: 'Yamuna',
      nodeIndex: 2,
      location: LatLng(28.7000, 77.2430),
      dissolvedOxygenMgL: 3.2,
      bodMgL: 7.4,
      turbidityNtu: 72,
      ph: 8.3,
      riskLabel: 'Nutrient + organic pulse',
    ),
    IndustryNearbyNodeDemo(
      id: 'narmada_n1',
      riverName: 'Narmada',
      nodeIndex: 1,
      location: LatLng(21.7290, 72.9860),
      dissolvedOxygenMgL: 6.2,
      bodMgL: 2.8,
      turbidityNtu: 28,
      ph: 7.3,
      riskLabel: 'Relatively stable',
    ),
    IndustryNearbyNodeDemo(
      id: 'godavari_n1',
      riverName: 'Godavari',
      nodeIndex: 1,
      location: LatLng(17.0054, 81.7765),
      dissolvedOxygenMgL: 5.8,
      bodMgL: 4.1,
      turbidityNtu: 38,
      ph: 7.5,
      riskLabel: 'Moderate agricultural influence',
    ),
  ];
}
