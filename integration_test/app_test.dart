// ─── Integration tests — Qarta ─────────────────────────────────────────────
//
// flutter test integration_test/app_test.dart \
//   --dart-define=TEST_MERCHANT_EMAIL=gobinthib99+qarta@gmail.com \
//   --dart-define=TEST_MERCHANT_PASS=Billbill2102 \
//   --dart-define=TEST_CLIENT_EMAIL=pierre.dubois-2609@outlook.com \
//   --dart-define=TEST_CLIENT_PASS=Judithx2107 \
//   -d R3CT30WG3QW

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fidelitypass_app/main.dart' as app;

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Qarta — suite complète', (tester) async {
    await signOut();
    app.main();
    await passSplash(tester);

    // ── 1. Landing AuthScreen ─────────────────────────────────────────────
    await _testLanding(tester);

    // ── COMMERÇANT ────────────────────────────────────────────────────────
    await _testMerchantLogin(tester);
    await _testMerchantDashboard(tester);
    await _testMerchantStats(tester);       // écran stats complet
    await _testMerchantHistory(tester);    // onglet historique
    await _testMerchantClientDetail(tester); // fiche client depuis liste
    await _testMerchantProfil(tester);     // BottomSheet profil + déconnexion UI

    // ── CLIENT ────────────────────────────────────────────────────────────
    await _testClientLogin(tester);
    await _testClientCards(tester);        // onglet cartes + header
    await _testClientScanTab(tester);      // onglet scan
    await _testClientHistory(tester);      // onglet historique
    await _testClientProfil(tester);       // onglet profil + déconnexion UI

    // ── AUTH EDGE CASES ───────────────────────────────────────────────────
    await _testWrongPassword(tester);
    await _testRegistrationToOtp(tester);
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. LANDING
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _testLanding(WidgetTester tester) async {
  expect(find.text('Créer un compte'), findsAtLeastNWidgets(1),
      reason: '[Landing] "Créer un compte" absent');
  expect(find.text('Se connecter'), findsAtLeastNWidgets(1),
      reason: '[Landing] "Se connecter" absent');
  expect(find.text('Continuer avec Google'), findsAtLeastNWidgets(1),
      reason: '[Landing] "Continuer avec Google" absent');
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMERÇANT
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _testMerchantLogin(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty || kMerchantPass.isEmpty) return;
  await loginWith(tester, kMerchantEmail, kMerchantPass);
  expect(find.text('Accueil'), findsAtLeastNWidgets(1),
      reason: '[Merchant login] nav "Accueil" absent — login raté ?');
}

// ── Dashboard ───────────────────────────────────────────────────────────────

Future<void> _testMerchantDashboard(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty) return;

  // APIs : me, stats, clients, daily, scan-history, card-design
  await pumpFor(tester, seconds: 8);

  // Onboarding 1re visite → fermer
  if (find.text('Passer').evaluate().isNotEmpty) {
    await tester.tap(find.text('Passer').first);
    await pumpFor(tester, seconds: 2);
  } else if (find.text('Commencer').evaluate().isNotEmpty) {
    await tester.tap(find.text('Commencer').first);
    await pumpFor(tester, seconds: 2);
  }

  // Textes statiques du dashboard (haut de liste = toujours construits)
  expect(find.text('Demander un avis Google'), findsAtLeastNWidgets(1),
      reason: '[Dashboard] bulle Google absente');
  expect(find.textContaining('ajoutés'), findsAtLeastNWidgets(1),
      reason: '[Dashboard] KPI "Tampons/Points ajoutés" absent');
  expect(find.text('Taux de retour'), findsAtLeastNWidgets(1),
      reason: '[Dashboard] "Taux de retour" absent');
  expect(find.text('Statistiques générales'), findsAtLeastNWidgets(1),
      reason: '[Dashboard] "Statistiques générales" absent');
}

// ── Stats screen ────────────────────────────────────────────────────────────

