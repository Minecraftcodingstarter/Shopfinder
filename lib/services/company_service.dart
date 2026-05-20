import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_model.dart';
import 'auth_service.dart';
import 'backend_service.dart';

class CompanyService {
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  bool _initialized = false;
  List<Company> _companies = [];
  static const String _storageKey = 'cached_companies';

  static String resolveImageUrl(String url) {
    if (url.startsWith('data:') || url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final base = BackendService().baseUrl ?? 'http://localhost:3000';
    return '$base$url';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _loadFromBackend();
    if (_companies.isEmpty) {
      await _loadFromCache();
    }
    _initialized = true;
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = _companies.map((c) {
        final json = c.toJson();
        json['images'] = (json['images'] as List<dynamic>?)
            ?.where((img) => img is String && !img.startsWith('data:image'))
            .toList() ?? [];
        if (json['logoUrl'] is String && (json['logoUrl'] as String).startsWith('data:image')) {
          json['logoUrl'] = '';
        }
        return json;
      }).toList();
      final json = jsonEncode(clean);
      await prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('CompanyService cache save error: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json == null || json.isEmpty) return;
      final list = jsonDecode(json) as List<dynamic>;
      _companies = list.map((e) {
        final map = e as Map<String, dynamic>;
        if (map['images'] != null) {
          map['images'] = (map['images'] as List<dynamic>)
              .map((img) => resolveImageUrl(img.toString()))
              .toList();
        }
        if (map['logoUrl'] != null && map['logoUrl'].toString().isNotEmpty) {
          map['logoUrl'] = resolveImageUrl(map['logoUrl'].toString());
        }
        return Company.fromJson(map);
      }).toList();
      debugPrint('Loaded ${_companies.length} companies from cache');
    } catch (e) {
      debugPrint('CompanyService cache load error: $e');
    }
  }

  List<Company> get companies => List.unmodifiable(_companies);

  List<Company> get myCompanies {
    final user = AuthService().currentUser;
    if (user == null) return [];
    return _companies.where((c) => c.userEmail == user.email).toList();
  }

  List<Company> get allListedCompanies =>
      _companies.where((c) => c.userEmail.isNotEmpty).toList();

  Company? getCompany(String id) {
    try {
      return _companies.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCompany(Company company) async {
    try {
      final data = await BackendService().post('/api/companies', body: {
        'name': company.name,
        'description': company.description,
        'address': company.address,
        'phoneNumber': company.phoneNumber,
        'email': company.email,
        'website': company.website,
        'categories': company.categories,
        'latitude': company.latitude,
        'longitude': company.longitude,
        'serviceRadiusKm': company.serviceRadius,
        'priceLevel': company.priceLevel,
        'images': company.images,
        'logoUrl': company.logoUrl,
      });
      if (data != null) {
        _companies.add(Company(
          id: data['id'] as String,
          userEmail: company.userEmail,
          name: company.name,
          description: company.description,
          address: company.address,
          phoneNumber: company.phoneNumber,
          email: company.email,
          website: company.website,
          categories: (data['categories'] as List<dynamic>?)
              ?.map((e) => e.toString()).toList() ?? company.categories,
          latitude: company.latitude,
          longitude: company.longitude,
          serviceRadius: company.serviceRadius,
          priceLevel: company.priceLevel,
          createdAt: DateTime.parse(data['createdAt'] as String),
          viewCount: company.viewCount,
          averageRating: company.averageRating,
          reviewCount: company.reviewCount,
          images: (data['images'] as List<dynamic>?)
              ?.map((e) => resolveImageUrl(e.toString())).toList() ?? company.images,
          hideAddress: data['hideAddress'] as bool? ?? company.hideAddress,
          hasWhatsapp: data['hasWhatsapp'] as bool? ?? company.hasWhatsapp,
          wantsAdvertising: data['wantsAdvertising'] as bool? ?? company.wantsAdvertising,
          logoUrl: data['logoUrl'] != null ? resolveImageUrl(data['logoUrl'] as String) : company.logoUrl,
        ));
      } else {
        _companies.add(company);
      }
    } catch (e) {
      debugPrint('CompanyService add error: $e');
      _companies.add(company);
    }
    await _saveToCache();
  }

  Future<void> updateCompany(Company updated) async {
    try {
      final data = await BackendService().put('/api/companies/${updated.id}', body: {
        'name': updated.name,
        'description': updated.description,
        'address': updated.address,
        'phoneNumber': updated.phoneNumber,
        'email': updated.email,
        'website': updated.website,
        'categories': updated.categories,
        'latitude': updated.latitude,
        'longitude': updated.longitude,
        'serviceRadiusKm': updated.serviceRadius,
        'priceLevel': updated.priceLevel,
        'images': updated.images,
        'logoUrl': updated.logoUrl,
        'hideAddress': updated.hideAddress,
        'hasWhatsapp': updated.hasWhatsapp,
        'wantsAdvertising': updated.wantsAdvertising,
      });
      if (data != null) {
        final index = _companies.indexWhere((c) => c.id == updated.id);
        if (index != -1) {
          final existing = _companies[index];
          _companies[index] = Company(
            id: updated.id,
            userEmail: existing.userEmail,
            name: data['name'] as String? ?? updated.name,
            description: data['description'] as String? ?? updated.description,
            address: data['address'] as String? ?? updated.address,
            phoneNumber: data['phoneNumber'] as String? ?? updated.phoneNumber,
            email: data['email'] as String? ?? updated.email,
            website: data['website'] as String? ?? updated.website,
            categories: (data['categories'] as List<dynamic>?)
                ?.map((e) => e.toString()).toList() ?? updated.categories,
            latitude: updated.latitude,
            longitude: updated.longitude,
            serviceRadius: updated.serviceRadius,
            priceLevel: data['priceLevel'] as String? ?? updated.priceLevel,
            createdAt: existing.createdAt,
            viewCount: data['viewCount'] as int? ?? updated.viewCount,
            averageRating: (data['averageRating'] as num?)?.toDouble() ?? updated.averageRating,
            reviewCount: data['reviewCount'] as int? ?? updated.reviewCount,
            images: (data['images'] as List<dynamic>?)
                ?.map((e) => resolveImageUrl(e.toString())).toList() ?? updated.images,
            hideAddress: data['hideAddress'] as bool? ?? updated.hideAddress,
            hasWhatsapp: data['hasWhatsapp'] as bool? ?? updated.hasWhatsapp,
            wantsAdvertising: data['wantsAdvertising'] as bool? ?? updated.wantsAdvertising,
            logoUrl: data['logoUrl'] != null ? resolveImageUrl(data['logoUrl'] as String) : updated.logoUrl,
          );
        }
      } else {
        final index = _companies.indexWhere((c) => c.id == updated.id);
        if (index != -1) {
          _companies[index] = updated;
        }
      }
    } catch (e) {
      debugPrint('CompanyService update error: $e');
      final index = _companies.indexWhere((c) => c.id == updated.id);
      if (index != -1) {
        _companies[index] = updated;
      }
    }
    await _saveToCache();
  }

  Future<void> deleteCompany(String id) async {
    try {
      await BackendService().delete('/api/companies/$id');
    } catch (e) {
      debugPrint('CompanyService delete error: $e');
    }
    _companies.removeWhere((c) => c.id == id);
    await _saveToCache();
  }

  Future<Company?> fetchCompanyById(String id) async {
    try {
      final data = await BackendService().get('/api/companies/$id', auth: false);
      if (data == null) return null;
      if (data['images'] != null) {
        data['images'] = (data['images'] as List<dynamic>)
            .map((e) => resolveImageUrl(e.toString()))
            .toList();
      }
      if (data['logoUrl'] != null && data['logoUrl'].toString().isNotEmpty) {
        data['logoUrl'] = resolveImageUrl(data['logoUrl'].toString());
      }
      final company = Company.fromJson(data);
      final index = _companies.indexWhere((c) => c.id == id);
      if (index != -1) {
        _companies[index] = company;
      }
      return company;
    } catch (e) {
      debugPrint('fetchCompanyById error: $e');
      return null;
    }
  }

  Future<void> recordView(String companyId) async {
    try {
      await BackendService().post('/api/companies/$companyId/view');
    } catch (_) {}
    final company = getCompany(companyId);
    if (company != null) {
      company.addView();
    }
  }

  Future<void> addReview(String companyId, CompanyReview review) async {
    final company = getCompany(companyId);
    if (company == null) return;
    try {
      await BackendService().post(
        '/api/reviews/companies/$companyId/reviews',
        body: {
          'rating': review.rating,
          'comment': review.comment ?? '',
        },
      );
    } catch (e) {
      debugPrint('CompanyService addReview error: $e');
    }
    company.addReview(review);
  }

  List<CompanyReview> getReviewsForCompany(String companyId) {
    final company = getCompany(companyId);
    if (company == null) return [];
    final reviews = List<CompanyReview>.from(company.reviews);
    reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reviews;
  }

  double getAverageRating(String companyId) {
    final company = getCompany(companyId);
    return company?.averageRating ?? 0.0;
  }

  int getReviewCount(String companyId) {
    final company = getCompany(companyId);
    return company?.reviewCount ?? 0;
  }

  Future<List<Company>> fetchFromBackend({
    double? lat,
    double? lng,
    double? radius,
    String? category,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (lat != null) params['lat'] = lat.toString();
      if (lng != null) params['lng'] = lng.toString();
      if (radius != null) params['radius'] = radius.toString();
      if (category != null && category != 'Alle') params['category'] = category;
      if (search != null) params['search'] = search;

      final result = await BackendService().getList('/api/companies', queryParams: params.isNotEmpty ? params : null, auth: false);
      if (result == null) return [];

      final companies = result.map((json) => Company(
        id: json['id'] as String,
        userEmail: json['ownerName'] as String? ?? '',
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        address: json['address'] as String,
        phoneNumber: json['phoneNumber'] as String? ?? '',
        email: json['email'] as String? ?? '',
        website: json['website'] as String?,
        categories: (json['categories'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? ['Sonstiges'],
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        serviceRadius: (json['serviceRadius'] as num?)?.toDouble(),
        priceLevel: json['priceLevel'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        viewCount: json['viewCount'] as int? ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: json['reviewCount'] as int? ?? 0,
        images: (json['images'] as List<dynamic>?)
            ?.map((e) => resolveImageUrl(e.toString())).toList() ?? [],
        hideAddress: json['hideAddress'] as bool? ?? false,
        hasWhatsapp: json['hasWhatsapp'] as bool? ?? false,
        wantsAdvertising: json['wantsAdvertising'] as bool? ?? false,
        logoUrl: json['logoUrl'] != null ? resolveImageUrl(json['logoUrl'] as String) : '',
      )).toList();

      if (companies.isNotEmpty) {
        _companies = companies;
        await _saveToCache();
      }
      return companies;
    } catch (e) {
      debugPrint('CompanyService fetchFromBackend error: $e');
      return [];
    }
  }

  Future<void> _loadFromBackend() async {
    await fetchFromBackend();
  }
}
