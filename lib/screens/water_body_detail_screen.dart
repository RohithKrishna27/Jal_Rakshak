import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/services/ollama_chat_service.dart';

class WaterBodyDetailScreen extends StatefulWidget {
  const WaterBodyDetailScreen({
    super.key,
    required this.name,
    required this.status,
    required this.bod,
    required this.fact,
    this.trend,
  });

  final String name;
  final String status;
  final String bod;
  final String fact;
  final String? trend;

  @override
  State<WaterBodyDetailScreen> createState() => _WaterBodyDetailScreenState();
}

class _WaterBodyDetailScreenState extends State<WaterBodyDetailScreen> {
  final OllamaChatService _chatService = OllamaChatService();

  bool _isLoadingInsights = true;
  String? _insights;
  String? _insightsError;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoadingInsights = true;
      _insightsError = null;
    });

    final prompt = '''
Give accurate, concise, practical information for this Indian water body:
Name: ${widget.name}
Current status: ${widget.status}
BOD: ${widget.bod} mg/L
Known note: ${widget.fact}
Trend: ${widget.trend ?? 'Not available'}

Return plain text only (no markdown) with exactly 4 sections:
1) Water Quality Snapshot
2) Likely Pollution Sources
3) Action Plan For Authorities
4) What Citizens Can Do This Week
Keep total response under 180 words.
''';

    try {
      final reply = await _chatService.generateReply(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
      );

      if (!mounted) return;
      setState(() {
        _insights = reply;
        _isLoadingInsights = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _insightsError =
            'AI insights are currently unavailable. Please check your local model server and try again.';
        _isLoadingInsights = false;
      });
    }
  }

  Color _statusColor() {
    if (widget.status.toLowerCase().contains('critical') ||
        widget.status.toLowerCase().contains('severe') ||
        widget.status.toLowerCase().contains('high')) {
      return const Color(0xFFDC2626);
    }
    if (widget.status.toLowerCase().contains('moderate')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF15803D);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: const Text('Water Body Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A3D62), Color(0xFF1565C0)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoChip('Status', widget.status, statusColor),
                    _infoChip('BOD', '${widget.bod} mg/L', Colors.white),
                    if (widget.trend != null)
                      _infoChip('Trend', widget.trend!, Colors.white),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Known Field Observation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.fact,
                    style: const TextStyle(height: 1.45, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AI Insights',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: 'Refresh insights',
                        onPressed: _isLoadingInsights ? null : _loadInsights,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (_isLoadingInsights)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(minHeight: 3),
                    )
                  else if (_insightsError != null)
                    Text(
                      _insightsError!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    )
                  else
                    Text(
                      _insights ?? '',
                      style: const TextStyle(height: 1.5, color: Color(0xFF0F172A)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(color: accent, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
