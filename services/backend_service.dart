// lib/services/backend_service.dart
//
// DIREKT-VERSION: Kein Node-Server mehr. Alte /api/...-Aufrufe werden
// hier abgefangen und direkt auf Supabase umgeleitet.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  SupabaseClient get _db => Supabase.instance.client;

  bool _initialized = false;
  Future<void> initialize({String? baseUrl}) async {
    _initialized = true;
  }

  bool get isInitialized => _initialized;
  String? get baseUrl => null;
  void setBaseUrl(String url) {}
  bool get isAuthenticated => _db.auth.currentSession != null;
  String? get _uid => _db.auth.currentUser?.id;

  Future<void> clearToken() async {}

  Future<Map<dynamic, dynamic>?> verifySupabaseToken() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _db
          .from('users')
          .select('email, display_name, phone_number')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        return {
          'email': user.email,
          'displayName': user.userMetadata?['display_name'],
          'phoneNumber': user.phone,
        };
      }
      return {
        'email': row['email'],
        'displayName': row['display_name'],
        'phoneNumber': row['phone_number'],
      };
    } catch (e) {
      debugPrint('verifySupabaseToken (direct) error: $e');
      return {
        'email': user.email,
        'displayName': user.userMetadata?['display_name'],
      };
    }
  }

  // --- Kompatibilitaets-Router: alte /api/...-Pfade -> Supabase ---

    Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true, // wird ignoriert, Supabase regelt Auth selbst
  }) async {

    body ??= {};

    if (path == '/api/proxy/gemini') {
      throw ApiException(
        501,
        'Gemini lief ueber den Node-Server. Ohne Server bitte eine Supabase '
        'Edge Function "gemini" anlegen.',
      );
    }

    if (path == '/api/services') {
      final uid = _requireUid();
      final insert = {
        'provider_id': uid,
        'title': body['title'],
        'description': body['description'],
        'category_id': body['category_id'] ?? body['categoryId'],
        'price': body['price'],
        'price_unit': body['price_unit'] ?? body['priceUnit'] ?? '\u20AC',
        'location': body['location'],
        'latitude': body['latitude'],
        'longitude': body['longitude'],
      }..removeWhere((_, v) => v == null);
      final row = await _db.from('services').insert(insert).select().single();
      return Map<String, dynamic>.from(row);
    }

    final reviewMatch =
        RegExp(r'^/api/services/([^/]+)/reviews$').firstMatch(path);
    if (reviewMatch != null) {
      final uid = _requireUid();
      final row = await _db
          .from('service_reviews')
          .insert({
            'user_id': uid,
            'service_id': reviewMatch.group(1),
            'rating': body['rating'],
            'comment': body['comment'],
          })
          .select()
          .single();
      return Map<String, dynamic>.from(row);
    }

    final reportMatch =
        RegExp(r'^/api/reports/companies/([^/]+)/report$').firstMatch(path);
    if (reportMatch != null) {
      final row = await _db
          .from('company_reports')
          .insert({
            'company_id': reportMatch.group(1),
            'reporter_email': body['reporter_email'] ??
                body['reporterEmail'] ??
                _db.auth.currentUser?.email ??
                '',
            'reason': body['reason'],
          })
          .select()
          .single();
      return Map<String, dynamic>.from(row);
    }

    throw ApiException(404, 'Unbekannter POST-Pfad: $path');
  }

    Future<void> delete(String path, {bool auth = true}) async {
    final m = RegExp(r'^/api/services/([^/]+)$').firstMatch(path);
    if (m != null) {
      _requireUid();
      await _db.from('services').delete().eq('id', m.group(1)!);
      return;
    }
    throw ApiException(404, 'Unbekannter DELETE-Pfad: $path');
  }

    Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? queryParams,
    bool auth = true, // wird ignoriert
  }) async {
    query ??= queryParams ?? {};


    final reviewMatch =
        RegExp(r'^/api/services/([^/]+)/reviews$').firstMatch(path);
    if (reviewMatch != null) {
      final rows = await _db
          .from('service_reviews')
          .select()
          .eq('service_id', reviewMatch.group(1)!)
          .order('created_at', ascending: false);
      return List<dynamic>.from(rows);
    }

    if (path == '/api/services') {
      var q = _db.from('services').select();
      if (query['category_id'] != null) {
        q = q.eq('category_id', query['category_id']);
      }
      if (query['provider_id'] != null) {
        q = q.eq('provider_id', query['provider_id']);
      }
      final rows = await q.order('created_at', ascending: false);
      return List<dynamic>.from(rows);
    }

    throw ApiException(404, 'Unbekannter GET-Pfad: $path');
  }

  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw ApiException(401, 'Nicht eingeloggt.');
    return uid;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
