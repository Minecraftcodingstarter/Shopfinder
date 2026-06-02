# Firebase Setup Anleitung

## 1. Firebase-Projekt erstellen

1. Öffne https://console.firebase.google.com/
2. Klicke auf **"Projekt erstellen"**
3. Gib als Projektnamen ein: `nearby-shop-finder` (oder einen beliebigen Namen)
4. **Google Analytics** kann deaktiviert werden (optional)
5. Klicke auf **"Projekt erstellen"** und warte ein paar Sekunden
6. Klicke auf **"Weiter"** (falls Analytics angeboten wird, überspringe es)

---

## 2. Android-App registrieren

Wenn dein Projekt erstellt ist, landest du auf der **Projekt-Übersichtsseite**.
Dort siehst du in der Mitte mehrere Platform-Icons: **Android, iOS, Web, Unity, Flutter**.

### Falls du die Icons **nicht** siehst:

1. Klicke links oben auf das **Zahnrad-Symbol** (⚙️) neben "Projektübersicht"
2. Wähle **"Projekteinstellungen"**
3. Scrolle runter zur Karte **"Deine Apps"**
4. Klicke auf den Button **"App hinzufügen"**
5. Es erscheinen die Platform-Auswahl-Icons

### Android-App hinzufügen:

1. Klicke auf das **Android-Icon** (das grüne Roboter-Symbol mit dem Namen "Android")
2. Ein Formular öffnet sich → **Android-Paketname** eingeben:
   ```
   com.example.nearby_shop_finder
   ```
3. **App-Spitzname** (optional): `ShopFinder`
4. **Debug-Signaturzertifikat SHA-1**: **Feld leer lassen** (wird später gebraucht, aber nicht jetzt)
5. Klicke auf **"App registrieren"**

### 2.1 google-services.json herunterladen

Nach dem Registrieren erscheint ein neuer Bildschirm:

1. Klicke auf den Button **"google-services.json herunterladen"**
2. Speichere die Datei unter:
   ```
   C:\Users\pixel\Desktop\buissness\nearby_shop_finder\android\app\google-services.json
   ```
   **⚠️ Wichtig:** Die Datei muss GENAU in `android/app/google-services.json` liegen, nicht in `android/` und nicht woanders.
3. Klicke auf **"Weiter"** (die nächsten zwei SDK-Schritte überspringen – Flutter erledigt das automatisch)
4. Klicze nochmal **"Weiter"** und dann auf **"Zur Konsole"**

### 2.2 Prüfen ob die Datei richtig liegt

Führe im Terminal aus:
```powershell
Test-Path "C:\Users\pixel\Desktop\buissness\nearby_shop_finder\android\app\google-services.json"
```
Die Ausgabe muss `True` sein – wenn `False`, liegt die Datei im falschen Ordner.

---

## 3. iOS-App registrieren (nur nötig für macOS/iOS-Entwicklung)

1. Gehe zu **Projekteinstellungen** (⚙️-Zahnrad oben links) → **"App hinzufügen"**
2. Klicke auf das **iOS-Icon** (Apfel-Symbol mit "iOS")
3. **iOS-Bundle-ID** eingeben:
   ```
   com.example.nearby_shop_finder
   ```
4. **App-Spitzname** (optional): `ShopFinder`
5. **App Store ID**: Feld leer lassen
6. Klicke auf **"App registrieren"**

### 3.1 GoogleService-Info.plist herunterladen

1. Klicke auf **"GoogleService-Info.plist herunterladen"**
2. Speichere unter:
   ```
   C:\Users\pixel\Desktop\buissness\nearby_shop_finder\ios\Runner\GoogleService-Info.plist
   ```
3. Klicke auf **"Weiter"** (SDK-Schritte überspringen) und dann **"Zur Konsole"**

---

## 4. Firebase Authentication aktivieren

1. Gehe in der Firebase Console links auf **"Authentication"** (im Menü unter "Build")
2. Klicke auf den Tab **"Anmeldedienste"** (Sign-in method)
3. Klicke auf **"E-Mail/Passwort"** und **"Aktivieren"** (ganz oben), dann **"Speichern"**
4. **Optional – Google-Anmeldung aktivieren:**
   - Klicke auf **"Google"**
   - Setze den Schalter auf **"Aktiviert"**
   - Wähle eine **Support-E-Mail** aus (deine E-Mail-Adresse)
   - Klicke auf **"Speichern"**

