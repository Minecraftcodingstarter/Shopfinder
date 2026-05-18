import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/shop_model.dart';

class GeminiService {
  final http.Client _client = http.Client();
  static const List<String> _models = ['gemini-2.0-flash', 'gemini-1.5-flash'];
  static const String _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

  Future<List<Shop>> searchShops({
    required String query,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    if (ApiKeys.geminiApiKey.isEmpty) return [];

    final prompt = '''
Du bist ein lokaler Such-Assistent. Finde bis zu 8 relevante Läden, Restaurants oder Dienstleistungen für die Anfrage: "$query" in der Nähe von ($latitude, $longitude).

Nutze dein Wissen aus öffentlichen Quellen, Google Maps und Google Rezensionen.

Für JEDEN Laden gibst du folgende Felder als JSON-Array zurück:
- name (string, Pflicht)
- address (string, Pflicht)
- latitude (number, Pflicht)
- longitude (number, Pflicht)
- category (string, z.B. 'Restaurant', 'Supermarkt', 'Friseur')
- priceLevel (string, Pflicht – einer von: '€' = günstig unter 10€, '€€' = mittel 10-30€, '€€€' = teuer 30-60€, '€€€€' = sehr teuer 60€+)
- rating (number, Pflicht – Bewertung von 0.0 bis 5.0 basierend auf Google-Rezensionen)
- reviewCount (number, wie viele Rezensionen du kennst)

WICHTIG: Jeder Eintrag MUSS priceLevel und rating enthalten. Schätze den Preis basierend auf dem was du über den Laden weißt (Art des Ladens, Lage, was Kunden in Rezensionen sagen).
Schätze die Bewertung basierend auf öffentlichen Rezensionen und Bewertungen.

Antworte NUR mit dem JSON-Array, keine Erklärungen, kein Markdown.
''';

    try {
      final result = await _tryModels(
        _models,
        prompt: prompt,
        temperature: 0.2,
        maxTokens: 2048,
      );
      if (result == null) return [];
      return _parseShopList(result, query);
    } catch (e) {
      debugPrint('Gemini search error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> enrichShopInfo(String shopName, String address) async {
    if (ApiKeys.geminiApiKey.isEmpty) return {};

    final prompt = '''
Du kennst Google Rezensionen und öffentliche Informationen über "$shopName" ($address).

Gib ein JSON-Objekt mit diesen Feldern zurück:
- priceLevel: string, einer von '€', '€€', '€€€', '€€€€' – schätze den Preis basierend auf dem was Kunden in Rezensionen sagen
- rating: number, 0.0 bis 5.0 – die durchschnittliche Google-Bewertung
- reviewCount: number – wie viele Google-Rezensionen es gibt
- priceInfo: string – ein kurzer Satz was Kunden über die Preise sagen (z.B. "Günstige Mittagsgerichte ab 8€" oder "Hochpreisig aber exklusiv")
- reviewSummary: string – ein kurzer Satz was Kunden allgemein sagen

Nur das JSON-Objekt, keine Erklärungen.
''';

    try {
      final result = await _tryModels(
        _models,
        prompt: prompt,
        temperature: 0.3,
        maxTokens: 1024,
      );
      if (result == null) return {};

      final jsonText = _extractJson(result);
      if (jsonText.isEmpty) return {};

      final decoded = jsonDecode(jsonText) as Map<String, dynamic>?;
      return decoded ?? {};
    } catch (e) {
      debugPrint('Gemini enrich error: $e');
      return {};
    }
  }

  List<Shop> _parseShopList(String rawText, String query) {
    final jsonText = _extractJson(rawText);
    if (jsonText.isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonText) as List<dynamic>?;
      if (decoded == null) return [];

      return decoded.whereType<Map<String, dynamic>>().map((place) {
        final lat = _parseDouble(place['latitude']) ?? 0.0;
        final lng = _parseDouble(place['longitude']) ?? 0.0;
        final priceRaw = place['priceLevel']?.toString() ?? place['price_level']?.toString();
        final ratingRaw = place['rating']?.toString();
        final reviewCount = _parseInt(place['reviewCount'] ?? place['review_count']);

        return Shop(
          id: 'gemini_${place['name']?.toString() ?? '$lat$lng'}',
          name: place['name']?.toString() ?? 'Unbekannt',
          address: place['address']?.toString() ?? 'Keine Adresse',
          latitude: lat,
          longitude: lng,
          rating: _parseDouble(ratingRaw),
          userRatingsTotal: reviewCount,
          phoneNumber: null,
          website: null,
          types: ['gemini'],
          photoReference: null,
          distance: null,
          priceLevel: _normalizePriceLevel(priceRaw),
          openingHours: null,
          isOpen: null,
          description: null,
        );
      }).where((shop) => shop.latitude != 0 && shop.longitude != 0).toList();
    } catch (e) {
      debugPrint('Gemini parse error: $e');
      return [];
    }
  }

  Future<String?> generateShortDescription(String shopName, String address) async {
    if (ApiKeys.geminiApiKey.isEmpty) return null;

    final prompt = '''
Gib eine sehr kurze Beschreibung (maximal 1 Satz) für "$shopName" in $address.
Was für ein Geschäft, Restaurant oder Dienstleistung ist es? Was bietet es an?
Antworte nur mit der Beschreibung, keine Einleitung oder Erklärung.
''';

    try {
      final result = await _tryModels(
        _models,
        prompt: prompt,
        temperature: 0.3,
        maxTokens: 200,
      );
      if (result == null) return null;
      return result.trim();
    } catch (e) {
      debugPrint('Gemini short description error: $e');
      return null;
    }
  }

  String? _normalizePriceLevel(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim().toLowerCase();
    if (clean == '€€€€' || clean.contains('sehr teuer')) return '€€€€';
    if (clean == '€€€' || clean == 'teuer' || clean.contains('€€€')) return '€€€';
    if (clean == '€€' || clean == 'mittel' || clean.contains('€€')) return '€€';
    if (clean == '€' || clean == 'günstig' || clean == 'billig' || clean.startsWith('€')) return '€';
    return null;
  }

  Future<String?> _tryModels(List<String> models, {required String prompt, double temperature = 0.3, int maxTokens = 1024}) async {
    for (final model in models) {
      try {
        final uri = Uri.parse('$_endpoint/$model:generateContent?key=${ApiKeys.geminiApiKey}');
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': temperature,
              'maxOutputTokens': maxTokens,
            },
          }),
        );

        if (response.statusCode == 429) {
          debugPrint('Gemini rate limit ($model), trying next model');
          continue;
        }

        if (response.statusCode != 200) {
          debugPrint('Gemini API error ($model): ${response.statusCode}');
          continue;
        }

        final responseBody = jsonDecode(response.body) as Map<String, dynamic>?;
        if (responseBody == null) continue;

        final rawText = _extractResponseText(responseBody);
        if (rawText.isNotEmpty) return rawText;
      } catch (e) {
        debugPrint('Gemini error ($model): $e');
        continue;
      }
    }
    return null;
  }

  String _extractResponseText(Map<String, dynamic> body) {
    try {
      final candidates = body['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0] as Map<String, dynamic>?;
        if (content != null) {
          final parts = content['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text']?.toString() ?? '';
          }
        }
      }
    } catch (_) {}
    return '';
  }

  String _extractJson(String text) {
    final startIdx = text.indexOf('[');
    if (startIdx >= 0) {
      final endIdx = text.lastIndexOf(']');
      if (endIdx > startIdx) return text.substring(startIdx, endIdx + 1);
    }
    final objStart = text.indexOf('{');
    if (objStart >= 0) {
      final objEnd = text.lastIndexOf('}');
      if (objEnd > objStart) return text.substring(objStart, objEnd + 1);
    }
    return '';
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return null;
    if (parsed > 10) return parsed / 2;
    return parsed;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}
