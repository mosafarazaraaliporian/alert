import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  
  // Register user
  static Future<Map<String, dynamic>> registerUser({
    required String chatId,
    required String fcmToken,
    required String deviceId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'fcm_token': fcmToken,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to register: ${response.body}');
      }
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }

  // Create alert
  static Future<Map<String, dynamic>> createAlert({
    required String chatId,
    required String coinName,
    required double targetPrice,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/alerts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'coin_name': coinName,
          'target_price': targetPrice,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create alert: ${response.body}');
      }
    } catch (e) {
      print('Error creating alert: $e');
      rethrow;
    }
  }

  // Get user alerts
  static Future<List<dynamic>> getAlerts(String chatId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/alerts/$chatId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['alerts'] ?? [];
      } else {
        throw Exception('Failed to get alerts: ${response.body}');
      }
    } catch (e) {
      print('Error getting alerts: $e');
      rethrow;
    }
  }

  // Delete alert
  static Future<Map<String, dynamic>> deleteAlert({
    required String chatId,
    required int alertId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/alerts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'alert_id': alertId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to delete alert: ${response.body}');
      }
    } catch (e) {
      print('Error deleting alert: $e');
      rethrow;
    }
  }

  // Get current price
  static Future<Map<String, dynamic>> getPrice(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/price/$symbol'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get price: ${response.body}');
      }
    } catch (e) {
      print('Error getting price: $e');
      rethrow;
    }
  }
}
