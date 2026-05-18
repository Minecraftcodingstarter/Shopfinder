import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  double _defaultSearchRadius = 5000;

  double get defaultSearchRadius => _defaultSearchRadius;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultSearchRadius = prefs.getDouble('defaultSearchRadius') ?? 5000;
    notifyListeners();
  }

  Future<void> setDefaultSearchRadius(double value) async {
    if (_defaultSearchRadius == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('defaultSearchRadius', value);
    _defaultSearchRadius = value;
    notifyListeners();
  }

  void resetToDefaults() {
    _defaultSearchRadius = 5000;
    loadSettings();
  }
}
