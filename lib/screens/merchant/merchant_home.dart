import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import '../auth_screen.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'clients_screen.dart';
import 'static_qr_screen.dart';
import 'merchant_onboarding.dart';
import 'abonnement_screen.dart';
import 'stats_screen.dart';
import 'info_commerce_screen.dart';
import 'carte_editor_screen.dart';
import 'google_auto_screen.dart';
import 'merchant_inbox_screen.dart';
import '../client/cards_tab.dart' show LoyaltyCardFace, CardStyle;
import '../../utils/logger.dart';

// ─── Design tokens (alignés sur le mockup dashboard v10) ────────────────────
const _kPrimary   = Color(0xFF2C7BE5);
const _kBlueLight = Color(0xFF4A9EF5);
const _kNavy      = Color(0xFF0B1220);
const _kNavyCard  = Color(0xFF1E2D45);
const _kGold      = Color(0xFFF59E0B);
const _kSuccess   = Color(0xFF27AE60);
const _kError     = Color(0xFFE24B4A);
const _kPurple    = Color(0xFF7C3AED);

// Largeur max du contenu — sur tablette/pliable on centre, sur téléphone aucun effet
const double _kMaxContentWidth = 500;

class MerchantHome extends StatefulWidget {
  final String token;
  final String merchantName;
  final Map? initialProfile;
  final Map? initialStats;
  final List<dynamic> initialRecentClients;
  final List<dynamic> initialDaily;
  final List<dynamic> initialScanHistory;
  final Map? initialCardDesign;

