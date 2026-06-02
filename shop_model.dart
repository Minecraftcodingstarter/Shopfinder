class Shop {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? userRatingsTotal;
  final String? phoneNumber;
  final String? email;
  final String? website;
  final List<String> types;
  final String? photoReference;
  final double? distance;
  String? priceLevel;
  final Map<String, dynamic>? openingHours;
  final bool? isOpen;
  final String? description;
  final List<String> tags;
  final String? cuisine;
  final String? imageUrl;
  final String? logoUrl;
  final String? facebook;
  final String? instagram;
  final Map<String, dynamic>? rawData;
  final bool fromDb;

  Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.userRatingsTotal,
    this.phoneNumber,
    this.email,
    this.website,
    this.types = const [],
    this.photoReference,
    this.distance,
    this.priceLevel,
    this.openingHours,
    this.isOpen,
    this.description,
    this.tags = const [],
    this.cuisine,
    this.imageUrl,
    this.logoUrl,
    this.facebook,
    this.instagram,
    this.rawData,
    this.fromDb = false,
  });

  factory Shop.fromOsmPlace(Map<String, dynamic> place) {
    final lat = double.tryParse(place['lat']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(place['lon']?.toString() ?? '') ?? 0.0;
    final extratags = place['extratags'] is Map ? Map<String, dynamic>.from(place['extratags'] as Map) : <String, dynamic>{};
    final addressDetails = place['address'] is Map ? Map<String, dynamic>.from(place['address'] as Map) : <String, dynamic>{ };

    String? getAddress() {
      if (addressDetails.isNotEmpty) {
        final parts = <String>[];
        final road = addressDetails['road']?.toString() ?? addressDetails['street']?.toString();
        final housenumber = addressDetails['house_number']?.toString();
        if (road != null) parts.add('$road ${housenumber ?? ''}'.trim());
        final city = addressDetails['city']?.toString() ?? addressDetails['town']?.toString() ?? addressDetails['village']?.toString();
        if (city != null && city.isNotEmpty) parts.add(city);
        final postcode = addressDetails['postcode']?.toString() ?? '';
        if (postcode.isNotEmpty) parts.first = '${parts.isNotEmpty ? parts.first : ''} $postcode'.trim();
        if (parts.isNotEmpty) return parts.join(', ');
      }
      return place['display_name']?.toString() ?? 'Unknown address';
    }

    // Extract type list from OSM class/type
    final typeList = <String>[];
    if (place['class'] is String) typeList.add(place['class'] as String);
    if (place['type'] is String) typeList.add(place['type'] as String);

    // Extract opening hours from extratags
    Map<String, dynamic>? getOpeningHours() {
      final oh = extratags['opening_hours']?.toString();
      if (oh != null && oh.isNotEmpty) {
        return {'hours': oh, 'raw': oh};
      }
      return null;
    }

    // Extract website
    String? getWebsite() {
      return extratags['website']?.toString() ?? extratags['url']?.toString() ?? extratags['contact:website']?.toString();
    }

    // Extract phone
    String? getPhone() {
      return extratags['phone']?.toString() ?? extratags['contact:phone']?.toString() ?? extratags['telephone']?.toString();
    }

    // Extract price level from extratags if available
    String? getPriceLevel() {
      final price = extratags['price']?.toString();
      if (price != null && price.isNotEmpty) return price;
      final level = extratags['price_level']?.toString();
      if (level != null && level.isNotEmpty) return level;
      return null;
    }

    // Extract rating from extratags (used by some OSM contributors)
    double? getRating() {
      final raw = extratags['rating']?.toString() ??
          extratags['stars']?.toString() ??
          extratags['review:rating']?.toString();
      final parsed = double.tryParse(raw ?? '');
      if (parsed != null && parsed >= 0 && parsed <= 10) {
        return parsed > 5 ? parsed / 2 : parsed;
      }
      return null;
    }

    // Extract total user ratings count
    int? getRatingTotal() {
      final raw = extratags['review:count']?.toString() ??
          extratags['reviews']?.toString() ??
          extratags['rating:count']?.toString();
      return int.tryParse(raw ?? '');
    }

    return Shop(
      id: place['place_id']?.toString() ?? place['osm_id']?.toString() ?? '$lat,$lng',
      name: place['display_name']?.toString().split(',').first ?? 'Unknown',
      address: getAddress()!,
      latitude: lat,
      longitude: lng,
      rating: getRating(),
      userRatingsTotal: getRatingTotal(),
      phoneNumber: getPhone(),
      website: getWebsite(),
      types: typeList,
      photoReference: null,
      distance: null,
      priceLevel: getPriceLevel(),
      openingHours: getOpeningHours(),
      isOpen: null,
      description: extratags['description']?.toString() ?? extratags['note']?.toString(),
      tags: extratags.keys.where((k) => k.startsWith('amenity') || k.startsWith('shop') || k.startsWith('cuisine')).toList(),
      cuisine: extratags['cuisine']?.toString(),
      facebook: extratags['contact:facebook']?.toString() ?? extratags['facebook']?.toString(),
      instagram: extratags['contact:instagram']?.toString() ?? extratags['instagram']?.toString(),
      rawData: place,
    );
  }

  double getScore({String sortBy = 'quality'}) {
    switch (sortBy) {
      case 'rating':
        return rating ?? 0.0;
      case 'price':
        return _reversePriceLevel();
      case 'popularity':
        return (userRatingsTotal ?? 0) * (rating ?? 0.0);
      case 'quality':
      default:
        return (_mapRatingToScore() * 0.4) + (_popularityScore() * 0.3) + (_priceScore() * 0.3);
    }
  }

  double _mapRatingToScore() {
    return (rating ?? 0.0) * 20;
  }

  double _popularityScore() {
    final total = userRatingsTotal ?? 0;
    if (total > 500) return 100.0;
    if (total > 100) return 80.0;
    if (total > 50) return 60.0;
    if (total > 10) return 40.0;
    return 20.0;
  }

  double _reversePriceLevel() {
    switch (priceLevel) {
      case '€': return 200.0;
      case '€€': return 150.0;
      case '€€€': return 100.0;
      case '€€€€': return 50.0;
      default: return 100.0;
    }
  }

  double _priceScore() {
    return _reversePriceLevel();
  }

  /// Formatted opening hours string for display
  String? get openingHoursText {
    if (openingHours == null) return null;
    return openingHours!['hours']?.toString() ?? openingHours!['raw']?.toString();
  }

  /// Check if currently open (only works if we have opening hours)
  bool? get currentlyOpen {
    if (openingHours == null) return null;
    return isOpen;
  }
}

class Service {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String? priceUnit;
  final String providerName;
  final String providerPhone;
  final String? providerEmail;
  final String location;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final List<String> tags;
  final String? imageUrl;

  Service({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.priceUnit,
    required this.providerName,
    required this.providerPhone,
    this.providerEmail,
    required this.location,
    this.latitude,
    this.longitude,
    this.rating,
    this.tags = const [],
    this.imageUrl,
  });
}

class ShopReview {
  final String id;
  final String shopId;
  final String userName;
  final double rating;
  final String? comment;
  final DateTime timestamp;
  final List<String> tags;

  ShopReview({
    required this.id,
    required this.shopId,
    required this.userName,
    required this.rating,
    this.comment,
    required this.timestamp,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'shopId': shopId,
    'userName': userName,
    'rating': rating,
    'comment': comment,
    'timestamp': timestamp.toIso8601String(),
    'tags': tags,
  };

  factory ShopReview.fromJson(Map<String, dynamic> json) => ShopReview(
    id: json['id'] as String,
    shopId: json['shopId'] as String,
    userName: json['userName'] as String,
    rating: (json['rating'] as num).toDouble(),
    comment: json['comment'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    tags: List<String>.from((json['tags'] as List?) ?? []),
  );
}