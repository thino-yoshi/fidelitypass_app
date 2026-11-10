import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/platform_route.dart';
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
import '../../utils/logger.dart';
import 'merchant_tokens.dart';
import 'merchant_profil_sheet.dart';
import 'widgets/merchant_header.dart';
import 'widgets/merchant_bottom_nav.dart';
import 'widgets/merchant_dashboard.dart';

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
  int _tab = 0;
  Map? merchantInfo;
  Map? stats;
  bool loading = true;
  bool _showOnboarding = false;
  List<dynamic> _recentClients = [];
  List<dynamic> _daily = [];
  List<dynamic> _scanHistory = [];
  String _period = 'today';
  String _graphRange = '7j';
  String _retPeriod = 'sem';
  Map? _cardDesign;

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

  Future<void> _navigateToCarteEditor() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      platformRoute(
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
    Navigator.pushReplacement(context, platformRoute(builder: (_) => const AuthScreen()));
  }

  void _openScanner() {
    Navigator.push(context, platformRoute(
      builder: (_) => ScannerScreen(token: widget.token, merchantInfo: merchantInfo, initialHistory: _scanHistory),
    ));
  }

  void _showProfilSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MerchantProfilSheet(
        token: widget.token,
        merchantInfo: merchantInfo,
        onLogout: _logout,
        onNavigateToNotifs: () => Navigator.push(context, platformRoute(
          builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: merchantInfo, initialClients: _recentClients))),
        onNavigateToQR: () => Navigator.push(context, platformRoute(
          builder: (_) => StaticQRScreen(token: widget.token, businessName: _businessName, accentColor: kPrimary),
        )),
        onNavigateToAbonnement: () => Navigator.push(context, platformRoute(
          builder: (_) => const AbonnementScreen(),
        )),
        onNavigateToInfo: () => Navigator.push(context, platformRoute(
          builder: (_) => InfoCommerceScreen(token: widget.token, merchantInfo: merchantInfo ?? {}),
        )).then((updated) {
          if (updated != null && mounted) setState(() => merchantInfo = updated as Map);
        }),
        onNavigateToCarteEditor: _navigateToCarteEditor,
        onNavigateToStats: () => Navigator.push(context, platformRoute(
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
        backgroundColor: context.cBg,
        body: Stack(
          children: [
            Column(
              children: [
                MerchantHeader(
                  businessName:  _businessName,
                  initials:      _initials,
                  clientsCount:  stats?['total_clients'] ?? 0,
                  rewardsCount:  stats?['total_rewards'] ?? 0,
                  isActive:      (merchantInfo?['subscription_status'] as String?) == 'active',
                  onProfileTap:  _showProfilSheet,
                  onClientsTap:  () => setState(() => _tab = 1),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 84 + MediaQuery.of(context).padding.bottom),
                    child: loading
                        ? const Center(child: CircularProgressIndicator(color: kPrimary))
                        : _buildTabContent(),
                  ),
                ),
              ],
            ),
            MerchantBottomNav(
              currentTab:   _tab,
              onTabChanged: (idx) { AppLogger.merchant('Onglet → $idx'); setState(() => _tab = idx); },
              onScanTap:    _openScanner,
            ),
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

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        if (merchantInfo == null) return _buildNoProfile();
        return MerchantDashboard(
          merchantInfo:        merchantInfo!,
          stats:               stats,
          daily:               _daily,
          scanHistory:         _scanHistory,
          recentClients:       _recentClients,
          cardDesign:          _cardDesign,
          period:              _period,
          graphRange:          _graphRange,
          retPeriod:           _retPeriod,
          isPoints:            _isPoints,
          onPeriodChanged:     (v) => setState(() => _period = v),
          onGraphRangeChanged: (v) => setState(() => _graphRange = v),
          onRetPeriodChanged:  (v) => setState(() => _retPeriod = v),
          onRefresh:           () => _loadData(showSpinner: false),
          onNavigateToCarteEditor: _navigateToCarteEditor,
          token:               widget.token,
        );
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
      default: return const SizedBox();
    }
  }

  Widget _buildNoProfile() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚠️', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 16),
        Text('Profil non configuré', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.cText)),
        const SizedBox(height: 8),
        Text('Configure ton commerce pour commencer à fidéliser tes clients.',
            textAlign: TextAlign.center, style: TextStyle(color: context.cSub, fontSize: 14, height: 1.5)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configurez votre programme sur qarta.be'), duration: Duration(seconds: 3))),
          icon: const Icon(Icons.open_in_browser_rounded, size: 16),
          label: const Text('Configurer sur qarta.be'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ]),
    ));
  }
}
