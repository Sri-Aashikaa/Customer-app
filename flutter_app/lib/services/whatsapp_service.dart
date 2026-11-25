import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// WhatsApp Cloud API Config
/// Credentials are read securely from compile-time environment variables
/// (--dart-define=WHATSAPP_ACCESS_TOKEN=... --dart-define=WHATSAPP_PHONE_NUMBER_ID=...)
/// to prevent leaking secrets in source code and reverse-engineered client binaries.
class WhatsAppConfig {
  static const String phoneNumberId = String.fromEnvironment(
    'WHATSAPP_PHONE_NUMBER_ID',
    defaultValue: '1090065870862766',
  );
  static const String accessToken = String.fromEnvironment(
    'WHATSAPP_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String templateName = 'amudham_authendication';

  static bool get isConfigured =>
      phoneNumberId.isNotEmpty && accessToken.isNotEmpty;
}

class WhatsAppService {
  /// Sends OTP via WhatsApp Cloud API using template amudham_authendication
  static Future<bool> sendAuthenticationOtp(
      String mobileNumber, String otpCode) async {
    // 1. Sanitize mobile number
    String cleanMobile = mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanMobile.length == 10) {
      cleanMobile = '91$cleanMobile'; // Add India country code if 10 digits
    } else if (cleanMobile.length < 10) {
      return false;
    }

    if (!WhatsAppConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint(
            'WhatsAppService: WhatsApp Cloud API token not set. Configure WHATSAPP_ACCESS_TOKEN via --dart-define.');
      }
      return false;
    }

    final url = Uri.parse(
        'https://graph.facebook.com/v21.0/${WhatsAppConfig.phoneNumberId}/messages');

    final payload = {
      'messaging_product': 'whatsapp',
      'to': cleanMobile,
      'type': 'template',
      'template': {
        'name': WhatsAppConfig.templateName,
        'language': {'code': 'en'},
        'components': [
          {
            'type': 'body',
            'parameters': [
              {'type': 'text', 'text': otpCode}
            ]
          },
          {
            'type': 'button',
            'sub_type': 'url',
            'index': '0',
            'parameters': [
              {'type': 'text', 'text': otpCode}
            ]
          }
        ]
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${WhatsAppConfig.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        // Fallback retry format
        final fallbackPayload = {
          'messaging_product': 'whatsapp',
          'to': cleanMobile,
          'type': 'template',
          'template': {
            'name': WhatsAppConfig.templateName,
            'language': {'code': 'en'},
            'components': [
              {
                'type': 'body',
                'parameters': [
                  {'type': 'text', 'text': otpCode}
                ]
              }
            ]
          }
        };

        final fbResponse = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer ${WhatsAppConfig.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(fallbackPayload),
        ).timeout(const Duration(seconds: 12));

        return fbResponse.statusCode == 200 || fbResponse.statusCode == 201;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WhatsAppService error: $e');
      }
      return false;
    }
  }
}
