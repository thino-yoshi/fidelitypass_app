# Documentation Setup iOS — Qarta (com.yassin.qarta)

> Document de référence technique. À consulter en cas de problème avec Firebase, Google Sign-In, Apple Sign-In ou les notifications push.

---

## 1. Contexte

L'app Qarta a deux bundle IDs dans l'historique du projet :

| Bundle ID | Usage |
|---|---|
| `com.yassin.fidelitypassapp` | **Ancien** — app originale, ne plus utiliser |
| `com.yassin.qarta` | **Actuel** — bundle ID de production |

Beaucoup de problèmes rencontrés venaient du fait que la configuration Firebase pointait encore sur l'ancien bundle ID.

---

## 2. GoogleService-Info.plist

### Fichier correct (com.yassin.qarta)

Emplacement dans le projet : `ios/Runner/GoogleService-Info.plist`

Valeurs clés à vérifier :

```xml
<key>CLIENT_ID</key>
<string>1097051657980-dqrn9vb9r0jb5kbqm60bq45d4itlgulo.apps.googleusercontent.com</string>

<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.1097051657980-dqrn9vb9r0jb5kbqm60bq45d4itlgulo</string>

<key>BUNDLE_ID</key>
<string>com.yassin.qarta</string>

<key>GOOGLE_APP_ID</key>
<string>1:1097051657980:ios:dacf15029d24c61d8d6979</string>

<key>GCM_SENDER_ID</key>
<string>1097051657980</string>

<key>PROJECT_ID</key>
<string>fidelitypass-c4a88</string>

<key>API_KEY</key>
<string>AIzaSyDDqXH6l3yrHdxLckGvt7Nn1rVfAq0sFKo</string>
```

### Comment vérifier que le bon plist est en place

```bash
grep -A 1 BUNDLE_ID ~/Documents/fidelitypass_app_github/ios/Runner/GoogleService-Info.plist
```

Doit afficher : `<string>com.yassin.qarta</string>`

### Où télécharger le plist

Firebase Console → projet `fidelitypass-c4a88` → Paramètres → Général → **Applications Apple** → app **qarta / com.yassin.qarta** → bouton "GoogleService-Info.plist"

---

## 3. Info.plist — URL Schemes Google

Emplacement : `ios/Runner/Info.plist`

### Valeurs à vérifier dans Xcode

| Clé | Valeur correcte |
|---|---|
| `GIDClientID` | `1097051657980-dqrn9vb9r0jb5kbqm60bq45d4itlgulo.apps.googleusercontent.com` |
| `CFBundleURLSchemes` (Item 0) | `com.googleusercontent.apps.1097051657980-dqrn9vb9r0jb5kbqm60bq45d4itlgulo` |
| `CFBundleURLSchemes` (Item 1 — qarta) | `qarta` (deep link Supabase) |

> ⚠️ Ces deux valeurs doivent correspondre exactement au `CLIENT_ID` et `REVERSED_CLIENT_ID` du plist ci-dessus.

---

## 4. Firebase — Initialisation dans le code

### Problème rencontré

`Firebase.initializeApp()` sans options échouait avec `[core/not-initialized]` même avec le bon plist en place — Firebase ne trouvait pas le plist dans le bundle compilé.

### Solution appliquée

Création de `lib/firebase_options.dart` avec les options explicites :

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        return ios;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDDqXH6l3yrHdxLckGvt7Nn1rVfAq0sFKo',
    appId: '1:1097051657980:ios:dacf15029d24c61d8d6979',
    messagingSenderId: '1097051657980',
    projectId: 'fidelitypass-c4a88',
    storageBucket: 'fidelitypass-c4a88.firebasestorage.app',
    iosBundleId: 'com.yassin.qarta',
  );
}
```

Et dans `lib/main.dart` :

```dart
import 'firebase_options.dart';

// ...

await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

---

## 5. Google Sign-In — Configuration Supabase

### Problème rencontré

