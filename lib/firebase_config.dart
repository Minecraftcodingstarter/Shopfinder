import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

FirebaseOptions get firebaseOptions {
  return FirebaseOptions(
    apiKey: dotenv.get('FIREBASE_API_KEY'),
    authDomain: dotenv.get('FIREBASE_AUTH_DOMAIN'),
    projectId: dotenv.get('FIREBASE_PROJECT_ID'),
    storageBucket: dotenv.get('FIREBASE_STORAGE_BUCKET'),
    messagingSenderId: dotenv.get('FIREBASE_MESSAGING_SENDER_ID'),
    appId: dotenv.get('FIREBASE_APP_ID'),
    measurementId: dotenv.get('FIREBASE_MEASUREMENT_ID'),
  );
}

String? get googleWebClientId {
  if (!kIsWeb) return null;
  final id = dotenv.get('GOOGLE_WEB_CLIENT_ID');
  if (id.isEmpty || id == 'your_project_number-random_hash.apps.googleusercontent.com') return null;
  return id;
}
