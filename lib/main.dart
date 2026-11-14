import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'config/supabase_config.dart';
import 'config/api.dart';
import 'screens/auth_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/merchant/merchant_home.dart';
import 'screens/merchant/merchant_tokens.dart' show kIsIOS;
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen_ios.dart' show SplashIos;
import 'utils/logger.dart';
import 'utils/platform_route.dart';
import 'firebase_options.dart';

/// Merchant ID en attente (deep link reçu avant que l'utilisateur soit connecté)
String? pendingJoinMerchantId;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final themeNotifier    = ValueNotifier<ThemeMode>(ThemeMode.light);
final navigatorKey     = GlobalKey<NavigatorState>();
final notifOpenNotifier = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Pre-warm Railway dès que possible (fire-and-forget)
  // Railway cold start peut prendre 5-9s — on lance le ping pendant Supabase+Firebase init
  http.get(Uri.parse(apiUrl)).catchError((_) => http.Response('', 0));

  // ── Supabase + Firebase en parallèle ─────────────────────────────────────
  AppLogger.splash('Démarrage app — init Supabase + Firebase...');
  await Future.wait([
    Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .then<void>((_) {})
        .catchError((_) {}),
  ]);
  AppLogger.splash('Supabase + Firebase initialisés ✓');

  try {
    // Init local notifications (dépend de Firebase)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      ),
    );

    AppLogger.splash('Notifications initialisées ✓');

    // Demande de permission et config foreground après runApp (évite crash watchdog iOS)
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final notifPush = prefs.getBool('notif_push') ?? true;
        final messaging = FirebaseMessaging.instance;
        if (notifPush) {
          await messaging.requestPermission(alert: true, badge: true, sound: true);
          await messaging.setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true,
          );
          AppLogger.fcm('Permission notifications accordée ✓');
        } else {
          // Push désactivé par l'utilisateur → couper l'affichage foreground
          await messaging.setForegroundNotificationPresentationOptions(
            alert: false, badge: false, sound: false,
          );
          AppLogger.fcm('Push désactivé par préférence utilisateur');
        }
      } catch (e) {
        AppLogger.error('Erreur permission notifications : $e');
      }
    });

    // Tap sur notif quand l'app est en background → ouvrir le panel notifs
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      notifOpenNotifier.value++;
    });

    // Afficher les notifs en foreground (Android uniquement — iOS gère via setForegroundNotificationPresentationOptions)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.fcm('Message reçu en foreground : ${message.notification?.title}');
      if (Platform.isAndroid) {
        flutterLocalNotificationsPlugin.show(
          message.messageId?.hashCode ?? 0,
          message.notification?.title,
          message.notification?.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'qarta_channel',
              'Qarta Notifications',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  } catch (e) {
    AppLogger.error('Firebase non disponible (émulateur ?) — notifs push désactivées : $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  AppLogger.splash('Thème chargé : ${isDark ? "dark" : "light"}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Qarta',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF2C7BE5),
          scaffoldBackgroundColor: const Color(0xFFF4F2EE),
          // iPhone : police du système (SF Pro). Android : Sora, inchangé.
          textTheme: kIsIOS
              ? null
              : GoogleFonts.soraTextTheme(ThemeData(brightness: Brightness.light).textTheme),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF2C7BE5),
          scaffoldBackgroundColor: const Color(0xFF0B1220),
          cardColor: const Color(0xFF0F1E35),
          textTheme: kIsIOS
              ? null
              : GoogleFonts.soraTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
        ),
        home: const SplashRouter(),
      ),
    );
  }
}

// Données préchargées pendant le splash
class _PreloadedData {
  final Map<String, dynamic>? session;
  final bool fromCache;
  // Client
  final List<dynamic> cards;
  final List<dynamic> history;
  final List<dynamic> rewards;
  final List<dynamic> rawNotifs;
  // Merchant
  final Map? merchantProfile;
  final Map? merchantStats;
  final List<dynamic> recentClients;
  final List<dynamic> daily;
  final List<dynamic> scanHistory;
  final Map? cardDesign;

