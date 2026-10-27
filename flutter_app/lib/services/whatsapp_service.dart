import 'dart:convert';
import 'package:http/http.dart' as http;

/// WhatsApp Cloud API Config provided by USER
class WhatsAppConfig {
  static const String phoneNumberId = '1090065870862766';
  static const String accessToken =
      'EAAU9xREEx7EBSFa5JjIT4sTIvp2hJksuKvVGVU0fnQjKSQ9sWlGFcvdSbBFUS4ZAV1NwZCeI8IPHmk84N5oyQoRAXAxBPXZBBZB8qPivvpYR523VME4ZCOXaIZAXy3KzuWwL4LbSAqW2lCZBipeZCCJkwQFytsI4kdZA7IHMS8iqnIIK0jMtedxZBdLuZC6E63ZAYhyhKAZDZD';
  static const String templateName = 'amudham_authendication';
}

class WhatsAppService {
  /// Sends OTP via WhatsApp Cloud API using template amudham_authendication
  static Future<bool> sendAuthenticationOtp(
      String mobileNumber, String otpCode) async {
    // 1. Sanitize mobile number
    String cleanMobile = mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanMobile.length == 10) {
      cleanMobile = '91$cleanMobile'; // Add India country code if 10 digits
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
      );

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
        );

        return fbResponse.statusCode == 200 || fbResponse.statusCode == 201;
      }
    } catch (_) {
      return false;
    }
  }
}
