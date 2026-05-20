import 'package:flutter/foundation.dart';
import '../models/shop_model.dart';
import 'backend_service.dart';

class ServiceMarketplace {
  static final ServiceMarketplace _instance = ServiceMarketplace._internal();
  factory ServiceMarketplace() => _instance;
  ServiceMarketplace._internal();

  final List<Service> _services = [];
  final List<ServiceReview> _serviceReviews = [];

  List<Service> get services => List.unmodifiable(_services);

  Future<void> addService(Service service) async {
    try {
      final data = await BackendService().post('/api/services', body: {
        'title': service.title,
        'description': service.description,
        'category': service.category,
        'price': service.price,
        'priceUnit': service.priceUnit ?? '€',
        'location': service.location,
        'latitude': service.latitude,
        'longitude': service.longitude,
      });
      if (data != null) {
        final newId = data['id'] as String;
        _services.removeWhere((s) => s.id == service.id);
        _services.add(Service(
          id: newId,
          title: service.title,
          description: service.description,
          category: service.category,
          price: service.price,
          priceUnit: service.priceUnit,
          providerName: service.providerName,
          providerPhone: service.providerPhone,
          providerEmail: service.providerEmail,
          location: service.location,
          latitude: service.latitude,
          longitude: service.longitude,
          rating: service.rating,
          tags: service.tags,
          imageUrl: service.imageUrl,
        ));
        return;
      }
    } catch (e) {
      debugPrint('ServiceMarketplace addService backend error: $e');
    }
    _services.add(service);
  }

  Future<void> removeService(String id) async {
    try {
      await BackendService().delete('/api/services/$id');
    } catch (e) {
      debugPrint('ServiceMarketplace removeService error: $e');
    }
    _services.removeWhere((s) => s.id == id);
  }

  Future<List<Service>> fetchFromBackend({
    String? category,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final result = await BackendService().getList('/api/services',
          queryParams: params.isNotEmpty ? params : null, auth: false);
      if (result == null) return [];

      final services = result.map((json) => Service(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
        price: (json['price'] as num).toDouble(),
        priceUnit: json['priceUnit'] as String? ?? '€',
        providerName: json['providerName'] as String? ?? '',
        providerPhone: json['providerPhone'] as String? ?? '',
        providerEmail: json['providerEmail'] as String?,
        location: json['location'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        rating: (json['averageRating'] as num?)?.toDouble(),
        tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
        imageUrl: json['imageUrl'] as String?,
      )).toList();

      _services
        ..clear()
        ..addAll(services);
      return services;
    } catch (e) {
      debugPrint('ServiceMarketplace fetchFromBackend error: $e');
      return [];
    }
  }

  List<Service> searchServices({
    String? query,
    String? category,
    String? location,
    double? maxPrice,
  }) {
    return _services.where((s) {
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        if (!(s.title.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q) ||
            s.tags.any((t) => t.toLowerCase().contains(q)))) {
          return false;
        }
      }
      if (category != null && category.isNotEmpty) {
        if (s.category.toLowerCase() != category.toLowerCase()) return false;
      }
      if (location != null && location.isNotEmpty) {
        if (!s.location.toLowerCase().contains(location.toLowerCase())) return false;
      }
      if (maxPrice != null) {
        if (s.price > maxPrice) return false;
      }
      return true;
    }).toList();
  }

  List<Service> getServicesByCategory(String category) {
    return _services.where((s) => s.category == category).toList();
  }

  List<String> get categories =>
      _services.map((s) => s.category).toSet().toList()..sort();

  Future<void> addServiceReview(ServiceReview review) async {
    try {
      final data = await BackendService().post(
        '/api/reviews/services/${review.serviceId}/reviews',
        body: {
          'rating': review.rating,
          'comment': review.comment ?? '',
        },
      );
      if (data != null) {
        final newId = data['id'] as String;
        _serviceReviews.removeWhere((r) => r.id == review.id);
        _serviceReviews.add(ServiceReview(
          id: newId,
          serviceId: review.serviceId,
          userName: review.userName,
          rating: review.rating,
          comment: review.comment,
          timestamp: review.timestamp,
        ));
        return;
      }
    } catch (e) {
      debugPrint('ServiceMarketplace addReview backend error: $e');
    }
    _serviceReviews.add(review);
  }

  Future<List<ServiceReview>> fetchReviewsFromBackend(String serviceId) async {
    try {
      final result = await BackendService().getList(
        '/api/reviews/services/$serviceId/reviews',
        auth: false,
      );
      if (result == null) return [];
      return result.map((json) => ServiceReview(
        id: json['id'] as String,
        serviceId: serviceId,
        userName: json['userName'] as String,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String?,
        timestamp: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      )).toList();
    } catch (e) {
      debugPrint('ServiceMarketplace fetchReviews error: $e');
      return [];
    }
  }

  List<ServiceReview> getReviewsForService(String serviceId) {
    return _serviceReviews.where((r) => r.serviceId == serviceId).toList();
  }

  double getAverageServiceRating(String serviceId) {
    final reviews = getReviewsForService(serviceId);
    if (reviews.isEmpty) return 0.0;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
  }
}

class ServiceReview {
  final String id;
  final String serviceId;
  final String userName;
  final double rating;
  final String? comment;
  final DateTime timestamp;

  ServiceReview({
    required this.id,
    required this.serviceId,
    required this.userName,
    required this.rating,
    this.comment,
    required this.timestamp,
  });
}
