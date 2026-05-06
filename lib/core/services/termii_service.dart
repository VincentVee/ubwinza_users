import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/termii_config.dart';

class TermiiService {
  static const String baseUrl = TermiiConfig.baseUrl;
  static const String apiKey = TermiiConfig.apiKey;
  static const String senderId = TermiiConfig.senderId;// Replace with your actual API key

  // Send OTP to phone number - Corrected API format
  static Future<Map<String, dynamic>> sendOTP(String phoneNumber) async {
    try {
      // Format phone number (remove any spaces, ensure proper format)
      String formattedPhone = phoneNumber.trim().replaceAll(' ', '');
      if (!formattedPhone.startsWith('+')) {
        // Add Zambia country code if not present
        if (formattedPhone.startsWith('0')) {
          formattedPhone = '+260${formattedPhone.substring(1)}';
        } else if (formattedPhone.length == 9) {
          formattedPhone = '+260$formattedPhone';
        } else {
          formattedPhone = '+$formattedPhone';
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/sms/otp/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'api_key': apiKey,
          'to': formattedPhone,  // Changed from 'phone_number' to 'to'
          'from': 'Ubwinza',      // Sender ID
          'pin_attempts': 3,
          'pin_time_to_live': 5,
          'pin_length': 6,
          'pin_placeholder': '< 1234 >',
          'message_text': 'Your Ubwinza verification code is < 1234 >',
          'message_type': 'NUMERIC',  // Add this
          'pin_type': 'NUMERIC',       // Add this
        }),
      );

      print('Termii sendOTP response: ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      print('Termii sendOTP error: $e');
      return {'error': e.toString()};
    }
  }

  // Verify OTP code
  static Future<Map<String, dynamic>> verifyOTP(String pinId, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sms/otp/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'api_key': apiKey,
          'pin_id': pinId,
          'pin': pin,
        }),
      );

      print('Termii verifyOTP response: ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      print('Termii verifyOTP error: $e');
      return {'error': e.toString()};
    }
  }
}