  const MerchantHome({
    super.key,
    required this.token,
    required this.merchantName,
    this.initialProfile,
    this.initialStats,
    this.initialRecentClients  = const [],
    this.initialDaily          = const [],
    this.initialScanHistory    = const [],
    this.initialCardDesign,
  });

  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome> {
  Color get _kBg    => context.cBg;
  Color get _kWhite => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText  => context.cText;
  Color get _kSub   => context.cSub;

  int _tab = 0;
  Map? merchantInfo;
  Map? stats;
  bool loading = true;
  bool _showOnboarding = false;
  List<dynamic> _recentClients = [];
  List<dynamic> _daily = [];        // [{date, scans, rewards}] sur 30 jours
  List<dynamic> _scanHistory = [];  // derniers scans (pour estimer la rétention)
  String _period = 'today';         // 'today' | '7j' | '30j'
  String _graphRange = '7j';        // '7j' | '30j' — plage du graphique
  String _retPeriod = 'sem';        // 'sem' | 'mois' — taux de retour
  Map? _cardDesign;                 // design de carte créé sur qarta.be (card_design JSON)

  static const Map<String, Map<String, dynamic>> _categoryStyles = {
    'Café':        {'emoji': '☕', 'color': Color(0xFF2C7BE5)},
    'Boulangerie': {'emoji': '🥐', 'color': Color(0xFFD4A017)},
    'Restaurant':  {'emoji': '🍽', 'color': Color(0xFFC0392B)},
    'Healthy':     {'emoji': '🥗', 'color': Color(0xFF27AE60)},
    'Librairie':   {'emoji': '📚', 'color': Color(0xFF8E44AD)},
    'Coiffeur':    {'emoji': '✂', 'color': Color(0xFF2980B9)},
  };

  Map<String, dynamic> get _style {
    final cat = merchantInfo?['category'] as String? ?? '';
    return _categoryStyles[cat] ?? {'emoji': '🏪', 'color': _kPrimary};
  }

  bool get _isPoints => (merchantInfo?['program_type'] as String?) == 'points';

  String get _businessName => merchantInfo?['business_name'] as String? ?? widget.merchantName;

  String get _initials {
    final name = _businessName.trim();
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : 'Q';
  }

  @override
  void initState() {
    super.initState();
    AppLogger.merchant('MerchantHome chargé → merchantName: ${widget.merchantName}');
    if (widget.initialProfile != null) {
      // Données préchargées depuis le splash → affichage immédiat sans spinner
      merchantInfo   = widget.initialProfile;
      stats          = widget.initialStats;
      _recentClients = List<dynamic>.from(widget.initialRecentClients);
      _daily         = List<dynamic>.from(widget.initialDaily);
      _scanHistory   = List<dynamic>.from(widget.initialScanHistory);
      _cardDesign    = widget.initialCardDesign;
      loading        = false;
      AppLogger.merchant('Données préchargées appliquées → ${merchantInfo?['business_name']}');
    } else {
      _loadData();
    }
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('merchant_onboarding_done') ?? false;
    if (!done && mounted) {
      AppLogger.merchant('Onboarding → première visite, affichage tutoriel');
      setState(() => _showOnboarding = true);
    } else {
      AppLogger.merchant('Onboarding → déjà complété, skip');
    }
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    AppLogger.merchant('Chargement profil + stats...');
    if (showSpinner) setState(() => loading = true);
    final api = ApiService.instance;

    final profileResult = await api.getMerchantProfile();
    final statsResult   = await api.getMerchantStats();

    if (mounted) {
      if (profileResult.isOk) {
        AppLogger.merchant('Profil → business_name: ${profileResult.value['business_name']}, category: ${profileResult.value['category']}');
      } else {
        AppLogger.error('Profil → erreur : ${profileResult.error}');
      }
      if (statsResult.isOk) {
        AppLogger.merchant('Stats → clients: ${statsResult.value['total_clients']}, tampons: ${statsResult.value['total_stamps']}, récompenses: ${statsResult.value['total_rewards']}');
      } else {
        AppLogger.error('Stats → erreur : ${statsResult.error}');
      }
      setState(() {
        merchantInfo = profileResult.isOk ? profileResult.value : null;
        stats        = statsResult.isOk   ? statsResult.value   : null;
        loading      = false;
      });
    }
    await _loadRecentClients();
    await _loadDaily();
    await _loadCardDesign();
  }

  Future<void> _loadCardDesign() async {
    AppLogger.merchant('Chargement design carte...');
    final r = await ApiService.instance.getMerchantCardDesign();
    if (mounted && r.isOk) {
      final hasDesign = r.value != null;
      AppLogger.merchant('Design carte → ${hasDesign ? "trouvé" : "aucun design créé"}');
      setState(() => _cardDesign = r.value?['card_design'] as Map?);
    } else if (r.isErr) {
      AppLogger.error('Design carte → erreur : ${r.error}');
    }
  }

  Future<void> _loadRecentClients() async {
    final r = await ApiService.instance.getMerchantClients();
    if (mounted && r.isOk) {
      AppLogger.merchant('Clients → ${r.value.length} chargé(s)');
      setState(() => _recentClients = r.value);
    }
  }

  Future<void> _loadDaily() async {
    AppLogger.merchant('Chargement stats 30j + historique scans...');
    final r = await ApiService.instance.getDailyStats();
    if (mounted && r.isOk) {
      AppLogger.merchant('Stats daily → ${r.value.length} jours reçus');
      setState(() => _daily = r.value);
    }
    final h = await ApiService.instance.getMerchantScanHistory();
    if (mounted && h.isOk) {
      AppLogger.merchant('Historique scans → ${h.value.length} entrées');
      setState(() => _scanHistory = h.value);
    }
  }

  // Taux de retour estimé : % de clients revenus ≥ 2× sur la période, à partir
  // de l'historique des scans (approx ; un endpoint dédié serait plus précis).
  ({int pct, int returning, int total}) _retention(String period) {
    final cutoff = DateTime.now().subtract(Duration(days: period == 'sem' ? 7 : 30));
    final counts = <String, int>{};
    for (final s in _scanHistory) {
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
      if (t == null || t.isBefore(cutoff)) continue;
      final cid = (s['client_id'] ?? '').toString();
      if (cid.isEmpty) continue;
      counts[cid] = (counts[cid] ?? 0) + 1;
    }
    final total = counts.length;
    final returning = counts.values.where((c) => c >= 2).length;
    final pct = total > 0 ? (returning / total * 100).round() : 0;
    return (pct: pct, returning: returning, total: total);
  }

  int _retentionPrevPct(String period) {
    final days = period == 'sem' ? 7 : 30;
    final now  = DateTime.now();
    final from = now.subtract(Duration(days: days * 2));
    final to   = now.subtract(Duration(days: days));
    final counts = <String, int>{};
    for (final s in _scanHistory) {
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
      if (t == null || t.isBefore(from) || !t.isBefore(to)) continue;
      final cid = (s['client_id'] ?? '').toString();
      if (cid.isEmpty) continue;
      counts[cid] = (counts[cid] ?? 0) + 1;
    }
    if (counts.isEmpty) return 0;
    final returning = counts.values.where((c) => c >= 2).length;
    return (returning / counts.length * 100).round();
  }

  // ─── Agrégation KPIs selon la période sélectionnée ──────────────────────────
  // Retourne {scans, rewards, scansDelta, rewardsDelta} (delta = null si non calculable)
  Map<String, int?> _periodAgg() {
    if (_daily.isEmpty) return {'scans': 0, 'rewards': 0, 'scansDelta': null, 'rewardsDelta': null};
    int sumScans(List<dynamic> l)   => l.fold(0, (s, d) => s + ((d['scans']   as int?) ?? 0));
    int sumRewards(List<dynamic> l) => l.fold(0, (s, d) => s + ((d['rewards'] as int?) ?? 0));

    if (_period == 'today') {
      final today = _daily.last;
      final yest  = _daily.length >= 2 ? _daily[_daily.length - 2] : null;
      final s = (today['scans'] as int?) ?? 0, r = (today['rewards'] as int?) ?? 0;
      return {
        'scans': s, 'rewards': r,
        'scansDelta':   yest != null ? s - ((yest['scans']   as int?) ?? 0) : null,
        'rewardsDelta': yest != null ? r - ((yest['rewards'] as int?) ?? 0) : null,
      };
    }
    final n = _period == '7j' ? 7 : 30;
    final cur  = _daily.length >= n ? _daily.sublist(_daily.length - n) : _daily;
    final prev = _daily.length >= n * 2 ? _daily.sublist(_daily.length - n * 2, _daily.length - n) : null;
    return {
      'scans': sumScans(cur), 'rewards': sumRewards(cur),
      'scansDelta':   prev != null ? sumScans(cur)   - sumScans(prev)   : null,
      'rewardsDelta': prev != null ? sumRewards(cur) - sumRewards(prev) : null,
    };
  }

  Future<void> _navigateToCarteEditor() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CarteEditorScreen(token: widget.token, merchantInfo: merchantInfo ?? {}, initialDesign: _cardDesign),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _cardDesign = result;
        final newName = result['cardName'] as String?;
        if (newName != null && newName.isNotEmpty && merchantInfo != null) {
          merchantInfo = Map.from(merchantInfo!)..['business_name'] = newName;
        }
      });
    }
  }

  void _logout() async {
    AppLogger.auth('Logout merchant → déconnexion');
    await AuthService.logout();
    if (!mounted) return;
    AppLogger.nav('Logout → retour AuthScreen');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _openScanner() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScannerScreen(token: widget.token, merchantInfo: merchantInfo, initialHistory: _scanHistory),
    ));
  }

  void _showProfilSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MerchantProfilSheet(
        token: widget.token,
        merchantInfo: merchantInfo,
        onLogout: _logout,
        onNavigateToProgram: null,
        onNavigateToNotifs: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: merchantInfo, initialClients: _recentClients))),
        onNavigateToQR: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => StaticQRScreen(token: widget.token, businessName: _businessName, accentColor: _kPrimary),
        )),
        onNavigateToAbonnement: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const AbonnementScreen(),
        )),
        onNavigateToInfo: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => InfoCommerceScreen(token: widget.token, merchantInfo: merchantInfo ?? {}),
        )).then((updated) {
          if (updated != null && mounted) setState(() => merchantInfo = updated as Map);
        }),
        onNavigateToCarteEditor: _navigateToCarteEditor,
        onNavigateToStats: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => StatsScreen(
            token: widget.token,
            merchantInfo: merchantInfo,
            initialStats:   stats,
            initialDaily:   _daily,
            initialHistory: _scanHistory,
            initialClients: _recentClients,
          ),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 84 + MediaQuery.of(context).padding.bottom),
                    child: loading
                        ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                        : _buildTabContent(),
                  ),
                ),
              ],
            ),
            _buildBottomNav(),
            if (_showOnboarding) MerchantOnboardingScreen(
              onDone: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('merchant_onboarding_done', true);
                if (mounted) setState(() => _showOnboarding = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header navy (avatar + nom + statut + cloche) ───────────────────────────

  Widget _buildHeader() {
    final clients = stats?['total_clients'] ?? 0;
    final rewards = stats?['total_rewards'] ?? 0;
    final active  = (merchantInfo?['subscription_status'] as String?) == 'active';

    return Container(
      color: _kNavy,
      child: Stack(children: [
        // Orbe lumineux discret
        Positioned(
          top: -60, right: -20,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kPrimary.withValues(alpha: 0.25), Colors.transparent], stops: const [0, 0.7]))),
        ),
        Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: Column(children: [
          // Ligne du haut
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 14, left: 20, right: 20, bottom: 0),
            child: Row(children: [
              GestureDetector(
                onTap: _showProfilSheet,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _kBlueLight.withValues(alpha: 0.45), width: 1.5)),
                  child: Center(child: Text(_initials,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kBlueLight))),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_businessName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kSuccess, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Connecté · ${active ? "Plan Pro" : "Plan Free"}',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
                  ]),
                ]),
              ),
            ]),
          ),
          // Bande stats globales
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(children: [
              _gsCard('$clients', 'Clients carte', () => setState(() => _tab = 1)),
              const SizedBox(width: 7),
              _gsCard('$rewards', 'Récompenses', null),
            ]),
          ),
        ]),
        )),
      ]),
    );
  }

  Widget _gsCard(String val, String label, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kNavyCard),
          ),
          child: Column(children: [
            Text(val, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.42))),
          ]),
        ),
      ),
    );
  }

  // ─── Tab Content ──────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0: return _buildDashboard();
      case 1: return ClientsScreen(
          token:               widget.token,
          merchantInfo:        merchantInfo,
          cardDesign:          _cardDesign,
          initialClients:      _recentClients,
          initialScanHistory:  _scanHistory,
        );
      case 2: return HistoryScreen(
          token:              widget.token,
          merchantInfo:       merchantInfo,
          initialHistory:     _scanHistory,
          initialClients:     _recentClients,
          initialCardDesign:  _cardDesign,
        );
      case 3: return NotificationsScreen(token: widget.token, merchantInfo: merchantInfo, initialClients: _recentClients);
      default: return _buildDashboard();
    }
  }

  // ─── Dashboard ────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    if (merchantInfo == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('⚠️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 16),
          Text('Profil non configuré', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 8),
          Text('Configure ton commerce pour commencer à fidéliser tes clients.',
              textAlign: TextAlign.center, style: TextStyle(color: _kSub, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Configurez votre programme sur qarta.be'), duration: Duration(seconds: 3))),
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: const Text('Configurer sur qarta.be'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ]),
      ));
    }

    final agg = _periodAgg();

    return RefreshIndicator(
      onRefresh: () => _loadData(showSpinner: false),
      color: _kPrimary,
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
        child: ListView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(context).padding.bottom),
        children: [
          _googleBubble(),
          const SizedBox(height: 12),
          _periodToggle(),
          const SizedBox(height: 12),
          _kpiGrid(agg),
          const SizedBox(height: 12),
          _retentionCard(),
          const SizedBox(height: 14),
          Center(child: Text('Statistiques générales',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kText))),
          const SizedBox(height: 8),
          _graphCard(),
          const SizedBox(height: 12),
          _cardPreviewBlock(),
        ],
      ),
      )),
    );
  }

  // ── Bulle "Demander un avis Google" ─────────────────────────────────────────
  Widget _googleBubble() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => GoogleAutoScreen(token: widget.token, merchantInfo: merchantInfo ?? {}))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A3A6B), Color(0xFF0F2044)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBlueLight.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Text('G', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
          const SizedBox(width: 8),
          const Expanded(child: Text('Demander un avis Google',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
            child: const Text('+5 pts offerts',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFFBBF24))),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.5), size: 16),
        ]),
      ),
    );
  }

  // ── Carte "Taux de retour" (rétention) ─────────────────────────────────────
  Widget _retentionCard() {
    final r       = _retention(_retPeriod);
    final prevPct = _retentionPrevPct(_retPeriod);
    final delta   = r.pct - prevPct;
    final deltaStr = delta > 0 ? '+$delta%' : (delta < 0 ? '$delta%' : '= même');
    final isDark = context.isDark;
    final bg     = isDark ? _kNavyCard : const Color(0xFFEFF5FE);
    final border = isDark ? const Color(0xFF2A3D5A) : const Color(0xFFD6E6FB);
    final iconBg = isDark ? _kPrimary.withValues(alpha: 0.25) : const Color(0xFFDBEAFB);

    Widget pill(String key, String label) {
      final active = _retPeriod == key;
      return GestureDetector(
        onTap: () => setState(() => _retPeriod = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
              color: active ? Colors.white : _kSub)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.replay_rounded, color: _kPrimary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Taux de retour', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kText)),
            Text('Clients qui reviennent', style: TextStyle(fontSize: 9, color: _kSub)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${r.pct}%', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _kPrimary, height: 1)),
            Text('$deltaStr ${_retPeriod == 'sem' ? "cette sem." : "ce mois"}',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: delta < 0 ? _kError : _kSuccess)),
          ]),
        ]),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: context.cSurface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [pill('sem', 'Semaine'), pill('mois', 'Mois')]),
        ),
      ]),
    );
  }

  // ── Toggle période (Aujourd'hui / 7 jours / 30 jours) ──────────────────────
  Widget _periodToggle() {
    Widget btn(String key, String label) {
      final active = _period == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _period = key),
          child: Container(
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kSub)),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: _kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
      child: Row(children: [
        btn('today', "Aujourd'hui"),
        btn('7j', '7 jours'),
        btn('30j', '30 jours'),
      ]),
    );
  }

  // ── Grille de 3 KPIs (1 ligne) ──────────────────────────────────────────────
  Widget _kpiGrid(Map<String, int?> agg) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _kpiCard('0', 'Clients ${_period == 'today' ? "aujourd'hui" : 'actifs'}', null),
        const SizedBox(width: 8),
        _kpiCard('${agg['scans'] ?? 0}', _isPoints ? 'Points ajoutés' : 'Tampons ajoutés', agg['scansDelta']),
        const SizedBox(width: 8),
        _kpiCard('0', 'Nouveaux clients', null),
      ]),
    );
  }

  Widget _kpiCard(String val, String label, int? delta) {
    final ref = _period == 'today' ? 'hier' : 'préc.';
    Widget? deltaChip;
    if (delta != null) {
      final up = delta > 0, flat = delta == 0;
      final c = flat ? _kSub : (up ? _kSuccess : _kError);
      final bg = flat ? _kBg : (up ? const Color(0xFFE4F5EB) : const Color(0xFFFDE8E7));
      deltaChip = Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(flat ? '= même qu\'$ref' : '${up ? "↑ +" : "↓ "}$delta vs $ref',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
      );
    }
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: _kNavyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A3D5A)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kBlueLight, height: 1)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.65))),
          if (deltaChip != null) deltaChip,
        ]),
      ),
    );
  }

  // ── Graphique : barres groupées (tampons bleu + récompenses vert) ──────────
  // Aligné sur le mockup : valeur au-dessus de chaque barre + labels jours.
  List<Map<String, dynamic>> _graphGroups() {
    if (_daily.isEmpty) return [];
    const wd = ['L', 'M', 'M', 'J', 'V', 'S', 'D']; // lundi..dimanche
    if (_graphRange == '7j') {
      final days = _daily.length >= 7 ? _daily.sublist(_daily.length - 7) : _daily;
      return days.map((d) {
        final date = DateTime.tryParse(d['date'] as String? ?? '');
        return {
          'label': date != null ? wd[(date.weekday - 1).clamp(0, 6)] : '',
          'stamps': (d['scans'] as int?) ?? 0,
          'rewards': (d['rewards'] as int?) ?? 0,
        };
      }).toList();
    }
    // 30j → 4 semaines agrégées (S1..S4) sur les 28 derniers jours
    final last28 = _daily.length >= 28 ? _daily.sublist(_daily.length - 28) : _daily;
    final perWeek = (last28.length / 4).ceil().clamp(1, last28.length);
    final groups = <Map<String, dynamic>>[];
    for (int w = 0; w < 4; w++) {
      final start = w * perWeek;
      if (start >= last28.length) break;
      final end = (start + perWeek).clamp(0, last28.length);
      final slice = last28.sublist(start, end);
      groups.add({
        'label': 'S${w + 1}',
        'stamps': slice.fold<int>(0, (a, d) => a + ((d['scans'] as int?) ?? 0)),
        'rewards': slice.fold<int>(0, (a, d) => a + ((d['rewards'] as int?) ?? 0)),
      });
    }
    return groups;
  }

  Widget _graphCard() {
    final groups = _graphGroups();
    final maxV = groups.fold<double>(1, (m, g) => (g['stamps'] as int) > m ? (g['stamps'] as int).toDouble() : m);
    final headroom = maxV * 1.28; // marge en haut pour les valeurs

    Widget gpBtn(String key, String label) {
      final active = _graphRange == key;
      return GestureDetector(
        onTap: () => setState(() => _graphRange = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _kPrimary : _kBorder),
          ),
          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: active ? Colors.white : _kSub)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_isPoints ? 'Évolution des points' : 'Évolution des tampons',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText))),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StatsScreen(
                token: widget.token,
                merchantInfo: merchantInfo,
                initialStats:   stats,
                initialDaily:   _daily,
                initialHistory: _scanHistory,
                initialClients: _recentClients,
              ))),
            child: const Text('Voir stats →', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kPrimary)),
          ),
          const SizedBox(width: 8),
          gpBtn('7j', '7j'), const SizedBox(width: 4), gpBtn('30j', 'Mois'),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 88,
          child: groups.isEmpty
              ? Center(child: Text('Pas encore de données', style: TextStyle(fontSize: 11, color: _kSub)))
              : Row(children: groups.map((g) {
                  final s = g['stamps'] as int;
                  final r = g['rewards'] as int;
                  return Expanded(
                    child: Column(children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(s, headroom, _kPrimary),
                            if (r > 0) ...[const SizedBox(width: 3), _bar(r, headroom, _kSuccess)],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(g['label'] as String, style: TextStyle(fontSize: 8, color: _kSub)),
                    ]),
                  );
                }).toList()),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _legend(_kPrimary, _isPoints ? 'Points' : 'Tampons'),
          const SizedBox(width: 14),
          _legend(_kSuccess, 'Récompenses'),
        ]),
      ]),
    );
  }

  Widget _bar(int value, double maxV, Color color) {
    final h = maxV > 0 ? (value / maxV * 60).clamp(value > 0 ? 4.0 : 2.0, 60.0) : 2.0;
    return Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
      Text('$value', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Container(width: _graphRange == '7j' ? 9 : 16, height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    ]);
  }

  Widget _legend(Color c, String label) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 9, color: _kSub)),
      ]);

  // ── Aperçu "Ma carte fidélité" — réutilise le rendu client (design réel) ────
  Widget _cardPreviewBlock() {
    // Carte synthétique au même format que côté client (LoyaltyCardFace).
    final card = {
      'stamps_count': 0,
      'card_design': _cardDesign,
      'merchants': merchantInfo ?? {},
    };
    final style = CardStyle.fromDesign(
      _cardDesign,
      merchantLogoUrl: merchantInfo?['logo_url'] as String?,
      fallbackColor: _kPrimary,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Ma carte fidélité', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kText)),
        GestureDetector(
          onTap: _navigateToCarteEditor,
          child: const Text('Modifier', style: TextStyle(fontSize: 10, color: _kPrimary, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _navigateToCarteEditor,
        child: SizedBox(
          height: 220,
          child: LoyaltyCardFace(
            card: card,
            style: style,
            userName: 'Client',
          ),
        ),
      ),
      const SizedBox(height: 8),
      Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit_outlined, size: 11, color: _kSub),
        const SizedBox(width: 5),
        Text('Appuyer pour modifier la carte', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
      ])),
    ]);
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 84 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(color: _kWhite, border: Border(top: BorderSide(color: _kBorder))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: Row(children: [
            _navItem(Icons.home_outlined, 'Accueil', 0),
            _navScanFab(),
            _navItem(Icons.history_rounded, 'Historique', 2),
          ]),
        )),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () { AppLogger.merchant('Onglet → $label'); setState(() => _tab = idx); },
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? _kPrimary : _kSub, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: active ? _kPrimary : _kSub)),
        ]),
      ),
    );
  }

  Widget _navScanFab() {
    return Expanded(
      child: GestureDetector(
        onTap: _openScanner,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: _kBlueLight,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _kBlueLight.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 2),
          Text('Scanner', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _kSub)),
        ]),
      ),
    );
  }
}

