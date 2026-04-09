import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/merchant/merchant_home.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Charger la préférence de thème
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // Init local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  // Demander permission notifications Android 13+
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Afficher les notifs en foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
          fontFamily: 'Roboto',
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF2C7BE5),
        ),
        darkTheme: ThemeData(
          fontFamily: 'Roboto',
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF2C7BE5),
          scaffoldBackgroundColor: const Color(0xFF0F1923),
          cardColor: const Color(0xFF1A2535),
        ),
        home: const SplashRouter(),
      ),
    );
  }
}

class SplashRouter extends StatelessWidget {
  const SplashRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      onComplete: () async {
        final session = await AuthService.getSession();
        if (!context.mounted) return;
        if (session == null) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const AuthScreen()));
          return;
        }
        if (session['user_type'] == 'merchant') {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => MerchantHome(
                        token: session['token']!,
                        merchantName: session['name']!,
                      )));
        } else {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => ClientHome(
                        token: session['token']!,
                        userName: session['name']!,
                      )));
        }
      },
    );
  }
}
