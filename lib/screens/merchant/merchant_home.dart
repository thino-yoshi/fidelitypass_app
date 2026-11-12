import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/platform_route.dart';
import '../auth_screen.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'clients_screen.dart';
import 'static_qr_screen.dart';
import 'abonnement_screen.dart';
import 'stats_screen.dart';
import 'info_commerce_screen.dart';
import 'carte_editor_screen.dart';
import 'merchant_tokens.dart';
import 'merchant_profil_sheet.dart';
import 'widgets/merchant_bottom_nav.dart';
import 'widgets/merchant_stat_list.dart';

class MerchantHome extends StatefulWidget {
  final String token;
  final String merchantName;
  final Map? initialProfile;
  final Map? initialStats;
  final List<dynamic> initialRecentClients;
  final List<dynamic> initialDaily;
  final List<dynamic> initialScanHistory;
  final Map? initialCardDesign;
  final bool fromCache;

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
    this.fromCache             = false,
  });

  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome> {
  int _tab = 0;
  int _period = 0;
  int _carouselPage = 0;
  late final PageController _carouselCtrl = PageController();

  Map? _merchantInfo;
  Map? _stats;
  bool _loading = true;
  List<dynamic> _recentClients = [];
  List<dynamic> _daily = [];
  List<dynamic> _scanHistory = [];
  Map? _cardDesign;

  String get _businessName =>
      (_merchantInfo?['business_name'] as String?) ?? widget.merchantName;

  String get _initials {
    final parts = _businessName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    final n = _businessName.trim();
    return n.isNotEmpty ? n.substring(0, n.length.clamp(0, 2)).toUpperCase() : 'Q';
  }

  String get _dateLabel {
    const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const mois  = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                   'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    final now = DateTime.now();
    return '${jours[now.weekday - 1]} ${now.day} ${mois[now.month - 1]}';
  }

  // ── Helpers stats ─────────────────────────────────────────────────────────

  int get _scansToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final d = _daily.where((e) => (e['date'] as String?) == today).toList();
    return d.isEmpty ? 0 : (d.first['scans'] as int? ?? 0);
  }

  int get _rewardsToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final d = _daily.where((e) => (e['date'] as String?) == today).toList();
    return d.isEmpty ? 0 : (d.first['rewards'] as int? ?? 0);
  }

  int get _scans7j {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    return _daily
        .where((e) => ((e['date'] as String?) ?? '').compareTo(cutoff) >= 0)
        .fold(0, (sum, e) => sum + (e['scans'] as int? ?? 0));
  }

  int get _rewards7j {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    return _daily
        .where((e) => ((e['date'] as String?) ?? '').compareTo(cutoff) >= 0)
        .fold(0, (sum, e) => sum + (e['rewards'] as int? ?? 0));
  }

  int get _scans30j  => _daily.fold(0, (sum, e) => sum + (e['scans']   as int? ?? 0));
  int get _rewards30j => _daily.fold(0, (sum, e) => sum + (e['rewards'] as int? ?? 0));

  int get _clientsNearReward {
    int count = 0;
    for (final c in _recentClients) {
      final stamps   = (c['stamps_count']    as int?) ?? 0;
      final required = (c['stamps_required'] as int?) ?? 1;
      if (stamps >= required * 0.75 && stamps < required) count++;
    }
    return count;
  }

  int _newClients(String period) {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    final cutoff7j = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    return _scanHistory.where((e) {
      if ((e['stamps_count'] as int? ?? 0) != 1) return false;
      final date = ((e['created_at'] as String?) ?? '').substring(0, 10);
      if (period == 'today') return date == now;
      if (period == '7j')    return date.compareTo(cutoff7j) >= 0;
      return true;
    }).length;
  }

  // ── Chargement données ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _merchantInfo  = widget.initialProfile;
      _stats         = widget.initialStats;
      _recentClients = List<dynamic>.from(widget.initialRecentClients);
      _daily         = List<dynamic>.from(widget.initialDaily);
      _scanHistory   = List<dynamic>.from(widget.initialScanHistory);
      _cardDesign    = widget.initialCardDesign;
      _loading       = false;
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _carouselCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    final api = ApiService.instance;
    final profileResult = await api.getMerchantProfile();
    final statsResult   = await api.getMerchantStats();
    if (mounted) {
      setState(() {
        _merchantInfo = profileResult.isOk ? profileResult.value : null;
        _stats        = statsResult.isOk   ? statsResult.value   : null;
        _loading      = false;
      });
    }
    await _loadRecentClients();
    await _loadDaily();
    await _loadCardDesign();
  }

  Future<void> _loadCardDesign() async {
    final r = await ApiService.instance.getMerchantCardDesign();
    if (mounted && r.isOk) {
      setState(() => _cardDesign = r.value?['card_design'] as Map?);
    }
  }

  Future<void> _loadRecentClients() async {
    final r = await ApiService.instance.getMerchantClients();
    if (mounted && r.isOk) setState(() => _recentClients = r.value);
  }

  Future<void> _loadDaily() async {
    final r = await ApiService.instance.getDailyStats();
    if (mounted && r.isOk) setState(() => _daily = r.value);
    final h = await ApiService.instance.getMerchantScanHistory();
    if (mounted && h.isOk) setState(() => _scanHistory = h.value);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openScanner() {
    Navigator.push(context, platformRoute(
      builder: (_) => ScannerScreen(
        token: widget.token,
        merchantInfo: _merchantInfo,
        initialHistory: _scanHistory,
      ),
    ));
  }

  Future<void> _navigateToCarteEditor() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      platformRoute(
        builder: (_) => CarteEditorScreen(
          token: widget.token,
          merchantInfo: _merchantInfo ?? {},
          initialDesign: _cardDesign,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _cardDesign = result;
        final newName = result['cardName'] as String?;
        if (newName != null && newName.isNotEmpty && _merchantInfo != null) {
          _merchantInfo = Map.from(_merchantInfo!)..['business_name'] = newName;
        }
      });
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, platformRoute(builder: (_) => const AuthScreen()));
  }

  void _openProfilScreen() {
    Navigator.push(context, platformRoute(
      builder: (_) => MerchantProfilSheet(
        token: widget.token,
        merchantInfo: _merchantInfo,
        onLogout: _logout,
        isTab: true,
        onNavigateToNotifs: () => Navigator.push(context, platformRoute(
          builder: (_) => NotificationsScreen(
            token: widget.token,
            merchantInfo: _merchantInfo,
            initialClients: _recentClients,
          ))),
        onNavigateToQR: () => Navigator.push(context, platformRoute(
          builder: (_) => StaticQRScreen(
            token: widget.token,
            businessName: _businessName,
            accentColor: kPrimary,
          ),
        )),
        onNavigateToAbonnement: () => Navigator.push(context, platformRoute(
          builder: (_) => const AbonnementScreen(),
        )),
        onNavigateToInfo: () => Navigator.push(context, platformRoute(
          builder: (_) => InfoCommerceScreen(
            token: widget.token,
            merchantInfo: _merchantInfo ?? {},
          ),
        )).then((updated) {
          if (updated != null && mounted) setState(() => _merchantInfo = updated as Map);
        }),
        onNavigateToCarteEditor: _navigateToCarteEditor,
        onNavigateToStats: () => Navigator.push(context, platformRoute(
          builder: (_) => StatsScreen(
            token: widget.token,
            merchantInfo: _merchantInfo,
            initialStats:   _stats,
            initialDaily:   _daily,
            initialHistory: _scanHistory,
            initialClients: _recentClients,
          ),
        )),
      ),
    ));
  }

  // ── Blocs UI ──────────────────────────────────────────────────────────────

  Widget _headerBlock() => GestureDetector(
        onTap: _openProfilScreen,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: context.cBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_dateLabel,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w400,
                  color: const Color(0xFF9CA3AF))),
              const SizedBox(height: 2),
              Text(_businessName,
                style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827))),
            ])),
            Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF2C7BE5),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(_initials,
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white))),
            ),
          ]),
        ),
      );

  Widget _statsBlock() => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          // ── Clients fidèles ───────────────────────────────────────────────
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('${_stats?['total_clients'] ?? 0}',
              style: GoogleFonts.inter(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1)),
            const SizedBox(height: 4),
            Text('Clients fidèles',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w400,
                color: const Color(0xFF8B9EB7))),
          ])),
          Container(width: 1, height: 40, color: const Color(0xFF1E2D45)),
          const SizedBox(width: 20),
          // ── Proches du cadeau ─────────────────────────────────────────────
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('$_clientsNearReward',
              style: GoogleFonts.inter(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: const Color(0xFFF59E0B), height: 1)),
            const SizedBox(height: 4),
            Text('Proches du cadeau',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w400,
                color: const Color(0xFF8B9EB7))),
          ])),
        ]),
      );

  Widget _periodSelector() {
    const labels = ["Aujourd'hui", '7 jours', '30 jours'];
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8DFD2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final segW = (constraints.maxWidth - 8) / 3;
        return SizedBox(
          height: 34,
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              left: _period * segW,
              top: 0, bottom: 0, width: segW,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 6, offset: const Offset(0, 2),
                  )],
                ),
              ),
            ),
            Row(children: List.generate(3, (i) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _period = i),
              child: SizedBox(
                width: segW, height: 34,
                child: Center(child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: _period == i ? FontWeight.w700 : FontWeight.w500,
                    color: _period == i ? const Color(0xFF111827) : const Color(0xFF6B7280),
                  ),
                  child: Text(labels[i]),
                )),
              ),
            ))),
          ]),
        );
      }),
    );
  }

  Widget _statsListBlock() {
    final int scans, rewards, newClients;
    String retourStr;

    if (_period == 0) {
      scans      = _scansToday;
      rewards    = _rewardsToday;
      newClients = _newClients('today');
      retourStr  = scans > 0 ? '${(rewards * 100 / scans).round()} %' : '0 %';
    } else if (_period == 1) {
      scans      = _scans7j;
      rewards    = _rewards7j;
      newClients = _newClients('7j');
      retourStr  = scans > 0 ? '${(rewards * 100 / scans).round()} %' : '0 %';
    } else {
      scans      = _scans30j;
      rewards    = _rewards30j;
      newClients = _newClients('30j');
      retourStr  = scans > 0 ? '${(rewards * 100 / scans).round()} %' : '0 %';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: MerchantStatList(rows: [
        MerchantStatRow(icon: CupertinoIcons.person_2,                label: 'Clients venus',       value: '$scans'),
        MerchantStatRow(icon: CupertinoIcons.gift,                    label: 'Récompenses données', value: '$rewards'),
        MerchantStatRow(icon: CupertinoIcons.plus_circle,             label: 'Nouveaux clients',    value: '$newClients'),
        MerchantStatRow(icon: CupertinoIcons.arrow_counterclockwise,  label: 'Taux de retour',      value: retourStr),
      ]),
    );
  }

  Widget _carouselBlock() {
    return Column(children: [
      SizedBox(
        height: 178,
        child: PageView(
          controller: _carouselCtrl,
          onPageChanged: (i) => setState(() => _carouselPage = i),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _passagesContent(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: _navigateToCarteEditor,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text('Modifier la carte',
                    style: GoogleFonts.inter(fontSize: 14,
                      color: const Color(0xFF9CA3AF)))),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(children: [
          Expanded(child: AnimatedOpacity(
            opacity: _carouselPage == 1 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Text('← Mon graphique',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500,
                color: const Color(0xFF2C7BE5).withValues(alpha: 0.55))),
          )),
          for (int i = 0; i < 2; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _carouselPage == i ? 16.0 : 6.0,
              height: 6,
              decoration: BoxDecoration(
                color: _carouselPage == i
                  ? const Color(0xFF2C7BE5)
                  : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          Expanded(child: AnimatedOpacity(
            opacity: _carouselPage == 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Align(alignment: Alignment.centerRight,
              child: Text('Ma carte →',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500,
                  color: const Color(0xFF2C7BE5).withValues(alpha: 0.55)))),
          )),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _passagesContent() {
    final now = DateTime.now();
    final todayWeekday = now.weekday - 1; // 0=Lundi … 6=Dimanche
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    // 7 derniers jours du plus ancien au plus récent
    final List<double> values = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final entry = _daily.where((e) => (e['date'] as String?) == dateStr).toList();
      return entry.isEmpty ? 0.0 : (entry.first['scans'] as int? ?? 0).toDouble();
    });
    final maxVal = values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Passages',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                color: const Color(0xFF111827))),
            const SizedBox(height: 2),
            Text('Cette semaine',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400,
                color: const Color(0xFF9CA3AF))),
          ])),
          GestureDetector(
            onTap: () => Navigator.push(context, platformRoute(
              builder: (_) => StatsScreen(
                token: widget.token,
                merchantInfo: _merchantInfo,
                initialStats:   _stats,
                initialDaily:   _daily,
                initialHistory: _scanHistory,
                initialClients: _recentClients,
              ),
            )),
            child: Text('Voir tout ›',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500,
                color: const Color(0xFF2C7BE5))),
          ),
        ]),
        const SizedBox(height: 16),
        // Barres
        SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final isActive = i == todayWeekday;
              final barH = (values[i] / maxVal) * 56;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: barH < 4 ? 4 : barH,
                  decoration: BoxDecoration(
                    color: isActive
                      ? const Color(0xFF2C7BE5)
                      : const Color(0xFFBFD7F5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ));
            }),
          ),
        ),
        const SizedBox(height: 6),
        // Labels
        Row(children: List.generate(7, (i) {
          final isActive = i == todayWeekday;
          return Expanded(child: Center(child: Text(labels[i],
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: isActive ? const Color(0xFF2C7BE5) : const Color(0xFF9CA3AF)))));
        })),
      ]),
    );
  }

  Widget _googleReviewBlock() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        ),
        child: Row(children: [
          Text('G', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700,
            foreground: Paint()..shader = const LinearGradient(
              colors: [Color(0xFF4285F4), Color(0xFF4285F4)],
            ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
          )),
          const SizedBox(width: 12),
          Expanded(child: Text('Demander un avis Google',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
              color: const Color(0xFF111827)))),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
        ]),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  Widget _homeContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        74 + MediaQuery.of(context).padding.bottom + 24,
      ),
      children: [
        _headerBlock(),
        _statsBlock(),
        _periodSelector(),
        _statsListBlock(),
        _carouselBlock(),
        _googleReviewBlock(),
      ],
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
            _tab == 2
              ? HistoryScreen(
                  token: widget.token,
                  merchantInfo: _merchantInfo,
                  initialHistory: _scanHistory,
                  initialClients: _recentClients,
                  initialCardDesign: _cardDesign,
                )
              : _homeContent(),
            MerchantBottomNav(
              currentTab:   _tab,
              onTabChanged: (i) => setState(() => _tab = i),
              onScanTap:    _openScanner,
            ),
          ],
        ),
      ),
    );
  }
}
