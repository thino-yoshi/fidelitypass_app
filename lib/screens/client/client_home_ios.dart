// ══════════════════════════════════════════════════════════════════════════════
// Accueil client iPhone (style Apple) — fichier iOS de Yassine.
//
// Écran autonome : toute la logique (cartes, récompenses, notifs, deep links,
// profil…) vient du ClientHomeController partagé. Ce fichier ne fait que
// l'affichage iPhone et les fenêtres Apple (alertes, feuilles, pages Réglages).
// client_home.dart (Android, Thigrou) crée le controller et affiche ce widget
// quand l'appareil est un iPhone.
// ══════════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/demo_mode.dart';
import '../../services/auth_service.dart';
import '../../utils/platform_route.dart';
import '../auth_screen.dart';
import 'cards_tab.dart' show CardStyle, StampEvent;
import 'cards_tab_ios.dart';
import 'client_home_controller.dart';
import 'help_sheet.dart' show HelpSheet;
import 'history_tab_ios.dart';
import 'manage_cards_screen_ios.dart';
import 'scan_tab_ios.dart';
import 'widgets/client_bottom_nav_ios.dart';
import 'widgets/client_glow_background.dart';
import 'widgets/client_header_ios.dart';
import 'widgets/client_notifications_ios.dart';
import 'widgets/client_open_card_ios.dart';
import 'widgets/client_profile_ios.dart';
import 'widgets/client_rewards_ios.dart';
import 'widgets/client_settings_ios.dart';
import 'widgets/client_sheets_ios.dart';

class ClientHomeIos extends StatefulWidget {
  final ClientHomeController controller;
  final String token;
  const ClientHomeIos({super.key, required this.controller, required this.token});

  @override
  State<ClientHomeIos> createState() => _ClientHomeIosState();
}

class _ClientHomeIosState extends State<ClientHomeIos> {
  ClientHomeController get _c => widget.controller;

