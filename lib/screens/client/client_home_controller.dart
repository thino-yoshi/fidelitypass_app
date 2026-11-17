import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/widget_service.dart';
import '../../config/api.dart';
import '../../main.dart';
import '../../config/demo_mode.dart';
import '../../utils/logger.dart';
import 'cards_tab.dart' show StampEvent;

// ── Résultats d'actions (l'UI affiche les messages à sa façon) ───────────────

enum JoinResult { added, alreadyMember, error }

class JoinMerchantResult {
  final JoinResult status;
  final String? cardId;
  final String? errorMessage;
  const JoinMerchantResult(this.status, {this.cardId, this.errorMessage});
}

// ── Controller ────────────────────────────────────────────────────────────────

class ClientHomeController extends ChangeNotifier {
  final String token;

  // ── Données exposées ────────────────────────────────────────────────────────
  List<dynamic> cards       = [];
  List<dynamic> rewards     = [];
  List<dynamic> history     = [];
  List<Map>     notifs      = [];
  int  cardCount    = 0;
  int  totalStamps  = 0;
  int  rewardCount  = 0;
  int  notifCount   = 0;
  String notifFilter = 'tout';
  bool   notifsLoaded = false;
  bool   statsLoaded  = false;

  String  userName       = '';
  String  userEmail      = '';
  String  phone          = '';
  bool    isGoogle       = false;
  bool    isOAuth        = false;
  String? profileImageUrl;
  String? profileImagePath;

  int tab     = 0;
  int prevTab = 0;

  // ── Callbacks événements (l'UI choisit comment les afficher) ────────────────
  void Function(StampEvent e)? onStampEvent;           // tampon ou récompense reçue
  void Function()? onLogout;                            // navigation vers AuthScreen
  void Function()? onNotifOpen;                        // ouvrir le panneau notifications
  void Function(JoinMerchantResult result)? onMerchantJoined; // carte ajoutée / déjà membre

  // ── Privé ───────────────────────────────────────────────────────────────────
  Timer? _keepAliveTimer;
  StreamSubscription<Uri>?     _deepLinkSub;
  StreamSubscription<dynamic>? _fcmForegroundSub;
  Uri?      _lastHandledDeepLink;
  DateTime? _lastCardsRefresh;

  static const _notifStyle = {
    'recompense': {'icon': '⭐', 'color': 0xFFFBBF24},
    'tampon':     {'icon': '✓',  'color': 0xFF2C7BE5},
    'promo':      {'icon': '→',  'color': 0xFF27AE60},
    'targeted':   {'icon': '→',  'color': 0xFF27AE60},
    'scheduled':  {'icon': '→',  'color': 0xFF27AE60},
  };

  ClientHomeController({
    required this.token,
    required String initialUserName,
    List<dynamic> initialCards     = const [],
    List<dynamic> initialHistory   = const [],
    List<dynamic> initialRewards   = const [],
    List<dynamic> initialRawNotifs = const [],
    bool fromCache = false,
  }) {
    userName = initialUserName;
    _init(
      initialCards:     initialCards,
      initialHistory:   initialHistory,
      initialRewards:   initialRewards,
      initialRawNotifs: initialRawNotifs,
      fromCache:        fromCache,
    );
  }

