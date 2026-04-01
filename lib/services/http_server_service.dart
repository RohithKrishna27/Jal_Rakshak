import 'dart:io';
import 'package:flutter/services.dart';

class HttpServerService {
  static HttpServer? _server;
  static const int port = 8080;

  static Future<void> startServer() async {
    if (_server != null) return; // Already running

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

      _server!.listen((HttpRequest request) async {
        try {
          final path = request.uri.path;

          if (path == '/' || path == '/assets/globe.html') {
            // Serve the globe.html file
            final html = await rootBundle.loadString('assets/globe.html');
            request.response
              ..headers.contentType = ContentType.html
              ..headers.add('Access-Control-Allow-Origin', '*')
              ..write(html)
              ..close();
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..write('404 Not Found')
              ..close();
          }
        } catch (e) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error: $e')
            ..close();
        }
      });
    } catch (e) {
      // Server startup failed - app can still run but globe won't load
    }
  }

  static Future<void> stopServer() async {
    await _server?.close();
    _server = null;
  }

  static String getGlobeUrl() => 'http://localhost:$port/assets/globe.html';
}
