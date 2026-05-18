import '../models/shop_model.dart';

class ServiceMarketplace {
  static final ServiceMarketplace _instance = ServiceMarketplace._internal();
  factory ServiceMarketplace() => _instance;
  ServiceMarketplace._internal();

  final List<Service> _services = [];
  final List<ServiceReview> _serviceReviews = [];

  List<Service> get services => List.unmodifiable(_services);

  void addService(Service service) {
    _services.add(service);
  }

  void removeService(String id) {
    _services.removeWhere((s) => s.id == id);
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

  void addServiceReview(ServiceReview review) {
    _serviceReviews.add(review);
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
