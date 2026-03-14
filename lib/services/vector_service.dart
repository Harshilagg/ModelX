// lib/services/vector_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_config.dart';

class VectorService {
  final String _apiKey = AiConfig.pineconeApiKey;
  final String _indexHost = AiConfig.pineconeIndexHost;

  /// Upserts a profile to Pinecone using text-based inference.
  /// This uses Pinecone's server-side embedding generation.
  Future<void> upsertProfileText(String userId, String text, Map<String, dynamic> metadata) async {
    final url = Uri.parse('$_indexHost/vectors/upsert');

    final payload = {
      'vectors': [
        {
          'id': userId,
          'metadata': metadata,
          // Since we are using an inference-integrated index, 
          // we might need to follow specific integration patterns 
          // or use the standard upsert if the index is already "inference-powered".
          // Note: Standard upsert usually takes 'values' (vector).
          // If the user selected an Inference configuration in the dashboard,
          // they usually use the 'upsert' with a special parameter or a dedicated endpoint.
          // For most "Inference" indices in Pinecone, you still need to get the vector first.
        }
      ]
    };

    // TODO: Verify exact Pinecone Inference API endpoint for direct text upsert
    // If using Pinecone's new integrated inference, the flow might differ.
    // For now, we will implement the standard vector upsert and update it 
    // once we confirm if they want us to call Pinecone's /embed API first.
  }

  /// Standard vector upsert
  Future<void> upsertVector(String id, List<double> values, Map<String, dynamic> metadata) async {
    final url = Uri.parse('$_indexHost/vectors/upsert');
    
    final payload = {
      'vectors': [
        {
          'id': id,
          'values': values,
          'metadata': metadata,
        }
      ]
    };

    final response = await http.post(
      url,
      headers: {
        'Api-Key': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Pinecone upsert failed: ${response.body}');
    }
  }

  /// Search for similar profiles
  Future<List<Map<String, dynamic>>> search(List<double> queryVector, {int topK = 10, Map<String, dynamic>? filter}) async {
    final url = Uri.parse('$_indexHost/query');

    final payload = {
      'vector': queryVector,
      'topK': topK,
      'includeMetadata': true,
      if (filter != null) 'filter': filter,
    };

    final response = await http.post(
      url,
      headers: {
        'Api-Key': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['matches'] ?? []);
    } else {
      throw Exception('Pinecone query failed: ${response.body}');
    }
  }

  /// Delete a profile vector
  Future<void> delete(String id) async {
    final url = Uri.parse('$_indexHost/vectors/delete');
    
    final payload = {
      'ids': [id]
    };

    final response = await http.post(
      url,
      headers: {
        'Api-Key': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Pinecone delete failed: ${response.body}');
    }
  }
}
