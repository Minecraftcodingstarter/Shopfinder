// main.dart  (DIREKT-Version: Supabase init, kein localhost-Backend, kein Firebase)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/legal_content.dart';
import 'supabase_config.dart';
import 'providers/app_settings.dart';
import 'screens/home_screen.dart';
import 'screens/legal_page_screen.dart';
import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'services/company_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase initialisieren (ersetzt Firebase + localhost-Backend)
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await BackendService().initialize();
  final settings = AppSettings();
  await settings.loadSettings();
  await AuthService().initialize();
  await CompanyService().initialize();

  runApp(ServicePlaceApp(settings: settings));
}

class ServicePlaceApp extends StatelessWidget {
  final AppSettings settings;
  const ServicePlaceApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServicePlace',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      home: const AuthGate(),
      routes: {
        '/impressum': (_) =>
            const LegalPageScreen(content: LegalContent.impressum),
        '/datenschutz': (_) =>
            const LegalPageScreen(content: LegalContent.datenschutz),
        '/nutzungsbedingungen': (_) =>
            const LegalPageScreen(content: LegalContent.nutzungsbedingungen),
        '/agb': (_) => const LegalPageScreen(content: LegalContent.agb),
        '/cookie-richtlinie': (_) =>
            const LegalPageScreen(content: LegalContent.cookieRichtlinie),
      },
    );
  }

  ThemeData _buildLightTheme() {
    const primary = Color(0xFF1A237E);
    const secondary = Color(0xFF7C4DFF);
    const surface = Color(0xFFF5F7FA);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: const Color(0xFFFF8A65),
        onTertiary: Colors.white,
        error: const Color(0xFFD32F2F),
        onError: Colors.white,
        surface: surface,
        onSurface: const Color(0xFF1A1A2E),
        outline: const Color(0xFFE0E0E0),
        outlineVariant: const Color(0xFFF0F0F0),
        primaryContainer: primary.withAlpha(25),
        onPrimaryContainer: primary,
        secondaryContainer: secondary.withAlpha(25),
        onSecondaryContainer: secondary,
        surfaceContainerHighest: Colors.white,
        onSurfaceVariant: const Color(0xFF757575),
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black.withAlpha(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelType: NavigationRailLabelType.all,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey[200], thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        final userData = await BackendService().verifySupabaseToken();
        if (userData != null) _auth.updateFromBackend(userData);
      } else {
        await BackendService().clearToken();
      }
      if (mounted) setState(() {});
    });

    _auth.initialize().then((_) async {
      if (_auth.isLoggedIn) {
        await _auth.syncWithBackend();
      }
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text('ServicePlace',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
    return const HomeScreen();
  }
}
