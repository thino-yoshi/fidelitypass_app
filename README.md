# Qarta — App Mobile

Application Flutter de fidélité digitale. Deux portails : clients (collecter des tampons) et commerçants (scanner, gérer, analyser).

## Stack

- **Flutter** (Dart) — iOS + Android
- **Firebase** — notifications push (FCM)
- **Google Sign-In** — authentification Google
- **mobile_scanner** — lecture QR codes
- **fl_chart** — graphiques statistiques

## Installation

```bash
# Installer les dépendances
flutter pub get

# Lancer (pointe sur prod par défaut)
flutter run

# Lancer en dev (localhost:8000)
flutter run --dart-define=ENV=dev

# Lancer en staging
flutter run --dart-define=ENV=staging
```

## Configuration requise

1. **Firebase** — placer `android/app/google-services.json` (Android) et `ios/Runner/GoogleService-Info.plist` (iOS)
2. **URL API** — définie dans `lib/config/api.dart` via `--dart-define=ENV=dev|staging|prod`
3. **Google Sign-In Android** — enregistrer le SHA-1 dans Firebase Console

Voir `.env.example` pour le détail complet.

## Structure

```
lib/
├── main.dart                    # Point d'entrée, Firebase, thème, navigatorKey
├── config/api.dart              # URL API selon environnement
├── services/
│   ├── auth_service.dart        # Auth + wrappers HTTP (timeout, 401, erreurs réseau)
│   └── widget_service.dart      # Widget Android home screen
└── screens/
    ├── splash_screen.dart
    ├── auth_screen.dart
    ├── client/
    │   ├── client_home.dart
    │   ├── cards_tab.dart       # QR dynamique avec refresh auto 60s
    │   ├── history_tab.dart
    │   └── stores_tab.dart
    └── merchant/
        ├── merchant_home.dart
        ├── scanner_screen.dart
        ├── program_screen.dart
        ├── clients_screen.dart
        ├── notifications_screen.dart
        ├── static_qr_screen.dart
        └── chart_widget.dart
```

## Build production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```
