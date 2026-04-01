import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Exception thrown when prediction request fails.
class PredictionServiceException implements Exception {
  PredictionServiceException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    if (statusCode != null) {
      return 'PredictionServiceException(statusCode: $statusCode, message: $message)';
    }
    return 'PredictionServiceException(message: $message)';
  }
}

class PredictionService {
  PredictionService({
    http.Client? client,
    Uri? endpoint,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _endpoint = endpoint ??
            Uri.parse(
              'https://unstern-jaylee-chromosomal.ngrok-free.dev/predict',
            ),
        _timeout = timeout ?? const Duration(seconds: 20);

  final http.Client _client;
  final Uri _endpoint;
  final Duration _timeout;

  /// Calls ML API and returns parsed JSON response as a map.
  Future<Map<String, dynamic>> predictPollution(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client
          .post(
            _endpoint,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PredictionServiceException(
          'API request failed with status ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (e) {
        throw PredictionServiceException(
          'Invalid response format: expected JSON.',
          statusCode: response.statusCode,
          cause: e,
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw PredictionServiceException(
          'Invalid response shape: expected a JSON object.',
          statusCode: response.statusCode,
        );
      }

      return decoded;
    } on SocketException catch (e) {
      throw PredictionServiceException(
        'Network error: unable to reach prediction server.',
        cause: e,
      );
    } on TimeoutException catch (e) {
      throw PredictionServiceException(
        'Request timed out. Please try again.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw PredictionServiceException(
        'HTTP client error while calling prediction API.',
        cause: e,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
