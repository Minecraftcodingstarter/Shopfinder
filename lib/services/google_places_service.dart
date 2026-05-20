import 'package:flutter/foundation.dart';
import '../models/shop_model.dart';
import 'backend_service.dart';

class GooglePlacesResult {
  final double? rating;
  final int? ratingTotal;
  final String? priceLevel;

  GooglePlacesResult({this.rating, this.ratingTotal, this.priceLevel});
}

class GooglePlacesService {
  Future<GooglePlacesResult?> enrichShop(Shop shop) async {
    try {
      final query = '${shop.name} ${shop.address}';

      final findData = await BackendService().post('/api/proxy/places', body: {
        'input': query,
        'inputtype': 'textquery',
        'fields': 'place_id,name,rating,user_ratings_total,price_level',
      }, auth: false);

      if (findData == null) return null;

      final candidates = findData['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final placeId = candidates[0]['place_id']?.toString();
      if (placeId == null || placeId.isEmpty) return null;

      final detailData = await BackendService().post('/api/proxy/places/details', body: {
        'place_id': placeId,
        'fields': 'rating,user_ratings_total,price_level',
      }, auth: false);

      if (detailData == null) return null;

      final result = detailData['result'] as Map<String, dynamic>?;
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
}
