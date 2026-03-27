import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../services/auth_service.dart';
import '../auth_screen.dart';
import 'scanner_screen.dart';
import 'program_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'clients_screen.dart';
import 'static_qr_screen.dart';
import 'chart_widget.dart';

class MerchantHome extends StatefulWidget {
  final String token;
  final String merchantName;
  const MerchantHome({super.key, required this.token, required this.merchantName});

  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome> with TickerProviderStateMixin {
  int _tab = 0; // 0=dashboard, 1=clients, 2=historique, 3=notifs, 4=programme
  Map? merchantInfo;
  Map? stats;
  bool loading = true;

  // Styles par catégorie
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
    return _categoryStyles[cat] ?? {'emoji': '🏪', 'color': const Color(0xFF2C7BE5)};
  }

  Color get _accentColor => _style['color'] as Color;

  String get _businessName =>
      merchantInfo?['business_name'] as String? ?? widget.merchantName;

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
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/merchants/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final data = jsonDecode(res.body) as List;

      // Décoder le JWT pour trouver l'ID
      final parts = widget.token.split('.');
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final myId = decoded['sub'];
      final me = data.firstWhere((m) => m['id'] == myId, orElse: () => null);

      final statsRes = await http.get(
        Uri.parse('$apiUrl/cards/stats'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (mounted) {
        setState(() {
          merchantInfo = me;
          stats = statsRes.statusCode == 200 ? jsonDecode(statsRes.body) : null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F2EE),
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildSummaryStrip(),
                Expanded(
                  child: loading
                      ? Center(child: CircularProgressIndicator(color: _accentColor))
                      : _buildTabContent(),
                ),
              ],
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF0B1220),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 20, right: 20, bottom: 18,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: -20, right: -10,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_accentColor.withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Logo commerce
                  GestureDetector(
                    onTap: () => _showProfilSheet(),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: _accentColor.withOpacity(0.25),
                                border: Border.all(color: _accentColor.withOpacity(0.45), width: 1.5),
                              ),
                              child: Center(
                                child: Text(_style['emoji'] as String,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                            Positioned(
                              bottom: -2, right: -2,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF27AE60),
                                  border: Border.all(color: const Color(0xFF0B1220), width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tableau de bord', style: TextStyle(
                                color: Colors.white.withOpacity(0.4), fontSize: 10, height: 1)),
                            const SizedBox(height: 2),
                            Text(_businessName,
                              style: const TextStyle(color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.w800, height: 1.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF27AE60)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    loading ? '···' : '${stats?['total_clients'] ?? 0} clients · ${stats?['total_scans'] ?? 0} scans aujourd\'hui',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SUMMARY STRIP ──────────────────────────────────────────────────────────

  Widget _buildSummaryStrip() {
    final totalClients = stats?['total_clients'] ?? 0;
    final totalStamps = stats?['total_stamps'] ?? 0;
    final totalRewards = stats?['total_rewards'] ?? 0;

    return Container(
      color: const Color(0xFF0B1220),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          _sumCard('$totalClients', 'Clients', Colors.white, isActive: true),
          const SizedBox(width: 8),
          _sumCard('$totalStamps', 'Tampons', _accentColor),
          const SizedBox(width: 8),
          _sumCard('$totalRewards', 'Récompenses', const Color(0xFFFBBF24)),
        ],
      ),
    );
  }

  Widget _sumCard(String val, String label, Color valColor, {bool isActive = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withOpacity(0.18) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _accentColor.withOpacity(0.55) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(val, style: TextStyle(
                color: isActive ? Colors.white : valColor,
                fontSize: 20, fontWeight: FontWeight.w700, height: 1)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // ── TAB CONTENT ────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildDashboard();
      case 1:
        return ClientsScreen(token: widget.token, merchantInfo: merchantInfo);
      case 2:
        return HistoryScreen(token: widget.token, merchantInfo: merchantInfo);
      case 3:
        return NotificationsScreen(token: widget.token, merchantInfo: merchantInfo);
      case 4:
        return ProgramScreen(
          token: widget.token,
          merchantInfo: merchantInfo,
          onSaved: () async {
            setState(() { loading = true; _tab = 0; });
            await _loadData();
          },
        );
      default:
        return _buildDashboard();
    }
  }

  // ── DASHBOARD ──────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    if (merchantInfo == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 20),
              const Text('Profil non configuré',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1828))),
              const SizedBox(height: 8),
              Text('Configure ton commerce pour commencer à fidéliser tes clients.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _tab = 3),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Configurer mon programme'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _accentColor,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
        children: [

          // ── Actions rapides ──
          Row(
            children: [
              _quickAction(
                icon: Icons.people_outline,
                label: 'Clients',
                color: const Color(0xFF2C7BE5),
                onTap: () => setState(() => _tab = 1),
              ),
              const SizedBox(width: 10),
              _quickAction(
                icon: Icons.notifications_outlined,
                label: 'Notification',
                color: const Color(0xFF7B4FBF),
                onTap: () => setState(() => _tab = 3),
              ),
              const SizedBox(width: 10),
              _quickAction(
                icon: Icons.history_rounded,
                label: 'Historique',
                color: const Color(0xFF27AE60),
                onTap: () => setState(() => _tab = 2),
              ),
              const SizedBox(width: 10),
              _quickAction(
                icon: Icons.tune_rounded,
                label: 'Programme',
                color: const Color(0xFFF59E0B),
                onTap: () => setState(() => _tab = 4),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Stats détaillées ──
          _sectionTitle('Performances'),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(Icons.people_outline, 'Clients', '${stats?['total_clients'] ?? 0}', _accentColor),
              const SizedBox(width: 10),
              _statTile(Icons.star_outline_rounded, 'Tampons total', '${stats?['total_stamps'] ?? 0}', const Color(0xFF2980B9)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(Icons.emoji_events_outlined, 'Récompenses', '${stats?['total_rewards'] ?? 0}', const Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              _statTile(Icons.qr_code_scanner_rounded, 'Scans total', '${stats?['total_scans'] ?? 0}', const Color(0xFF27AE60)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Graphique 30 jours ──
          _sectionTitle('Activité'),
          const SizedBox(height: 10),
          StatsChartWidget(token: widget.token, accentColor: _accentColor),
          const SizedBox(height: 14),

          // ── Programme actuel ──
          _sectionTitle('Programme actuel'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDE9E3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Tampons requis
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _accentColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${merchantInfo!['stamps_required']}',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _accentColor, height: 1)),
                          Text('tampons', style: TextStyle(fontSize: 9, color: _accentColor.withOpacity(0.7))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_businessName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1828))),
                          const SizedBox(height: 4),
                          Text(merchantInfo?['category'] as String? ?? '',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '🎁 ${merchantInfo!['reward_description']}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _tab = 3),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F2EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF888888)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── QR Code Caisse ──
          _sectionTitle('QR Code Caisse'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StaticQRScreen(
                token: widget.token,
                businessName: _businessName,
                accentColor: _accentColor,
              ),
            )),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDE9E3)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.qr_code_rounded, color: _accentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Afficher mon QR code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1828))),
                        const SizedBox(height: 3),
                        Text('À imprimer ou afficher en caisse', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Aperçu carte client ──
          _sectionTitle('Aperçu carte client'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CARTE FIDÉLITÉ',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                letterSpacing: 0.1, color: Colors.white.withOpacity(0.55))),
                        const SizedBox(height: 2),
                        Text(_businessName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(_initials,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (ctx, constraints) {
                  final total = merchantInfo?['stamps_required'] as int? ?? 10;
                  // Calcule la taille max pour tenir sur la largeur dispo
                  final spacing = 4.0;
                  final perRow = total <= 10 ? total : (total <= 15 ? total : total);
                  final maxW = constraints.maxWidth;
                  // Taille d'un tampon = (largeur - espaces) / nombre par rangée
                  final cols = total <= 10 ? total : (total <= 15 ? 8 : 10);
                  final stampSize = ((maxW - spacing * (cols - 1)) / cols).clamp(16.0, 24.0);
                  return Wrap(
                    spacing: spacing, runSpacing: spacing,
                    children: List.generate(total, (i) => Container(
                      width: stampSize, height: stampSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(stampSize * 0.3),
                        color: i < 3 ? Colors.white.withOpacity(0.9) : Colors.transparent,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: i < 3 ? Center(child: Icon(Icons.check, size: stampSize * 0.5, color: _accentColor)) : null,
                    )),
                  );
                }),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Encore ${(merchantInfo?['stamps_required'] as int? ?? 10) - 3} tampons pour ${merchantInfo?['reward_description']}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('3/${merchantInfo?['stamps_required']}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: 3 / (merchantInfo?['stamps_required'] as int? ?? 10),
                    minHeight: 3,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets helpers ────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1828)));
  }

  Widget _quickAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDE9E3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1828))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDE9E3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, height: 1),
                      overflow: TextOverflow.ellipsis),
                  Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 82 + MediaQuery.of(context).padding.bottom,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDE9E3))),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10),
        child: Row(
          children: [
            _navItem(Icons.dashboard_outlined, 'Dashboard', 0),
            _navItem(Icons.people_outline, 'Clients', 1),
            _navScanFab(),
            _navItem(Icons.history_rounded, 'Historique', 2),
            _navItem(Icons.tune_rounded, 'Programme', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? _accentColor : const Color(0xFFBBBBBB), size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600,
              color: active ? _accentColor : const Color(0xFFBBBBBB),
            )),
          ],
        ),
      ),
    );
  }

  Widget _navScanFab() {
    return GestureDetector(
      onTap: _openScanner,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 3),
          Text('Scanner', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: _accentColor)),
        ],
      ),
    );
  }

  // ── PROFIL SHEET ───────────────────────────────────────────────────────────

  void _showProfilSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MerchantProfilSheet(
        businessName: _businessName,
        initials: _initials,
        emoji: _style['emoji'] as String,
        accentColor: _accentColor,
        category: merchantInfo?['category'] as String? ?? '',
        onLogout: _logout,
      ),
    );
  }
}

