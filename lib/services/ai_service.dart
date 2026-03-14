import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_config.dart';
import 'model_discovery.dart';

class AiService {
  // Singleton pattern
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal() {
    _initialize();
  }

  late final GenerativeModel _chatModel;
  late final GenerativeModel _proModel;
  late final GenerativeModel _embedModel;
  bool _isInitialized = false;

  void _initialize() {
    if (AiConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE' || AiConfig.geminiApiKey.isEmpty) {
      debugPrint('⚠️ Gemini API Key missing. AiService will not function.');
      return;
    }

    // Use the specific aliases confirmed in your ModelDiscovery list
    _chatModel = GenerativeModel(
      model: 'gemini-flash-latest', 
      apiKey: AiConfig.geminiApiKey,
    );

    _proModel = GenerativeModel(
      model: 'gemini-pro-latest',
      apiKey: AiConfig.geminiApiKey,
    );

    _embedModel = GenerativeModel(
      model: 'gemini-embedding-001', 
      apiKey: AiConfig.geminiApiKey,
    );
    
    _isInitialized = true;
    debugPrint('✅ AiService initialized with alias models');
  }

  /// Simple chat completion using Gemini Flash
  Future<String> chat(String prompt) async {
    if (!_isInitialized) return 'Gemini not configured';
    
    debugPrint('🤖 AiService.chat() starting...');
    final content = [Content.text(prompt)];
    try {
      final response = await _chatModel.generateContent(content);
      return response.text ?? '';
    } catch (e) {
      debugPrint('❌ AiService.chat() ERROR: $e');
      rethrow;
    }
  }

  /// Multimodal analysis using Gemini Pro (e.g. for portfolio images)
  Future<String> analyzeWithPro(String prompt, List<DataPart> imageParts) async {
    if (!_isInitialized) return 'Gemini not configured';

    debugPrint('🧠 AiService.analyzeWithPro() starting...');
    final content = [
      Content.multi([
        TextPart(prompt),
        ...imageParts,
      ])
    ];
    final response = await _proModel.generateContent(content);
    return response.text ?? '';
  }

  /// Generates a vector embedding for the given text.
  Future<List<double>> embedText(String text) async {
    if (!_isInitialized) throw Exception('Gemini not configured');

    debugPrint('🔢 AiService.embedText() starting...');
    
    final content = Content.text(text);
    try {
      final response = await _embedModel.embedContent(
        content,
        taskType: TaskType.retrievalDocument,
        outputDimensionality: 768,
      );
      return response.embedding.values;
    } catch (e) {
      debugPrint('❌ AiService.embedText() ERROR: $e');
      rethrow;
    }
  }
}
