import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Credentials (passés via --dart-define) ────────────────────────────────

const kMerchantEmail = String.fromEnvironment('TEST_MERCHANT_EMAIL');
const kMerchantPass  = String.fromEnvironment('TEST_MERCHANT_PASS');
const kClientEmail   = String.fromEnvironment('TEST_CLIENT_EMAIL');
const kClientPass    = String.fromEnvironment('TEST_CLIENT_PASS');

// ─── Pump helpers ─────────────────────────────────────────────────────────

/// Avance le clock de [seconds] secondes par tranches de 100ms.
/// À utiliser partout à la place de pumpAndSettle quand l'écran a des
/// AnimationController.repeat() (orb, scanline, glow, dots…).
Future<void> pumpFor(WidgetTester tester, {int seconds = 2}) async {
  final steps = seconds * 10;
  for (int i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Attend que l'AuthScreen soit visible (jusqu'à [maxSeconds]s).
Future<void> waitForAuthScreen(WidgetTester tester, {int maxSeconds = 10}) async {
  for (int i = 0; i < maxSeconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final onAuth = find.text('Se connecter').evaluate().isNotEmpty ||
                   find.text('Créer un compte').evaluate().isNotEmpty;
    if (onAuth) {
      await pumpFor(tester, seconds: 1);
      return;
    }
  }
  await pumpFor(tester, seconds: 1);
}

// ─── Splash ────────────────────────────────────────────────────────────────

/// Passe le splash et attend que l'AuthScreen soit réellement rendu.
Future<void> passSplash(WidgetTester tester) async {
  await waitForAuthScreen(tester, maxSeconds: 15);
}

// ─── Logout via UI ─────────────────────────────────────────────────────────

/// Déconnexion depuis MerchantHome :
/// Tap avatar (initiales dans le header) → BottomSheet → "Se déconnecter".
Future<void> logoutMerchant(WidgetTester tester) async {
  // L'avatar affiche les initiales du commerce (ex: "FO" pour FOUZIA).
  // On cherche le GestureDetector ancêtre du Container 44×44.
  // Plus robuste : trouver la première icône de notification dans le header
  // et prendre le GestureDetector frère — ou simplement taper les initiales.
  // On cherche un Text court (≤3 chars) dans le header qui déclenche le profil.
  final avatarText = find.byWidgetPredicate((w) {
    if (w is! Text) return false;
    final d = w.data ?? '';
    return d.length <= 3 && d == d.toUpperCase() && d.isNotEmpty;
  });
  if (avatarText.evaluate().isNotEmpty) {
    await tester.tap(avatarText.first);
    await pumpFor(tester, seconds: 1);
  }

  // BottomSheet ouverte : taper "Se déconnecter"
  expect(find.text('Se déconnecter'), findsAtLeastNWidgets(1),
      reason: '[logoutMerchant] "Se déconnecter" absent dans le sheet');
  await tester.tap(find.text('Se déconnecter').first);
  await waitForAuthScreen(tester, maxSeconds: 8);
}

/// Déconnexion depuis ClientHome :
/// Tap avatar header (GestureDetector contenant "Bonjour") → onglet Profil
/// → "Se déconnecter".
Future<void> logoutClient(WidgetTester tester) async {
  // L'avatar client est dans un GestureDetector qui contient aussi "Bonjour".
  final profilBtn = find.ancestor(
    of: find.text('Bonjour'),
    matching: find.byType(GestureDetector),
  );
  if (profilBtn.evaluate().isNotEmpty) {
    await tester.tap(profilBtn.first);
    await pumpFor(tester, seconds: 2);
  }

  // Onglet profil : taper "Se déconnecter"
  expect(find.text('Se déconnecter'), findsAtLeastNWidgets(1),
      reason: '[logoutClient] "Se déconnecter" absent dans le profil');
  await tester.tap(find.text('Se déconnecter').first);
  await waitForAuthScreen(tester, maxSeconds: 8);
}

// ─── Auth helpers ──────────────────────────────────────────────────────────

Finder fieldByHint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

/// Depuis le landing AuthScreen, navigue vers le formulaire login et connecte.
Future<void> loginWith(WidgetTester tester, String email, String pass) async {
  await tester.tap(find.text('Se connecter').first);
  await pumpFor(tester, seconds: 2); // _orbCtrl repeat()

  await tester.enterText(fieldByHint('toi@email.com'), email);
  await tester.pump();

  await tester.enterText(fieldByHint('••••••••'), pass);
  await tester.pump();

  await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
  await pumpFor(tester, seconds: 8); // appel réseau Supabase
}

/// Supprime la session Supabase (utile avant le premier app.main()).
Future<void> signOut() async {
  try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
}

// ─── Nav helpers ───────────────────────────────────────────────────────────

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await pumpFor(tester, seconds: 3);
}

// ─── Assertions ────────────────────────────────────────────────────────────

void expectVisible(String text) =>
    expect(find.text(text), findsAtLeastNWidgets(1),
        reason: '"$text" devrait être visible');
