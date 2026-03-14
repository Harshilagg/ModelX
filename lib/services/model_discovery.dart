// lib/services/model_discovery.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'ai_config.dart';

class ModelDiscovery {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static Future<void> listAvailableModels() async {
    final url = Uri.parse('$_baseUrl?key=${AiConfig.geminiApiKey}');
    
    debugPrint('🔍 Discovering available Gemini models...');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List models = data['models'] ?? [];
        debugPrint('✅ Found ${models.length} models:');
        for (var m in models) {
          final name = m['name'];
          final methods = (m['supportedGenerationMethods'] as List?)?.join(', ') ?? 'none';
          debugPrint(' - $name [Methods: $methods]');
        }
      } else {
        debugPrint('❌ Failed to list models: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error listing models: $e');
    }
  }
}
