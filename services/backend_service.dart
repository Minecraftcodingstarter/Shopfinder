// services/backend_service.dart
//
// DIREKT-VERSION: Es gibt KEINEN Node-Server mehr.
// Diese Klasse bleibt nur als duenner Kompatibilitaets-Layer bestehen,
// damit bestehende Aufrufe (verifySupabaseToken, baseUrl, isAuthenticated)
// nicht brechen. Alle echten Daten laufen jetzt direkt ueber Supabase.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  bool _initialized = false;

  Future<void> initialize({String? baseUrl}) async {
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  /// Es gibt keinen externen Server mehr -> Storage liefert absolute URLs.
  String? get baseUrl => null;
  void setBaseUrl(String url) {}

  bool get isAuthenticated =>
      Supabase.instance.client.auth.currentSession != null;

  Future<void> clearToken() async {
    // Nichts mehr zu tun - Supabase verwaltet die Session selbst.
  }

  /// Frueher: Token gegen den Node-Server verifizieren.
  /// Jetzt: Wir lesen das Nutzerprofil direkt aus public.users.
  Future<Map<dynamic, dynamic>?> verifySupabaseToken() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await client
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
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
