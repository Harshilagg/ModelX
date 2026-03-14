// lib/agency/scouting/ai_scout_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/ai_service.dart';
import '../../services/vector_service.dart';
import '../../services/groq_service.dart';
import '../../services/ai_config.dart';

class AiScoutResult {
  final Map<String, dynamic> profile;
  final String explanation;
  final double score;

  AiScoutResult({required this.profile, required this.explanation, required this.score});
}

class AiScoutService {
  final AiService _aiService = AiService();
  final VectorService _vectorService = VectorService();
  final GroqService _groqService = GroqService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Full RAG Pipeline: Search talent using natural language
  Future<List<AiScoutResult>> searchTalent(String query) async {
    // 1. Generate Query Embedding
    final queryVector = await _aiService.embedText(query);

    // 2. Vector Search (Pinecone)
    final matches = await _vectorService.search(queryVector, topK: 15);
    if (matches.isEmpty) return [];

    // 3. Fetch Full Profiles from Firestore
    final List<Map<String, dynamic>> candidateProfiles = [];
    for (var match in matches) {
      final docId = match['id'];
      final doc = await _db.collection('users').doc(docId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        candidateProfiles.add(data);
      }
    }

    if (candidateProfiles.isEmpty) return [];
  
    // 4. Semantic Re-ranking & Explanation (GROQ - Ultra Fast & High Free Quota)
    final prompt = _buildRerankingPrompt(query, candidateProfiles);
    
    final response = await _groqService.complete(
      AiConfig.modelChatAssistant,
      [
        {'role': 'system', 'content': 'You are an expert talent scout for ModelX. Your goal is to find the MOST relevant models for a specific query. Be very picky. If a model doesn\'t match a specific criteria (like location or gender), either exclude them or mark them as a non-match. Return a ranked list of only the candidates that realistically fit.'},
        {'role': 'user', 'content': prompt},
      ],
    );
  
    // 5. Parse LLM response and merge with profile data
    return _parseLlmResponse(response, candidateProfiles);
  }

  /// Build string representation and index profile in Pinecone
  Future<void> indexProfile(String userId, Map<String, dynamic> data) async {
    final profileText = _buildProfileSearchText(data);
    final embedding = await _aiService.embedText(profileText);

    final metadata = {
      'fullName': data['fullName'] ?? data['displayName'] ?? 'Unknown',
      'location': data['location'] ?? '',
      'gender': data['gender'] ?? '',
      'age': (data['age'] ?? 0).toString(),
      'specialties': (data['specialties'] as List?)?.join(', ') ?? '',
      'height': (data['height'] ?? '').toString(),
      'heightUnit': data['heightUnit'] ?? '',
      'weight': (data['weight'] ?? '').toString(),
      'shoeSize': (data['shoeSize'] ?? '').toString(),
      'eyeColor': data['eyeColor'] ?? '',
      'hairColor': data['hairColor'] ?? '',
      'skinColor': data['skinColor'] ?? '',
      'skills': data['skills'] ?? '',
    };

    await _vectorService.upsertVector(userId, embedding, metadata);
    print('✅ Indexed profile for $userId');
  }

  String _buildProfileSearchText(Map<String, dynamic> d) {
    return [
      d['fullName'] ?? d['displayName'] ?? '',
      d['gender'] ?? '',
      'Age: ${d['age'] ?? 'N/A'}',
      'Location: ${d['location'] ?? ''}',
      'Height: ${d['height'] ?? ''} ${d['heightUnit'] ?? ''}',
      'Weight: ${d['weight'] ?? ''}',
      'Shoe: ${d['shoeSize'] ?? ''} ${d['shoeSizeUnit'] ?? ''}',
      'Eye Color: ${d['eyeColor'] ?? ''}',
      'Hair Color: ${d['hairColor'] ?? ''}',
      'Skin Color: ${d['skinColor'] ?? ''}',
      'Shoulder: ${d['shoulderWidth'] ?? ''}',
      'Waist: ${d['waist'] ?? ''}',
      'Hips: ${d['hips'] ?? ''}',
      'Tattoos: ${d['tattoos'] ?? ''}',
      'Piercing: ${d['piercing'] ?? ''}',
      'Skills: ${(d['skills'] is List) ? (d['skills'] as List).join(', ') : d['skills']}',
      'Specialties: ${(d['specialties'] is List) ? (d['specialties'] as List).join(', ') : d['specialties']}',
      'Languages: ${(d['languages'] is List) ? (d['languages'] as List).join(', ') : d['languages']}',
      'Bio: ${d['bio'] ?? ''}',
      'Experience: ${d['experience'] ?? ''}',
      'Preferred Work: ${d['preferredWork'] ?? ''}',
    ].join(' | ');
  }

