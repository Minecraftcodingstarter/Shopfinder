import 'package:flutter/foundation.dart';

FirebaseOptions get firebaseOptions {
  return FirebaseOptions(
    apiKey: 'AIzaSyDgnD0vmSLj79EljwFm6l0MjMhWjibdrb4',
    authDomain: 'shopfinder-5f670.firebaseapp.com',
    projectId: 'shopfinder-5f670',
    storageBucket: 'shopfinder-5f670.firebasestorage.app',
    messagingSenderId: '777049269791',
    appId: '1:777049269791:web:bef2de6e622ebe0687d72a',
    measurementId: 'G-TBY545F08B',
  );
}

String? get googleWebClientId {
  if (!kIsWeb) return null;
  return '777049269791-jd2rivc2haokhbaiio0jtm84nbscs3mc.apps.googleusercontent.com';
}