Future<void> _testMerchantStats(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty) return;

  // Tap "Voir stats →" → ouvre StatsScreen
  final voirStats = find.text('Voir stats →');
  if (voirStats.evaluate().isNotEmpty) {
    await tester.tap(voirStats.first);
    await pumpFor(tester, seconds: 4);

    // StatsScreen : titre + graphique
    expect(find.textContaining('Statistiques'), findsAtLeastNWidgets(1),
        reason: '[Stats] titre "Statistiques" absent');
    expect(find.textContaining('Activité'), findsAtLeastNWidgets(1),
        reason: '[Stats] section "Activité" absente');

    // Retour au dashboard
    final back = find.byType(BackButton);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first);
    } else {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (navigator.canPop()) navigator.pop();
    }
    await pumpFor(tester, seconds: 2);
  }
}

// ── Historique commerçant ───────────────────────────────────────────────────

Future<void> _testMerchantHistory(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty) return;

  await tapTab(tester, 'Historique');
  expect(find.byType(Scaffold), findsAtLeastNWidgets(1),
      reason: '[Merchant history] Scaffold absent');

  await tapTab(tester, 'Accueil');
}

// ── Fiche client depuis la liste ────────────────────────────────────────────

Future<void> _testMerchantClientDetail(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty) return;

  // La section stats affiche les clients sous "Clients carte".
  // On cherche le compteur/nom de client dans la liste visible.
  // Si au moins 1 client, on peut taper dessus.
  final clientCard = find.textContaining('Clients carte');
  if (clientCard.evaluate().isNotEmpty) {
    await tester.tap(clientCard.first);
    await pumpFor(tester, seconds: 3);

    // ClientsScreen : liste des clients
    // Chercher un élément de la liste (email ou nom)
    final listTile = find.byType(ListTile);
    if (listTile.evaluate().isNotEmpty) {
      await tester.tap(listTile.first);
      await pumpFor(tester, seconds: 3);

      // Fiche client : des infos s'affichent
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1),
          reason: '[Client detail] Scaffold absent');

      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (navigator.canPop()) {
        navigator.pop();
        await pumpFor(tester, seconds: 2);
      }
    }

    // Retour au dashboard
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    if (navigator.canPop()) {
      navigator.pop();
      await pumpFor(tester, seconds: 2);
    }
  }
}

// ── Profil commerçant (BottomSheet) + déconnexion ──────────────────────────

Future<void> _testMerchantProfil(WidgetTester tester) async {
  if (kMerchantEmail.isEmpty) return;

  // Vérifier qu'on est sur Accueil avant de tester le profil
  expect(find.text('Accueil'), findsAtLeastNWidgets(1),
      reason: '[Merchant profil] pas sur le dashboard avant le logout');

  // logoutMerchant ouvre le BottomSheet profil et tape "Se déconnecter"
  await logoutMerchant(tester);

  // On est maintenant sur AuthScreen
  expect(find.text('Se connecter'), findsAtLeastNWidgets(1),
      reason: '[Merchant profil] AuthScreen non affichée après déconnexion');
}

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _testClientLogin(WidgetTester tester) async {
  if (kClientEmail.isEmpty || kClientPass.isEmpty) return;
  await loginWith(tester, kClientEmail, kClientPass);
  expect(find.text('Cartes'), findsAtLeastNWidgets(1),
      reason: '[Client login] nav "Cartes" absent — login raté ?');
}

// ── Cartes ──────────────────────────────────────────────────────────────────

Future<void> _testClientCards(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  await pumpFor(tester, seconds: 3);

  expect(find.text('Bonjour'), findsAtLeastNWidgets(1),
      reason: '[Client cards] salutation "Bonjour" absente');
  expect(find.text('Cartes'), findsAtLeastNWidgets(1),
      reason: '[Client cards] nav "Cartes" absent');
}

// ── Onglet scan ─────────────────────────────────────────────────────────────

Future<void> _testClientScanTab(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  final fab = find.byIcon(Icons.qr_code_scanner_rounded);
  if (fab.evaluate().isNotEmpty) {
    await tester.tap(fab.first);
    await pumpFor(tester, seconds: 2);
  }

  expect(find.text('Scanner le QR du commerce'), findsAtLeastNWidgets(1),
      reason: '[Client scan] texte "Scanner le QR du commerce" absent');

  await tapTab(tester, 'Cartes');
}

// ── Historique client ───────────────────────────────────────────────────────

Future<void> _testClientHistory(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  await tapTab(tester, 'Historique');
  expect(find.byType(Scaffold), findsAtLeastNWidgets(1),
      reason: '[Client history] Scaffold absent');

  await tapTab(tester, 'Cartes');
}

