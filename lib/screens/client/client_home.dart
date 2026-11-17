import 'package:flutter/cupertino.dart';
import '../merchant/merchant_tokens.dart' show kIsIOS;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../config/api.dart'; // utilisé dans client_home_ios.dart (part of)
import '../../main.dart'; // themeNotifier utilisé dans client_home_ios.dart
import '../auth_screen.dart';
import 'cards_tab.dart';
import 'history_tab.dart';
import 'history_tab_ios.dart';
import 'manage_cards_screen.dart';
import 'manage_cards_screen_ios.dart';
import 'notifications_sheet.dart';
import 'help_sheet.dart';
import 'widgets/client_bottom_nav_ios.dart'; // utilisé dans client_home_ios.dart (part of)
import 'widgets/client_bottom_nav.dart';
import 'widgets/client_header_ios.dart';
import 'widgets/client_header.dart';
import 'widgets/client_glow_background.dart';
import 'widgets/client_rewards_ios.dart';
import 'widgets/client_notifications_ios.dart';
import 'widgets/client_profile_ios.dart';
import 'widgets/client_profile_android.dart';
import 'widgets/client_notifs_android.dart';
import 'widgets/client_sheets_ios.dart';
import 'widgets/client_settings_ios.dart';
import 'personal_info_page_android.dart';
import 'notification_settings_page_android.dart';
import 'help_page_android.dart';
import '../../config/demo_mode.dart';
import 'scan_tab.dart';
import 'scan_tab_ios.dart';
import '../../config/app_colors.dart';
import '../../utils/logger.dart';
import '../../utils/platform_route.dart';
import 'client_home_controller.dart';

part 'client_home_ios.dart';

