import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

// ─── Résultat typé ────────────────────────────────────────────────────────────

class ApiResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResult._({this.data, this.error, this.statusCode});

  factory ApiResult.ok(T data) => ApiResult._(data: data);
  factory ApiResult.err(String message, {int? code}) =>
      ApiResult._(error: message, statusCode: code);

  bool get isOk  => error == null;
  bool get isErr => error != null;

  /// Récupère la donnée en supposant que isOk == true.
  T get value => data as T;
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Singleton — utilise toujours le token Supabase le plus récent via AuthService.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _timeout = Duration(seconds: 10);

  // Token toujours frais (Supabase SDK gère le refresh automatiquement)
  String get _token => AuthService.currentToken ?? '';

  Map<String, String> get _h => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  Map<String, String> get _hGet => {'Authorization': 'Bearer $_token'};

  // ── Méthodes HTTP de base ──────────────────────────────────────────────────

  Future<ApiResult<dynamic>> _get(String path) async {
    final sw = Stopwatch()..start();
    try {
      AppLogger.api('GET $path');
      final res = await http
          .get(Uri.parse('$apiUrl$path'), headers: _hGet)
          .timeout(_timeout);
      return _parse(res, sw);
    } catch (e) {
      return ApiResult.err(_netMsg(e, path));
    }
  }

  Future<ApiResult<dynamic>> _post(String path, Map<String, dynamic> body) async {
    final sw = Stopwatch()..start();
    try {
      AppLogger.api('POST $path');
      final res = await http
          .post(Uri.parse('$apiUrl$path'), headers: _h, body: jsonEncode(body))
          .timeout(_timeout);
      return _parse(res, sw);
    } catch (e) {
      return ApiResult.err(_netMsg(e, path));
    }
  }

  Future<ApiResult<dynamic>> _delete(String path) async {
    final sw = Stopwatch()..start();
    try {
      AppLogger.api('DELETE $path');
      final res = await http
          .delete(Uri.parse('$apiUrl$path'), headers: _hGet)
          .timeout(_timeout);
      return _parse(res, sw);
    } catch (e) {
      return ApiResult.err(_netMsg(e, path));
    }
  }

  ApiResult<dynamic> _parse(http.Response res, Stopwatch sw) {
    final ms = sw.elapsedMilliseconds;
    final method = res.request?.method ?? '?';
    final path = res.request?.url.path ?? '';
    if (res.statusCode >= 200 && res.statusCode < 300) {
      AppLogger.api('$method $path → ${res.statusCode} ✓ (${ms}ms)');
    } else {
      AppLogger.error('$method $path → ${res.statusCode} (${ms}ms) — ${res.body}');
    }

    if (res.statusCode == 401) {
      AppLogger.error('401 sur $path → logout forcé');
      AuthService.logout();
      return ApiResult.err('Session expirée — reconnectez-vous', code: 401);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final body = res.body.trim();
        return ApiResult.ok(body.isEmpty ? null : jsonDecode(body));
      } catch (_) {
        return ApiResult.ok(null);
      }
    }
    try {
      final detail = jsonDecode(res.body)['detail'] as String?;
      return ApiResult.err(detail ?? 'Erreur ${res.statusCode}', code: res.statusCode);
    } catch (_) {
      return ApiResult.err('Erreur ${res.statusCode}', code: res.statusCode);
    }
  }

  String _netMsg(Object e, String path) {
    AppLogger.error('Réseau $path → $e');
    if (e is SocketException) return 'Pas de connexion internet';
    if (e.toString().contains('TimeoutException')) return 'Le serveur ne répond pas';
    return 'Erreur réseau';
  }

  // ── COMMERÇANT ─────────────────────────────────────────────────────────────

  /// Profil du commerçant connecté (via /merchants/me).
  Future<ApiResult<Map<String, dynamic>>> getMerchantProfile() async {
    AppLogger.api('token présent: ${_token.isNotEmpty} / longueur: ${_token.length}');
    final r = await _get('/merchants/me');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Met à jour les infos publiques du commerce (écran Info commerce).
  Future<ApiResult<Map<String, dynamic>>> saveMerchantInfo(Map<String, dynamic> info) async {
    final r = await _post('/merchants/me/info', info);
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Crée ou met à jour le design visuel de la carte fidélité.
  Future<ApiResult<Map<String, dynamic>>> saveCardDesign(Map<String, dynamic> design) async {
    final r = await _post('/merchants/me/card-design', {'card_design': design});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Design de carte du commerçant (créé sur qarta.be) — { card_design, updated_at }.
  /// Retourne null dans la donnée si aucun design n'a encore été créé (404).
  Future<ApiResult<Map<String, dynamic>?>> getMerchantCardDesign() async {
    final r = await _get('/merchants/me/card-design');
    if (r.isErr) {
      // 404 = pas de design → on renvoie ok(null) pour ne pas casser l'écran
      if (r.statusCode == 404) return ApiResult.ok(null);
      return ApiResult.err(r.error!);
    }
    return ApiResult.ok(r.data as Map<String, dynamic>?);
  }

  /// Stats globales (clients, tampons, récompenses, scans).
  Future<ApiResult<Map<String, dynamic>>> getMerchantStats() async {
    final r = await _get('/cards/stats');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Liste des clients fidélité du commerçant.
  Future<ApiResult<List<dynamic>>> getMerchantClients({int limit = 50, int offset = 0}) async {
    final r = await _get('/cards/clients?limit=$limit&offset=$offset');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as List<dynamic>);
  }

  /// QR code statique du commerçant (généré automatiquement si absent).
  Future<ApiResult<String>> getStaticQR() async {
    final r = await _get('/merchants/me/static-qr');
    if (r.isErr) return ApiResult.err(r.error!);
    final token = (r.data as Map<String, dynamic>)['static_qr_token'] as String?;
    if (token == null) return ApiResult.err('Token QR introuvable');
    return ApiResult.ok(token);
  }

  /// Récompenses bonus configurées par le commerçant.
  Future<ApiResult<List<dynamic>>> getMerchantRewards() async {
    final r = await _get('/merchants/me/rewards');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as List<dynamic>);
  }

  /// Ajouter une récompense bonus.
  Future<ApiResult<Map<String, dynamic>>> addMerchantReward(
      int stamps, String description) async {
    final r = await _post('/merchants/me/rewards',
        {'stamps_required': stamps, 'description': description});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Supprimer une récompense bonus.
  Future<ApiResult<void>> deleteMerchantReward(String id) async {
    final r = await _delete('/merchants/me/rewards/$id');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(null);
  }

  /// Créer ou mettre à jour le programme de fidélité.
  Future<ApiResult<Map<String, dynamic>>> setupMerchant(
      Map<String, dynamic> data) async {
    final r = await _post('/merchants/setup', data);
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Ajouter ou retirer un tampon manuellement (delta = +1 ou -1).
  Future<ApiResult<Map<String, dynamic>>> adjustStamp(
      String cardId, int delta) async {
    final r = await _post('/cards/$cardId/adjust-stamp', {'delta': delta});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Note privée du commerçant sur un client (stockée sur sa carte).
  Future<ApiResult<void>> saveClientNote(String cardId, String note) async {
    final r = await _post('/cards/$cardId/note', {'note': note});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(null);
  }

  /// Historique des scans du commerçant.
  Future<ApiResult<List<dynamic>>> getMerchantScanHistory() async {
    final r = await _get('/cards/scan-history');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as List<dynamic>);
  }

  /// Statistiques journalières sur 30 jours.
  Future<ApiResult<List<dynamic>>> getDailyStats() async {
    final r = await _get('/cards/stats/daily');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as List<dynamic>);
  }

  /// Scanner le QR dynamique d'un client pour ajouter un tampon.
  Future<ApiResult<Map<String, dynamic>>> scanQR(String qrToken) async {
    final r = await _post('/scan/', {'qr_token': qrToken});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Identifie le client d'un QR SANS ajouter de tampon (le commerçant choisit
  /// ensuite combien ajouter via adjustStamp).
  Future<ApiResult<Map<String, dynamic>>> resolveScan(String qrToken) async {
    final r = await _post('/scan/resolve', {'qr_token': qrToken});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  // ── CLIENT ─────────────────────────────────────────────────────────────────

  /// Toutes les cartes fidélité du client connecté.
  Future<ApiResult<List<dynamic>>> getMyCards() async {
    final r = await _get('/cards/me');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as List<dynamic>);
  }

  /// Rejoindre un programme de fidélité via le QR statique du commerçant.
  Future<ApiResult<Map<String, dynamic>>> joinMerchant(String staticQrToken) async {
    final r = await _post('/cards/join', {'static_qr_token': staticQrToken});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Polling léger : retourne état actuel de la carte + horodatage du dernier scan.
  Future<ApiResult<Map<String, dynamic>>> pollCard(String cardId) async {
    final r = await _get('/cards/$cardId/poll');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Token QR dynamique (expire en 60s) pour qu'un commerçant scanne.
  Future<ApiResult<Map<String, dynamic>>> getDynamicQR(String cardId) async {
    final r = await _get('/cards/qr/$cardId');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Historique des scans du client connecté.
  Future<ApiResult<List<dynamic>>> getClientHistory() async {
    final r = await _get('/cards/my-history');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as List<dynamic>);
  }

  // ── RÉCOMPENSES (portefeuille) ───────────────────────────────────────────────

  /// Récompenses disponibles du client (triées de la plus ancienne à la récente).
  Future<ApiResult<List<dynamic>>> getMyRewards() async {
    final r = await _get('/rewards/me');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as List<dynamic>);
  }

  /// QR dynamique d'une récompense (pour la faire valider au commerce).
  Future<ApiResult<Map<String, dynamic>>> getRewardQR(String rewardId) async {
    final r = await _get('/rewards/$rewardId/qr');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// Le commerçant valide une récompense scannée.
  Future<ApiResult<Map<String, dynamic>>> redeemReward(String qrToken) async {
    final r = await _post('/rewards/redeem', {'qr_token': qrToken});
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  // ── WALLET ─────────────────────────────────────────────────────────────────

  /// JWT Google Wallet pour Android → ouvrir pay.google.com/gp/v/save/{jwt}
  Future<ApiResult<Map<String, dynamic>>> getGoogleWalletJwt(String cardId) async {
    final r = await _get('/cards/$cardId/wallet/google');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  /// URL .pkpass temporaire (5 min) pour iOS → ouvrir dans Safari
  Future<ApiResult<Map<String, dynamic>>> getAppleWalletUrl(String cardId) async {
    final r = await _get('/cards/$cardId/wallet/apple-url');
    if (r.isErr) return ApiResult.err(r.error!);
    return ApiResult.ok(r.data as Map<String, dynamic>);
  }

  // ── Helpers UI ─────────────────────────────────────────────────────────────

  /// Affiche un snackbar d'erreur si [result] est en erreur. Retourne isOk.
  static bool showErrIfNeeded<T>(
      BuildContext context, ApiResult<T> result) {
    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error!),
        backgroundColor: const Color(0xFFE24B4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
    return result.isOk;
  }
}
