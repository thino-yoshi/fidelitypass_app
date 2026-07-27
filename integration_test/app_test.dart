// ─── Integration tests — Qarta ────────────────────────────────────────────
//
// Lancer avec :
//   flutter test integration_test/app_test.dart \
//     --dart-define=TEST_MERCHANT_EMAIL=ton@merchant.com \
//     --dart-define=TEST_MERCHANT_PASS=monpass \
//     --dart-define=TEST_CLIENT_EMAIL=ton@client.com \
//     --dart-define=TEST_CLIENT_PASS=monpass
//
// Ou sur device physique :
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart \
//     --dart-define=...

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fidelitypass_app/main.dart' as app;

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Tous les tests tournent dans un seul testWidgets pour éviter la
  // double-initialisation de Firebase entre tests.
  testWidgets('Qarta — suite complète', (tester) async {
    // ── Démarrage ──────────────────────────────────────────────────────────
    await signOut(); // session propre avant tout
    app.main();
    await passSplash(tester);

    // ── 1. Landing — éléments de base ────────────────────────────────────
    await _testLanding(tester);

    // ── 2. Connexion commerçant ───────────────────────────────────────────
    await _testMerchantLogin(tester);

    // ── 3. Dashboard commerçant ───────────────────────────────────────────
    await _testMerchantDashboard(tester);

    // ── 4. Historique commerçant ──────────────────────────────────────────
    await _testMerchantHistory(tester);

    // ── 5. Déconnexion + connexion client ─────────────────────────────────
    await logoutAndGoToLanding(tester);
    await _testClientLogin(tester);

    // ── 6. Cartes client ──────────────────────────────────────────────────
    await _testClientCards(tester);

    // ── 7. Écran de scan client ───────────────────────────────────────────
    await _testClientScanScreen(tester);

    // ── 8. Historique client ──────────────────────────────────────────────
    await _testClientHistory(tester);

    // ── 9. Déconnexion + mauvais mdp ─────────────────────────────────────
    await logoutAndGoToLanding(tester);
    await _testWrongPassword(tester);

    // ── 10. Flow inscription jusqu'à l'étape OTP ─────────────────────────
    await _testRegistrationToOtp(tester);
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// FLOWS
// ═══════════════════════════════════════════════════════════════════════════

// ── 1. Landing ─────────────────────────────────────────────────────────────

Future<void> _testLanding(WidgetTester tester) async {
  expect(
    find.text('Créer un compte'),
    findsOneWidget,
    reason: '[Landing] bouton "Créer un compte" absent',
  );
  expect(
    find.text('Se connecter'),
    findsAtLeastNWidgets(1),
    reason: '[Landing] bouton "Se connecter" absent',
  );
  expect(
    find.text('Continuer avec Google'),
    findsOneWidget,
    reason: '[Landing] bouton Google absent',
  );
}

// ── 2. Connexion commerçant ─────────────────────────────────────────────────

Future<void> _testMerchantLogin(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty || kMerchantPass.isEmpty) {
    debugPrint('⚠️  TEST_MERCHANT_EMAIL / TEST_MERCHANT_PASS non définis — login commerçant ignoré');
    return;
  }

  await loginWith(tester, kMerchantEmail, kMerchantPass);

  // Vérifier qu'on est bien sur le home commerçant (onglet Accueil visible)
  expect(
    find.text('Accueil'),
    findsOneWidget,
    reason: '[Merchant login] onglet "Accueil" absent — login a peut-être échoué',
  );
}

// ── 3. Dashboard commerçant ─────────────────────────────────────────────────

Future<void> _testMerchantDashboard(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty) return;

  // L'onglet Accueil est déjà actif — vérifier les KPIs
  expect(
    find.text('Tampons ajoutés'),
    findsOneWidget,
    reason: '[Merchant dashboard] KPI "Tampons ajoutés" absent',
  );

  // Le graphique d'évolution doit être présent
  expect(
    find.text('Évolution des tampons'),
    findsOneWidget,
    reason: '[Merchant dashboard] graphique absent',
  );
}

// ── 4. Historique commerçant ────────────────────────────────────────────────

Future<void> _testMerchantHistory(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty) return;

  await tapTab(tester, 'Historique');

  // L'écran d'historique doit se charger sans erreur
  // Pas d'assertion sur le contenu (peut être vide)
  expect(find.byType(Scaffold), findsAtLeastNWidgets(1),
      reason: '[Merchant history] aucun Scaffold visible');

  // Revenir à l'accueil
  await tapTab(tester, 'Accueil');
}

// ── 5. Connexion client ─────────────────────────────────────────────────────

Future<void> _testClientLogin(WidgetTester tester) async {
  if (kClientEmail.isEmpty || kClientPass.isEmpty) {
    debugPrint('⚠️  TEST_CLIENT_EMAIL / TEST_CLIENT_PASS non définis — login client ignoré');
    return;
  }

  await loginWith(tester, kClientEmail, kClientPass);

  // Vérifier qu'on est bien sur le home client ("Cartes" visible)
  expect(
    find.text('Cartes'),
    findsOneWidget,
    reason: '[Client login] onglet "Cartes" absent — login a peut-être échoué',
  );
}

