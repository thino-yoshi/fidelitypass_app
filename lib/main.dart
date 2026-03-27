import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/auth_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/merchant/merchant_home.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Init local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  // Demander permission notifications Android 13+
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Afficher les notifs en foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('🔔 Notif reçue en foreground: ${message.notification?.title}');
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
    return MaterialApp(
      title: 'Qarta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      home: const SplashRouter(),
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
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const AuthScreen()));
          return;
        }
        if (session['user_type'] == 'merchant') {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => MerchantHome(
                token: session['token']!,
                merchantName: session['name']!,
              )));
        } else {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => ClientHome(
                token: session['token']!,
                userName: session['name']!,
              )));
        }
      },
    );
  }
}