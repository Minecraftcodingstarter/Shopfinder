import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static String get googleMapsApiKey => dotenv.get('GOOGLE_MAPS_API_KEY');
  static String get geminiApiKey => dotenv.get('GEMINI_API_KEY');
  static String get grokApiKey => dotenv.get('GROK_API_KEY');
}
