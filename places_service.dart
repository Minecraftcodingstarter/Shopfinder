import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/shop_model.dart';

class PlacesService {
  final http.Client _client = http.Client();

  Future<List<Shop>> searchNearbyShops({
    required double latitude,
    required double longitude,
    required double radius,
    String? keyword,
  }) async {
    try {
      final results = await _searchOsmPlaces(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        keyword: keyword,
      );

      final withDistance = _addDistances(results, latitude, longitude);
      return withDistance;
    } catch (e) {
      print('OSM-Fehler: $e');
      return [];
    }
  }

  Future<List<Shop>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required double radius,
    int limit = 30,
  }) async {
    try {
      final categories = [
        'Geschäfte und Dienstleistungen',
        'Restaurants und Cafés',
        'Supermarkt Bäcker Apotheke',
      ];

      final allShops = <Shop>[];
      final seen = <String>{};

      for (final cat in categories) {
        final results = await _searchOsmPlaces(
          latitude: latitude,
          longitude: longitude,
          radius: radius,
          keyword: cat,
          limit: limit ~/ categories.length,
        );
        for (final shop in results) {
          final key = '${shop.name}|${shop.latitude}|${shop.longitude}';
          if (seen.add(key)) {
            allShops.add(shop);
          }
        }
      }

      final withDistance = _addDistances(allShops, latitude, longitude);
      return withDistance;
    } catch (e) {
      print('OSM nearby error: $e');
      return [];
    }
  }

  List<Shop> _addDistances(List<Shop> shops, double lat, double lng) {
    final withDist = shops.map((shop) {
      final dist = _calculateDistance(lat, lng, shop.latitude, shop.longitude);
      return Shop(
        id: shop.id,
        name: shop.name,
        address: shop.address,
        latitude: shop.latitude,
        longitude: shop.longitude,
        rating: shop.rating,
        userRatingsTotal: shop.userRatingsTotal,
        phoneNumber: shop.phoneNumber,
        email: shop.email,
        website: shop.website,
        types: [...shop.types],
        photoReference: shop.photoReference,
        distance: dist,
        priceLevel: shop.priceLevel,
        openingHours: shop.openingHours,
        isOpen: shop.isOpen,
        description: shop.description,
        tags: shop.tags,
        cuisine: shop.cuisine,
        imageUrl: shop.imageUrl,
        facebook: shop.facebook,
        instagram: shop.instagram,
        rawData: shop.rawData,
      );
    }).toList();

    withDist.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    return withDist;
  }

  Future<List<Shop>> _searchOsmPlaces({
    required double latitude,
    required double longitude,
    required double radius,
    String? keyword,
    int limit = 30,
  }) async {
    final query = (keyword?.trim().isNotEmpty ?? false)
        ? keyword!.trim()
        : 'Geschäfte und Dienstleistungen';
    final delta = radius / 111000.0;
    final left = longitude - delta;
    final right = longitude + delta;
    final top = latitude + delta;
    final bottom = latitude - delta;

    final url = Uri.parse('https://nominatim.openstreetmap.org/search').replace(queryParameters: {
      'format': 'jsonv2',
      'q': query,
      'bounded': '1',
      'viewbox': '$left,$top,$right,$bottom',
      'limit': limit.toString(),
      'addressdetails': '1',
      'extratags': '1',
    });

    final response = await _client.get(url, headers: {
      'User-Agent': 'ServicePlace/1.0',
      'Accept-Language': 'de',
    });

    if (response.statusCode != 200) {
      throw Exception('OSM-Anfrage fehlgeschlagen: ${response.statusCode}');
    }

    final results = jsonDecode(response.body) as List? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(Shop.fromOsmPlace)
        .toList();
  }

  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<List<Shop>> getPopularShops(double lat, double lng) async {
    try {
      return await getNearbyPlaces(latitude: lat, longitude: lng, radius: 5000, limit: 15);
    } catch (e) {
      print('Popular shops error: $e');
      return [];
    }
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