  // ── État d'affichage iPhone uniquement ──────────────────────────────────────
  bool _searching = false;
  bool _rewardPillActive = false;
  late final PageController _pillPageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _c.addListener(_onCtrl);
    // L'iPhone gère ses propres fenêtres (Apple) pour les événements du moteur.
    _c.onStampEvent = _onStampEventIos;
    _c.onMerchantJoined = _onMerchantJoined;
    _c.onNotifOpen = () { if (mounted) _openNotifs(); };
    _c.onLogout = () {
      if (mounted) Navigator.pushReplacement(context, platformRoute(builder: (_) => const AuthScreen()));
    };
  }

  @override
  void dispose() {
    _c.removeListener(_onCtrl);
    _pillPageCtrl.dispose();
    super.dispose();
  }

  void _onCtrl() { if (mounted) setState(() {}); }

  // ── Raccourcis vers le moteur ───────────────────────────────────────────────
  List<dynamic> get _cards => _c.cards;
  List<dynamic> get _rewards => _c.rewards;
  String get _userName => _c.userName;
  int get _tab => _c.tab;

  ImageProvider? get _avatar => _c.profileImageUrl != null
      ? NetworkImage(_c.profileImageUrl!) as ImageProvider
      : _c.profileImagePath != null ? FileImage(File(_c.profileImagePath!)) : null;

  Future<void> _refreshManual() async {
    _c.loadStats();
    _c.loadRewardsCount();
    _c.loadHistory();
    _c.loadNotifs();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _setTab(int tab) {
    if (tab != 0) _searching = false;
    if (_tab == 0 && tab != 0 && _rewardPillActive) {
      _rewardPillActive = false;
      _pillPageCtrl.jumpToPage(0);
    }
    _c.setTab(tab);
  }

  void _openNotifs() => _c.openNotifs(); // iOS : points bleus visibles jusqu'à « Tout lire »

  void _closeNotifs() {
    _c.closeNotifs();
    // L'écran Cartes/Récompenses est recréé au retour : on le remet sur l'onglet choisi.
    if (_c.tab == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pillPageCtrl.hasClients) _pillPageCtrl.jumpToPage(_rewardPillActive ? 1 : 0);
      });
    }
  }

  void _goToRewards() {
    final already = _tab == 0;
    setState(() => _rewardPillActive = true);
    _c.setTab(0);
    if (already && _pillPageCtrl.hasClients) {
      _pillPageCtrl.animateToPage(1, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _pillPageCtrl.hasClients) _pillPageCtrl.jumpToPage(1); });
    }
  }

  void _goToCards() {
    final already = _tab == 0;
    setState(() => _rewardPillActive = false);
    _c.setTab(0);
    if (already && _pillPageCtrl.hasClients) {
      _pillPageCtrl.animateToPage(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _pillPageCtrl.hasClients) _pillPageCtrl.jumpToPage(0); });
    }
  }

  // ── Événements du moteur ────────────────────────────────────────────────────

  /// Tampon reçu (le moteur a déjà mis la carte à jour et en haut de la pile).
  /// iOS : « Tampon ajouté » s'affiche dans la carte ouverte ; carte pleine → « Carte complète ! ».
  void _onStampEventIos(StampEvent e) {
    if (e.reward) {
      _onRewardUnlockedIos(e);
    } else if (!QartaDemo.enabled) {
      _c.refreshCard(e.cardId);
    }
  }

  /// Lien d'invitation : même fenêtre « Carte ajoutée » qu'après un scan.
  void _onMerchantJoined(JoinMerchantResult r) {
    if (!mounted) return;
    switch (r.status) {
      case JoinResult.added:
        final card = _cards.cast<Map?>().firstWhere((c) => c?['id'] == r.cardId, orElse: () => null);
        if (card == null) { showIosAlert(context, 'Carte ajoutée', 'Ta nouvelle carte est dans tes cartes.'); return; }
        showCardAddedIos(context,
            merchant: (card['merchants'] as Map?) ?? const {}, design: card['card_design'],
            userName: _userName, alreadyMember: false).then((seeCard) {
          if (!mounted) return;
          if (seeCard == false) { _setTab(1); } else if (seeCard == true) { _openCardWalletIos(card); }
        });
      case JoinResult.alreadyMember:
        showIosAlert(context, 'Déjà dans tes cartes', 'Tu as déjà la carte de ce commerce.');
      case JoinResult.error:
        showIosAlert(context, 'Carte non ajoutée', r.errorMessage ?? 'Réessaie dans un instant.');
    }
  }

  /// Carte complétée → « Carte complète ! », puis la récompense.
  Future<void> _onRewardUnlockedIos(StampEvent e) async {
    final idx = _cards.indexWhere((c) => c['id'] == e.cardId);
    if (idx < 0) return;
    final card = _cards[idx] as Map;
    final merchant = (card['merchants'] as Map?) ?? {};
    final useNow = await showRewardUnlockedIos(
      context, merchant: merchant, design: card['card_design'], userName: _userName,
    );
    if (!mounted) return;
    // La carte repart avec le surplus (souvent 0).
    setState(() {
      final i = _cards.indexWhere((c) => c['id'] == e.cardId);
      if (i >= 0) {
        final c = Map<String, dynamic>.from(_cards[i] as Map);
        if (e.isPoints) { c['points_count'] = e.newCount; } else { c['stamps_count'] = e.newCount; }
        _c.cards[i] = c;
      }
    });
    Map? reward;
    if (QartaDemo.enabled) {
      reward = {
        'id': 'r-demo-${DateTime.now().millisecondsSinceEpoch}',
        'merchant_id': card['merchant_id'],
        'merchant_name': merchant['business_name'],
        'description': merchant['reward_description'],
        'card_design': card['card_design'],
        'merchant': merchant,
      };
      setState(() { _c.rewards = [..._rewards, reward]; _c.rewardCount = _c.rewards.length; });
    } else {
      _c.refreshCard(e.cardId);
      await _c.loadRewardsCount();
      reward = _rewards.cast<Map?>().firstWhere((r) => r?['merchant_id'] == card['merchant_id'], orElse: () => null);
    }
    if (!mounted) return;
    _goToRewards();
    if (useNow == true && reward != null) {
      _useRewardIos(merchant['business_name'] as String? ?? '', reward);
    }
  }

  // ── Cartes ──────────────────────────────────────────────────────────────────

  /// Ouvre la carte façon Wallet (après « Voir ma carte »).
  void _openCardWalletIos(Map card) {
    final style = CardStyle.fromDesign(card['card_design'],
        merchantLogoUrl: card['merchants']?['logo_url'] as String?, fallbackColor: kNavyCard);
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (ctx, anim, _) => OpenCardPageIos(
        animation: anim,
        child: QRModalIos(
          token: widget.token,
          card: card,
          style: style,
          userName: _userName,
          onStampAdded: _refreshManual,
          onStampEvent: _c.handleStampEvent,
        ),
      ),
    ));
  }

  /// Ouvre une carte depuis « Les plus proches » (onglet Récompenses).
  void _openCardIos(Map card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRModalIos(
        token: widget.token,
        card: card,
        style: CardStyle.fromDesign(card['card_design'],
            merchantLogoUrl: card['merchants']?['logo_url'] as String?, fallbackColor: kNavyCard),
        userName: _userName,
        onStampAdded: _refreshManual,
        onStampEvent: _c.handleStampEvent,
      ),
    );
  }

  /// Utiliser une récompense (QR + « Récompense utilisée »).
  void _useRewardIos(String merchantName, Map reward) {
    showRewardQrIos(
      context,
      reward: reward,
      merchantName: merchantName,
      userName: _userName,
      onRedeemed: () {
        if (QartaDemo.enabled) {
          setState(() {
            _c.rewards = _rewards.where((r) => r['id'] != reward['id']).toList();
            _c.rewardCount = _c.rewards.length;
          });
        } else {
          _refreshManual();
        }
      },
    );
  }

  /// Carte ajoutée depuis le scanner (affichage immédiat, le serveur confirme ensuite).
  void _addScannedCard(Map<String, dynamic> card, Map<String, dynamic> merchant, {required bool goHome}) {
    final localCard = Map<String, dynamic>.from(card)
      ..['merchants'] = merchant
      ..['card_design'] = card['card_design']
      ..['last_scan_at'] = null;
    setState(() {
      _c.cards.insert(0, localCard);
      _c.cardCount = _c.cards.length;
      if (goHome) { _c.tab = 0; _rewardPillActive = false; }
    });
    final cardId = card['id'] as String?;
    if (cardId != null && !QartaDemo.enabled) _c.refreshCard(cardId);
    // « Voir ma carte » ouvre directement la carte (QR à montrer en caisse).
    if (goHome) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _openCardWalletIos(localCard); });
    }
  }

  // ── Profil ──────────────────────────────────────────────────────────────────

  void _showPhotoOptions() {
    showPhotoActionsIos(context,
        hasPhoto: _c.profileImageUrl != null || _c.profileImagePath != null,
        onChoose: () => _c.pickProfileImage(context),
        onDelete: _c.deleteProfileImage);
  }

  Future<void> _showPersonalInfo() async {
    await Navigator.push(context, CupertinoPageRoute(builder: (_) => PersonalInfoPageIos(
      name: _c.userName,
      email: _c.userEmail,
      phone: _c.phone,
      emailLocked: _c.isOAuth,
      lockedBy: _c.isGoogle ? 'Google' : 'Apple',
      onSave: (n, e, p) async { await _c.savePersonalInfo(n, e, p); },
    )));
  }

  void _showChangePassword() {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => ChangePasswordPageIos(
      onSave: _c.changePassword,
    )));
  }

  void _showDeleteAccount() {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => DeleteAccountPageIos(
      cardCount: _cards.length,
      needsPassword: !_c.isOAuth,
      lockedBy: _c.isGoogle ? 'Google' : 'Apple',
      onDelete: (password) async {
        if (QartaDemo.enabled) {
          await Future.delayed(const Duration(milliseconds: 800));
          return 'Aperçu : la suppression n\'est pas faite pour de vrai.';
        }
        return _c.deleteAccount(password); // null = supprimé → onLogout ramène à l'accueil
      },
    )));
  }

  void _openManageCards() {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => ManageCardsScreenIos(
      token: widget.token,
      userName: _userName,
      cards: _cards,
      rewards: _rewards,
      onRefresh: _refreshManual,
    )));
  }

  void _openHelp() {
    Navigator.push(context, CupertinoPageRoute(
      builder: (_) => const HelpPageIos(faqs: HelpSheet.faqs, email: 'qarta.contact@gmail.com'),
    ));
  }

  /// Réglages des notifications (enregistrés à chaque interrupteur).
  Future<void> _openNotifSettingsIos() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    Navigator.push(context, CupertinoPageRoute(builder: (_) => NotificationSettingsPageIos(
      push: p.getBool('notif_push') ?? true,
      offres: p.getBool('notif_offres') ?? true,
      visites: p.getBool('notif_visites') ?? false,
      onSave: (push, offres, visites) async {
        await p.setBool('notif_push', push);
        await p.setBool('notif_offres', offres);
        await p.setBool('notif_visites', visites);
        if (QartaDemo.enabled) return true;
        try {
          final res = await AuthService.authPut('/notifications/preferences', '', {
            'notif_push': push, 'notif_offres': offres, 'notif_visites': visites,
          });
          return res.statusCode >= 200 && res.statusCode < 300;
        } catch (_) {
          return false;
        }
      },
    )));
  }

  // ── Affichage ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_tab == 3 || _tab == 4) return _buildPage();
    if (_tab == 1) {
      return Scaffold(
        backgroundColor: kNavy,
        body: ScanTabIos(
          token: widget.token,
          userName: _userName,
          onCardAdded: (card, merchant) => _addScannedCard(card, merchant, goHome: true),
          onCardAddedStay: (card, merchant) => _addScannedCard(card, merchant, goHome: false),
          onBack: () => _setTab(0),
        ),
      );
    }
    return _buildHome();
  }

  /// Accueil : Cartes / Récompenses (tab 0) ou Historique (tab 2).
  Widget _buildHome() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.qBg,
        body: Stack(children: [
          const Positioned.fill(child: ClientGlowBackground()),
          Positioned.fill(child: iosReadableWidth(Stack(children: [
            Column(children: [
              if (_searching && _tab == 0) SizedBox(height: MediaQuery.paddingOf(context).top),
              // Pendant la recherche, le titre et le sélecteur se replient (comme sur iPhone).
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _searching && _tab == 0
                    ? const SizedBox(width: double.infinity)
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        SafeArea(
                          bottom: false,
                          child: ClientHeaderIos(
                            caption: ClientHeaderIos.today(),
                            title: _tab == 0 ? 'Bonjour ${_c.firstName}' : 'Historique',
                            notifCount: _c.notifCount,
                            onNotifTap: _openNotifs,
                            onProfileTap: _c.openProfil,
                            avatarImage: _avatar,
                            initials: _c.initials,
                          ),
                        ),
                        if (_tab == 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: SizedBox(
                              width: double.infinity,
                              child: CupertinoSlidingSegmentedControl<int>(
                                groupValue: _rewardPillActive ? 1 : 0,
                                padding: const EdgeInsets.all(2),
                                children: {
                                  0: _segLabel('Cartes', _c.cardCount),
                                  1: _segLabel('Récompenses', _c.rewardCount),
                                },
                                onValueChanged: (v) => v == 1 ? _goToRewards() : _goToCards(),
                              ),
                            ),
                          ),
                      ]),
              ),
              Expanded(child: _tab == 2 ? _buildHistory() : _buildCardsAndRewards()),
            ]),
            // Comme sur iPhone : la barre se cache pendant qu'on tape (clavier ouvert).
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              ClientBottomNavIos(
                currentTab: _tab,
                onTabChanged: _setTab,
                onScanTap: () => _setTab(1),
              ),
          ]))),
        ]),
      ),
    );
  }

  Widget _buildCardsAndRewards() => PageView(
        controller: _pillPageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          CardsTabIos(
            token: widget.token,
            userName: _userName,
            cards: _cards,
            onRefresh: _refreshManual,
            onStampEvent: _c.handleStampEvent,
            onScanTap: () => _setTab(1),
            onSearchActive: (v) => setState(() => _searching = v),
          ),
          ClientRewardsIos(
            rewards: _rewards,
            cards: _cards,
            onUse: _useRewardIos,
            onCardTap: _openCardIos,
            onRefresh: _refreshManual,
          ),
        ],
      );

  Widget _buildHistory() =>
      HistoryTabIos(token: widget.token, history: _c.history, onRefresh: _refreshManual, cards: _cards);

  Widget _segLabel(String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
          TextSpan(text: '  $n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.qSub)),
        ])),
      );

  /// Profil (tab 3) et Notifications (tab 4), plein écran sans barre.
  Widget _buildPage() {
    final account = _c.isOAuth ? (_c.isGoogle ? 'Compte Google' : 'Compte Apple') : _c.userEmail;
    final n = _c.cardCount;
    final cardsTxt = '$n carte${n > 1 ? 's' : ''}';
    final Widget body = _tab == 4
        ? ClientNotificationsIos(
            notifs: _c.notifs,
            filter: _c.notifFilter,
            onFilter: (f) => setState(() => _c.notifFilter = f),
            onBack: _closeNotifs,
            onReadAll: _c.markAllRead,
            onTap: (notif) => setState(() {
              notif['read'] = true;
              _c.notifCount = _c.notifs.where((x) => !(x['read'] as bool)).length;
            }),
          )
        : ClientProfileIos(
            name: _userName,
            subtitle: account.isEmpty ? cardsTxt : '$account · $cardsTxt',
            initials: _c.initials,
            avatar: _avatar,
            cardCount: n,
            showPassword: !_c.isOAuth,
            onBack: () => _setTab(_c.prevTab),
            onAvatarTap: _showPhotoOptions,
            onPersonalInfo: _showPersonalInfo,
            onPassword: _showChangePassword,
            onCards: _openManageCards,
            onNotifSettings: _openNotifSettingsIos,
            onHelp: _openHelp,
            onLogout: () => showLogoutConfirmIos(context, onLogout: _c.logout),
            onDelete: _showDeleteAccount,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(backgroundColor: context.cBg, body: iosReadableWidth(body)),
    );
  }
}
