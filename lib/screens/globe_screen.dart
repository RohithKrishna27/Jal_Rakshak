import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:priject_jalrakshak/services/http_server_service.dart';

class GlobeScreen extends StatefulWidget {
  const GlobeScreen({super.key});

  @override
  State<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends State<GlobeScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B1020));
    _loadGlobeHtml();
  }

  Future<void> _loadGlobeHtml() async {
    try {
      // Load globe from local HTTP server instead of assets
      // This ensures CesiumJS works properly with WebGL and CORS
      final url = HttpServerService.getGlobeUrl();
      await _controller.loadRequest(Uri.parse(url));
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load globe: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        title: const Text('3D Earth Globe'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            Container(
              color: const Color(0xFF0B1020),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_loadError != null)
            Container(
              color: const Color(0xFF0B1020),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