  void _init({
    required List<dynamic> initialCards,
    required List<dynamic> initialHistory,
    required List<dynamic> initialRewards,
    required List<dynamic> initialRawNotifs,
    required bool fromCache,
  }) {
    AppLogger.client('ClientHomeController init → userName: $userName');

    if (initialCards.isNotEmpty) {
      _applyCards(initialCards);
    } else {
      loadStats();
    }

    if (fromCache) {
      if (initialRewards.isNotEmpty) {
        rewards      = List<dynamic>.from(initialRewards);
        rewardCount  = rewards.length;
      }
      if (initialHistory.isNotEmpty) {
        history = List<dynamic>.from(initialHistory);
      }
      loadNotifs();
      Future.delayed(const Duration(milliseconds: 400), _silentRefreshAll);
    } else {
      if (initialRewards.isNotEmpty) {
        rewards     = List<dynamic>.from(initialRewards);
        rewardCount = rewards.length;
      } else {
        loadRewardsCount();
      }
      if (initialHistory.isNotEmpty) {
        history = List<dynamic>.from(initialHistory);
      } else {
        loadHistory();
      }
      if (initialRawNotifs.isNotEmpty) {
        _applyRawNotifs(initialRawNotifs);
      } else {
        loadNotifs();
      }
    }

    _loadProfileImage();
    _loadPhone();
    _loadSessionInfo();
    _checkPendingJoin();
    _initDeepLinks();
    _initNotifHandlers();

    _keepAliveTimer = Timer.periodic(const Duration(minutes: 8), (_) {
      http.get(Uri.parse(apiUrl)).catchError((_) => http.Response('', 0));
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _deepLinkSub?.cancel();
    _fcmForegroundSub?.cancel();
    notifOpenNotifier.removeListener(_onNotifOpen);
    super.dispose();
  }

  // ── Notifications ───────────────────────────────────────────────────────────

  void _initNotifHandlers() {
    notifOpenNotifier.addListener(_onNotifOpen);
    try {
      FirebaseMessaging.instance.getInitialMessage().then((msg) async {
        if (msg == null) return;
        await loadNotifs();
        if (msg.data['type'] == 'recompense') {
          setTab(0);
        } else {
          onNotifOpen?.call();
        }
      });
      _fcmForegroundSub = FirebaseMessaging.onMessage.listen((_) => loadNotifs());
      FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
        final notifId = msg.data['notification_id'] as String?;
        if (notifId != null) {
          try {
            await http.post(
              Uri.parse('$apiUrl/notifications/$notifId/opened'),
              headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? token}'},
            );
          } catch (_) {}
        }
        await loadNotifs();
        if (msg.data['type'] == 'recompense') {
          setTab(0);
        } else {
          onNotifOpen?.call();
        }
      });
    } catch (e) {
      debugPrint('[CLIENT] Firebase non dispo : $e');
    }
  }

  void _onNotifOpen() => onNotifOpen?.call();

  void _applyRawNotifs(List<dynamic> raw) {
    notifs = raw.map((n) {
      final type  = n['type'] as String? ?? 'promo';
      final style = _notifStyle[type] ?? _notifStyle['promo']!;
      final dt    = DateTime.tryParse(n['created_at'] as String? ?? '')?.toLocal();
      final time  = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '';
      return <String, dynamic>{
        'id': n['id'], 'icon': style['icon'],
        'commerce': n['merchant_name'] ?? '', 'title': n['title'] ?? '',
        'body': n['body'] ?? '', 'time': time, 'color': style['color'],
        'read': n['read'] ?? false, 'type': type, 'dt': dt,
      };
    }).cast<Map>().toList();
    notifsLoaded = true;
    notifCount   = notifs.where((n) => !(n['read'] as bool)).length;
  }

  Future<void> loadNotifs() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/notifications/client'),
        headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        notifs = data.map((n) {
          final type  = n['type'] as String? ?? 'promo';
          final style = _notifStyle[type] ?? _notifStyle['promo']!;
          final dt    = DateTime.tryParse(n['created_at'] as String? ?? '')?.toLocal();
          final time  = dt != null
              ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
              : '';
          return <String, dynamic>{
            'id': n['id'], 'icon': style['icon'],
            'commerce': n['merchant_name'] ?? '', 'title': n['title'] ?? '',
            'body': n['body'] ?? '', 'time': time, 'color': style['color'],
            'read': n['read'] ?? false, 'type': type, 'dt': dt,
          };
        }).cast<Map>().toList();
        notifsLoaded = true;
        notifCount   = notifs.where((n) => !(n['read'] as bool)).length;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (final n in notifs) n['read'] = true;
    notifCount = 0;
    notifyListeners();
    if (QartaDemo.enabled) return;
    await http.put(
      Uri.parse('$apiUrl/notifications/client/read-all'),
      headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? token}'},
    );
  }

  // ── Deep links ──────────────────────────────────────────────────────────────

  String? _merchantIdFromUri(Uri uri) {
    if (uri.scheme == 'qarta' && uri.host == 'join' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final s = uri.pathSegments;
    if (s.length >= 2 && s[0] == 'join') return s[1];
    return null;
  }

  void _initDeepLinks() {
    _deepLinkSub = AppLinks().uriLinkStream.listen((uri) {
      final id = _merchantIdFromUri(uri);
      if (id != null) joinMerchant(id);
    });
  }

  Future<void> _checkLatestDeepLink() async {
    final uri = await AppLinks().getLatestLink();
    if (uri == null || uri == _lastHandledDeepLink) return;
    _lastHandledDeepLink = uri;
    final id = _merchantIdFromUri(uri);
    if (id != null) joinMerchant(id);
  }

  Future<void> _checkPendingJoin() async {
    final merchantId = pendingJoinMerchantId;
    if (merchantId == null) return;
    pendingJoinMerchantId = null;
    await joinMerchant(merchantId);
  }

  // ── Actions publiques ───────────────────────────────────────────────────────

  Future<JoinMerchantResult> joinMerchant(String merchantId) async {
    final res = await http.post(
      Uri.parse('$apiUrl/cards/'),
      headers: {
        'Authorization': 'Bearer ${AuthService.currentToken ?? token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'merchant_id': merchantId}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final cardId = (jsonDecode(res.body) as Map<String, dynamic>?)?['id'] as String?;
      if (cardId != null) await refreshCard(cardId); else await loadStats();
      final result = JoinMerchantResult(JoinResult.added, cardId: cardId);
      onMerchantJoined?.call(result);
      return result;
    }
    if (res.statusCode == 409) {
      const result = JoinMerchantResult(JoinResult.alreadyMember);
      onMerchantJoined?.call(result);
      return result;
    }
    final result = JoinMerchantResult(JoinResult.error, errorMessage: 'Erreur ${res.statusCode}');
    onMerchantJoined?.call(result);
    return result;
  }

  Future<void> refresh() async {
    await Future.wait([loadStats(), loadHistory(), loadRewardsCount(), loadNotifs()]);
  }

  Future<void> refreshCard(String cardId) async {
    final r = await ApiService.instance.getCardDetail(cardId);
    if (r.isErr) return;
    final updated = r.value;
    final idx = cards.indexWhere((c) => c['id'] == cardId);
    if (idx >= 0) {
      cards[idx] = updated;
    } else {
      cards.insert(0, updated);
    }
    AppLogger.client('[PERF] Carte ${updated['merchants']?['business_name'] ?? cardId} actualisée');
    notifyListeners();
  }

  Future<String?> savePersonalInfo(String name, String email, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', phone);
    this.phone = phone;
    if (!QartaDemo.enabled) {
      try {
        final reqBody = <String, dynamic>{'name': name};
        if (!isOAuth) reqBody['email'] = email;
        final res = await http.patch(
          Uri.parse('$apiUrl/users/me'),
          headers: {
            'Authorization': 'Bearer ${AuthService.currentToken ?? token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(reqBody),
        );
        if (res.statusCode == 200) {
          final updated = jsonDecode(res.body);
          userEmail = updated['email'] ?? userEmail;
          userName  = updated['name']  ?? userName;
          await prefs.setString('name',  userName);
          await prefs.setString('email', userEmail);
          notifyListeners();
          return null;
        }
        return (jsonDecode(res.body) as Map?)?['detail']?.toString() ?? 'Erreur';
      } catch (_) {
        return 'Pas de connexion. Vérifie ton réseau et réessaie.';
      }
    } else {
      userName = name;
      if (!isOAuth) userEmail = email;
      notifyListeners();
      return null;
    }
  }

  Future<String?> changePassword(String current, String next) async {
    if (QartaDemo.enabled) return null;
    try {
      final res = await http.put(
        Uri.parse('$apiUrl/users/change-password'),
        headers: {
          'Authorization': 'Bearer ${AuthService.currentToken ?? token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'current_password': current, 'new_password': next}),
      );
      if (res.statusCode == 200) return null;
      return (jsonDecode(res.body) as Map?)?['detail']?.toString()
          ?? 'Le mot de passe n\'a pas pu être changé.';
    } catch (_) {
      return 'Pas de connexion. Vérifie ton réseau et réessaie.';
    }
  }

  // ignore: use_build_context_synchronously
  Future<void> pickProfileImage(BuildContext ctx) async {
    final picker  = ImagePicker();
    final picked  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recadrer',
          toolbarColor: const Color(0xFF0B1220),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Recadrer'),
      ],
    );
    if (cropped == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', cropped.path);
    profileImagePath = cropped.path;
    notifyListeners();

    try {
      final req = http.MultipartRequest('POST', Uri.parse('$apiUrl/users/profile-picture'))
        ..headers['Authorization'] = 'Bearer ${AuthService.currentToken ?? token}'
        ..files.add(await http.MultipartFile.fromPath('file', cropped.path));
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode == 200) {
        final url = jsonDecode(res.body)['profile_picture_url'] as String?;
        if (url != null) {
          await prefs.setString('profile_image_url', url);
          profileImageUrl = url;
          notifyListeners();
        }
      } else {
        AppLogger.error('Photo profil → upload échoué : ${res.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Photo profil → exception : $e');
    }
  }

  Future<void> deleteProfileImage() async {
    final prevUrl  = profileImageUrl;
    final prevPath = profileImagePath;
    profileImageUrl  = null;
    profileImagePath = null;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('profile_image_url');
      prefs.remove('profile_image_path');
    });
    http.delete(
      Uri.parse('$apiUrl/users/profile-picture'),
      headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? token}'},
    ).then((res) {
      if (res.statusCode != 200) {
        profileImageUrl  = prevUrl;
        profileImagePath = prevPath;
        notifyListeners();
      }
    }).catchError((_) {
      profileImageUrl  = prevUrl;
      profileImagePath = prevPath;
      notifyListeners();
    });
  }

  Future<void> logout() async {
    AppLogger.auth('Logout client → déconnexion');
    await AuthService.logout();
    onLogout?.call();
  }

  Future<String?> deleteAccount(String password) async {
    try {
      final res = await http.delete(
        Uri.parse('$apiUrl/users/account'),
        headers: {
          'Authorization': 'Bearer ${AuthService.currentToken ?? token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'password': password}),
      );
      if (res.statusCode == 200) {
        await logout();
        return null;
      }
      return (jsonDecode(res.body) as Map?)?['detail']?.toString()
          ?? 'Le compte n\'a pas pu être supprimé. Réessaie.';
    } catch (_) {
      return 'Pas de connexion.';
    }
  }

  // ── Navigation / tabs ───────────────────────────────────────────────────────

  void setTab(int t) {
    prevTab = tab;
    tab = t;
    notifyListeners();
  }

  void openProfil() {
    prevTab = (tab == 3 || tab == 4) ? 0 : tab;
    tab = 3;
    notifyListeners();
  }

  void openNotifs() {
    prevTab = tab;
    tab = 4;
    notifyListeners();
  }

  void closeNotifs() {
    if (notifCount > 0) markAllRead();
    tab = prevTab;
    notifyListeners();
  }

  // ── Stamp event (logique commune) ───────────────────────────────────────────

  Future<void> handleStampEvent(StampEvent e) async {
    final idx = cards.indexWhere((c) => c['id'] == e.cardId);
    if (idx >= 0) {
      final card = Map<String, dynamic>.from(cards[idx] as Map);
      if (e.reward) {
        if (e.isPoints) card['points_count'] = e.total;
        else            card['stamps_count']  = e.total;
      } else {
        if (e.isPoints) card['points_count'] = e.newCount;
        else            card['stamps_count']  = e.newCount;
      }
      card['last_scan_at'] = DateTime.now().toUtc().toIso8601String();
      cards[idx] = card;
      if (idx > 0) { final c = cards.removeAt(idx); cards.insert(0, c); }
    }
    tab = 0;
    notifyListeners();
    onStampEvent?.call(e);
  }

  // ── Chargement données ──────────────────────────────────────────────────────

  void _applyCards(List<dynamic> data) {
    int stamps = 0;
    for (final c in data) stamps += c['stamps_count'] as int? ?? 0;
    data.sort((a, b) {
      final aAt = a['last_scan_at'] as String?;
      final bAt = b['last_scan_at'] as String?;
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return bAt.compareTo(aAt);
    });
    AppLogger.client('Cartes → ${data.length} carte(s), $stamps tampon(s) total');
    cards        = data;
    cardCount    = data.length;
    totalStamps  = stamps;
    statsLoaded  = true;
    WidgetService.updateFromCards(data);
    _lastCardsRefresh = DateTime.now();
    notifyListeners();
  }

  Future<void> loadStats() async {
    final sw = Stopwatch()..start();
    final r  = await ApiService.instance.getMyCards();
    if (r.isErr) return;
    final data = r.value.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    AppLogger.client('[PERF] Cartes chargées en ${sw.elapsedMilliseconds}ms (${data.length} cartes)');
    _applyCards(data);
    _saveCardsCache(data);
  }

  Future<void> loadHistory() async {
    final sw = Stopwatch()..start();
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/my-history'),
        headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        AppLogger.client('[PERF] Historique chargé en ${sw.elapsedMilliseconds}ms (${data.length} entrées)');
        history = data;
        notifyListeners();
        _saveHistoryCache(data);
      }
    } catch (_) {}
  }

  Future<void> loadRewardsCount() async {
    final sw = Stopwatch()..start();
    final r  = await ApiService.instance.getMyRewards();
    if (r.isOk) {
      AppLogger.client('[PERF] Récompenses chargées en ${sw.elapsedMilliseconds}ms (${r.value.length})');
      rewards     = r.value;
      rewardCount = r.value.length;
      notifyListeners();
      _saveRewardsCache(r.value as List);
    }
  }

  Future<void> _silentRefreshAll() async {
    AppLogger.client('[PERF] Refresh silencieux démarré');
    final sw      = Stopwatch()..start();
    final results = await Future.wait([
      ApiService.instance.getMyCards(),
      ApiService.instance.getMyRewards(),
    ]);
    AppLogger.client('[PERF] Refresh silencieux terminé en ${sw.elapsedMilliseconds}ms');
    final cardsResult   = results[0] as dynamic;
    final rewardsResult = results[1] as dynamic;
    if (cardsResult.isOk) {
      final fresh = (cardsResult.value as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
      _applyCards(fresh);
      _saveCardsCache(fresh);
    }
    if (rewardsResult.isOk && rewardsResult.value != null) {
      final fresh = rewardsResult.value as List;
      rewards     = fresh;
      rewardCount = fresh.length;
      notifyListeners();
      _saveRewardsCache(fresh);
    }
  }

  // ── Profil ──────────────────────────────────────────────────────────────────

  Future<void> _loadProfileImage() async {
    final prefs     = await SharedPreferences.getInstance();
    final cachedUrl  = prefs.getString('profile_image_url');
    final cachedPath = prefs.getString('profile_image_path');
    if (cachedUrl  != null && cachedUrl.isNotEmpty)             profileImageUrl  = cachedUrl;
    if (cachedPath != null && File(cachedPath).existsSync())    profileImagePath = cachedPath;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/users/me'),
        headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? token}'},
      );
      if (res.statusCode == 200) {
        final body       = jsonDecode(res.body) as Map<String, dynamic>;
        final url        = body['profile_picture_url'] as String?;
        final email      = body['email']  as String? ?? '';
        final serverName = body['name']   as String? ?? '';
        final serverGoogle = body['is_google'] as bool? ?? false;
        final localGoogle  = prefs.getBool('is_google') ?? false;
        final ig = serverGoogle || localGoogle;
        final io = (body['is_oauth'] as bool? ?? false) || ig;
        if (url   != null && url.isNotEmpty)   await prefs.setString('profile_image_url', url);
        if (email.isNotEmpty)                  await prefs.setString('email', email);
        if (serverName.isNotEmpty)             await prefs.setString('name', serverName);
        await prefs.setBool('is_google', ig);
        await prefs.setBool('is_oauth',  io);
        if (url   != null && url.isNotEmpty)   profileImageUrl = url;
        if (email.isNotEmpty)                  userEmail = email;
        if (serverName.isNotEmpty)             userName  = serverName;
        isGoogle = ig;
        isOAuth  = io;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    phone = prefs.getString('user_phone') ?? '';
    notifyListeners();
  }

  Future<void> _loadSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    final ig    = prefs.getBool('is_google') ?? false;
    final io    = prefs.getBool('is_oauth')  ?? ig;
    if (email.isNotEmpty) userEmail = email;
    if (ig) isGoogle = true;
    if (io) isOAuth  = true;
    notifyListeners();
  }

  // ── Cache ───────────────────────────────────────────────────────────────────

  Future<void> _saveCardsCache(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_client_cards', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _saveRewardsCache(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_client_rewards', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _saveHistoryCache(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_client_history', jsonEncode(data));
    } catch (_) {}
  }

  // ── App lifecycle ───────────────────────────────────────────────────────────

  Future<void> onAppResumed() async {
    _checkLatestDeepLink();
    final now   = DateTime.now();
    final stale = _lastCardsRefresh == null ||
        now.difference(_lastCardsRefresh!).inSeconds >= 30;
    if (stale) {
      await Future.delayed(const Duration(milliseconds: 350));
      AppLogger.client('App revenue au premier plan → refresh cartes + récompenses');
      await Future.wait([loadStats(), loadRewardsCount(), loadNotifs()]);
    } else {
      await loadNotifs();
    }
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  String get firstName {
    final parts = userName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : userName;
  }

  String get initials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
  }
}
