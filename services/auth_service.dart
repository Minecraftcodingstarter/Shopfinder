import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_service.dart';

class AuthUser {
  final String email;
  final String name;
  final bool isVerified;
  final String uid;
  final String phoneNumber;

  AuthUser({
    this.email = '',
    this.name = '',
    this.isVerified = false,
    required this.uid,
    this.phoneNumber = '',
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _client = Supabase.instance.client;
  AuthUser? _currentUser;
  String? _pendingPhoneNumber;

  User? get supabaseUser => _client.auth.currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isEmailVerified => _currentUser?.isVerified ?? false;

  Future<void> initialize() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      _currentUser = _fromSupabaseUser(session.user);
    }

    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _currentUser = _fromSupabaseUser(session.user);
      } else {
        _currentUser = null;
      }
    });
  }

  AuthUser _fromSupabaseUser(User user) {
    return AuthUser(
      email: user.email ?? '',
      name: user.userMetadata?['display_name'] as String? ?? '',
      isVerified: user.emailConfirmedAt != null,
      uid: user.id,
      phoneNumber: user.phone ?? '',
    );
  }

  /// Registrierung mit E-Mail & Passwort
  Future<String?> register(String email, String password, {String name = ''}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Bitte geben Sie eine E-Mail-Adresse ein.';
    if (!_isValidEmail(cleanEmail)) return 'Ungültiges E-Mail-Format.';
    if (password.length < 6) return 'Passwort muss mindestens 6 Zeichen lang sein.';

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'display_name': name},
      );

      if (response.user != null) {
        _currentUser = _fromSupabaseUser(response.user!);
        return null; // Erfolg
      }
      return 'Registrierung fehlgeschlagen.';
    } on AuthException catch (e) {
      if (e.message.contains('already registered')) {
        return 'Diese E-Mail ist bereits registriert.';
      }
      return 'Registrierung fehlgeschlagen: ${e.message}';
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  /// Login mit E-Mail & Passwort
  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Bitte geben Sie Ihre E-Mail-Adresse ein.';
    if (!_isValidEmail(cleanEmail)) return 'Ungültiges E-Mail-Format.';

    try {
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (response.user == null) return 'Anmeldung fehlgeschlagen.';

      if (response.user!.emailConfirmedAt == null) {
        _currentUser = _fromSupabaseUser(response.user!);
        return 'Bitte bestätigen Sie zuerst Ihre E-Mail-Adresse. Wir haben einen Bestätigungslink an $cleanEmail gesendet.';
      }

      _currentUser = _fromSupabaseUser(response.user!);
      await syncWithBackend();
      return null;
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return 'Falsche E-Mail oder Passwort.';
      }
      if (e.message.contains('Email not confirmed')) {
        return 'Bitte bestätigen Sie Ihre E-Mail-Adresse.';
      }
      return 'Anmeldung fehlgeschlagen: ${e.message}';
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  /// Google Sign-In
  Future<String?> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.shopfinder://login-callback/',
      );
      return null;
    } on AuthException catch (e) {
      return 'Google Sign-In fehlgeschlagen: ${e.message}';
    } catch (e) {
      return 'Google Sign-In fehlgeschlagen: $e';
    }
  }

  /// Bestätigungs-E-Mail erneut senden
  Future<void> sendVerificationEmail() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      await _client.auth.resend(email: user.email, type: OtpType.signup);
    }
  }

  /// Google Sign-In Verfügbarkeit (mit Supabase OAuth immer verfügbar)
  bool get isGoogleSignInAvailable => true;

  /// SMS-Code senden (Phone Auth)
  Future<void> sendPhoneCode({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String error) onError,
    required void Function() onAutoVerified,
  }) async {
    _pendingPhoneNumber = phoneNumber;
    try {
      await _client.auth.signInWithOtp(phone: phoneNumber);
      onCodeSent();
    } on AuthException catch (e) {
      onError(e.message);
    } catch (e) {
      onError('Ein Fehler ist aufgetreten: $e');
    }
  }

  /// SMS-Code verifizieren
  Future<String?> verifyPhoneCode(String code) async {
    final phone = _pendingPhoneNumber;
    if (phone == null || phone.isEmpty) {
      return 'Keine Telefonnummer vorhanden.';
    }
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: code,
        type: OtpType.sms,
      );
      if (response.session != null) {
        _currentUser = _fromSupabaseUser(response.session!.user);
        await syncWithBackend();
        return null;
      }
      return 'Verifikation fehlgeschlagen.';
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid')) {
        return 'Falscher Bestätigungscode.';
      }
      if (e.message.toLowerCase().contains('expired')) {
        return 'Der Code ist abgelaufen. Bitte senden Sie einen neuen Code.';
      }
      return 'Fehler: ${e.message}';
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  /// Passwort zurücksetzen
  Future<String?> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Bitte geben Sie Ihre E-Mail-Adresse ein.';
    if (!_isValidEmail(cleanEmail)) return 'Ungültiges E-Mail-Format.';

    try {
      await _client.auth.resetPasswordForEmail(cleanEmail);
      return null;
    } on AuthException catch (e) {
      return 'Fehler: ${e.message}';
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  /// Verifizierungsstatus prüfen
  Future<bool> verifyEmail() async {
    try {
      await _client.auth.refreshSession();
    } catch (_) {
      return false;
    }
    final user = _client.auth.currentUser;
    if (user != null && user.emailConfirmedAt != null) {
      _currentUser = _fromSupabaseUser(user);
      return true;
    }
    return false;
  }

  void updateFromSupabaseSession(Session session) {
    _currentUser = _fromSupabaseUser(session.user);
  }

  void updateFromBackend(Map<dynamic, dynamic> userData) {
    _currentUser = AuthUser(
      email: userData['email'] as String? ?? _currentUser?.email ?? '',
      name: userData['displayName'] as String? ?? _currentUser?.name ?? '',
      isVerified: true,
      uid: _currentUser?.uid ?? '',
      phoneNumber: userData['phoneNumber'] as String? ?? _currentUser?.phoneNumber ?? '',
    );
  }

  Future<void> syncWithBackend() async {
    try {
      final userData = await BackendService().verifySupabaseToken();
      if (userData != null) {
        updateFromBackend(userData);
      }
    } catch (e) {
      debugPrint('Backend sync error (non-fatal): $e');
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}