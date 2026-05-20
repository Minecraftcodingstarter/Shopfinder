import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  String? _baseUrl;
  String? _jwtToken;
  bool _initialized = false;
  final http.Client _client = http.Client();

  static const String _jwtKey = 'backend_jwt_token';

  Future<void> initialize({String? baseUrl}) async {
    if (_initialized) return;
    _baseUrl = baseUrl ?? 'http://localhost:3000';
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString(_jwtKey);
    _initialized = true;
  }

  bool get isAuthenticated => _jwtToken != null;

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  String? get baseUrl => _baseUrl;

  Future<void> _saveToken(String token) async {
    _jwtToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, token);
  }

  Future<void> clearToken() async {
    _jwtToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth && _jwtToken != null) {
      headers['Authorization'] = 'Bearer $_jwtToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>?> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body as Map<String, dynamic>?;
    }
    final message = body is Map ? (body['message'] ?? 'Unbekannter Fehler') : 'Unbekannter Fehler';
    debugPrint('Backend API error ${response.statusCode}: $message');
    throw ApiException(response.statusCode, message.toString());
  }

  Future<List<dynamic>?> _handleListResponse(http.Response response) async {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body as List<dynamic>?;
    }
    final message = body is Map ? (body['message'] ?? 'Unbekannter Fehler') : 'Unbekannter Fehler';
    debugPrint('Backend API error ${response.statusCode}: $message');
    throw ApiException(response.statusCode, message.toString());
  }

  String get _url => _baseUrl ?? 'http://localhost:3000';

  Future<Map<String, dynamic>?> get(String path, {Map<String, String>? queryParams, bool auth = true}) async {
    try {
      var uri = Uri.parse('$_url$path');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await _client.get(uri, headers: await _headers(auth: auth));
      final result = await _handleResponse(response);
      return result;
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Backend GET error: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getList(String path, {Map<String, String>? queryParams, bool auth = true}) async {
    try {
      var uri = Uri.parse('$_url$path');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await _client.get(uri, headers: await _headers(auth: auth));
      final result = await _handleListResponse(response);
      return result;
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Backend GET list error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final uri = Uri.parse('$_url$path');
      final response = await _client.post(
        uri,
        headers: await _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      final data = await _handleResponse(response);
      return data;
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Backend POST error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> put(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final uri = Uri.parse('$_url$path');
      final response = await _client.put(
        uri,
        headers: await _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      return await _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Backend PUT error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> delete(String path, {bool auth = true}) async {
    try {
      final uri = Uri.parse('$_url$path');
      final response = await _client.delete(uri, headers: await _headers(auth: auth));
      return await _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Backend DELETE error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyFirebaseToken() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) return null;

      final firebaseUser = AuthService().firebaseUser;
      if (firebaseUser == null) return null;

      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) return null;

      final result = await post('/api/auth/verify', body: {'idToken': idToken}, auth: false);
      if (result != null && result['token'] != null) {
        await _saveToken(result['token'] as String);
        return result['user'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Backend verify error: $e');
      return null;
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
