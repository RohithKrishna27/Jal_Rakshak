import 'dart:math';

/// Generates realistic environmental parameters for pollution prediction.
///
/// Ranges:
/// - pH: 6.0 to 8.0
/// - Temperature: 20.0 to 35.0
/// - Humidity: 30.0 to 90.0
/// - Conductivity: 0.1 to 1.0
Map<String, dynamic> generateEnvironmentalData({Random? random}) {
  final rng = random ?? Random();

  double inRange(double min, double max) {
    return min + rng.nextDouble() * (max - min);
  }

  // Small jitter keeps values from looking overly uniform.
  double withJitter(double value, double min, double max, double jitter) {
    final adjusted = value + inRange(-jitter, jitter);
    return adjusted.clamp(min, max).toDouble();
  }

  final temperature = withJitter(inRange(20.0, 35.0), 20.0, 35.0, 0.6);
  final ph = withJitter(inRange(6.0, 8.0), 6.0, 8.0, 0.08);
  final humidity = withJitter(inRange(30.0, 90.0), 30.0, 90.0, 1.5);
  final conductivity = withJitter(inRange(0.1, 1.0), 0.1, 1.0, 0.04);

  return <String, dynamic>{
    'N': 70 + rng.nextInt(71),
    'P': 30 + rng.nextInt(71),
    'K': 10 + rng.nextInt(51),
    'Temperature': double.parse(temperature.toStringAsFixed(2)),
    'pH': double.parse(ph.toStringAsFixed(2)),
    'Humidity': double.parse(humidity.toStringAsFixed(2)),
    'Soil_Temperature': double.parse(
      withJitter(temperature - inRange(1.0, 4.5), 15.0, 33.0, 0.5)
          .toStringAsFixed(2),
    ),
    'Conductivity': double.parse(conductivity.toStringAsFixed(3)),
  };
}
