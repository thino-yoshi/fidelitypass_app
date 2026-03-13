import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/api.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$apiUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      print('📥 Login response: $data');
      await saveSession(
        data['access_token'] ?? '',
        data['user_type'] ?? 'client',
        data['name'] ?? email,
      );
      await saveFCMToken(data['access_token'] ?? '');
      return data;
    }
    final error = jsonDecode(res.body);
    throw Exception(error['detail'] ?? 'Erreur de connexion');
  }

  static Future<Map<String, dynamic>> register(
      String email,
      String password,
      String name,
      String userType,
      ) async {
    final res = await http.post(
      Uri.parse('$apiUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'user_type': userType,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      print('📥 Register response: $data');
      await saveSession(
        data['access_token'] ?? '',
        data['user_type'] ?? userType,
        data['name'] ?? name,
      );
      await saveFCMToken(data['access_token'] ?? '');
      return data;
    }
    final error = jsonDecode(res.body);
    throw Exception(error['detail'] ?? 'Erreur inscription');
  }

  static Future<void> saveFCMToken(String authToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      print('🔔 Permission: ${settings.authorizationStatus}');
      final fcmToken = await messaging.getToken();
      print('📱 FCM Token: $fcmToken');
      if (fcmToken != null && authToken.isNotEmpty) {
        final res = await http.put(
          Uri.parse('$apiUrl/users/fcm-token'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'fcm_token': fcmToken}),
        );
        print('✅ FCM Token envoyé: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur FCM: $e');
    }
  }

  static Future<void> saveSession(
      String token,
      String userType,
      String name,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user_type', userType);
    await prefs.setString('name', name);
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userType = prefs.getString('user_type');
    final name = prefs.getString('name');
    if (token == null || token.isEmpty) return null;
    return {
      'token': token,
      'user_type': userType ?? 'client',
      'name': name ?? '',
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}