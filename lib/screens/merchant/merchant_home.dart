import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../main.dart';
import '../../widgets/user_avatar.dart';
import '../auth_screen.dart';
import 'scanner_screen.dart';
import 'program_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'clients_screen.dart';
import 'static_qr_screen.dart';
import 'card_preview_screen.dart';
import 'merchant_onboarding.dart';
import 'abonnement_screen.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF2C7BE5);
const _kGold    = Color(0xFFF59E0B);
const _kSuccess = Color(0xFF27AE60);
const _kError   = Color(0xFFE24B4A);
const _kPurple  = Color(0xFF7C3AED);

class MerchantHome extends StatefulWidget {
  final String token;
  final String merchantName;
  const MerchantHome({super.key, required this.token, required this.merchantName});

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
    _loadData();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('merchant_onboarding_done') ?? false;
    if (!done && mounted) setState(() => _showOnboarding = true);
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final res  = await http.get(Uri.parse('$apiUrl/merchants/'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final data = jsonDecode(res.body) as List;
      final parts = widget.token.split('.');
      final normalized = base64Url.normalize(parts[1]);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final myId = decoded['sub'];
      final me = data.firstWhere((m) => m['id'] == myId, orElse: () => null);
      final statsRes = await http.get(Uri.parse('$apiUrl/cards/stats'), headers: {'Authorization': 'Bearer ${widget.token}'});
      if (mounted) {
        setState(() {
          merchantInfo = me;
          stats = statsRes.statusCode == 200 ? jsonDecode(statsRes.body) : null;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
    await _loadRecentClients();
  }

  Future<void> _loadRecentClients() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/cards/clients'), headers: {'Authorization': 'Bearer ${widget.token}'});
      if (mounted && res.statusCode == 200) {
        setState(() => _recentClients = (jsonDecode(res.body) as List).take(3).toList());
      }
    } catch (_) {}
  }

  void _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _openScanner() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScannerScreen(token: widget.token, merchantInfo: merchantInfo),
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
        onNavigateToProgram: () => setState(() => _tab = 4),
        onNavigateToNotifs: () => setState(() => _tab = 3),
        onNavigateToQR: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => StaticQRScreen(token: widget.token, businessName: _businessName, accentColor: _kPrimary),
        )),
        onNavigateToAbonnement: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const AbonnementScreen(),
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
                    padding: EdgeInsets.only(bottom: 64 + MediaQuery.of(context).padding.bottom),
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
                if (mounted) setState(() { _showOnboarding = false; _tab = 4; });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final emoji = _style['emoji'] as String;
    final clientsCount = stats?['total_clients'] ?? 0;
    final scansCount   = stats?['total_scans'] ?? 0;