class ClientHome extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> initialCards;
  final List<dynamic> initialHistory;
  final List<dynamic> initialRewards;
  final List<dynamic> initialRawNotifs;
  final bool fromCache;
  const ClientHome({
    super.key,
    required this.token,
    required this.userName,
    this.initialCards    = const [],
    this.initialHistory  = const [],
    this.initialRewards  = const [],
    this.initialRawNotifs = const [],
    this.fromCache       = false,
  });

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late ClientHomeController _ctrl;

  // ── Variables UI Android uniquement ────────────────────────────────────────
  bool _searching = false;
  bool _previewEmpty = false;
  bool _rewardPillActive = false;
  String? _animatingCardId;
  String? _slidingInCardId;
  StampEvent? _lastStampEvent;
  StampEvent? _stampBadge;
  Timer? _stampBadgeTimer;
  Timer? _slideInTimer;
  String? _cardToastText;
  Timer? _cardToastTimer;
  late PageController _pillPageCtrl;

  // ── Getters de délégation (compatibilité client_home_ios.dart via part of) ─
  List<dynamic> get _cards    => _ctrl.cards;
  List<dynamic> get _rewards  => _ctrl.rewards;
  set _rewards(List<dynamic> v) { _ctrl.rewards = v; _ctrl.rewardCount = v.length; }
  List<dynamic> get _history  => _ctrl.history;
  List<Map>     get _notifs   => _ctrl.notifs;
  int    get _notifCount  => _ctrl.notifCount;
  set _notifCount(int v)  => _ctrl.notifCount = v;
  int    get _cardCount   => _ctrl.cardCount;
  int    get _rewardCount => _ctrl.rewardCount;
  set _rewardCount(int v) => _ctrl.rewardCount = v;
  String get _notifFilter => _ctrl.notifFilter;
  set _notifFilter(String v) => _ctrl.notifFilter = v;
  bool   get _notifsLoaded => _ctrl.notifsLoaded;
  bool   get _statsLoaded  => _ctrl.statsLoaded;
  String get _userName     => _ctrl.userName;
  String get _userEmail    => _ctrl.userEmail;
  String get _phone        => _ctrl.phone;
  bool   get _isGoogle     => _ctrl.isGoogle;
  bool   get _isOAuth      => _ctrl.isOAuth;
  String? get _profileImageUrl  => _ctrl.profileImageUrl;
  String? get _profileImagePath => _ctrl.profileImagePath;
  int    get _tab     => _ctrl.tab;
  int    get _prevTab => _ctrl.prevTab;
  String get _firstName => _ctrl.firstName;
  String get _initials  => _ctrl.initials;

  @override
  void initState() {
    super.initState();
    AppLogger.client('ClientHome chargé → userName: ${widget.userName}');
    WidgetsBinding.instance.addObserver(this);
    _pillPageCtrl = PageController();
    _ctrl = ClientHomeController(
      token: widget.token,
      initialUserName: widget.userName,
      initialCards:     widget.initialCards,
      initialHistory:   widget.initialHistory,
      initialRewards:   widget.initialRewards,
      initialRawNotifs: widget.initialRawNotifs,
      fromCache:        widget.fromCache,
    );
    _ctrl.addListener(() { if (mounted) setState(() {}); });
    _ctrl.onStampEvent = _handleStampEvent;
    _ctrl.onLogout = () {
      if (mounted) Navigator.pushReplacement(context, platformRoute(builder: (_) => const AuthScreen()));
    };
    _ctrl.onNotifOpen = () {
      if (mounted) _openNotifs();
    };
    _ctrl.onMerchantJoined = _onMerchantJoined;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _ctrl.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pillPageCtrl.dispose();
    _stampBadgeTimer?.cancel();
    _slideInTimer?.cancel();
    _cardToastTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Callbacks controller → UI ───────────────────────────────────────────────

  void _onMerchantJoined(JoinMerchantResult result) {
    if (!mounted) return;
    if (result.status == JoinResult.added) {
      if (kIsIOS) { _showJoinedIos(result.cardId); return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Carte ajoutée !'),
        backgroundColor: Color(0xFF2C7BE5),
        behavior: SnackBarBehavior.floating,
      ));
    } else if (result.status == JoinResult.alreadyMember) {
      if (kIsIOS) { showIosAlert(context, 'Déjà dans tes cartes', 'Tu as déjà la carte de ce commerce.'); return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tu as déjà cette carte !'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // Appelé par le controller après avoir mis à jour les cartes
  void _handleStampEvent(StampEvent e) {
    if (kIsIOS) {
      if (e.reward) _onRewardUnlockedIos(e);
      else if (!QartaDemo.enabled) _ctrl.refreshCard(e.cardId);
      return;
    }
    if (e.reward) setState(() => _lastStampEvent = e);
    _showStampPopup(e);
  }

  // ── Méthodes de délégation logique ─────────────────────────────────────────

  // Point d'entrée pour les widgets (CardsTab, QRModal iOS) → logique dans controller
  Future<void> _onStampEvent(StampEvent e) => _ctrl.handleStampEvent(e);

  Future<void> _refreshCard(String cardId) => _ctrl.refreshCard(cardId);
  Future<void> _loadRewardsCount()          => _ctrl.loadRewardsCount();
  void         _markAllRead()               => _ctrl.markAllRead();
  void         _logout()                    => _ctrl.logout();

  Future<void> _refreshManual() async {
    AppLogger.client('Refresh manuel → tout en arrière-plan');
    _ctrl.loadStats();
    _ctrl.loadRewardsCount();
    _ctrl.loadHistory();
    _ctrl.loadNotifs();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ── Navigation / tabs ───────────────────────────────────────────────────────

  void _setTab(int tab) {
    if (tab != 0) setState(() => _searching = false);
    if (_ctrl.tab == 0 && tab != 0 && _rewardPillActive) {
      setState(() => _rewardPillActive = false);
      _pillPageCtrl.jumpToPage(0);
    }
    _ctrl.setTab(tab);
  }

  void _openProfil() => _ctrl.openProfil();

  void _openNotifs() {
    _ctrl.openNotifs();
    if (_notifCount > 0 && !kIsIOS) _markAllRead();
  }

  void _closeNotifs() => _ctrl.closeNotifs();

  void _goToRewards() {
    final already = _ctrl.tab == 0;
    setState(() => _rewardPillActive = true);
    _ctrl.setTab(0);
    if (already) {
      _pillPageCtrl.animateToPage(1, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pillPageCtrl.jumpToPage(1);
      });
    }
  }

  void _goToCards() {
    final already = _ctrl.tab == 0;
    setState(() => _rewardPillActive = false);
    _ctrl.setTab(0);
    if (already) {
      _pillPageCtrl.animateToPage(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pillPageCtrl.jumpToPage(0);
      });
    }
  }

  // ── UI : photo de profil ────────────────────────────────────────────────────

  void _showPhotoOptions() {
    final hasPhoto = _profileImageUrl != null || _profileImagePath != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: context.qBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: context.qBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          _photoOptionRow(
            icon: Icons.photo_library_outlined,
            label: 'Changer la photo',
            onTap: () { Navigator.pop(context); _ctrl.pickProfileImage(context); },
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 4),
            _photoOptionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer la photo',
              color: const Color(0xFFE24B4A),
              onTap: () { Navigator.pop(context); _ctrl.deleteProfileImage(); },
            ),
          ],
        ]),
      ),
    );
  }

  Widget _photoOptionRow({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final c = color ?? context.qText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.qSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c)),
        ]),
      ),
    );
  }

  // ── UI : infos perso ────────────────────────────────────────────────────────

  Future<void> _showPersonalInfo() async {
    if (Platform.isIOS) {
      await Navigator.push(context, CupertinoPageRoute(builder: (_) => PersonalInfoPageIos(
        name: _userName,
        email: _userEmail,
        phone: _phone,
        emailLocked: _isOAuth,
        lockedBy: _isGoogle ? 'Google' : 'Apple',
        onSave: _ctrl.savePersonalInfo,
      )));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalInfoPageAndroid(
      name: _userName,
      email: _userEmail,
      phone: _phone,
      emailLocked: _isOAuth,
      lockedBy: _isGoogle ? 'Google' : 'Apple',
      onSave: _ctrl.savePersonalInfo,
    )));
  }

  // ── UI : changement de mot de passe ────────────────────────────────────────

  void _showChangePassword() {
    if (kIsIOS) {
      Navigator.push(context, CupertinoPageRoute(builder: (_) => ChangePasswordPageIos(
        onSave: (current, next) async {
          if (QartaDemo.enabled) return null;
          return await _ctrl.changePassword(current, next);
        },
      )));
      return;
    }
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading      = false;
    bool showCurrent  = false;
    bool showNew      = false;
    bool showConfirm  = false;
    const blue = Color(0xFF2C7BE5);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bg     = isDark ? const Color(0xFF1E1D2A) : Colors.white;
          final sub    = isDark ? Colors.white54 : Colors.black45;

          Widget passField({
            required TextEditingController ctrl,
            required String label,
            required bool visible,
            required VoidCallback onToggle,
          }) => Container(
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: blue.withValues(alpha: 0.12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.lock_outline_rounded, color: blue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  obscureText: !visible,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: label,
                    hintStyle: TextStyle(color: sub, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: sub, size: 18),
                onPressed: onToggle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          );

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Changer le mot de passe', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 20),
                  passField(ctrl: currentCtrl, label: 'Mot de passe actuel', visible: showCurrent, onToggle: () => setS(() => showCurrent = !showCurrent)),
                  const SizedBox(height: 12),
                  passField(ctrl: newCtrl, label: 'Nouveau mot de passe', visible: showNew, onToggle: () => setS(() => showNew = !showNew)),
                  const SizedBox(height: 12),
                  passField(ctrl: confirmCtrl, label: 'Confirmer le nouveau mot de passe', visible: showConfirm, onToggle: () => setS(() => showConfirm = !showConfirm)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : () async {
                        if (newCtrl.text != confirmCtrl.text) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Les mots de passe ne correspondent pas'),
                            backgroundColor: Colors.red,
                          ));
                          return;
                        }
                        setS(() => loading = true);
                        final err = await _ctrl.changePassword(currentCtrl.text, newCtrl.text);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(err ?? 'Mot de passe mis à jour !'),
                          backgroundColor: err == null ? blue : Colors.red,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(backgroundColor: Colors.white))
                          : const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── UI : suppression de compte ──────────────────────────────────────────────

  void _showDeleteAccount() {
    final passCtrl = TextEditingController();
    bool loading = false;
    (kIsIOS ? showCupertinoDialog<void> : showDialog<void>)(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final actions = [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                final err = await _ctrl.deleteAccount(passCtrl.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (err != null && mounted) {
                  if (kIsIOS) {
                    showIosAlert(context, 'Suppression impossible', err);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                  }
                }
                // Si err == null : _ctrl.logout() a déjà déclenché onLogout → navigation auto
              },
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive()) : const Text('Supprimer'),
            ),
          ];
          final content = Material(
            color: Colors.transparent,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Cette action est irréversible. Toutes tes cartes et données seront supprimées.', style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              kIsIOS
                  ? CupertinoTextField(controller: passCtrl, obscureText: true, placeholder: 'Ton mot de passe')
                  : TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirme ton mot de passe')),
            ]),
          );
          if (kIsIOS) {
            return CupertinoAlertDialog(
              title: const Text('Supprimer mon compte', style: TextStyle(color: Color(0xFFE24B4A))),
              content: content,
              actions: actions,
            );
          }
          return AlertDialog(
            title: const Text('Supprimer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFE24B4A))),
            content: content,
            actions: actions,
          );
        },
      ),
    );
  }

  // ── UI : tampon / récompense Android ───────────────────────────────────────

  void _showStampPopup(StampEvent e) {
    _stampBadgeTimer?.cancel();
    setState(() => _stampBadge = e);
    _stampBadgeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _stampBadge = null);
      if (e.reward) {
        setState(() => _animatingCardId = e.cardId);
      } else {
        _ctrl.refreshCard(e.cardId);
      }
    });
  }

  Future<void> _onRewardAnimationDone() async {
    if (!mounted) return;
    final e      = _lastStampEvent;
    final cardId = _animatingCardId;
    setState(() {
      if (e != null && cardId != null) {
        final idx = _ctrl.cards.indexWhere((c) => c['id'] == cardId);
        if (idx >= 0) {
          final card = Map<String, dynamic>.from(_ctrl.cards[idx] as Map);
          if (e.isPoints) card['points_count'] = e.newCount;
          else            card['stamps_count']  = e.newCount;
          _ctrl.cards[idx] = card;
        }
      }
      _animatingCardId = null;
      _slidingInCardId = cardId;
    });
    if (cardId != null) _ctrl.refreshCard(cardId);
    _slideInTimer?.cancel();
    _slideInTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _slidingInCardId = null);
    });
  }

  Widget _buildCardToast(String name) {
    final bottom = MediaQuery.of(context).viewPadding.bottom + 110;
    return Positioned(
      bottom: bottom,
      left: 24, right: 24,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$name ajoutée à vos cartes',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildStampBadge(StampEvent e) {
    final unit   = e.isPoints ? 'pt' : 'tampon';
    final accent = e.reward ? const Color(0xFFFBBF24) : const Color(0xFF27AE60);
    final bg     = e.reward ? const Color(0xFFFFFBEB) : const Color(0xFFF0F9F4);
    final txt    = e.reward ? const Color(0xFF92400E) : const Color(0xFF065F46);
    final label  = e.reward
        ? '🎉 Récompense chez ${e.merchantName}'
        : '+${e.delta} ${unit}${e.delta > 1 ? "s" : ""} · ${e.merchantName}';
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
                boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(e.reward ? Icons.emoji_events_rounded : Icons.check_rounded, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: txt))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (kIsIOS && (_tab == 0 || _tab == 2)) return _buildIosHome();
    if (kIsIOS && (_tab == 3 || _tab == 4)) return _buildIosPage();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.qBg,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: MediaQuery(
          data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
          child: Stack(
            children: [
              if (_tab == 1)
                Positioned.fill(child: _buildTabContent())
              else
                Column(children: [
                  Expanded(child: _buildTabContent()),
                ]),
              if (_tab != 1) ...[
                ClientBottomNav(
                  currentTab: _tab,
                  onTabChanged: _setTab,
                  onScanTap: () => _setTab(1),
                  profileImageUrl: _profileImageUrl,
                ),
              ],
              if (_cardToastText != null) _buildCardToast(_cardToastText!),
              if (_stampBadge != null) _buildStampBadge(_stampBadge!),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab content ─────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return PageView(
          controller: _pillPageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            CardsTab(
              token: widget.token,
              userName: _userName,
              cards: _previewEmpty ? [] : _cards,
              onRefresh: _refreshManual,
              onStampEvent: _onStampEvent,
              cardIdToAnimate: _animatingCardId,
              cardIdToSlideIn: _slidingInCardId,
              onAnimationDone: _onRewardAnimationDone,
              onScanTap: () => _setTab(1),
              onSearchActive: (v) => setState(() => _searching = v),
              activeTab: _tab,
              onNavTap: _setTab,
            ),
            ClientRewardsIos(
              rewards: _previewEmpty ? [] : _rewards,
              cards:   _previewEmpty ? [] : _cards,
              onUse: _useRewardIos,
              onCardTap: _openCardIos,
              onRefresh: _refreshManual,
            ),
          ],
        );
      case 1:
        void addCard(Map<String, dynamic> card, Map<String, dynamic> merchant, {required bool goHome}) {
          final localCard = Map<String, dynamic>.from(card)
            ..['merchants']    = merchant
            ..['card_design']  = card['card_design']
            ..['last_scan_at'] = null;
          final merchantName = merchant['business_name'] as String? ?? '';
          setState(() {
            _ctrl.cards.insert(0, localCard);
            _ctrl.cardCount = _ctrl.cards.length;
            if (goHome) { _ctrl.tab = 0; _rewardPillActive = false; }
            _cardToastText = merchantName.isNotEmpty ? merchantName : 'Nouvelle carte';
          });
          _cardToastTimer?.cancel();
          _cardToastTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _cardToastText = null);
          });
          final cardId = card['id'] as String?;
          if (cardId != null && !QartaDemo.enabled) _ctrl.refreshCard(cardId);
        }
        return kIsIOS
            ? ScanTabIos(
                token: widget.token,
                userName: _userName,
                onCardAdded: (card, merchant) => addCard(card, merchant, goHome: true),
                onCardAddedStay: (card, merchant) => addCard(card, merchant, goHome: false),
                onBack: () => _setTab(0),
              )
            : ScanTab(
                token: widget.token,
                userName: _userName,
                onCardAdded: (card, merchant) => addCard(card, merchant, goHome: true),
                onCardAddedStay: (card, merchant) => addCard(card, merchant, goHome: false),
                onBack: () => _setTab(0),
              );
      case 2:
        return kIsIOS
            ? HistoryTabIos(token: widget.token, history: _history, onRefresh: _refreshManual, cards: _cards)
            : HistoryTab(token: widget.token, history: _history, onRefresh: _refreshManual, cards: _cards);
      case 3:
        return ClientProfileAndroid(
          isOAuth: _isOAuth,
          isGoogle: _isGoogle,
          onPersonalInfo: _showPersonalInfo,
          onPassword: _showChangePassword,
          onCards: () => Navigator.push(context, platformRoute(
            builder: (_) => kIsIOS
                ? ManageCardsScreenIos(
                    token: widget.token,
                    userName: _userName,
                    cards: _cards,
                    rewards: _rewards,
                    onRefresh: _refreshManual,
                  )
                : ManageCardsScreen(
                    token: widget.token,
                    userName: _userName,
                    cards: _cards,
                    rewards: _rewards,
                    onRefresh: _refreshManual,
                  ),
          )),
          onNotifSettings: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const NotificationsSheet(),
          ),
          onHelp: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const HelpSheet(),
          ),
          onLogout: _logout,
          onDelete: _showDeleteAccount,
        );
      case 4:
        return ClientNotifsAndroid(
          notifs: _notifs,
          filter: _notifFilter,
          onTap: (n) => setState(() {
            n['read'] = true;
            _notifCount = _notifs.where((x) => !(x['read'] as bool)).length;
          }),
        );
      default:
        return CardsTab(token: widget.token, userName: _userName, cards: _cards, onRefresh: _ctrl.loadStats, onStampEvent: _onStampEvent);
    }
  }
}
