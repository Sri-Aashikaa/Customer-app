import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/session_service.dart';

const String _supabaseUrl = 'https://czmnxrrqcrcqwvdlruif.supabase.co';
const String _supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6bW54cnJxY3JjcXd2ZGxydWlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMTU5NjAsImV4cCI6MjEwNTg5MTk2MH0.-jex033UIYC_PnoLg53pWeKZVY68gIsJFWJiDzO7if0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  final savedCustomer = await UserSession.getSession();
  runApp(AmuthamApp(savedCustomer: savedCustomer));
}

class AmuthamApp extends StatelessWidget {
  final Map<String, dynamic>? savedCustomer;
  const AmuthamApp({super.key, this.savedCustomer});

  @override
  Widget build(BuildContext context) {
    Widget homeWidget;
    if (savedCustomer != null) {
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
      title: 'Amudham Raw Milk',
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
  }
}
