import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
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

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;
  String? _googleClientId;
  bool _googleSignInAvailable = false;

  AuthUser? _currentUser;
  firebase_auth.User? get firebaseUser => _auth.currentUser;

  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isEmailVerified => _currentUser?.isVerified ?? false;
  bool get isGoogleSignInAvailable => _googleSignInAvailable;

  Future<void> initialize({String? googleClientId}) async {
    if (googleClientId != null) _googleClientId = googleClientId;
    final user = _auth.currentUser;
    if (user != null) {
      _currentUser = _fromFirebaseUser(user);
    }
    _tryInitGoogleSignIn();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _currentUser = _fromFirebaseUser(user);
      } else {
        _currentUser = null;
      }
    });
  }

  void _tryInitGoogleSignIn() {
    if (_googleSignIn != null) return;
    try {
      if (_googleClientId != null) {
        _googleSignIn = GoogleSignIn(clientId: _googleClientId);
      } else {
        _googleSignIn = GoogleSignIn();
      }
      _googleSignInAvailable = true;
    } catch (_) {
      _googleSignIn = null;
      _googleSignInAvailable = false;
    }
  }

  AuthUser _fromFirebaseUser(firebase_auth.User user) {
    return AuthUser(
      email: user.email ?? '',
      name: user.displayName ?? '',
      isVerified: user.emailVerified || user.phoneNumber != null,
      uid: user.uid,
      phoneNumber: user.phoneNumber ?? '',
    );
  }

  Future<String?> register(String email, String password, {String name = ''}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Bitte geben Sie eine E-Mail-Adresse ein.';
    if (!_isValidEmail(cleanEmail)) return 'Ungültiges E-Mail-Format.';
    if (password.length < 6) return 'Passwort muss mindestens 6 Zeichen lang sein.';

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      if (name.isNotEmpty) {
        await cred.user?.updateDisplayName(name);
      }
      await cred.user?.sendEmailVerification();
      _currentUser = _fromFirebaseUser(cred.user!);
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Diese E-Mail ist bereits registriert.';
        case 'weak-password':
          return 'Das Passwort ist zu schwach.';
        case 'invalid-email':
          return 'Ungültiges E-Mail-Format.';
        case 'operation-not-allowed':
          return 'E-Mail/Passwort-Anmeldung ist in der Firebase Console nicht aktiviert. '
              'Gehe zu Authentication → Sign-in method → E-Mail/Passwort → Aktivieren.';
        default:
          return 'Registrierung fehlgeschlagen: ${e.message}';
      }
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Bitte geben Sie Ihre E-Mail-Adresse ein.';
    if (!_isValidEmail(cleanEmail)) return 'Ungültiges E-Mail-Format.';

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      if (!cred.user!.emailVerified) {
        _currentUser = _fromFirebaseUser(cred.user!);
        return 'Bitte bestätigen Sie zuerst Ihre E-Mail-Adresse. Wir haben einen Bestätigungslink an $cleanEmail gesendet.';
      }

      _currentUser = _fromFirebaseUser(cred.user!);
      await syncWithBackend();
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Kein Konto mit dieser E-Mail gefunden.';
        case 'wrong-password':
          return 'Falsches Passwort.';
        case 'invalid-credential':
          return 'Falsche E-Mail oder Passwort.';
        case 'invalid-email':
          return 'Ungültiges E-Mail-Format.';
        case 'too-many-requests':
          return 'Zu viele Fehlversuche. Bitte versuchen Sie es später erneut.';
        default:
          return 'Anmeldung fehlgeschlagen: ${e.message}';
      }
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!_googleSignInAvailable || _googleSignIn == null) {
      return 'Google Sign-In ist nicht verfügbar. Web Client ID fehlt. Siehe web/index.html oder firebase_config.dart.';
    }

    try {
      final googleAccount = await _googleSignIn!.signIn();
      if (googleAccount == null) return 'Google Sign-In abgebrochen.';

      final googleAuth = await googleAccount.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken ?? googleAuth.accessToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      _currentUser = _fromFirebaseUser(cred.user!);
      await syncWithBackend();
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return 'Ein Konto existiert bereits mit dieser E-Mail über einen anderen Anbieter.';
      }
      if (e.code == 'invalid-credential') {
        return 'Google-Anmeldung fehlgeschlagen. Prüfe ob Firebase Google Auth aktiviert ist.';
      }
      return 'Google Sign-In fehlgeschlagen (${e.code}): ${e.message}';
    } catch (e) {
      return 'Google Sign-In fehlgeschlagen: $e';
    }
  }

  String? _verificationId;
  bool _autoSignedIn = false;

  void sendPhoneCode({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String error) onError,
    required void Function() onAutoVerified,
  }) {
    _autoSignedIn = false;
    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
        _currentUser = _fromFirebaseUser(_auth.currentUser!);
        await syncWithBackend();
        _autoSignedIn = true;
        onAutoVerified();
      },
      verificationFailed: (e) {
        onError(e.message ?? 'Verifikation fehlgeschlagen');
      },
      codeSent: (verificationId, forceResendingToken) {
        _verificationId = verificationId;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<String?> verifyPhoneCode(String smsCode) async {
    if (_verificationId == null) {
      return 'Keine Verifikations-ID vorhanden. Bitte senden Sie zuerst einen Code.';
    }
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      _currentUser = _fromFirebaseUser(_auth.currentUser!);
      await syncWithBackend();
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-verification-code':
          return 'Falscher Bestätigungscode.';
        case 'session-expired':
          return 'Die Sitzung ist abgelaufen. Bitte senden Sie einen neuen Code.';
        default:
          return 'Fehler: ${e.message}';
      }
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  void updateFromBackend(Map<String, dynamic> userData) {
    _currentUser = AuthUser(
      email: userData['email'] as String? ?? _currentUser?.email ?? '',
      name: userData['displayName'] as String? ?? _currentUser?.name ?? '',
      isVerified: true,
      uid: _currentUser?.uid ?? '',
      phoneNumber: userData['phoneNumber'] as String? ?? _currentUser?.phoneNumber ?? '',
    );
  }

  Future<String?> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Bitte geben Sie Ihre E-Mail-Adresse ein.';
    if (!_isValidEmail(cleanEmail)) return 'Ungültiges E-Mail-Format.';

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Kein Konto mit dieser E-Mail gefunden.';
        case 'invalid-email':
          return 'Ungültiges E-Mail-Format.';
        default:
          return 'Fehler: ${e.message}';
      }
    } catch (e) {
      return 'Ein Fehler ist aufgetreten: $e';
    }
  }

  Future<bool> verifyEmail() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    if (user.emailVerified) {
      _currentUser = _fromFirebaseUser(user);
      return true;
    }
    return false;
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> syncWithBackend() async {
    try {
      final userData = await BackendService().verifyFirebaseToken();
      if (userData != null) {
        updateFromBackend(userData);
      }
    } catch (e) {
      debugPrint('Backend sync error (non-fatal): $e');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
    } catch (_) {}
    _currentUser = null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}
