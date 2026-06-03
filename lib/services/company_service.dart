// services/company_service.dart
//
// DIREKT-VERSION: Diese Datei spricht NICHT mehr mit dem alten Node-Server,
// sondern direkt mit Supabase (Postgres-Tabellen + Supabase Storage).
// Der BackendService / die /uploads-Logik wird hier nicht mehr verwendet.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company_model.dart';
import 'auth_service.dart';

class CompanyService {
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  SupabaseClient get _db => Supabase.instance.client;
  static const String _bucket = 'company-images';

  bool _initialized = false;
  List<Company> _companies = [];
  static const String _storageKey = 'cached_companies';

  // Mapping category_id (int) <-> name, damit wir mit String-Kategorien weiterarbeiten können.
  final Map<int, String> _categoryById = {};
  final Map<String, int> _categoryByName = {};

  /// Bilder, die schon volle URLs sind, bleiben unverändert.
  /// (Supabase Storage liefert immer absolute https-URLs.)
  static String resolveImageUrl(String url) => url;

  // ---------------------------------------------------------------------------
  // Initialisierung
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadCategories();
    await fetchFromBackend();
    if (_companies.isEmpty) {
      await _loadFromCache();
    }
    _initialized = true;
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _db.from('categories').select('id, name');
      _categoryById.clear();
      _categoryByName.clear();
      for (final row in (rows as List)) {
        final id = row['id'] as int;
        final name = row['name'] as String;
        _categoryById[id] = name;
        _categoryByName[name] = id;
      }
    } catch (e) {
      debugPrint('CompanyService category load error: $e');
    }
  }

  int? _categoryIdFor(List<String> categories) {
    if (categories.isEmpty) return null;
    return _categoryByName[categories.first];
  }

  // ---------------------------------------------------------------------------
  // Lokaler Cache (offline fallback) - identisch zu vorher
  // ---------------------------------------------------------------------------
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = _companies.map((c) {
        final json = c.toJson();
        json['images'] = (json['images'] as List<dynamic>?)
                ?.where((img) => img is String && !img.startsWith('data:image'))
                .toList() ??
            [];
        if (json['logoUrl'] is String &&
            (json['logoUrl'] as String).startsWith('data:image')) {
          json['logoUrl'] = '';
        }
        return json;
      }).toList();
      await prefs.setString(_storageKey, jsonEncode(clean));
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
      _companies = list.map((e) => Company.fromJson(e as Map<String, dynamic>)).toList();
      debugPrint('Loaded ${_companies.length} companies from cache');
    } catch (e) {
      debugPrint('CompanyService cache load error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Getter
  // ---------------------------------------------------------------------------
  List<Company> get companies => List.unmodifiable(_companies);

  List<Company> get myCompanies {
    final user = AuthService().currentUser;
    if (user == null) return [];
    return _companies.where((c) => c.ownerId == user.uid || c.userEmail == user.email).toList();
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

  // ---------------------------------------------------------------------------
  // Bild-Upload zu Supabase Storage
  // ---------------------------------------------------------------------------

  /// Lädt eine einzelne Bilddatei (als Bytes) in den Storage hoch und gibt
  /// die oeffentliche URL zurueck.
  Future<String> uploadImageBytes(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = _db.auth.currentUser?.id ?? 'anon';
    final fileName =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.$ext';
    await _db.storage.from(_bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );
    return _db.storage.from(_bucket).getPublicUrl(fileName);
  }

  /// Akzeptiert eine Liste von "Bildern" (entweder bereits https-URLs ODER
  /// data:-URLs / base64) und gibt eine Liste reiner Storage-URLs zurueck.
  /// Bereits hochgeladene https-Bilder werden unveraendert durchgereicht.
  Future<List<String>> _ensureUploaded(List<String> images) async {
    final result = <String>[];
    for (final img in images) {
      if (img.isEmpty) continue;
      if (img.startsWith('http://') || img.startsWith('https://')) {
        result.add(img);
        continue;
      }
      if (img.startsWith('data:image')) {
        try {
          final parts = img.split(',');
          final meta = parts.first; // z.B. data:image/png;base64
          final b64 = parts.length > 1 ? parts[1] : '';
          final ext = meta.contains('png')
              ? 'png'
              : meta.contains('webp')
                  ? 'webp'
                  : 'jpg';
          final bytes = base64Decode(b64);
          final url = await uploadImageBytes(bytes, ext: ext);
          result.add(url);
        } catch (e) {
          debugPrint('Image upload error: $e');
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // CRUD - direkt gegen Supabase
  // ---------------------------------------------------------------------------
  Future<void> addCompany(Company company) async {
    try {
      final ownerId = _db.auth.currentUser?.id;
      if (ownerId == null) throw 'Nicht eingeloggt';

      final uploadedImages = await _ensureUploaded(company.images);
      final logoUrls = await _ensureUploaded(
          company.logoUrl.isNotEmpty ? [company.logoUrl] : []);
      final logoUrl = logoUrls.isNotEmpty ? logoUrls.first : '';

      final inserted = await _db
          .from('companies')
          .insert({
            'owner_id': ownerId,
            'name': company.name,
            'description': company.description,
            'address': company.address,
            'phone_number': company.phoneNumber,
            'email': company.email,
            'website': company.website,
            'category_id': _categoryIdFor(company.categories),
            'latitude': company.latitude,
            'longitude': company.longitude,
            'service_radius_km': company.serviceRadius,
            'price_level': company.priceLevel,
            'hide_address': company.hideAddress,
            'has_whatsapp': company.hasWhatsapp,
            'wants_advertising': company.wantsAdvertising,
            'logo_url': logoUrl,
          })
          .select()
          .single();

      final newId = inserted['id'] as String;

      // Many-to-Many Kategorien
      await _syncCompanyCategories(newId, company.categories);
      // Bilder in company_images
      await _replaceCompanyImages(newId, uploadedImages);

      _companies.add(Company(
        id: newId,
        userEmail: company.userEmail,
        ownerId: ownerId,
        name: company.name,
        description: company.description,
        address: company.address,
        phoneNumber: company.phoneNumber,
        email: company.email,
        website: company.website,
        categories: company.categories,
        latitude: company.latitude,
        longitude: company.longitude,
        serviceRadius: company.serviceRadius,
        priceLevel: company.priceLevel,
        createdAt:
            DateTime.tryParse(inserted['created_at'] as String? ?? '') ??
                DateTime.now(),
        viewCount: company.viewCount,
        averageRating: company.averageRating,
        reviewCount: company.reviewCount,
        images: uploadedImages,
        hideAddress: company.hideAddress,
        hasWhatsapp: company.hasWhatsapp,
        wantsAdvertising: company.wantsAdvertising,
        logoUrl: logoUrl,
      ));
    } catch (e) {
      debugPrint('CompanyService add error: $e');
      _companies.add(company);
    }
    await _saveToCache();
  }

  Future<void> updateCompany(Company updated) async {
    try {
      final uploadedImages = await _ensureUploaded(updated.images);
      final logoUrls = await _ensureUploaded(
          updated.logoUrl.isNotEmpty ? [updated.logoUrl] : []);
      final logoUrl = logoUrls.isNotEmpty ? logoUrls.first : updated.logoUrl;

      await _db.from('companies').update({
        'name': updated.name,
        'description': updated.description,
        'address': updated.address,
        'phone_number': updated.phoneNumber,
        'email': updated.email,
        'website': updated.website,
        'category_id': _categoryIdFor(updated.categories),
        'latitude': updated.latitude,
        'longitude': updated.longitude,
        'service_radius_km': updated.serviceRadius,
        'price_level': updated.priceLevel,
        'hide_address': updated.hideAddress,
        'has_whatsapp': updated.hasWhatsapp,
        'wants_advertising': updated.wantsAdvertising,
        'logo_url': logoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', updated.id);

      await _syncCompanyCategories(updated.id, updated.categories);
      await _replaceCompanyImages(updated.id, uploadedImages);

      final index = _companies.indexWhere((c) => c.id == updated.id);
      if (index != -1) {
        final existing = _companies[index];
        _companies[index] = Company(
          id: updated.id,
          userEmail: existing.userEmail,
          ownerId: existing.ownerId,
          name: updated.name,
          description: updated.description,
          address: updated.address,
          phoneNumber: updated.phoneNumber,
          email: updated.email,
          website: updated.website,
          categories: updated.categories,
          latitude: updated.latitude,
          longitude: updated.longitude,
          serviceRadius: updated.serviceRadius,
          priceLevel: updated.priceLevel,
          createdAt: existing.createdAt,
          viewCount: updated.viewCount,
          averageRating: updated.averageRating,
          reviewCount: updated.reviewCount,
          reviews: existing.reviews,
          images: uploadedImages,
          hideAddress: updated.hideAddress,
          hasWhatsapp: updated.hasWhatsapp,
          wantsAdvertising: updated.wantsAdvertising,
          logoUrl: logoUrl,
        );
      }
    } catch (e) {
      debugPrint('CompanyService update error: $e');
      final index = _companies.indexWhere((c) => c.id == updated.id);
      if (index != -1) _companies[index] = updated;
    }
    await _saveToCache();
  }

  Future<void> deleteCompany(String id) async {
    try {
      // company_images & company_categories werden via ON DELETE CASCADE entfernt
      await _db.from('companies').delete().eq('id', id);
    } catch (e) {
      debugPrint('CompanyService delete error: $e');
    }
    _companies.removeWhere((c) => c.id == id);
    await _saveToCache();
  }

  // ---------------------------------------------------------------------------
  // Hilfsfunktionen: Kategorien & Bilder
  // ---------------------------------------------------------------------------
  Future<void> _syncCompanyCategories(
      String companyId, List<String> categories) async {
    try {
      await _db.from('company_categories').delete().eq('company_id', companyId);
      final rows = <Map<String, dynamic>>[];
      for (final name in categories) {
        final catId = _categoryByName[name];
        if (catId != null) {
          rows.add({'company_id': companyId, 'category_id': catId});
        }
      }
      if (rows.isNotEmpty) {
        await _db.from('company_categories').insert(rows);
      }
    } catch (e) {
      debugPrint('syncCompanyCategories error: $e');
    }
  }

  Future<void> _replaceCompanyImages(
      String companyId, List<String> imageUrls) async {
    try {
      await _db.from('company_images').delete().eq('company_id', companyId);
      if (imageUrls.isEmpty) return;
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < imageUrls.length; i++) {
        rows.add({
          'company_id': companyId,
          'image_url': imageUrls[i],
          'sort_order': i,
        });
      }
      await _db.from('company_images').insert(rows);
    } catch (e) {
      debugPrint('replaceCompanyImages error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Lesen
  // ---------------------------------------------------------------------------
  Future<Company?> fetchCompanyById(String id) async {
    try {
      final row = await _db.from('companies').select('''
            *,
            company_images ( image_url, sort_order ),
            company_categories ( category_id ),
            reviews ( id, user_id, rating, comment, created_at )
          ''').eq('id', id).single();
      final company = _rowToCompany(row);
      final index = _companies.indexWhere((c) => c.id == id);
      if (index != -1) {
        _companies[index] = company;
      } else {
        _companies.add(company);
      }
      return company;
    } catch (e) {
      debugPrint('fetchCompanyById error: $e');
      return null;
    }
  }

  Future<void> recordView(String companyId) async {
    try {
      // atomisch hochzaehlen via RPC (siehe SQL) oder fallback lokal
      await _db.rpc('increment_company_view', params: {'cid': companyId});
    } catch (_) {}
    final company = getCompany(companyId);
    company?.addView();
  }

  Future<void> addReview(String companyId, CompanyReview review) async {
    final company = getCompany(companyId);
    if (company == null) return;
    try {
      await _db.from('reviews').insert({
        'user_id': _db.auth.currentUser?.id,
        'company_id': companyId,
        'rating': review.rating.round(),
        'comment': review.comment ?? '',
      });
    } catch (e) {
      debugPrint('addReview error: $e');
    }
    company.addReview(review);
  }

  Future<void> updateReview(String companyId, String reviewId,
      {double? rating, String? comment}) async {
    final body = <String, dynamic>{};
    if (rating != null) body['rating'] = rating.round();
    if (comment != null) body['comment'] = comment;
    try {
      await _db.from('reviews').update(body).eq('id', reviewId);
    } catch (e) {
      debugPrint('updateReview error: $e');
    }
    final company = getCompany(companyId);
    if (company != null) {
      final idx = company.reviews.indexWhere((r) => r.id == reviewId);
      if (idx != -1) {
        final old = company.reviews[idx];
        company.reviews[idx] = CompanyReview(
          id: old.id,
          companyId: old.companyId,
          userId: old.userId,
          userName: old.userName,
          rating: rating ?? old.rating,
          comment: comment ?? old.comment,
          timestamp: old.timestamp,
        );
        company.recalculateRating();
      }
    }
  }

  List<CompanyReview> getReviewsForCompany(String companyId) {
    final company = getCompany(companyId);
    if (company == null) return [];
    final reviews = List<CompanyReview>.from(company.reviews);
    reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reviews;
  }

  double getAverageRating(String companyId) =>
      getCompany(companyId)?.averageRating ?? 0.0;

  int getReviewCount(String companyId) =>
      getCompany(companyId)?.reviewCount ?? 0;

  // ---------------------------------------------------------------------------
  // Liste laden (mit optionalem Filter)
  // ---------------------------------------------------------------------------
  Future<List<Company>> fetchFromBackend({
    double? lat,
    double? lng,
    double? radius,
    String? category,
    String? search,
  }) async {
    try {
      if (_categoryById.isEmpty) await _loadCategories();

      var query = _db.from('companies').select('''
            *,
            company_images ( image_url, sort_order ),
            company_categories ( category_id ),
            reviews ( id, user_id, rating, comment, created_at )
          ''');

      if (category != null && category != 'Alle') {
        final catId = _categoryByName[category];
        if (catId != null) query = query.eq('category_id', catId);
      }
      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }

      final rows = await query;
      final companies =
          (rows as List).map((r) => _rowToCompany(r as Map<String, dynamic>)).toList();

      // optionaler Radius-Filter clientseitig (einfacher Distanz-Check)
      var result = companies;
      if (lat != null && lng != null && radius != null) {
        result = companies.where((c) {
          if (c.latitude == null || c.longitude == null) return true;
          final d = _distanceKm(lat, lng, c.latitude!, c.longitude!);
          return d <= radius;
        }).toList();
      }

      // lokalen Bestand aktualisieren
      for (final company in companies) {
        final idx = _companies.indexWhere((c) => c.id == company.id);
        if (idx != -1) {
          _companies[idx] = company;
        } else {
          _companies.add(company);
        }
      }
      await _saveToCache();
      return result;
    } catch (e) {
      debugPrint('CompanyService fetchFromBackend error: $e');
      return [];
    }
  }

  /// Ruft alle Unternehmen des eingeloggten Users aus Supabase ab.
  Future<List<Company>> fetchMyCompanies() async {
    final user = _db.auth.currentUser;
    if (user == null) return [];
    try {
      if (_categoryById.isEmpty) await _loadCategories();
      final rows = await _db.from('companies').select('''
            *,
            company_images ( image_url, sort_order ),
            company_categories ( category_id ),
            reviews ( id, user_id, rating, comment, created_at )
          ''').eq('owner_id', user.id);
      final companies =
          (rows as List).map((r) => _rowToCompany(r as Map<String, dynamic>)).toList();
      for (final company in companies) {
        final idx = _companies.indexWhere((c) => c.id == company.id);
        if (idx != -1) {
          _companies[idx] = company;
        } else {
          _companies.add(company);
        }
      }
      await _saveToCache();
      return companies;
    } catch (e) {
      debugPrint('CompanyService fetchMyCompanies error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping DB-Row -> Company
  // ---------------------------------------------------------------------------
  Company _rowToCompany(Map<String, dynamic> json) {
    // Bilder sortiert
    final imgList = (json['company_images'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList()
      ..sort((a, b) =>
          (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0));
    final images =
        imgList.map((e) => e['image_url'].toString()).toList();

    // Kategorien (M2M + Haupt-Kategorie)
    final cats = <String>[];
    final mainCatId = json['category_id'] as int?;
    if (mainCatId != null && _categoryById.containsKey(mainCatId)) {
      cats.add(_categoryById[mainCatId]!);
    }
    for (final cc in (json['company_categories'] as List<dynamic>? ?? [])) {
      final id = (cc as Map<String, dynamic>)['category_id'] as int?;
      if (id != null && _categoryById.containsKey(id)) {
        final name = _categoryById[id]!;
        if (!cats.contains(name)) cats.add(name);
      }
    }
    if (cats.isEmpty) cats.add('Sonstiges');

    // Reviews
    final reviews = (json['reviews'] as List<dynamic>? ?? []).map((e) {
      final r = e as Map<String, dynamic>;
      return CompanyReview(
        id: r['id'].toString(),
        companyId: json['id'].toString(),
        userId: r['user_id']?.toString() ?? '',
        userName: '',
        rating: (r['rating'] as num).toDouble(),
        comment: r['comment'] as String?,
        timestamp:
            DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();

    final ownerId = json['owner_id'] as String? ?? '';
    final company = Company(
      id: json['id'].toString(),
      userEmail: '',
      ownerId: ownerId,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      email: json['email'] as String? ?? '',
      website: json['website'] as String?,
      categories: cats,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      serviceRadius: (json['service_radius_km'] as num?)?.toDouble(),
      priceLevel: json['price_level'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      viewCount: json['view_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? reviews.length,
      reviews: reviews,
      images: images,
      hideAddress: json['hide_address'] as bool? ?? false,
      hasWhatsapp: json['has_whatsapp'] as bool? ?? false,
      wantsAdvertising: json['wants_advertising'] as bool? ?? false,
      logoUrl: json['logo_url'] as String? ?? '',
    );
    if (reviews.isNotEmpty && (json['review_count'] == null)) {
      company.recalculateRating();
    }
    return company;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (dLat / 2) * (dLat / 2) +
        (dLon / 2) * (dLon / 2);
    // einfache Naeherung reicht fuer Filter; fuer Genauigkeit Haversine nutzen
    return r * (a < 0 ? 0 : a) * 111; // grobe Naeherung
  }

  double _deg2rad(double deg) => deg * 3.141592653589793 / 180.0;
}
