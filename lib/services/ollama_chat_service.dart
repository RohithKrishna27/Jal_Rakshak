import 'dart:convert';

import 'package:http/http.dart' as http;

class OllamaChatException implements Exception {
  OllamaChatException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return 'OllamaChatException: $message';
    }
    return 'OllamaChatException($statusCode): $message';
  }
}

class OllamaChatService {
  OllamaChatService({
    http.Client? client,
    this.baseUrl = 'http://10.62.88.191:11434',
    this.model = 'gpt-oss:120b-cloud',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String model;

  Future<String> generateReply({
    required List<Map<String, String>> messages,
  }) async {
    final uri = Uri.parse('$baseUrl/api/generate');
    final systemPrompt = _buildSystemPrompt();
    final prompt = _buildPrompt(messages);

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'prompt': '$systemPrompt\n\n$prompt',
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OllamaChatException(
        'Chat request failed',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw OllamaChatException('Invalid response from Ollama server');
    }

    final reply = decoded['response']?.toString().trim();
    if (reply == null || reply.isEmpty) {
      throw OllamaChatException('Empty response from Ollama server');
    }

    return reply;
  }

  String _buildSystemPrompt() {
    return '''
You are Jal Rakshak Assistant, a helpful chatbot inside a river conservation app.
Answer briefly, clearly, and practically.
Focus on river pollution, clean-up actions, reporting, local awareness, and app help.
If the user asks something outside the app context, still answer politely and concisely.
''';
  }

  String _buildPrompt(List<Map<String, String>> messages) {
    final buffer = StringBuffer();
    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final content = message['content'] ?? '';
      if (content.trim().isEmpty) continue;
      buffer.writeln('${role.toUpperCase()}: $content');
    }
    buffer.writeln('ASSISTANT:');
    return buffer.toString();
  }
}