    return Container(
      color: _kWhite,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16, right: 16, bottom: 12,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _showProfilSheet,
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_businessName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
              Text(loading ? '···' : '$clientsCount clients · $scansCount scans aujourd\'hui',
                  style: TextStyle(fontSize: 11, color: _kSub)),
            ]),
          ]),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _showProfilSheet,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
            child: Icon(Icons.person_outline_rounded, color: _kSub, size: 18),
          ),
        ),
      ]),
    );
  }

  // ─── Tab Content ──────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0: return _buildDashboard();
      case 1: return ClientsScreen(token: widget.token, merchantInfo: merchantInfo);
      case 2: return HistoryScreen(token: widget.token, merchantInfo: merchantInfo);
      case 3: return NotificationsScreen(token: widget.token, merchantInfo: merchantInfo);
      case 4: return ProgramScreen(
        token: widget.token,
        merchantInfo: merchantInfo,
        onSaved: () async { setState(() { loading = true; _tab = 0; }); await _loadData(); },
      );
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
            onPressed: () => setState(() => _tab = 4),
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Configurer mon programme'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ]),
      ));
    }

    final clientsActifs    = stats?['total_clients'] as int? ?? 0;
    final pointsDistribues = stats?['total_stamps']  as int? ?? 0;
    final recompenses      = stats?['total_rewards']  as int? ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _kPrimary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        children: [
          // Stats
          Row(children: [
            _statCard(Icons.people_outline_rounded, '$clientsActifs', 'Clients actifs', _kPrimary),
            const SizedBox(width: 10),
            _statCard(Icons.check_circle_outline_rounded, '$pointsDistribues', 'Tampons', _kSuccess),
            const SizedBox(width: 10),
            _statCard(Icons.star_outline_rounded, '$recompenses', 'Récompenses', _kGold),
          ]),
          const SizedBox(height: 16),

          // Clients récents
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Clients récents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
                GestureDetector(
                  onTap: () => setState(() => _tab = 1),
                  child: const Text('Voir tout', style: TextStyle(fontSize: 13, color: _kPrimary, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),
              if (_recentClients.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun client', style: TextStyle(color: _kSub)),
                ))
              else
                ..._recentClients.asMap().entries.map((entry) {
                  final i = entry.key;
                  final card = entry.value;
                  final user = card['users'] as Map? ?? {};
                  final name = (user['name'] ?? user['email'] ?? 'Client') as String;
                  final stamps = card['stamps_count'] as int? ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i > 0 ? Border(top: BorderSide(color: _kBorder)) : null,
                    ),
                    child: Row(children: [
                      UserAvatar(imageUrl: card['users']?['profile_picture_url'] as String?, name: name, size: 38),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
                        Text('$stamps tampons', style: TextStyle(fontSize: 11, color: _kSub)),
                      ])),
                      Icon(Icons.chevron_right_rounded, color: _kSub, size: 18),
                    ]),
                  );
                }),
            ]),
          ),

          const SizedBox(height: 12),

          // Actions rapides
          Row(children: [
            _quickAction(Icons.qr_code_scanner_rounded, 'Scanner', _kPrimary, _openScanner),
            const SizedBox(width: 10),
            _quickAction(Icons.notifications_outlined, 'Notifs', _kGold, () => setState(() => _tab = 3)),
            const SizedBox(width: 10),
            _quickAction(Icons.tune_rounded, 'Programme', _kSuccess, () => setState(() => _tab = 4)),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kText, height: 1)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: _kSub, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(color: _kWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 34, height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kText)),
          ]),
        ),
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 64 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(color: _kWhite, border: Border(top: BorderSide(color: _kBorder))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          _navItem(Icons.dashboard_outlined, 'Dashboard', 0),
          _navItem(Icons.people_outline, 'Clients', 1),
          _navScanFab(),
          _navItem(Icons.history_rounded, 'Historique', 2),
          _navItem(Icons.tune_rounded, 'Programme', 4),
        ]),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 3),
          const Text('Scanner', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _kPrimary)),
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

  const _MerchantProfilSheet({
    required this.token, this.merchantInfo, required this.onLogout,
    this.onNavigateToProgram, this.onNavigateToNotifs, this.onNavigateToQR, this.onNavigateToAbonnement,
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
        Container(
          color: _kPrimary, width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white38, width: 2)),
              child: Center(child: Text(initials,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: const Text('✦ Plan Pro', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
        ),

        // Body
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MON COMMERCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _section(kWhite, kBorder, [
              _row(context, kBorder, kText, kSub, Icons.description_outlined, _kPrimary.withOpacity(0.12), _kPrimary, 'Informations', 'Nom, adresse', () => Navigator.pop(context)),
              _row(context, kBorder, kText, kSub, Icons.credit_card_outlined, _kSuccess.withOpacity(0.12), _kSuccess, 'Ma carte fidélité', 'Tampons, récompense',
                  () { Navigator.pop(context); onNavigateToProgram?.call(); }, noBorder: true),
            ]),
            const SizedBox(height: 14),
            Text('MARKETING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _section(kWhite, kBorder, [
              _row(context, kBorder, kText, kSub, Icons.notifications_outlined, _kGold.withOpacity(0.12), _kGold, 'Notifications push', 'Promos, rappels',
                  () { Navigator.pop(context); onNavigateToNotifs?.call(); }),
              _row(context, kBorder, kText, kSub, Icons.qr_code_2_rounded, _kPrimary.withOpacity(0.12), _kPrimary, 'QR Code boutique', 'Afficher en caisse',
                  () { Navigator.pop(context); onNavigateToQR?.call(); }),
              _row(context, kBorder, kText, kSub, Icons.show_chart_rounded, _kPurple.withOpacity(0.12), _kPurple, 'Statistiques', 'Analyse de l\'activité',
                  () => Navigator.pop(context), noBorder: true),
            ]),
            const SizedBox(height: 14),
            Text('COMPTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _section(kWhite, kBorder, [
              _row(context, kBorder, kText, kSub, Icons.star_outline_rounded, _kError.withOpacity(0.12), _kError, 'Abonnement', 'Plan Pro · Actif',
                  () { Navigator.pop(context); onNavigateToAbonnement?.call(); }),
              _row(context, kBorder, kText, kSub, Icons.help_outline_rounded, kBg, kSub, 'Aide & Support', 'FAQ, nous contacter',
                  () => Navigator.pop(context), noBorder: true),
            ]),
            const SizedBox(height: 14),
            // Dark mode
            Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, mode, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Container(width: 32, height: 32,
                        decoration: BoxDecoration(color: _kPurple.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
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
                      activeColor: _kPrimary,
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: double.infinity, height: 46,
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kError.withOpacity(0.4))),
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
