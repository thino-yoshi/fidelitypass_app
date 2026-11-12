# Design client iPhone — notice

Branche `design-apple-client`, créée depuis `test-merchant-home` (f0e856e). Elle touche **uniquement l'espace client** et le thème iPhone.

## Ce qui change
- **iPhone :** nouveau design client, style Apple.
- **Android :** rien ne change. Chaque branchement passe par ton `kIsIOS` (`merchant_tokens.dart`), donc `kForceIOSDesign = true` affiche aussi ce design sur Android.

## Fichiers nouveaux (rien à faire, il suffit de les avoir)
- `lib/screens/client/widgets/` : 12 widgets, rangés comme les tiens côté commerçant :
  `client_bottom_nav_ios`, `client_cards_stack_ios`, `client_glow_background`, `client_header_ios`, `client_history_ios`, `client_hours`, `client_notifications_ios`, `client_pass_face_ios`, `client_profile_ios`, `client_rewards_ios`, `client_settings_ios`, `client_sheets_ios`
- `lib/config/app_text.dart` : textes partagés.
- `lib/config/demo_mode.dart` : `QartaDemo.enabled = false`. Ne sert qu'à l'aperçu sans serveur et n'a aucun effet dans l'appli.

## Fichiers existants modifiés (des `if (kIsIOS)` qui appellent les widgets)
- `client_home.dart` : en-tête, barre du bas, récompenses, profil, réglages, notifications.
- `cards_tab.dart` : pile de cartes et carte ouverte façon Wallet.
- `history_tab.dart`, `scan_tab.dart`, `manage_cards_screen.dart`, `help_sheet.dart` : versions iPhone.
- `main.dart` : sur iPhone, la police du système (SF Pro) remplace Sora. Ça touche **toute l'appli sur iPhone, commerçant compris**. Sur Android, Sora reste.

Tes derniers changements sont gardés : les textes « Plus que X tampons avant : … » et le suivi `notification_id`.

## Vérifié
- `flutter analyze` : 0 erreur (seulement des avertissements, la plupart du code inutilisé).
- Testé sur le simulateur iPhone : cartes et historique s'affichent bien.
- **Pas testé** : avec ton vrai serveur et un vrai compte. Les données passent par tes appels existants, mais c'est à vérifier de ton côté.

## Pas inclus
- Côté commerçant : rien n'a été touché.
- Écran de connexion client : en cours, il viendra à part.
