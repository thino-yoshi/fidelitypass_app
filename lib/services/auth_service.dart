import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api.dart';
import '../main.dart' show navigatorKey;
import '../screens/auth_screen.dart';
import '../utils/logger.dart';

const _kTimeout = Duration(seconds: 10);

class AuthService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // ── Token actuel (toujours frais via Supabase SDK) ──────────────────────────
  static String? get currentToken => _supabase.auth.currentSession?.accessToken;

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

  // ── Connexion email / mot de passe ──────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    AppLogger.auth('Login tentative → $email');
    final res = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null || res.session == null) {
      AppLogger.error('Login échoué → utilisateur ou session null');
      throw Exception('Connexion échouée — vérifiez vos identifiants');
    }
    final userType = resolveUserType(user.userMetadata);
    final name     = (user.userMetadata?['name']      as String?) ?? user.email ?? '';
    final token    = res.session!.accessToken;
    AppLogger.auth('Login succès → user_type: $userType, name: $name');

    await saveSession(token, userType, name, email: user.email ?? '');
    await fetchAndSaveProfile(token);
    await saveFCMToken(token);

    return {'token': token, 'user_type': userType, 'name': name};
  }

  // ── Inscription email / mot de passe (clients uniquement) ───────────────────
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name,
    String userType, {
    String? merchantCode, // conservé pour compat, non utilisé
  }) async {
    AppLogger.auth('Register tentative → email: $email, type: $userType, name: $name');
    final res = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'user_type': userType, 'name': name},
    );
    final user = res.user;
    if (user == null) {
      AppLogger.error('Register échoué → user null');
      throw Exception('Inscription échouée');
    }

    // Email confirmation activée → session null, on attend la vérification
    if (res.session == null) {
      AppLogger.auth('Register → OTP envoyé à $email, en attente de confirmation');
      return {'pending_confirmation': true, 'user_type': userType, 'name': name, 'token': ''};
    }

    final token = res.session!.accessToken;
    AppLogger.auth('Register succès → session directe obtenue');
    await saveSession(token, userType, name, email: user.email ?? '');
    await fetchAndSaveProfile(token);
    await saveFCMToken(token);

    return {'token': token, 'user_type': userType, 'name': name};
  }

  // ── Connexion Google (token natif → Supabase) ────────────────────────────────
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    AppLogger.auth('Google OAuth → tentative de connexion...');
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    final googleUser   = await googleSignIn.signIn();
    if (googleUser == null) {
      AppLogger.auth('Google OAuth → annulée par l\'utilisateur');
      throw Exception('Connexion Google annulée');
    }
    AppLogger.auth('Google OAuth → compte sélectionné : ${googleUser.email}');

    final googleAuth = await googleUser.authentication;
    final idToken    = googleAuth.idToken;
    if (idToken == null) {
      AppLogger.error('Google OAuth → idToken null');
      throw Exception('Token Google introuvable');
    }

    final res = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
    final user = res.user;
    if (user == null || res.session == null) {
      AppLogger.error('Google OAuth → user ou session null après signInWithIdToken');
      throw Exception('Connexion Google échouée');
    }

    final name = (user.userMetadata?['name'] as String?)
        ?? googleUser.displayName
        ?? user.email
        ?? '';

    final meta = user.userMetadata ?? {};
    if (!meta.containsKey('user_type')) {
      AppLogger.auth('Google OAuth → user_type absent dans metadata → updateUser + refreshSession');
      await _supabase.auth.updateUser(
        UserAttributes(data: {'user_type': 'client', 'name': name}),
      );
      await _supabase.auth.refreshSession();
    }

    final userType = resolveUserType(_supabase.auth.currentUser?.userMetadata ?? meta);
    final token    = _supabase.auth.currentSession!.accessToken;
    AppLogger.auth('Google OAuth succès → user_type: $userType, name: $name');

    await saveSession(token, userType, name, email: user.email ?? '', isGoogle: true);
    await fetchAndSaveProfile(token);
    await saveFCMToken(token);

    return {'token': token, 'user_type': userType, 'name': name};
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

  /// Lit la session Supabase active (remplace la lecture via SharedPreferences).
  static Future<Map<String, String>?> getSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      AppLogger.auth('getSession → aucune session active');
      return null;
    }

    final user     = _supabase.auth.currentUser;
    final userType = resolveUserType(user?.userMetadata);
    final name     = (user?.userMetadata?['name'] as String?) ?? user?.email ?? '';
    AppLogger.auth('getSession → user_type: $userType, name: $name');

    return {
      'token':     session.accessToken,
      'user_type': userType,
      'name':      name,
    };
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    AppLogger.auth('Logout → effacement session + Supabase signOut');
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