---

## 5. SHA-1 Fingerprint für Google Sign-In (nur nötig falls Google Sign-In verwendet wird)

Falls Google Sign-In nicht funktioniert, musst du den SHA-1 Schlüssel in Firebase eintragen.

### SHA-1 ermitteln

Terminal öffnen und ausführen:

```powershell
cd C:\Users\pixel\Desktop\buissness\nearby_shop_finder\android
.\gradlew signingReport
```

**Das kann 1–3 Minuten dauern** – Gradle lädt Abhängigkeiten herunter. Keine Sorge, das ist normal.

In der Ausgabe suchst du nach diesem Block (ca. ganz unten):

```
Variant: debug
Config: debug
Store: ...\debug.keystore
SHA-1: 2A:3B:4C:5D:6E:7F:8A:9B:0C:1D:2E:3F:4A:5B:6C:7D:8E:9F:0A:1B
```

Kopiere den SHA-1 Wert (die 40 Zeichen mit Doppelpunkten).

### In Firebase eintragen

1. Gehe zurück zur **Firebase Console**
2. Klicke oben links auf das **⚙️-Zahnrad** → **"Projekteinstellungen"**
3. Scrolle runter zu **"Deine Apps"**
4. Klicke auf den **Namen deiner Android-App** (nicht auf das Bearbeiten-Symbol, sondern auf den App-Namen)
5. Es klappt sich ein Bereich auf → klicke auf **"SHA-Fingerabdruck hinzufügen"**
6. Füge den kopierten SHA-1 Wert ein
7. Klicke auf **"Speichern"**

---

## 6. Firebase Web-App registrieren (nur nötig falls für Web entwickelt wird)

Falls du `flutter run -d chrome` verwenden willst.

**⚠️ Wichtig:** Du musst in der Firebase Console eine Web-App registrieren, damit Firebase für Web funktioniert. Deine aktuellen Config-Daten sind **bereits** in `lib/firebase_config.dart` eingetragen.

### Web-App in der Firebase Console registrieren:

1. Gehe zu **Projekteinstellungen** (⚙️ oben links) → **"App hinzufügen"**
2. Klicke auf das **Web-Icon** (`</>` Symbol)
3. **App-Namen** eingeben: `ShopFinder Web`
4. Klicke auf **"App registrieren"**
5. Dir wird JavaScript-Code angezeigt – **du musst nichts kopieren**, der Code ist bereits in `lib/firebase_config.dart` eingetragen
6. Klicke auf **"Weiter"** und dann **"Zur Konsole"**

### Web-Client-ID für Google Sign-In eintragen (⚠️ Pflicht für Web!):

Nachdem die Web-App registriert ist, brauchst du die **Web-Client-ID** für Google Sign-In:

1. Gehe in der Firebase Console zu **Projekteinstellungen (⚙️)**
2. Scrolle runter zu **"Deine Apps"**
3. Klicke auf deine **Web-App**
4. Kopiere die **"Web-Client-ID"** – sieht so aus:
   ```
   777049269791-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
   ```
5. Öffne `lib/firebase_config.dart` und ersetze den Kommentar bei `googleWebClientId`:
   ```dart
   String? get googleWebClientId {
     if (!kIsWeb) return null;
     return '777049269791-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com';
   }
   ```

### Config-Datei prüfen:

Öffne `lib/firebase_config.dart` und vergleiche die Werte mit denen in der Firebase Console.
Falls sich etwas geändert hat (z.B. nach Projekt-Updates), aktualisiere die Werte dort.

Die Datei sollte so aussehen (deine Werte sind bereits eingetragen ✅):

