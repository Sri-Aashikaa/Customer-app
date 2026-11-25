import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../widgets/app_logo.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

const _green = Color(0xFF059669);

class LanguageSelectionScreen extends StatefulWidget {
  final Map<String, dynamic>? savedCustomer;
  final bool isFirstTime;

  const LanguageSelectionScreen({
    super.key,
    this.savedCustomer,
    this.isFirstTime = true,
  });

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late String _selectedLanguage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default to Tamil as primary regional language or existing preference
    _selectedLanguage = LanguageService.currentLanguage == 'ta' ? 'ta' : 'en';
  }

  Future<void> _handleContinue() async {
    setState(() => _saving = true);
    await LanguageService.setLanguage(_selectedLanguage);

    if (!mounted) return;

    if (!widget.isFirstTime) {
      Navigator.pop(context, _selectedLanguage);
      return;
    }

    // First time navigation flow
    Widget nextScreen;
    if (widget.savedCustomer != null) {
      final cust = widget.savedCustomer!;
      if (cust['account_status'] == 'INACTIVE' || cust['milk_quantity'] == null) {
        nextScreen = OnboardingScreen(customer: cust);
      } else {
        nextScreen = HomeScreen(customer: cust);
      }
    } else {
      nextScreen = const AuthScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTa = _selectedLanguage == 'ta';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top App Logo & Brand (changes dynamically as per selected language)
                Center(
                  child: AppLogo(
                    language: _selectedLanguage,
                    size: 92,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 16),

                // Bilingual App Title
                const Center(
                  child: Text(
                    'Sri Aashikaa',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'ஸ்ரீ ஆஷிகா',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    isTa ? 'ஒவ்வொரு துளியிலும் புத்துணர்ச்சி...' : 'Freshness in every drop...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.translate_rounded,
                        color: _green,
                        size: 32,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isTa ? 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்' : 'Choose Your Language',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTa
                            ? 'பயன்பாட்டைத் தொடர உங்கள் விருப்ப மொழியைத் தேர்ந்தெடுக்கவும்'
                            : 'Please select your preferred language to proceed',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Language Option 1: Tamil
                _languageCard(
                  code: 'ta',
                  title: 'தமிழ்',
                  englishTitle: 'Tamil',
                  description: 'பயன்பாட்டை முழுமையாக தமிழில் பயன்படுத்தவும்',
                  isSelected: _selectedLanguage == 'ta',
                  badge: 'தமிழ்நாடு',
                ),
                const SizedBox(height: 14),

                // Language Option 2: English
                _languageCard(
                  code: 'en',
                  title: 'English',
                  englishTitle: 'Default Language',
                  description: 'Use the complete application in English',
                  isSelected: _selectedLanguage == 'en',
                  badge: 'EN',
                ),
                const SizedBox(height: 28),

                // Continue Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saving ? null : _handleContinue,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isTa ? 'தொடரவும் (Continue)' : 'Continue (தொடரவும்)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
                const SizedBox(height: 16),

                // Subtitle reminder
                Center(
                  child: Text(
                    isTa
                        ? '💡 அமைப்புகள் பக்கத்தில் (Settings) எப்போது வேண்டுமானாலும் மொழியை மாற்றலாம்.'
                        : '💡 You can change your language anytime from Settings / Profile.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageCard({
    required String code,
    required String title,
    required String englishTitle,
    required String description,
    required bool isSelected,
    required String badge,
  }) {
    return InkWell(
      onTap: () {
        setState(() => _selectedLanguage = code);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _green : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: _green.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Language Specific Logo Thumbnail
            AppLogo(
              language: code,
              size: 46,
              compact: true,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 14),

            // Titles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($englishTitle)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? _green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? const Color(0xFF047857) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Radio / Checkmark
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _green : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _green : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
