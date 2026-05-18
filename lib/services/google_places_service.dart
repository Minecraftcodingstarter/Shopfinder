import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/shop_model.dart';

class GooglePlacesResult {
  final double? rating;
  final int? ratingTotal;
  final String? priceLevel;

  GooglePlacesResult({this.rating, this.ratingTotal, this.priceLevel});
}

class GooglePlacesService {
  final http.Client _client = http.Client();
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  Future<GooglePlacesResult?> enrichShop(Shop shop) async {
    if (ApiKeys.googleMapsApiKey.isEmpty || ApiKeys.googleMapsApiKey == 'AIzaSyA5HAn_0qhXC7AgHFJWpRvL2qlWBYxPkV8') {
      return null;
    }

    try {
      final query = '${shop.name} ${shop.address}';
      final findUrl = Uri.parse('$_baseUrl/findplacefromtext/json').replace(
        queryParameters: {
          'input': query,
          'inputtype': 'textquery',
          'fields': 'place_id,name,rating,user_ratings_total,price_level',
          'key': ApiKeys.googleMapsApiKey,
        },
      );

      final findRes = await _client.get(findUrl, headers: {
        'Accept-Language': 'de',
      });

      if (findRes.statusCode != 200) return null;

      final findBody = jsonDecode(findRes.body);
      final candidates = findBody['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final placeId = candidates[0]['place_id']?.toString();
      if (placeId == null || placeId.isEmpty) return null;

      final detailUrl = Uri.parse('$_baseUrl/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'fields': 'rating,user_ratings_total,price_level',
          'key': ApiKeys.googleMapsApiKey,
        },
      );

      final detailRes = await _client.get(detailUrl, headers: {
        'Accept-Language': 'de',
      });

      if (detailRes.statusCode != 200) return null;

      final detailBody = jsonDecode(detailRes.body);
      final result = detailBody['result'] as Map<String, dynamic>?;
      if (result == null) return null;

      final ratingRaw = result['rating'];
      final rating = ratingRaw != null ? double.tryParse(ratingRaw.toString()) : null;
      final ratingTotalRaw = result['user_ratings_total'];
      final ratingTotal = ratingTotalRaw != null ? int.tryParse(ratingTotalRaw.toString()) : null;
      final priceLevelRaw = result['price_level'];
      final priceLevel = priceLevelRaw != null ? (() {
        final lvl = int.tryParse(priceLevelRaw.toString());
        if (lvl == null) return null;
        switch (lvl) {
          case 0: return 'Kostenlos';
          case 1: return '€';
          case 2: return '€€';
          case 3: return '€€€';
          case 4: return '€€€€';
          default: return null;
        }
      })() : null;

      return GooglePlacesResult(
        rating: rating,
        ratingTotal: ratingTotal,
        priceLevel: priceLevel,
      );
    } catch (e) {
      debugPrint('Google Places enrich error: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