  String _buildRerankingPrompt(String query, List<Map<String, dynamic>> profiles) {
    String profileList = profiles.map((p) {
      return """
ID: ${p['id']}
Name: ${p['fullName']}
Location: ${p['location']}
Age: ${p['age']}
Gender: ${p['gender']}
Height: ${p['height']} ${p['heightUnit']}
Weight: ${p['weight']}
Shoe Size: ${p['shoeSize']} ${p['shoeSizeUnit']}
Eye Color: ${p['eyeColor']}
Hair Color: ${p['hairColor']}
Skin Tone: ${p['skinColor']}
Shoulder Width: ${p['shoulderWidth']}
Waist: ${p['waist']}
Hips: ${p['hips']}
Tattoos: ${p['tattoos']}
Piercing: ${p['piercing']}
Preferred Work: ${p['preferredWork']}
Skills: ${p['skills']}
Bio: ${p['bio']}
""";
    }).join("\n---\n");
    
    return """
User Search Goal: "$query"

Current Candidates (Top 15 results from Vector Search):
$profileList

Your Task:
1. Analyze if these candidates actually match the User Search Goal. 
2. Be STRICT. If the user asked for "Delhi" and a candidate is in "Mumbai", they are a "NOT A MATCH" and should be excluded.
3. If the user didn't specify a criteria, be more flexible.
4. Return a list of only the relevant candidates.

Format:
ID: [id]
MATCH: [Brief professional explanation of why they fit]
---
ID: [id]
MATCH: ...

If NONE of the candidates match, simply reply with "NO_MATCHES".
""";
  }

  List<AiScoutResult> _parseLlmResponse(String response, List<Map<String, dynamic>> profiles) {
    if (response.contains('NO_MATCHES')) return [];
    
    final List<AiScoutResult> results = [];
    final sections = response.split('---');

    for (var section in sections) {
      final lines = section.trim().split('\n');
      String? id;
      String? matchText;

      for (var line in lines) {
        final cleanLine = line.trim();
        final lowerLine = cleanLine.toLowerCase();
        if (lowerLine.startsWith('id:')) {
          id = cleanLine.substring(3).trim();
          // Remove potential quotes or brackets
          id = id.replaceAll('"', '').replaceAll("'", '').replaceAll('[', '').replaceAll(']', '');
        }
        if (lowerLine.startsWith('match:')) {
          matchText = cleanLine.substring(6).trim();
        }
      }

      if (id != null && matchText != null) {
        final profile = profiles.firstWhere((p) => p['id'] == id, orElse: () => {});
        if (profile.isNotEmpty) {
          results.add(AiScoutResult(
            profile: profile,
            explanation: matchText,
            score: 1.0 - (results.length * 0.05),
          ));
        }
      }
    }
    
    return results;
  }

  /// Get general concierge guidance using Groq (Llama)
  Future<String> getGuidance(String query, String userType) async {
    try {
      final response = await _groqService.complete(
        AiConfig.modelChatAssistant,
        [
          {
            'role': 'system',
            'content': '''You are the ModelX AI Concierge, a sophisticated assistant for a premium talent platform.
User Type: $userType

Instructions:
1. Provide helpful, concise guidance (under 60 words).
2. If they are a Model, help with portfolio, jobs, or profile tips.
3. If they are an Agency/Brand, help with scouting, gigs, or hiring.
4. Tone: Elegant, professional, and prestigious.
5. If asked about app features, give general professional advice matching the industry.'''
          },
          {'role': 'user', 'content': query},
        ],
      );
      return response;
    } catch (e) {
      debugPrint('Concierge Error: $e');
      return "I'm here to help you succeed on ModelX. How can I assist with your career today?";
    }
  }
}
