import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/language_selection_screen.dart';
import 'services/session_service.dart';
import 'services/language_service.dart';
import 'services/api.dart';

const String _supabaseUrl = 'https://eftixvhkmtujlbayrauk.supabase.co';
const String _supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmdGl4dmhrbXR1amxiYXlyYXVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0NzcyNjgsImV4cCI6MjExMDA1MzI2OH0.NWAHkzFcAS9w9YF_v7-_GVRa_c5Rb4Ltkc3BUweXNrg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseAPI.loadAppVersion();
  Map<String, dynamic>? savedCustomer;
  try {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    await LanguageService.init();
    savedCustomer = await UserSession.getSession();
  } catch (e, stack) {
    debugPrint('Startup initialization error: $e\n$stack');
  }
  runApp(SriAashikaaApp(savedCustomer: savedCustomer));
}

class SriAashikaaApp extends StatelessWidget {
  final Map<String, dynamic>? savedCustomer;
  const SriAashikaaApp({super.key, this.savedCustomer});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.languageNotifier,
      builder: (context, currentLang, child) {
        Widget homeWidget;
        if (!LanguageService.hasChosenLanguage()) {
          homeWidget = LanguageSelectionScreen(savedCustomer: savedCustomer, isFirstTime: true);
        } else if (savedCustomer != null) {
          if (savedCustomer!['account_status'] == 'INACTIVE' ||
              savedCustomer!['milk_quantity'] == null) {
            homeWidget = OnboardingScreen(customer: savedCustomer!);
          } else {
            homeWidget = HomeScreen(customer: savedCustomer!);
          }
        } else {
          homeWidget = const AuthScreen();
        }

        return MaterialApp(
          title: currentLang == 'ta' ? 'ஸ்ரீ ஆஷிகா' : 'Sri Aashikaa',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF059669)),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          home: homeWidget,
        );
      },
    );
  }
}

/// Backwards compatibility alias for tests and legacy references
typedef AmuthamApp = SriAashikaaApp;
