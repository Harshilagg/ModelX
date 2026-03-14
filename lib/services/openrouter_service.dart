// lib/services/openrouter_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_config.dart';

class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  /// Sends a chat completion request to OpenRouter.
  /// [model] should be one of the models defined in [AiConfig].
  /// [messages] is a list of maps with 'role' and 'content' keys.
  Future<String> complete(String model, List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer ${AiConfig.openRouterApiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://modelx.app', // Required by OpenRouter
          'X-Title': 'ModelX App',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? '';
      } else {
        throw Exception('OpenRouter request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ OpenRouter Error: $e');
      throw Exception('Failed to communicate with OpenRouter');
    }
  }
}