  _PreloadedData({
    required this.session,
    this.fromCache       = false,
    this.cards           = const [],
    this.history         = const [],
    this.rewards         = const [],
    this.rawNotifs       = const [],
    this.merchantProfile,
    this.merchantStats,
    this.recentClients   = const [],
    this.daily           = const [],
    this.scanHistory     = const [],
    this.cardDesign,
  });
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  late Future<_PreloadedData> _preloadFuture;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _preloadFuture = _preload();
    Future.wait([
      _preloadFuture,
      Future.delayed(const Duration(milliseconds: 600)),
    ]).then((_) {
      if (mounted) _onSplashComplete();
    });
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    // Lien initial (app ouverte via deep link avant que SplashRouter soit monté)
    final initial = await appLinks.getInitialLink();
    if (initial != null) _handleDeepLink(initial);
    // Stream pour les liens reçus pendant que l'app tourne (OAuth callback inclus)
    _linkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    // Callback OAuth Supabase (Google / Apple) → passer à Supabase pour compléter la session
    if (uri.host == 'login-callback') {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
      return;
    }
    _storeDeepLink(uri);
  }

  void _storeDeepLink(Uri uri) {
    String? merchantId;
    if (uri.scheme == 'qarta' && uri.host == 'join' && uri.pathSegments.isNotEmpty) {
      merchantId = uri.pathSegments.first;
    } else {
      final s = uri.pathSegments;
      if (s.length >= 2 && s[0] == 'join') merchantId = s[1];
    }
    if (merchantId != null) {
      pendingJoinMerchantId = merchantId;
      AppLogger.nav('Deep link stocké → merchant: $merchantId');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<_PreloadedData> _preload() async {
    final swTotal = Stopwatch()..start();
    final session = await AuthService.getSession();
    AppLogger.splash('[PERF] Session chargée en ${swTotal.elapsedMilliseconds}ms');
    if (session == null) {
      return _PreloadedData(session: null);
    }
    AuthService.saveFCMToken(session['token']!);
    AppLogger.splash('Session → user_type: ${session['user_type']}, name: ${session['name']}');

    // ── Commerçant : cache-first ────────────────────────────────────────────
    if (session['user_type'] == 'merchant') {
      final prefs = await SharedPreferences.getInstance();
      final cachedMerchantJson = prefs.getString('cache_merchant_data');
      if (cachedMerchantJson != null) {
        try {
          final swCache = Stopwatch()..start();
          final c = jsonDecode(cachedMerchantJson) as Map<String, dynamic>;
          AppLogger.splash('[PERF] Cache merchant lu en ${swCache.elapsedMilliseconds}ms ⚡ → ${c['profile']?['business_name']}');
          AppLogger.splash('[PERF] Temps total splash (avec cache) : ${swTotal.elapsedMilliseconds}ms');
          return _PreloadedData(
            session:         session,
            merchantProfile: c['profile'] as Map?,
            merchantStats:   c['stats'] as Map?,
            recentClients:   (c['clients'] as List? ?? []),
            daily:           (c['daily'] as List? ?? []),
            scanHistory:     (c['scanHistory'] as List? ?? []),
            cardDesign:      c['cardDesign'] as Map?,
            fromCache:       true,
          );
        } catch (_) {
          prefs.remove('cache_merchant_data');
        }
      }

      // Pas de cache → 6 appels en parallèle
      final results = await Future.wait([
        ApiService.instance.getMerchantProfile(),       // [0]
        ApiService.instance.getMerchantStats(),          // [1]
        ApiService.instance.getMerchantClients(),           // [2] tous les clients
        ApiService.instance.getDailyStats(),             // [3]
        ApiService.instance.getMerchantScanHistory(),    // [4]
        ApiService.instance.getMerchantCardDesign(),     // [5]
      ]);

      Map? merchantProfile;
      Map? merchantStats;
      List<dynamic> recentClients = [];
      List<dynamic> daily         = [];
      List<dynamic> scanHistory   = [];
      Map? cardDesign;

      final r0 = results[0] as dynamic;
      if (r0.isOk && r0.value != null) merchantProfile = r0.value as Map;

      final r1 = results[1] as dynamic;
      if (r1.isOk && r1.value != null) merchantStats = r1.value as Map;

      final r2 = results[2] as dynamic;
      if (r2.isOk && r2.value != null) recentClients = r2.value as List;

      final r3 = results[3] as dynamic;
      if (r3.isOk && r3.value != null) daily = r3.value as List;

      final r4 = results[4] as dynamic;
      if (r4.isOk && r4.value != null) scanHistory = r4.value as List;

      final r5 = results[5] as dynamic;
      if (r5.isOk && r5.value != null) {
        cardDesign = (r5.value as Map?)?['card_design'] as Map?;
      }

      AppLogger.splash('Merchant préchargé → ${merchantProfile?['business_name']}, ${recentClients.length} clients, ${daily.length} jours');
      // Sauvegarder pour le prochain lancement
      if (merchantProfile != null) {
        prefs.setString('cache_merchant_data', jsonEncode({
          'profile':     merchantProfile,
          'stats':       merchantStats,
          'clients':     recentClients,
          'daily':       daily,
          'scanHistory': scanHistory,
          'cardDesign':  cardDesign,
        }));
      }
      return _PreloadedData(
        session:         session,
        merchantProfile: merchantProfile,
        merchantStats:   merchantStats,
        recentClients:   recentClients,
        daily:           daily,
        scanHistory:     scanHistory,
        cardDesign:      cardDesign,
      );
    }

    // ── Client : cache-first ────────────────────────────────────────────────
    if (session['user_type'] == 'client') {
      final token = session['token']!;
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cache_client_cards');

      // Cache disponible → affichage instantané
      if (cachedJson != null) {
        try {
          final swCache = Stopwatch()..start();
          final cachedCards   = (jsonDecode(cachedJson) as List)
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
          final cachedRewardsJson = prefs.getString('cache_client_rewards');
          final cachedHistoryJson = prefs.getString('cache_client_history');
          final cachedRewards = cachedRewardsJson != null
              ? jsonDecode(cachedRewardsJson) as List : <dynamic>[];
          final cachedHistory = cachedHistoryJson != null
              ? jsonDecode(cachedHistoryJson) as List : <dynamic>[];
          AppLogger.splash('[PERF] Cache client lu en ${swCache.elapsedMilliseconds}ms ⚡ → ${cachedCards.length} cartes, ${cachedRewards.length} récompenses, ${cachedHistory.length} historique');
          AppLogger.splash('[PERF] Temps total splash (avec cache) : ${swTotal.elapsedMilliseconds}ms');
          return _PreloadedData(
            session: session,
            cards: cachedCards,
            rewards: cachedRewards,
            history: cachedHistory,
            fromCache: true,
          );
        } catch (_) {
          prefs.remove('cache_client_cards');
          prefs.remove('cache_client_rewards');
          prefs.remove('cache_client_history');
        }
      }

      // Pas de cache (premier lancement) → 4 appels en parallèle
      final swApi = Stopwatch()..start();
      final results = await Future.wait([
        ApiService.instance.getMyCards(),  // [0]
        _fetchHistory(token),              // [1]
        ApiService.instance.getMyRewards(), // [2]
        _fetchNotifs(token),               // [3]
      ]);
      AppLogger.splash('[PERF] 4 appels API parallèles client en ${swApi.elapsedMilliseconds}ms');

      final cardsResult   = results[0] as dynamic;
      final history       = results[1] as List<dynamic>;
      final rewardsResult = results[2] as dynamic;
      final rawNotifs     = results[3] as List<dynamic>;

      List<dynamic> cards   = [];
      List<dynamic> rewards = [];
      if (cardsResult.isOk) {
        cards = (cardsResult.value as List)
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();
        AppLogger.splash('Cartes préchargées → ${cards.length} carte(s)');
        // Sauvegarder pour le prochain lancement
        prefs.setString('cache_client_cards', jsonEncode(cards));
      }
      if (rewardsResult.isOk && rewardsResult.value != null) {
        rewards = rewardsResult.value as List;
        AppLogger.splash('Récompenses préchargées → ${rewards.length} récompense(s)');
        prefs.setString('cache_client_rewards', jsonEncode(rewards));
      }
      if (history.isNotEmpty) {
        prefs.setString('cache_client_history', jsonEncode(history));
      }
      AppLogger.splash('Notifs préchargées → ${rawNotifs.length} notif(s)');
      AppLogger.splash('[PERF] Temps total splash (premier lancement) : ${swTotal.elapsedMilliseconds}ms');

      return _PreloadedData(
        session: session,
        cards: cards,
        history: history,
        rewards: rewards,
        rawNotifs: rawNotifs,
      );
    }

    return _PreloadedData(session: session);
  }

  Future<List<dynamic>> _fetchHistory(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/my-history'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) return jsonDecode(res.body) as List;
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchNotifs(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/notifications/client'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) return jsonDecode(res.body) as List;
    } catch (_) {}
    return [];
  }

  void _onSplashComplete() async {
    // Attendre le préchargement si pas encore fini
    final data = await _preloadFuture;
    if (!mounted) return;

    final session = data.session;
    if (session == null) {
      AppLogger.nav('Aucune session → AuthScreen');
      // iPhone : fondu doux du chargement vers l'accueil (même fond bleu nuit).
      Navigator.pushReplacement(context, kIsIOS
          ? PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),
              pageBuilder: (_, __, ___) => const AuthScreen(),
              transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child))
          : platformRoute(builder: (_) => const AuthScreen()));
      return;
    }

    if (session['user_type'] == 'merchant') {
      AppLogger.nav('Redirection → MerchantHome (${session['name']})');
      Navigator.pushReplacement(context, platformRoute(
          builder: (_) => MerchantHome(
                token:               session['token']!,
                merchantName:        session['name']!,
                initialProfile:      data.merchantProfile,
                initialStats:        data.merchantStats,
                initialRecentClients: data.recentClients,
                initialDaily:        data.daily,
                initialScanHistory:  data.scanHistory,
                initialCardDesign:   data.cardDesign,
                fromCache:           data.fromCache,
              )));
    } else {
      AppLogger.nav('Redirection → ClientHome (${session['name']})');
      Navigator.pushReplacement(context, platformRoute(
          builder: (_) => ClientHome(
                token: session['token']!,
                userName: session['name']!,
                initialCards: data.cards,
                initialHistory: data.history,
                initialRewards: data.rewards,
                initialRawNotifs: data.rawNotifs,
                fromCache: data.fromCache,
              )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return kIsIOS ? const SplashIos() : const SplashScreen();
  }
}
