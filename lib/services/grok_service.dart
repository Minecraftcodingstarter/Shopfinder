import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/shop_model.dart';

class GrokService {
  final http.Client _client = http.Client();
  static const String _endpoint = 'https://api.openai.com/v1/responses';
  static const String _model = 'grok-mini';

  Future<List<Shop>> searchShops({
    required String query,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    if (ApiKeys.grokApiKey.isEmpty) return [];

    final prompt = '''
Du bist ein intelligenter Suchassistent für lokale Shops und Dienstleistungen.
Gegeben ist eine Anfrage: "$query" und ein Standort mit Breite $latitude, Länge $longitude.
Nutze öffentliches Wissen, Karteninformationen und lokale Geschäftslisten, um bis zu 10 relevante Treffern zu finden.
Gib nur eine JSON-Liste zurück. Jeder Eintrag muss folgende Felder enthalten:
- name
- address
- latitude
- longitude
- category
- source

Antworte nur mit dem reinen JSON-Array, ohne zusätzliche Erklärungen.
''';

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer ${ApiKeys.grokApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'input': prompt,
        'temperature': 0.2,
        'max_output_tokens': 400,
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint('Grok API authentication failed (${response.statusCode}). Bitte überprüfe den API-Key.');
      return [];
    }

    if (response.statusCode != 200) {
      debugPrint('Grok API error: ${response.statusCode} ${response.body}');
      return [];
    }

    final responseBody = jsonDecode(response.body);
    final String rawText = _extractResponseText(responseBody);
    if (rawText.isEmpty) return [];

    final jsonText = _extractJsonArray(rawText);
    if (jsonText.isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonText) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().map((place) {
        final lat = double.tryParse(place['latitude']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(place['longitude']?.toString() ?? '') ?? 0.0;
        return Shop(
          id: place['name']?.toString() ?? '${lat}_$lng',
          name: place['name']?.toString() ?? 'Unbekannt',
          address: place['address']?.toString() ?? 'Keine Adresse',
          latitude: lat,
          longitude: lng,
          rating: null,
          userRatingsTotal: null,
          phoneNumber: null,
          website: null,
          types: ['grok'],
          photoReference: null,
          distance: null,
          priceLevel: null,
          openingHours: null,
          isOpen: null,
        );
      }).where((shop) => shop.latitude != 0 && shop.longitude != 0).toList();
    } catch (e) {
      debugPrint('Grok parsing error: $e');
      return [];
    }
  }

  String _extractResponseText(Map<String, dynamic> body) {
    if (body['output'] is List) {
      final output = body['output'] as List;
      if (output.isNotEmpty && output[0] is Map) {
        final content = output[0]['content'];
        if (content is List && content.isNotEmpty && content[0] is Map) {
          return content[0]['text']?.toString() ?? '';
        }
      }
    }
    if (body['choices'] is List) {
      final choices = body['choices'] as List;
      if (choices.isNotEmpty && choices[0] is Map) {
        return choices[0]['message']?['content']?[0]?['text']?.toString() ?? '';
      }
    }
    return body['text']?.toString() ?? '';
  }

  String _extractJsonArray(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1);
    }
    return '';
  }
}
