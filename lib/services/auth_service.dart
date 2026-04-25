import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/api.dart';
import '../main.dart' show navigatorKey;
import '../screens/auth_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _kTimeout = Duration(seconds: 10);

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
        data['token'] ?? data['access_token'] ?? '',
        data['user_type'] ?? 'client',
        data['name'] ?? email,
      );
      await saveFCMToken(data['token'] ?? data['access_token'] ?? '');
      return data;
    }
    final error = jsonDecode(res.body);
    throw Exception(error['detail'] ?? 'Erreur de connexion');
  }

  static Future<Map<String, dynamic>> register(
      String email,
      String password,
      String name,
      String userType, {
        String? merchantCode,
      }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'name': name,
      'user_type': userType,
    };
    if (merchantCode != null && merchantCode.isNotEmpty) {
      body['merchant_code'] = merchantCode;
    }

    final res = await http.post(
      Uri.parse('$apiUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      print('📥 Register response: $data');
      await saveSession(
        data['token'] ?? data['access_token'] ?? '',
        data['user_type'] ?? userType,
        data['name'] ?? name,
      );
      await saveFCMToken(data['token'] ?? data['access_token'] ?? '');
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
        print('🚀 Envoi FCM token vers API...');
        final res = await http.put(
          Uri.parse('$apiUrl/users/fcm-token'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'fcm_token': fcmToken}),
        );
        print('✅ FCM Token envoyé: ${res.statusCode}');
        print('📨 Réponse body: ${res.body}');
      } else {
        print('⚠️ FCM Token null ou authToken vide — token: $fcmToken, auth: $authToken');
      }
    } catch (e) {
      print('❌ Erreur FCM: $e');
    }
  }

  static Future<void> saveSession(
      String token,
      String userType,
      String name, {
      String email = '',
      bool isGoogle = false,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user_type', userType);
    await prefs.setString('name', name);
    if (email.isNotEmpty) await prefs.setString('email', email);
    await prefs.setBool('is_google', isGoogle);
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
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}
  }

  /// Redirige vers le login si le token est expiré (401).
  static Future<void> _handleUnauthorized() async {
    await logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  /// Transforme les exceptions réseau en messages lisibles.
  static String networkErrorMessage(Object e) {
    if (e is SocketException) return 'Pas de connexion internet.';
    if (e is HttpException) return 'Erreur serveur. Réessayez.';
    if (e.toString().contains('TimeoutException')) return 'Le serveur met trop de temps à répondre.';
    return 'Erreur réseau. Réessayez.';
  }

  /// Wrapper GET authentifié — timeout 10s + gestion 401.
  static Future<http.Response> authGet(String path, String token) async {
    final res = await http.get(
      Uri.parse('$apiUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }

  /// Wrapper POST authentifié — timeout 10s + gestion 401.
  static Future<http.Response> authPost(String path, String token, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$apiUrl$path'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }

  /// Wrapper PUT authentifié — timeout 10s + gestion 401.
  static Future<http.Response> authPut(String path, String token, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$apiUrl$path'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }

  /// Wrapper DELETE authentifié — timeout 10s + gestion 401.
  static Future<http.Response> authDelete(String path, String token) async {
    final res = await http.delete(
      Uri.parse('$apiUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }
}