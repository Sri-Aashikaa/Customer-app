import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper service for persistent customer login sessions across app restarts
class UserSession {
  static const String _key = 'logged_in_customer_session';

  /// Save customer login session locally
  static Future<void> saveSession(Map<String, dynamic> customer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(customer));
    } catch (_) {}
  }

  /// Retrieve active saved customer session if available
  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_key);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Clear session on explicit user logout
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
