import 'package:flutter/material.dart';

import 'package:priject_jalrakshak/services/prediction_service.dart';
import 'package:priject_jalrakshak/utils/environmental_data_generator.dart';

class PollutionPredictionDashboard extends StatefulWidget {
  const PollutionPredictionDashboard({super.key});

  @override
  State<PollutionPredictionDashboard> createState() =>
      _PollutionPredictionDashboardState();
}

class _PollutionPredictionDashboardState
    extends State<PollutionPredictionDashboard> {
  final PredictionService _predictionService = PredictionService();

  bool _isLoading = true;
  String? _errorMessage;
  String _pollutionLevel = 'Unknown';
  double? _riskPercent;

  @override
  void initState() {
    super.initState();
    _runPrediction();
  }

  @override
  void dispose() {
    _predictionService.dispose();
    super.dispose();
  }

  Future<void> _runPrediction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = generateEnvironmentalData();
      final result = await _predictionService.predictPollution(payload);

      final level = _extractPollutionLevel(result);
      final score = _extractRiskPercent(result);

      if (!mounted) return;
      setState(() {
        _pollutionLevel = level;
        _riskPercent = score;
      });
    } on PredictionServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to fetch prediction right now.';
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
    final value = result['pollution_level'] ??
        result['pollutionLevel'] ??
        result['level'] ??
        result['prediction'];
    return value?.toString().trim().isNotEmpty == true
        ? value.toString().trim()
        : 'Unknown';
  }

  double? _extractRiskPercent(Map<String, dynamic> result) {
    final value = result['risk_score'] ??
        result['riskScore'] ??
        result['score'] ??
        result['probability'];

    double? parsed;
    if (value is num) {
      parsed = value.toDouble();
    } else if (value != null) {
      parsed = double.tryParse(value.toString());
    }

    if (parsed == null) return null;
    if (parsed <= 1) return parsed * 100;
    return parsed;
  }

  Color _statusColor() {
    final level = _pollutionLevel.toLowerCase();
    if (level.contains('high') || (_riskPercent != null && _riskPercent! > 80)) {
      return Colors.red;
    }
    if (level.contains('medium') ||
        (_riskPercent != null && _riskPercent! >= 50 && _riskPercent! <= 80)) {
      return Colors.amber;
    }
    return Colors.green;
  }

  String _alertText() {
    final color = _statusColor();
    if (color == Colors.red) return 'Critical pollution risk';
    if (color == Colors.amber) return 'Moderate risk';
    return 'Safe';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Pollution Prediction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh prediction',
                onPressed: _isLoading ? null : _runPrediction,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const LinearProgressIndicator()
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            )
          else ...[
            Text(
              _pollutionLevel,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _riskPercent == null
                  ? 'Risk Score: Not available'
                  : 'Risk Score: ${_riskPercent!.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _alertText(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
