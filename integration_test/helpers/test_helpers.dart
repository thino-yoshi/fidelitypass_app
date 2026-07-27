import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Credentials (passés via --dart-define) ────────────────────────────────

const kMerchantEmail = String.fromEnvironment('TEST_MERCHANT_EMAIL');
const kMerchantPass  = String.fromEnvironment('TEST_MERCHANT_PASS');
const kClientEmail   = String.fromEnvironment('TEST_CLIENT_EMAIL');
const kClientPass    = String.fromEnvironment('TEST_CLIENT_PASS');

// ─── Session ───────────────────────────────────────────────────────────────

/// Déconnecte la session Supabase active (noop si déjà déconnecté).
Future<void> signOut() async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {}
}

// ─── Splash ────────────────────────────────────────────────────────────────

/// Attend que le splash disparaisse et que l'écran suivant soit prêt.
Future<void> passSplash(WidgetTester tester) async {
  // Le splash peut durer jusqu'à 3s — on attend jusqu'à 6s pour être sûr.
  await tester.pumpAndSettle(const Duration(seconds: 6));
}

// ─── Auth helpers ──────────────────────────────────────────────────────────

/// Cherche un TextField par son hintText.
Finder fieldByHint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

/// Depuis le landing, navigue vers le login et connecte l'utilisateur.
Future<void> loginWith(WidgetTester tester, String email, String pass) async {
  // Landing → bouton "Se connecter"
  await tester.tap(find.text('Se connecter').first);
  await tester.pumpAndSettle();

  // Remplir email
  await tester.enterText(fieldByHint('toi@email.com'), email);
  await tester.pump();

  // Remplir password (dernier TextField de la page)
  await tester.enterText(fieldByHint('••••••••'), pass);
  await tester.pump();

  // Tapper Se connecter (bouton ElevatedButton)
  final loginBtn = find.widgetWithText(ElevatedButton, 'Se connecter');
  await tester.tap(loginBtn);

  // Attendre la navigation (appel réseau Railway)
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

/// Depuis n'importe quel écran, revient au landing via sign-out.
Future<void> logoutAndGoToLanding(WidgetTester tester) async {
  await signOut();
  // Relancer le routing — on pump pour que le 401/redirect s'applique
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

// ─── Nav helpers ───────────────────────────────────────────────────────────

/// Tape sur un onglet de la bottom-nav par son label.
Future<void> tapTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.tap(tab.first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

// ─── Assertions ────────────────────────────────────────────────────────────

/// Vérifie qu'un texte est visible à l'écran.
void expectVisible(String text) =>
    expect(find.text(text), findsAtLeastNWidgets(1),
        reason: '"$text" devrait être visible');

/// Vérifie qu'au moins un widget du type T est visible.
void expectWidgetVisible<T extends Widget>() =>
    expect(find.byType(T), findsAtLeastNWidgets(1),
        reason: '${T.toString()} devrait être visible');