```dart
import 'package:flutter/foundation.dart';

FirebaseOptions get firebaseOptions {
  return const FirebaseOptions(
    apiKey: 'AIzaSyDgnD0vmSLj79EljwFm6l0MjMhWjibdrb4',
    authDomain: 'shopfinder-5f670.firebaseapp.com',
    projectId: 'shopfinder-5f670',
    storageBucket: 'shopfinder-5f670.firebasestorage.app',
    messagingSenderId: '777049269791',
    appId: '1:777049269791:web:bef2de6e622ebe0687d72a',
    measurementId: 'G-TBY545F08B',
  );
}
```

---

## 7. Abhängigkeiten installieren

Nachdem alle Config-Dateien platziert sind:

```powershell
cd C:\Users\pixel\Desktop\buissness\nearby_shop_finder

# Alte Sperrdatei löschen für sauberen Fetch
Remove-Item -LiteralPath "pubspec.lock" -ErrorAction SilentlyContinue

# Pakete installieren
flutter pub get
```

**Wenn Fehler auftreten**, führe aus:
```powershell
flutter clean
flutter pub get
```

---

## 8. App starten & testen

### Android:
```powershell
flutter run
```

### Web (optional):
```powershell
flutter run -d chrome
```

### Test-Ablauf:
1. App startet → **Ladebildschirm** (ShopFinder Logo)
2. Dann → **Login-Bildschirm**
3. Klicke auf **"Noch kein Konto? Jetzt registrieren"**
4. Gib eine E-Mail und ein Passwort (min. 6 Zeichen) ein
5. Klicke auf **"Konto erstellen"**
6. Firebase sendet eine **Bestätigungs-E-Mail** an deine Adresse
7. Öffne dein E-Mail-Postfach und klicke auf den Bestätigungslink
8. Geh zurück zur App, klicke auf **"Ich habe bestätigt – Weiter"**
9. Du wirst zur **Suchseite** weitergeleitet

---

## 9. Fehlerbehebung

### "Ich finde das Android-Icon nicht"

Nach der Projekterstellung landest du auf der **Projekt-Übersicht**. 
- Wenn du die Platform-Icons (Android, iOS, Web) **nicht** siehst: Klicke links oben auf **Projekteinstellungen (⚙️)** → dort im Tab **"Allgemein"** → scrolle zu **"Deine Apps"** → klicke auf **"App hinzufügen"**
- Falls du schon Apps hast: Der Button heißt **"App hinzufügen"** (nicht das + Symbol)
- Die Icons zeigen **nur** anfangs auf der Übersichtsseite – danach findest du sie nur noch über "Projekteinstellungen"

### "No Firebase App '[DEFAULT]' has been created"
- Die `google-services.json` fehlt oder liegt im falschen Ordner
- Prüfe: `Test-Path "android/app/google-services.json"`

### "google-services.json not found"
- Führe `flutter clean` und dann `flutter pub get` aus
- Stelle sicher dass die Datei wirklich in `android/app/` liegt

### "Sign in failed" / "Google Sign-In fehlgeschlagen"
- SHA-1 Fingerprint fehlt in Firebase Console (siehe Schritt 5)
- Oder unterstützte E-Mail ist nicht korrekt

### "flutter pub get" hängt oder schlägt fehl
- Probiere: `flutter pub get --offline` (falls Pakete schon im Cache sind)
- Oder lösche den `pubspec.lock` und `.dart_tool/` Ordner

---

## Projektstruktur (nur Firebase-relevante Dateien)

```
nearby_shop_finder/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts          ✅ Google Services Plugin hinzugefügt
│   │   └── google-services.json      ❌ MUSS von dir heruntergeladen werden
│   └── settings.gradle.kts           ✅ Google Services Plugin hinzugefügt
├── ios/
│   └── Runner/
│       └── GoogleService-Info.plist   ❌ NUR bei iOS-Entwicklung nötig
├── lib/
│   ├── main.dart                      ✅ Firebase + AuthGate hinzugefügt
│   ├── screens/
│   │   ├── auth_screen.dart           ✅ Angepasst für Firebase
│   │   └── search_screen.dart         ✅ Placeholder-Text, kein Auto-Search
│   └── services/
│       └── auth_service.dart          ✅ Komplett für Firebase umgeschrieben
├── pubspec.yaml                       ✅ firebase_core + firebase_auth
└── FIREBASE_SETUP.md                  ← Diese Datei
```
