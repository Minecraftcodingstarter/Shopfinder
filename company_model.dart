class Company {
  final String id;
  final String userEmail;
  String name;
  String description;
  String address;
  String phoneNumber;
  String email;
  String? website;
  List<String> categories;
  double? latitude;
  double? longitude;
  double? serviceRadius;
  String? priceLevel;
  DateTime createdAt;
  int viewCount;
  double averageRating;
  int reviewCount;
  List<CompanyReview> reviews;
  List<String> images;
  bool hideAddress;
  bool hasWhatsapp;
  bool wantsAdvertising;
  String logoUrl;

  Company({
    required this.id,
    required this.userEmail,
    required this.name,
    this.description = '',
    required this.address,
    this.phoneNumber = '',
    this.email = '',
    this.website,
    this.categories = const ['Sonstiges'],
    this.latitude,
    this.longitude,
    this.serviceRadius,
    this.priceLevel,
    DateTime? createdAt,
    this.viewCount = 0,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    List<CompanyReview>? reviews,
    List<String>? images,
    this.hideAddress = false,
    this.hasWhatsapp = false,
    this.wantsAdvertising = false,
    this.logoUrl = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        reviews = reviews ?? [],
        images = images ?? [];

  bool get isUnlimitedRadius => serviceRadius != null && serviceRadius! < 0;
  bool get isDelivery => serviceRadius != null && serviceRadius! >= 0;
  bool get isFixedLocation => serviceRadius == null;

  void addView() {
    viewCount++;
  }

  void addReview(CompanyReview review) {
    reviews.add(review);
    reviewCount = reviews.length;
    averageRating = reviews.map((r) => r.rating).fold(0.0, (a, b) => a + b) / reviewCount;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userEmail': userEmail,
    'name': name,
    'description': description,
    'address': address,
    'phoneNumber': phoneNumber,
    'email': email,
    'website': website,
    'categories': categories,
    'latitude': latitude,
    'longitude': longitude,
    'serviceRadius': serviceRadius,
    'priceLevel': priceLevel,
    'createdAt': createdAt.toIso8601String(),
    'viewCount': viewCount,
    'averageRating': averageRating,
    'reviewCount': reviewCount,
    'reviews': reviews.map((r) => r.toJson()).toList(),
    'images': images,
    'hideAddress': hideAddress,
    'hasWhatsapp': hasWhatsapp,
    'wantsAdvertising': wantsAdvertising,
    'logoUrl': logoUrl,
  };

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'] as String,
    userEmail: json['userEmail'] as String? ?? '',
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    address: json['address'] as String,
    phoneNumber: json['phoneNumber'] as String? ?? '',
    email: json['email'] as String? ?? '',
    website: json['website'] as String?,
    categories: (json['categories'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        (json['category'] != null ? [json['category'] as String] : ['Sonstiges']),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    serviceRadius: (json['serviceRadius'] as num?)?.toDouble(),
    priceLevel: json['priceLevel'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    viewCount: json['viewCount'] as int? ?? 0,
    averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
    reviewCount: json['reviewCount'] as int? ?? 0,
    reviews: (json['reviews'] as List<dynamic>?)
        ?.map((e) => CompanyReview.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    images: (json['images'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [],
    hideAddress: json['hideAddress'] as bool? ?? false,
    hasWhatsapp: json['hasWhatsapp'] as bool? ?? false,
    wantsAdvertising: json['wantsAdvertising'] as bool? ?? false,
    logoUrl: json['logoUrl'] as String? ?? '',
  );
}

class CompanyReview {
  final String id;
  final String companyId;
  final String userName;
  final double rating;
  final String? comment;
  final DateTime timestamp;

  CompanyReview({
    required this.id,
    required this.companyId,
    required this.userName,
    required this.rating,
    this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'companyId': companyId,
    'userName': userName,
    'rating': rating,
    'comment': comment,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CompanyReview.fromJson(Map<String, dynamic> json) => CompanyReview(
    id: json['id'] as String,
    companyId: json['companyId'] as String,
    userName: json['userName'] as String,
    rating: (json['rating'] as num).toDouble(),
    comment: json['comment'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
