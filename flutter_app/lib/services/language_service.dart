import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_translations.dart';

class LanguageService {
  static const String prefKey = 'app_language';
  static const String prefHasChosenKey = 'has_chosen_language';

  // ValueNotifier so any widget can listen or re-render reactively
  static final ValueNotifier<String> languageNotifier = ValueNotifier<String>('en');

  static bool _hasChosen = false;

  static bool hasChosenLanguage() => _hasChosen;

  static String get currentLanguage => languageNotifier.value;
  static bool get isTamil => languageNotifier.value == 'ta';
  static bool get isEnglish => languageNotifier.value == 'en';

  /// Initialize language preferences from SharedPreferences on app startup
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(prefKey);
      final hasChosen = prefs.getBool(prefHasChosenKey) ?? (savedLang != null);

      _hasChosen = hasChosen;
      if (savedLang != null && (savedLang == 'ta' || savedLang == 'en')) {
        languageNotifier.value = savedLang;
      } else {
        languageNotifier.value = 'en';
      }
    } catch (e) {
      debugPrint('LanguageService.init error: $e');
    }
  }

  /// Change the app language and persist preference
  static Future<void> setLanguage(String langCode) async {
    if (langCode != 'en' && langCode != 'ta') return;
    languageNotifier.value = langCode;
    _hasChosen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, langCode);
      await prefs.setBool(prefHasChosenKey, true);
    } catch (e) {
      debugPrint('LanguageService.setLanguage error: $e');
    }
  }

  /// Look up translation string
  static String tr(String key, [Map<String, String>? params]) {
    return AppTranslations.tr(key, currentLanguage, params);
  }

  /// Localized display label for delivery slots while keeping backend keys unchanged.
  static String slotLabel(String raw) {
    final s = raw.toLowerCase().trim();
    if (raw.contains('🌅') && s.contains('morning')) return tr('slot_morning_emoji');
    if (raw.contains('🌇') && s.contains('evening')) return tr('slot_evening_emoji');
    if (raw.contains('☀️') || (s.contains('both') && s.contains('morning'))) return tr('slot_both_emoji');
    if (s.contains('entire')) return tr('slot_entire_day');
    if (s.contains('both')) return tr('both_shifts');
    if (s.contains('evening')) return tr('slot_evening');
    if (s.contains('morning')) return tr('slot_morning');
    return raw;
  }

  /// Localized display label for delivery plans while keeping backend keys unchanged.
  static String planLabel(String raw) {
    final p = raw.toLowerCase().trim();
    if (p == 'daily (mon - sun)') return tr('daily_all_days');
    if (p == 'daily' || p == 'monday-sunday') return tr('daily_all_days');
    if (p.contains('mon - sat') || p == 'monday-saturday') return tr('plan_mon_sat');
    if (p.contains('alternate')) return tr('alternate_days');
    if (p.contains('weekday') || p == 'monday-friday') return tr('weekdays_only');
    if (p.contains('weekend')) return tr('weekends_only');
    if (p == 'custom days (specify)') return tr('plan_custom_specify');
    if (p == 'custom days') return tr('custom_days');
    return raw;
  }

  /// Localized display label for billing cycle periods ('daily', 'weekly', 'monthly').
  static String periodLabel(String period) {
    switch (period.toLowerCase().trim()) {
      case 'daily':
        return tr('daily_cycle');
      case 'weekly':
        return tr('weekly_cycle');
      case 'monthly':
        return tr('monthly_cycle');
      default:
        return period;
    }
  }

  /// Localized display label for uppercase status badges while keeping backend enums unchanged.
  static String statusLabel(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'APPROVED':
        return tr('status_approved');
      case 'REJECTED':
        return tr('status_rejected');
      case 'REQUESTED':
        return tr('status_requested');
      case 'PENDING':
        return tr('status_pending');
      case 'PAID':
        return tr('status_paid');
      case 'COMPLETED':
        return tr('status_completed');
      case 'FAILED':
        return tr('status_failed');
      case 'CANCELLED':
        return tr('status_cancelled');
      case 'SKIPPED':
        return tr('status_skipped');
      case 'MISSED':
        return tr('status_missed');
      case 'IN PROGRESS':
      case 'IN_PROGRESS':
        return tr('status_in_progress');
      case 'DELIVERED':
        return tr('delivered').toUpperCase();
      case 'SCHEDULED':
        return tr('scheduled').toUpperCase();
      default:
        return raw;
    }
  }

  /// Localized weekday short name from weekday int (1=Mon..7=Sun) or English short string.
  static String dayShortLabel(dynamic day) {
    switch (day.toString().toLowerCase().trim()) {
      case '1':
      case 'mon':
      case 'monday':
        return tr('day_mon_short');
      case '2':
      case 'tue':
      case 'tuesday':
        return tr('day_tue_short');
      case '3':
      case 'wed':
      case 'wednesday':
        return tr('day_wed_short');
      case '4':
      case 'thu':
      case 'thursday':
        return tr('day_thu_short');
      case '5':
      case 'fri':
      case 'friday':
        return tr('day_fri_short');
      case '6':
      case 'sat':
      case 'saturday':
        return tr('day_sat_short');
      case '7':
      case 'sun':
      case 'sunday':
        return tr('day_sun_short');
      default:
        return day.toString();
    }
  }

  /// Localized weekday full name from weekday int (1=Mon..7=Sun) or English name.
  static String dayFullLabel(dynamic day) {
    switch (day.toString().toLowerCase().trim()) {
      case '1':
      case 'mon':
      case 'monday':
        return tr('day_mon');
      case '2':
      case 'tue':
      case 'tuesday':
        return tr('day_tue');
      case '3':
      case 'wed':
      case 'wednesday':
        return tr('day_wed');
      case '4':
      case 'thu':
      case 'thursday':
        return tr('day_thu');
      case '5':
      case 'fri':
      case 'friday':
        return tr('day_fri');
      case '6':
      case 'sat':
      case 'saturday':
        return tr('day_sat');
      case '7':
      case 'sun':
      case 'sunday':
        return tr('day_sun');
      default:
        return day.toString();
    }
  }

  /// Localized month short name (1-12).
  static String monthShortLabel(int month) {
    if (month < 1 || month > 12) return month.toString();
    return tr('month_$month');
  }

  /// Format a DateTime with localized weekday/month names safely without intl locale data errors.
  static String formatShortDate(DateTime d, {bool includeYear = false}) {
    final dd = d.day.toString().padLeft(2, '0');
    final mon = monthShortLabel(d.month);
    return includeYear ? '$dd $mon ${d.year}' : '$dd $mon';
  }

  static String formatFullDayDate(DateTime d) {
    final day = dayFullLabel(d.weekday);
    return '$day, ${formatShortDate(d, includeYear: true)}';
  }

  static String formatShortDayDate(DateTime d) {
    final day = dayShortLabel(d.weekday);
    return '$day, ${formatShortDate(d)}';
  }
}

/// Shorthand helper for easy access throughout the app
String tr(String key, [Map<String, String>? params]) => LanguageService.tr(key, params);

/// Extension on String for 'key'.tr syntax
extension StringLocalizationExtension on String {
  String get tr => LanguageService.tr(this);
}