// ── Profil bottom sheet ───────────────────────────────────────────────────────

class _MerchantProfilSheet extends StatelessWidget {
  final String businessName;
  final String initials;
  final String emoji;
  final Color accentColor;
  final String category;
  final VoidCallback onLogout;

  const _MerchantProfilSheet({
    required this.businessName,
    required this.initials,
    required this.emoji,
    required this.accentColor,
    required this.category,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F2EE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99)))),
          ),
          // Header
          Container(
            width: double.infinity,
            color: accentColor,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(category, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _profSection([
                  _profRow(Icons.store_outlined, const Color(0xFFE8F1FD), const Color(0xFF2C7BE5), 'Informations du commerce', 'Nom, catégorie, description'),
                  _profRow(Icons.bar_chart_outlined, const Color(0xFFE4F5EB), const Color(0xFF27AE60), 'Statistiques avancées', 'Voir les détails complets'),
                  _profRow(Icons.support_outlined, const Color(0xFFFEF3C7), const Color(0xFFF59E0B), 'Aide & Support', 'FAQ, nous contacter'),
                ]),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () { Navigator.pop(context); onLogout(); },
                  child: Container(
                    width: double.infinity, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE8E7), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFE24B4A), size: 16),
                        SizedBox(width: 8),
                        Text('Se déconnecter', style: TextStyle(color: Color(0xFFE24B4A), fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _profSection(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE9E3)),
      ),
      child: Column(children: rows),
    );
  }

  static Widget _profRow(IconData icon, Color iconBg, Color iconColor, String label, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF4F2EE)))),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1828))),
                Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0x4D1A1828), size: 18),
        ],
      ),
    );
  }
}

// ── Grid Painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A82F6).withOpacity(0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}