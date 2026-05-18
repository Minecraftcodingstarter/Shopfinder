import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_model.dart';
import 'auth_service.dart';

class CompanyService {
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  static const String _storageKey = 'user_companies';
  bool _initialized = false;
  List<Company> _companies = [];

  Future<void> initialize() async {
    if (_initialized) return;
    await _loadCompanies();
    _initialized = true;
  }

  List<Company> get companies => List.unmodifiable(_companies);

  List<Company> get myCompanies {
    final user = AuthService().currentUser;
    if (user == null) return [];
    return _companies.where((c) => c.userEmail == user.email).toList();
  }

  List<Company> get allListedCompanies => _companies.where((c) => c.userEmail.isNotEmpty).toList();

  Company? getCompany(String id) {
    try {
      return _companies.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCompany(Company company) async {
    _companies.add(company);
    await _saveCompanies();
  }

  Future<void> updateCompany(Company updated) async {
    final index = _companies.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _companies[index] = updated;
      await _saveCompanies();
    }
  }

  Future<void> deleteCompany(String id) async {
    _companies.removeWhere((c) => c.id == id);
    await _saveCompanies();
  }

  void recordView(String companyId) {
    final company = getCompany(companyId);
    if (company != null) {
      company.addView();
      _saveCompanies();
    }
  }

  Future<void> addReview(String companyId, CompanyReview review) async {
    final company = getCompany(companyId);
    if (company != null) {
      company.addReview(review);
      await _saveCompanies();
    }
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

  Future<void> _loadCompanies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null && json.isNotEmpty) {
        final List<dynamic> data = jsonDecode(json);
        _companies = data.map((e) => Company.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('CompanyService load error: $e');
    }
  }

  Future<void> _saveCompanies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_companies.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('CompanyService save error: $e');
    }
  }
}