// ─── Merchant Profile Sheet ────────────────────────────────────────────────────

class _MerchantProfilSheet extends StatelessWidget {
  final String token;
  final Map? merchantInfo;
  final VoidCallback onLogout;
  final VoidCallback? onNavigateToProgram;
  final VoidCallback? onNavigateToNotifs;
  final VoidCallback? onNavigateToQR;
  final VoidCallback? onNavigateToAbonnement;
  final VoidCallback? onNavigateToInfo;
  final VoidCallback? onNavigateToCarteEditor;
  final VoidCallback? onNavigateToStats;

  const _MerchantProfilSheet({
    required this.token, this.merchantInfo, required this.onLogout,
    this.onNavigateToProgram, this.onNavigateToNotifs, this.onNavigateToQR,
    this.onNavigateToAbonnement, this.onNavigateToInfo, this.onNavigateToCarteEditor,
    this.onNavigateToStats,
  });

  @override
  Widget build(BuildContext context) {
    final kBg = context.cBg;
    final kWhite = context.cSurface;
    final kBorder = context.cBorder;
    final kText = context.cText;
    final kSub = context.cSub;

    final name = merchantInfo?['business_name'] as String? ?? 'Commerce';
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Padding(padding: const EdgeInsets.only(top: 12),
            child: Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))))),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
              ),
              child: Center(child: Text(initials,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kPrimary))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
              Text('Mon commerce', style: TextStyle(fontSize: 11, color: kSub)),
            ])),
          ]),
        ),
        Divider(height: 1, color: kBorder),

        // Body
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MON COMMERCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _section(kWhite, kBorder, [
              _row(context, kBorder, kText, kSub, Icons.description_outlined, _kPrimary.withValues(alpha: 0.12), _kPrimary, 'Informations', 'Nom, adresse',
                  () { Navigator.pop(context); onNavigateToInfo?.call(); }),
              _row(context, kBorder, kText, kSub, Icons.credit_card_outlined, _kSuccess.withValues(alpha: 0.12), _kSuccess, 'Ma carte fidélité', 'Tampons, récompense, couleur',
                  () { Navigator.pop(context); onNavigateToCarteEditor?.call(); }, noBorder: true),
            ]),
            const SizedBox(height: 14),
            Text('MARKETING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _section(kWhite, kBorder, [
              _row(context, kBorder, kText, kSub, Icons.notifications_outlined, _kGold.withValues(alpha: 0.12), _kGold, 'Notifications push', 'Promos, rappels',
                  () { Navigator.pop(context); onNavigateToNotifs?.call(); }),
              _row(context, kBorder, kText, kSub, Icons.qr_code_2_rounded, _kPrimary.withValues(alpha: 0.12), _kPrimary, 'QR Code boutique', 'Afficher en caisse',
                  () { Navigator.pop(context); onNavigateToQR?.call(); }),
              _row(context, kBorder, kText, kSub, Icons.show_chart_rounded, _kPurple.withValues(alpha: 0.12), _kPurple, 'Statistiques', 'Analyse de l\'activité',
                  () { Navigator.pop(context); onNavigateToStats?.call(); }, noBorder: true),
            ]),
            const SizedBox(height: 14),
            Text('AIDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _section(kWhite, kBorder, [
              _row(context, kBorder, kText, kSub, Icons.help_outline_rounded, kBg, kSub, 'Aide & Support', 'FAQ, nous contacter',
                  () => Navigator.pop(context)),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, mode, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Container(width: 32, height: 32,
                        decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.dark_mode_outlined, color: Color(0xFF7C3AED), size: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mode sombre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                      Text('Thème de l\'application', style: TextStyle(fontSize: 11, color: kSub)),
                    ])),
                    Switch(
                      value: mode == ThemeMode.dark,
                      onChanged: (val) async {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        final p = await SharedPreferences.getInstance();
                        await p.setBool('dark_mode', val);
                      },
                      activeThumbColor: _kPrimary,
                    ),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: double.infinity, height: 46,
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kError.withValues(alpha: 0.4))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: _kError, size: 16),
                  SizedBox(width: 8),
                  Text('Se déconnecter', style: TextStyle(color: _kError, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _section(Color kWhite, Color kBorder, List<Widget> rows) => Container(
    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Column(children: rows),
  );

  Widget _row(BuildContext ctx, Color kBorder, Color kText, Color kSub,
      IconData icon, Color iconBg, Color iconColor, String label, String sub,
      VoidCallback onTap, {bool noBorder = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(border: noBorder ? null : Border(bottom: BorderSide(color: kBorder))),
        child: Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
            Text(sub, style: TextStyle(fontSize: 11, color: kSub)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18, color: kSub),
        ]),
      ),
    );
  }
}
