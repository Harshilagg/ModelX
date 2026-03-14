import 'package:flutter/foundation.dart';
import '../agency/scouting/ai_scout_service.dart';
import 'groq_service.dart';
import 'ai_config.dart';

enum CopilotIntent {
  talentSearch,
  appGuidance,
  messaging,
  profileFeedback,
  unknown
}

class AiCopilotService {
  final GroqService _groqService = GroqService();
  final AiScoutService _scoutService = AiScoutService();

  /// Determines the user's intent based on their query and the current app context.
  Future<CopilotIntent> classifyIntent(String query, Map<String, dynamic> context) async {
    final page = context['page'] ?? 'unknown';
    final role = context['role'] ?? 'user';

    final systemPrompt = '''You are the Intent Classifier for ModelX Copilot.
Your job is to categorize the user's query into one of these intents:
1. talentSearch: Finding specific models, scouting talent, searching for people. Only for Brands/Agencies looking for NEW people.
2. appGuidance: Questions about HOW to use the app, "how to post a gig", "how to get hired", "payments", "navigating", "creating a profile". These are process questions.
3. messaging: Writing chat replies, drafting emails, negotiating.
4. profileFeedback: Improving bios, analyzing portfolios, profile tips.

Context: 
Current Page: $page
User Role: $role

CRITICAL RULES:
- If Current Page is 'scout' and the query describes a person or a model (e.g., "tall models", "models in Delhi", "editorial girls"), ALWAYS classify as 'talentSearch'.
- If User Role is 'Model' or 'User', they CANNOT have the 'talentSearch' intent. They only seek 'appGuidance' or 'profileFeedback'.
- Queries like "How to post a gig" or "How to scout" are 'appGuidance', NOT 'talentSearch'.
- Only specific search queries like "Find a model with blonde hair" or "Scout for a luxury campaign" or simple descriptions of models are 'talentSearch'.

Respond with ONLY the intent name (e.g., "talentSearch").''';

    try {
      final response = await _groqService.complete(
        AiConfig.modelChatAssistant,
        [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': query},
        ],
      );

      final cleanResponse = response.trim().toLowerCase();
      if (cleanResponse.contains('talentsearch')) return CopilotIntent.talentSearch;
      if (cleanResponse.contains('appguidance')) return CopilotIntent.appGuidance;
      if (cleanResponse.contains('messaging')) return CopilotIntent.messaging;
      if (cleanResponse.contains('profilefeedback')) return CopilotIntent.profileFeedback;
      
      return CopilotIntent.unknown;
    } catch (e) {
      debugPrint('Intent Classification Error: $e');
      return CopilotIntent.unknown;
    }
  }

  /// Dispatches the query to the correct AI logic based on intent.
  Future<dynamic> handleRequest(String query, Map<String, dynamic> context) async {
    // Normalize user role
    final rawRole = context['role'] ?? 'Model';
    final role = (rawRole == 'User') ? 'Model' : rawRole;
    
    CopilotIntent intent;
    
    // On the scout page, if it doesn't look like a process question ("how to", "?", "account"),
    // assume it's a talent search to match the successful behavior of the simpler widget.
    if (context['page'] == 'scout') {
      final qLower = query.toLowerCase();
      if (!qLower.contains('how') && !qLower.contains('?') && !qLower.contains('account') && !qLower.contains('help')) {
        intent = CopilotIntent.talentSearch;
        debugPrint('🎯 AiCopilotService: Scout Page Direct Search Path');
      } else {
        intent = await classifyIntent(query, context);
      }
    } else {
      intent = await classifyIntent(query, context);
    }
    
    debugPrint('🎯 AiCopilotService: Intent Classified as $intent');
    
    // Safety check: Models don't search for talent
    if (role == 'Model' && intent == CopilotIntent.talentSearch) {
      intent = CopilotIntent.appGuidance;
    }
    
    switch (intent) {
      case CopilotIntent.talentSearch:
        // Ensure strictly search behavior
        return await _scoutService.searchTalent(query);
      
      case CopilotIntent.appGuidance:
        return await _scoutService.getGuidance(query, role);

      case CopilotIntent.messaging:
        return await _getMessagingAdvice(query, context);

      case CopilotIntent.profileFeedback:
        return await _getProfileAdvice(query, context);

      default:
        // Default to guidance if unknown
        return await _scoutService.getGuidance(query, role);
    }
  }

  Future<String> _getMessagingAdvice(String query, Map<String, dynamic> context) async {
    final chatContext = context['chatContext'] ?? 'No chat history available.';
    final response = await _groqService.complete(
      AiConfig.modelChatAssistant,
      [
        {
          'role': 'system', 
          'content': 'You are a messaging copilot for ModelX. Help the user draft professional, charming, and effective replies. Context: $chatContext'
        },
        {'role': 'user', 'content': query},
      ],
    );
    return response;
  }

  Future<String> _getProfileAdvice(String query, Map<String, dynamic> context) async {
    final profileData = context['profileData'] ?? 'No profile data available.';
    final response = await _groqService.complete(
      AiConfig.modelChatAssistant,
      [
        {
          'role': 'system', 
          'content': 'You are a career consultant for ModelX. Analyze the user\'s profile data and provide high-impact tips to improve their bio and portfolio. Data: $profileData'
        },
        {'role': 'user', 'content': query},
      ],
    );
    return response;
  }
}