Erreur : `AuthApiException: Unacceptable audience in id_token: [1097051657980-dqrn9vb9r0jb5kbqm60bq45d4itlgulo.apps.googleusercontent.com]`

Supabase vérifiait le token Google et ne reconnaissait pas le nouveau CLIENT_ID iOS.

### Solution appliquée

Supabase Dashboard → projet `fidelitypass` → **Authentication → Providers → Google** → champ **Client IDs**

Liste des CLIENT_IDs configurés (séparés par des virgules) :
```
1097051657980-rm2slbqt9atg9og0qdjc45nat5qe3jkj.apps.googleusercontent.com,1097051657980-r1dvb20pf3ofh0mee4ogqkqbbstlj506.apps.googleusercontent.com,1097051657980-dqrn9vb9r0jb5kbqm60bq45d4itlgulo.apps.googleusercontent.com
```

> Le troisième (`dqrn9vb9...`) est le nouveau CLIENT_ID iOS pour `com.yassin.qarta`.

---

## 6. Apple Sign-In

### Capabilities Xcode

Dans Xcode → Target Runner → **Signing & Capabilities** :
- ✅ **Sign In with Apple** — doit être présent

> Sans cette capability, Apple Sign-In retourne `AuthorizationError 1000` même en release.

### Capabilities Apple Developer Portal

Sur developer.apple.com → Identifiers → `com.yassin.qarta` :
- ✅ **Sign In with Apple** — coché
- ✅ **Push Notifications** — coché

### Comportement par mode de build

| Mode | Apple Sign-In | Google Sign-In |
|---|---|---|
| `flutter run` (debug) | ❌ Erreur 1000 (normal) | ✅ si Firebase initialisé |
| `flutter run --release` | ✅ | ✅ |
| TestFlight / App Store | ✅ | ✅ |

> L'erreur 1000 d'Apple Sign-In en mode debug est **normale et attendue** — ne pas essayer de la corriger.

---

## 7. Notifications Push

### Problème rencontré

- L'app n'apparaissait pas dans Réglages iOS → Notifications
- Aucune popup de permission n'était affichée au premier lancement

### Cause

Firebase ne s'initialisait pas (mauvais plist → `[core/not-initialized]`), donc le bloc `requestPermission` dans `main.dart` n'était jamais atteint.

### Solution

Fix Firebase (voir section 4) + désinstallation complète de l'app sur l'iPhone avant réinstallation.

> iOS mémorise que la permission n'a jamais été demandée. Si l'app a été installée avant que `requestPermission` soit appelé, il faut **désinstaller et réinstaller** pour voir la popup.

### APNs Key Firebase

Dans Firebase Console → projet `fidelitypass` → Paramètres → Cloud Messaging → **Apple app configuration** :
- Clé APNs configurée : `TDDDWRFWXZ`

---

## 8. Checklist — Après chaque changement de bundle ID ou de config Firebase

- [ ] Télécharger le bon `GoogleService-Info.plist` depuis Firebase Console pour `com.yassin.qarta`
- [ ] Vérifier `BUNDLE_ID: com.yassin.qarta` dans le plist (`grep -A 1 BUNDLE_ID`)
- [ ] Vérifier `GIDClientID` et `REVERSED_CLIENT_ID` dans `Info.plist` (correspondre au plist)
- [ ] Vérifier que `firebase_options.dart` a les bonnes valeurs
- [ ] Vérifier que Supabase a le bon CLIENT_ID iOS dans Authentication → Google
- [ ] Vérifier capabilities Xcode : Sign In with Apple ✅
- [ ] Vérifier capabilities Apple Developer Portal : Push Notifications ✅ + Sign In with Apple ✅
- [ ] Si notifications ne s'affichent pas : désinstaller l'app et réinstaller

---

## 9. Versions de l'app publiées

| Version | Build | Notes |
|---|---|---|
| 1.0.0 | — | Première version App Store |
| 1.0.1 | 6 | Build TestFlight — fix crash + fix Firebase |