// ── Profil client (onglet 3) + déconnexion ──────────────────────────────────

Future<void> _testClientProfil(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  // Ouvrir le profil via l'avatar du header (GestureDetector contenant "Bonjour")
  final profilBtn = find.ancestor(
    of: find.text('Bonjour'),
    matching: find.byType(GestureDetector),
  );
  if (profilBtn.evaluate().isNotEmpty) {
    await tester.tap(profilBtn.first);
    await pumpFor(tester, seconds: 2);
  }

  // Onglet profil : sections visibles
  expect(find.text('Informations personnelles'), findsAtLeastNWidgets(1),
      reason: '[Client profil] "Informations personnelles" absent');
  expect(find.text('Se déconnecter'), findsAtLeastNWidgets(1),
      reason: '[Client profil] "Se déconnecter" absent');

  // Déconnexion via le bouton UI
  await logoutClient(tester);

  // On est maintenant sur AuthScreen
  expect(find.text('Se connecter'), findsAtLeastNWidgets(1),
      reason: '[Client profil] AuthScreen non affichée après déconnexion');
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTH EDGE CASES
// ═══════════════════════════════════════════════════════════════════════════

// ── Mauvais mot de passe ────────────────────────────────────────────────────

Future<void> _testWrongPassword(WidgetTester tester) async {
  if (kClientEmail.isEmpty) return;

  await tester.tap(find.text('Se connecter').first);
  await pumpFor(tester, seconds: 2); // _orbCtrl repeat()

  await tester.enterText(fieldByHint('toi@email.com'), kClientEmail);
  await tester.pump();
  await tester.enterText(fieldByHint('••••••••'), 'mauvais_mot_de_passe_xyz');
  await tester.pump();

  await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
  await pumpFor(tester, seconds: 8);

  // _errorBox affiche Text('✗ <message>') en rouge
  expect(find.textContaining('✗'), findsAtLeastNWidgets(1),
      reason: '[Wrong password] aucun message d\'erreur "✗" affiché');

  await tester.tap(find.text('Retour').first);
  await pumpFor(tester, seconds: 2);
}

// ── Inscription → OTP ───────────────────────────────────────────────────────

Future<void> _testRegistrationToOtp(WidgetTester tester) async {
  // Étape 1 — choisir son profil
  await tester.tap(find.text('Créer un compte').first);
  await pumpFor(tester, seconds: 2);

  await tester.tap(find.text('Je suis client').first);
  await tester.pump();

  await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
  await pumpFor(tester, seconds: 2);

  // Étape 2 — formulaire (setState seulement, pas d'API)
  await tester.enterText(fieldByHint('Prénom'), 'Test');
  await tester.pump();
  await tester.enterText(fieldByHint('Nom'), 'Intégration');
  await tester.pump();
  final uniqueEmail =
      'test_int_${DateTime.now().millisecondsSinceEpoch}@mailnull.com';
  await tester.enterText(fieldByHint('Adresse email'), uniqueEmail);
  await tester.pump();
  await tester.enterText(fieldByHint('Mot de passe'), 'Test1234!');
  await pumpFor(tester, seconds: 1);

  // → étape 3 (pas d'API)
  await tester.tap(find.widgetWithText(ElevatedButton, 'Créer mon compte'));
  await pumpFor(tester, seconds: 2);

  expect(find.text('Bienvenue Test !'), findsAtLeastNWidgets(1),
      reason: '[Register step 3] "Bienvenue Test !" absent');

  // → étape 4 : API inscription réelle
  await tester.tap(find.widgetWithText(ElevatedButton, "C'est parti !"));
  await pumpFor(tester, seconds: 10);

  expect(find.text('Vérifie ton email'), findsAtLeastNWidgets(1),
      reason: '[Register step 4] écran OTP absent');
  expect(find.widgetWithText(ElevatedButton, 'Confirmer mon compte'),
      findsAtLeastNWidgets(1),
      reason: '[Register step 4] bouton "Confirmer mon compte" absent');

  // Saisir 8 chiffres → bouton actif
  await tester.enterText(fieldByHint('--------'), '12345678');
  await tester.pump();

  final confirmBtn = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Confirmer mon compte'),
  );
  expect(confirmBtn.onPressed, isNotNull,
      reason:
          '[Register step 4] bouton "Confirmer" devrait être actif avec 8 chiffres');
}