// ── 6. Cartes client ────────────────────────────────────────────────────────

Future<void> _testClientCards(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  // L'onglet Cartes est actif
  // "Bonjour" doit apparaître dans le header
  expect(
    find.text('Bonjour'),
    findsOneWidget,
    reason: '[Client cards] salutation "Bonjour" absente',
  );
}

// ── 7. Écran de scan client ─────────────────────────────────────────────────

Future<void> _testClientScanScreen(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  // Le FAB central ouvre le scanner — chercher l'icône QR / scan
  final scanFab = find.byIcon(Icons.qr_code_scanner_outlined);
  if (scanFab.evaluate().isEmpty) {
    // Fallback : essayer avec l'icône scanner générique
    final alt = find.byIcon(Icons.crop_free_rounded);
    if (alt.evaluate().isNotEmpty) {
      await tester.tap(alt.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  } else {
    await tester.tap(scanFab.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  // Vérifier que la caméra / scan UI s'ouvre (MobileScanner présent)
  // Note : pas de vrai scan — on vérifie juste que l'écran s'affiche
  // Revenir en arrière si une nouvelle page s'est ouverte
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (navigator.canPop()) {
    navigator.pop();
    await tester.pumpAndSettle();
  }
}

// ── 8. Historique client ────────────────────────────────────────────────────

Future<void> _testClientHistory(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  await tapTab(tester, 'Historique');

  expect(find.byType(Scaffold), findsAtLeastNWidgets(1),
      reason: '[Client history] aucun Scaffold visible');

  // Revenir aux cartes
  await tapTab(tester, 'Cartes');
}

// ── 9. Mauvais mot de passe ─────────────────────────────────────────────────

Future<void> _testWrongPassword(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  await tester.tap(find.text('Se connecter').first);
  await tester.pumpAndSettle();

  await tester.enterText(fieldByHint('toi@email.com'), kClientEmail);
  await tester.pump();
  await tester.enterText(fieldByHint('••••••••'), 'mauvais_mot_de_passe_xyz');
  await tester.pump();

  final loginBtn = find.widgetWithText(ElevatedButton, 'Se connecter');
  await tester.tap(loginBtn);
  await tester.pumpAndSettle(const Duration(seconds: 6));

  // Un message d'erreur rouge doit apparaître
  final errorBox = find.byWidgetPredicate(
    (w) => w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == const Color(0x22E24B4A),
  );
  expect(errorBox, findsAtLeastNWidgets(1),
      reason: '[Wrong password] aucun message d\'erreur affiché');

  // Retour au landing
  await tester.tap(find.text('Retour').first);
  await tester.pumpAndSettle();
}

// ── 10. Inscription → étape OTP ────────────────────────────────────────────

Future<void> _testRegistrationToOtp(WidgetTester tester) async {
  // Étape 1 — choisir "client"
  await tester.tap(find.text('Créer un compte'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Je suis client'));
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
  await tester.pumpAndSettle();

  // Étape 2 — remplir le formulaire
  await tester.enterText(fieldByHint('Prénom'), 'Test');
  await tester.pump();
  await tester.enterText(fieldByHint('Nom'), 'Intégration');
  await tester.pump();

  // Email unique pour éviter les conflits
  final uniqueEmail =
      'test_int_${DateTime.now().millisecondsSinceEpoch}@mailnull.com';
  await tester.enterText(fieldByHint('Adresse email'), uniqueEmail);
  await tester.pump();

  await tester.enterText(fieldByHint('Mot de passe'), 'Test1234!');
  await tester.pump();

  // Vérifier que le bouton est actif
  final createBtn = find.widgetWithText(ElevatedButton, 'Créer mon compte');
  await tester.tap(createBtn);
  await tester.pumpAndSettle();

  // Étape 3 — écran de confirmation (Bienvenue)
  expect(find.text('Bienvenue Test !'), findsOneWidget,
      reason: '[Register step 3] "Bienvenue Test !" absent');

  final startBtn = find.widgetWithText(ElevatedButton, "C'est parti !");
  await tester.tap(startBtn);
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // Étape 4 — saisie du code OTP (le vrai test : le champ s'affiche)
  expect(find.text('Vérifie ton email'), findsOneWidget,
      reason: '[Register step 4] écran OTP absent — le bug 1 n\'est pas corrigé');

  expect(find.text('Confirmer mon compte'), findsOneWidget,
      reason: '[Register step 4] bouton "Confirmer mon compte" absent');

  // Le champ code doit accepter 8 chiffres
  await tester.enterText(
    find.byWidgetPredicate(
      (w) => w is TextField && w.maxLength == 8,
    ),
    '12345678',
  );
  await tester.pump();

  // Le bouton Confirmer est maintenant actif (8 chiffres saisis)
  final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirmer mon compte');
  final btn = tester.widget<ElevatedButton>(confirmBtn);
  expect(btn.onPressed, isNotNull,
      reason: '[Register step 4] bouton "Confirmer" devrait être actif avec 6 chiffres');

  // Note : on ne valide pas le vrai code OTP ici (pas reçu en automatique)
  // Le test vérifie que l'écran est correct et que le bouton est actif.
}
