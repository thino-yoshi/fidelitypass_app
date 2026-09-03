import 'package:flutter/material.dart';
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
import 'config/supabase_config.dart';
import 'config/api.dart';
import 'screens/auth_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/merchant/merchant_home.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'utils/logger.dart';
import 'utils/platform_route.dart';

/// Merchant ID en attente (deep link reçu avant que l'utilisateur soit connecté)
String? pendingJoinMerchantId;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase (avant Firebase) ──────────────────────────────────────────────
  AppLogger.splash('Démarrage app — init Supabase...');
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  AppLogger.splash('Supabase initialisé ✓');

  try {
    AppLogger.splash('Init Firebase...');
    await Firebase.initializeApp();

    // Init local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: initializationSettingsAndroid),
    );

    // Demander permission notifications Android 13+
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    AppLogger.splash('Firebase initialisé ✓');
    AppLogger.fcm('Demande permission notifications...');

    // Afficher les notifs en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.fcm('Message reçu en foreground : ${message.notification?.title}');
      flutterLocalNotificationsPlugin.show(
        0,
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
          textTheme: GoogleFonts.soraTextTheme(
            ThemeData(brightness: Brightness.light).textTheme,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF2C7BE5),
          scaffoldBackgroundColor: const Color(0xFF0B1220),
          cardColor: const Color(0xFF0F1E35),
          textTheme: GoogleFonts.soraTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
          ),
        ),
        home: const SplashRouter(),
      ),
    );
  }
}

// Données préchargées pendant le splash
class _PreloadedData {
  final Map<String, dynamic>? session;
  // Client
  final List<dynamic> cards;
  final List<dynamic> history;
  // Merchant
  final Map? merchantProfile;
  final Map? merchantStats;
  final List<dynamic> recentClients;
  final List<dynamic> daily;
  final List<dynamic> scanHistory;
  final Map? cardDesign;

  _PreloadedData({
    required this.session,
    this.cards           = const [],
    this.history         = const [],
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
      Future.delayed(const Duration(milliseconds: 1800)),
    ]).then((_) {
      if (mounted) _onSplashComplete();
    });
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    // Lien initial (app ouverte via deep link avant que ClientHome soit monté)
    final initial = await appLinks.getInitialLink();
    if (initial != null) _storeDeepLink(initial);
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
    final session = await AuthService.getSession();
    if (session == null) {
      return _PreloadedData(session: null);
    }
    AuthService.saveFCMToken(session['token']!);
    AppLogger.splash('Session → user_type: ${session['user_type']}, name: ${session['name']}');

    // ── Commerçant : 6 appels en parallèle ──────────────────────────────────
    if (session['user_type'] == 'merchant') {
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

    // ── Client : cartes + historique en parallèle ────────────────────────────
    if (session['user_type'] == 'client') {
      final token = session['token']!;
      final results = await Future.wait([
        ApiService.instance.getMyCards(),
        _fetchHistory(token),
      ]);

      final cardsResult = results[0] as dynamic;
      final history     = results[1] as List<dynamic>;

      List<dynamic> cards = [];
      if (cardsResult.isOk) {
        cards = (cardsResult.value as List)
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();
        AppLogger.splash('Cartes préchargées → ${cards.length} carte(s)');
      }

      return _PreloadedData(session: session, cards: cards, history: history);
    }

    return _PreloadedData(session: session);
  }

  Future<List<dynamic>> _fetchHistory(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/my-history'),
        headers: {'Authorization': 'Bearer $token'},
      );
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
      Navigator.pushReplacement(
          context, platformRoute(builder: (_) => const AuthScreen()));
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
              )));
    } else {
      AppLogger.nav('Redirection → ClientHome (${session['name']})');
      Navigator.pushReplacement(context, platformRoute(
          builder: (_) => ClientHome(
                token: session['token']!,
                userName: session['name']!,
                initialCards: data.cards,
                initialHistory: data.history,
              )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
