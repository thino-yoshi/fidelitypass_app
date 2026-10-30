import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/api.dart';
import '../main.dart' show navigatorKey;
import '../screens/auth_screen.dart';
import '../utils/logger.dart';

const _kTimeout = Duration(seconds: 10);

class AuthService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // Cache synchrone du token (mis à jour par saveSession, vidé par logout)
  static String? _cachedToken;

  // Token actuel : Supabase en priorité, puis cache local (Google mobile / email)
  static String? get currentToken =>
      _supabase.auth.currentSession?.accessToken ?? _cachedToken;

  /// Détermine le type de compte depuis les métadonnées Supabase.
  /// Règle : site = marchand (clé `role`), app = client (clé `user_type`).
  /// On lit les deux clés pour être robuste quel que soit l'endroit de création.
  static String resolveUserType(Map<String, dynamic>? meta) {
    final ut = (meta?['user_type'] as String?)?.trim();
    if (ut == 'merchant' || ut == 'client') return ut!;
    final role = (meta?['role'] as String?)?.trim();
    if (role == 'merchant') return 'merchant';
    if (role == 'client') return 'client';
    return 'client';
  }

  // ── Connexion email / mot de passe (backend Railway → Neon) ────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    AppLogger.auth('Login tentative → $email');
    final res = await http.post(
      Uri.parse('$apiUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['detail'] ?? 'Connexion échouée');
    }

    final data     = jsonDecode(res.body) as Map<String, dynamic>;
    final token    = data['token'] as String;
    final userType = (data['user_type'] as String?) ?? 'client';
    final name     = (data['name']      as String?) ?? '';
    AppLogger.auth('Login succès → user_type: $userType, name: $name');

    await saveSession(token, userType, name, email: email);
    await saveFCMToken(token);

    return {'token': token, 'user_type': userType, 'name': name};
  }

  // ── Inscription email / mot de passe (backend Railway → Neon) ───────────────
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name,
    String userType, {
    String? merchantCode,
  }) async {
    AppLogger.auth('Register tentative → email: $email, type: $userType, name: $name');
    final res = await http.post(
      Uri.parse('$apiUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'user_type': userType,
        if (merchantCode != null) 'merchant_code': merchantCode,
      }),
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['detail'] ?? 'Inscription échouée');
    }

    final data     = jsonDecode(res.body) as Map<String, dynamic>;
    final token    = data['token'] as String;
    AppLogger.auth('Register succès → user_type: $userType');

    await saveSession(token, userType, name, email: email);
    await saveFCMToken(token);

    return {'token': token, 'user_type': userType, 'name': name};
  }

  // ── Connexion Google (natif → backend Railway, sans Supabase) ───────────────
  static Future<Map<String, dynamic>> launchGoogleSignIn() async {
    AppLogger.auth('Google Sign-In natif → ouverture sélecteur de compte...');
    final googleSignIn = GoogleSignIn(
      serverClientId: '1097051657980-rm2slbqt9atg9og0qdjc45nat5qe3jkj.apps.googleusercontent.com',
    );
    await googleSignIn.signOut();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Connexion Google annulée');
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Impossible d\'obtenir le token Google');

    AppLogger.auth('Google Sign-In → token obtenu, appel backend...');
    final res = await http.post(
      Uri.parse('$apiUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['detail'] ?? 'Connexion Google échouée (${res.statusCode})');
    }

    final data     = jsonDecode(res.body) as Map<String, dynamic>;
    final token    = data['token'] as String;
    final userType = (data['user_type'] as String?) ?? 'client';
    final name     = (data['name']      as String?) ?? '';
    final email    = (data['email']     as String?) ?? '';

    AppLogger.auth('Google Sign-In backend succès → user_type: $userType');
    await saveSession(token, userType, name, email: email, isGoogle: true);
    await saveFCMToken(token);

    return {'token': token, 'user_type': userType, 'name': name};
  }

  // Appelé quand une session Supabase OAuth arrive (Google browser ou Apple)
  static Future<Map<String, dynamic>> processCurrentGoogleUser() async {
    final user    = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;
    if (user == null || session == null) throw Exception('Aucune session active');

    final name = (user.userMetadata?['full_name'] as String?)
        ?? (user.userMetadata?['name'] as String?)
        ?? user.email
        ?? '';

    final meta = user.userMetadata ?? {};
    if (!meta.containsKey('user_type')) {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'user_type': 'client', 'name': name}),
      );
      await _supabase.auth.refreshSession();
    }

    final provider = (user.appMetadata['provider'] as String?) ?? '';
    final isGoogle = provider == 'google';
    final userType = resolveUserType(_supabase.auth.currentUser?.userMetadata ?? meta);
    final token    = _supabase.auth.currentSession!.accessToken;
    AppLogger.auth('processCurrentGoogleUser → provider: $provider, user_type: $userType');
    await saveSession(token, userType, name, email: user.email ?? '', isGoogle: isGoogle);
    await fetchAndSaveProfile(token);
    await saveFCMToken(token);
    return {'token': token, 'user_type': userType, 'name': name};
  }

  // ── Connexion Apple (OAuth Supabase → deep link qarta://login-callback) ──────
  static Future<void> launchAppleSignIn() async {
    AppLogger.auth('Apple Sign-In → ouverture OAuth Supabase...');
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'qarta://login-callback',
    );
  }

  // ── Envoi du token FCM à l'API ───────────────────────────────────────────────
  static Future<void> saveFCMToken(String authToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final fcmToken = await messaging.getToken();
      final token = currentToken ?? authToken;
      if (fcmToken != null && token.isNotEmpty) {
        AppLogger.fcm('Token FCM obtenu : ${fcmToken.substring(0, 20)}…');
        final res = await http.put(
          Uri.parse('$apiUrl/users/fcm-token'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'fcm_token': fcmToken}),
        ).timeout(_kTimeout);
        AppLogger.fcm('PUT /users/fcm-token → ${res.statusCode}');
      } else {
        AppLogger.fcm('Token FCM null ou authToken vide — pas de mise à jour');
      }
    } catch (e) {
      AppLogger.error('FCM saveFCMToken : $e');
    }
  }

  // ── Session ──────────────────────────────────────────────────────────────────

  /// Persiste les informations de base dans SharedPreferences (compatibilité
  /// avec les écrans qui lisent encore email/is_google depuis les prefs).
  static Future<void> saveSession(
    String token,
    String userType,
    String name, {
    String email   = '',
    bool isGoogle  = false,
  }) async {
    AppLogger.auth('saveSession → type: $userType, name: $name, email: $email, google: $isGoogle');
    _cachedToken = token; // cache synchrone pour currentToken
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token',     token);
    await prefs.setString('user_type', userType);
    await prefs.setString('name',      name);
    if (email.isNotEmpty) await prefs.setString('email', email);
    await prefs.setBool('is_google', isGoogle);
  }

  /// Enrichit le profil depuis Supabase Auth et le persiste (remplace l'appel
  /// à /users/me de l'ancienne version).
  static Future<void> fetchAndSaveProfile(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final email    = user.email ?? '';
      final isGoogle = (user.appMetadata['provider'] as String?) == 'google';
      final prefs    = await SharedPreferences.getInstance();
      if (email.isNotEmpty) await prefs.setString('email', email);
      // Ne jamais rétrograder is_google (OR avec la valeur locale)
      final localIsGoogle = prefs.getBool('is_google') ?? false;
      await prefs.setBool('is_google', isGoogle || localIsGoogle);
    } catch (_) {}
  }

  /// Lit la session active : Supabase en priorité, puis SharedPreferences (tokens backend).
  static Future<Map<String, String>?> getSession() async {
    // 1. Session Supabase (email/password classique ou Apple)
    final session = _supabase.auth.currentSession;
    if (session != null) {
      final user     = _supabase.auth.currentUser;
      final userType = resolveUserType(user?.userMetadata);
      var name = (user?.userMetadata?['name'] as String?) ?? '';
      // Apple ne retourne le nom qu'à la 1ère connexion — fallback sur SharedPreferences
      if (name.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('name') ?? '';
        name = saved.isNotEmpty ? saved : (user?.email ?? '');
      }
      AppLogger.auth('getSession → Supabase, user_type: $userType, name: $name');
      return {'token': session.accessToken, 'user_type': userType, 'name': name};
    }

    // 2. Token backend (Google mobile ou email/password via Railway)
    final prefs    = await SharedPreferences.getInstance();
    final token    = prefs.getString('token');
    if (token == null || token.isEmpty) {
      AppLogger.auth('getSession → aucune session active');
      return null;
    }
    _cachedToken = token; // restaure le cache synchrone au démarrage
    final userType = prefs.getString('user_type') ?? 'client';
    final name     = prefs.getString('name')      ?? '';
    AppLogger.auth('getSession → token backend, user_type: $userType, name: $name');
    return {'token': token, 'user_type': userType, 'name': name};
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    AppLogger.auth('Logout → effacement session + Supabase signOut');
    _cachedToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Supprimer uniquement les clés de session (pas les identifiants mémorisés ni le thème)
      await prefs.remove('token');
      await prefs.remove('user_type');
      await prefs.remove('name');
      await prefs.remove('email');
      await prefs.remove('is_google');
      await _supabase.auth.signOut();
      AppLogger.auth('Logout → succès');
    } catch (e) {
      AppLogger.error('Logout erreur : $e');
    }
  }

  // ── Gestion 401 ──────────────────────────────────────────────────────────────
  static Future<void> _handleUnauthorized() async {
    AppLogger.error('401 reçu → logout forcé + retour AuthScreen');
    await logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  static String networkErrorMessage(Object e) {
    if (e is SocketException) return 'Pas de connexion internet.';
    if (e is HttpException)   return 'Erreur serveur. Réessayez.';
    if (e.toString().contains('TimeoutException')) return 'Le serveur met trop de temps à répondre.';
    return 'Erreur réseau. Réessayez.';
  }

  // ── Helpers HTTP authentifiés ────────────────────────────────────────────────
  //   Toujours utiliser le token Supabase le plus récent (auto-refresh transparent).

  static String _resolve(String fallback) => currentToken ?? fallback;

  static Future<http.Response> authGet(String path, String token) async {
    final res = await http
        .get(Uri.parse('$apiUrl$path'),
            headers: {'Authorization': 'Bearer ${_resolve(token)}'})
        .timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }

  static Future<http.Response> authPost(
      String path, String token, Map<String, dynamic> body) async {
    final res = await http
        .post(
          Uri.parse('$apiUrl$path'),
          headers: {
            'Authorization': 'Bearer ${_resolve(token)}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }

  static Future<http.Response> authPut(
      String path, String token, Map<String, dynamic> body) async {
    final res = await http
        .put(
          Uri.parse('$apiUrl$path'),
          headers: {
            'Authorization': 'Bearer ${_resolve(token)}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }

  static Future<http.Response> authDelete(String path, String token) async {
    final res = await http
        .delete(Uri.parse('$apiUrl$path'),
            headers: {'Authorization': 'Bearer ${_resolve(token)}'})
        .timeout(_kTimeout);
    if (res.statusCode == 401) await _handleUnauthorized();
    return res;
  }
}
