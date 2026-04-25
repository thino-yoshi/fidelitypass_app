import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/widget_service.dart';
import '../../config/api.dart';
import '../../config/app_colors.dart';
import '../../main.dart';
import '../../widgets/user_avatar.dart';
import '../auth_screen.dart';
import 'cards_tab.dart';
import 'stores_tab.dart';
import 'history_tab.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────
const _kPrimary  = Color(0xFF2C7BE5);
const _kBlueL    = Color(0xFF4A9EFF);
const _kNavy     = Color(0xFF0B1220);
const _kDark     = Color(0xFF0F2044);
const _kError    = Color(0xFFE24B4A);
const _kGold     = Color(0xFFF59E0B);
const _kSuccess  = Color(0xFF27AE60);

class ClientHome extends StatefulWidget {
  final String token;
  final String userName;
  const ClientHome({super.key, required this.token, required this.userName});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> with TickerProviderStateMixin {
  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

  // 0=cartes  1=scan  2=historique
  int _tab = 0;
  int _cardCount  = 0;
  int _rewardCount = 0;
  int _notifCount  = 0;
  List<dynamic> _cards = [];
  bool _statsLoaded = false;
  bool _notifOpen   = false;
  late AnimationController _notifAnim;
  String? _profilePictureUrl;
  List<Map> _notifs     = [];
  bool _notifsLoaded    = false;
  String _notifFilter   = 'tout';

  static const Map<String, Map<String, dynamic>> _notifStyle = {
    'recompense': {'icon': '⭐', 'color': 0xFFFBBF24},
    'tampon':     {'icon': '✓',  'color': 0xFF2C7BE5},
    'promo':      {'icon': '→',  'color': 0xFF27AE60},
    'targeted':   {'icon': '→',  'color': 0xFF27AE60},
    'scheduled':  {'icon': '→',  'color': 0xFF27AE60},
  };

  @override
  void initState() {
    super.initState();
    _notifAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _loadStats();
    _loadNotifs();
    _loadProfile();
  }

  @override
  void dispose() {
    _notifAnim.dispose();
    super.dispose();
  }

  // ─── API ──────────────────────────────────────────────────────────────────

  Future<void> _loadNotifs() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/notifications/client'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as List;
        final mapped = data.map((n) {
          final type  = n['type'] as String? ?? 'promo';
          final style = _notifStyle[type] ?? _notifStyle['promo']!;
          final dt    = DateTime.tryParse(n['created_at'] as String? ?? '')?.toLocal();
          final time  = dt != null
              ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
              : '';
          return {
            'id': n['id'], 'icon': style['icon'], 'commerce': n['merchant_name'] ?? '',
            'title': n['title'] ?? '', 'body': n['body'] ?? '', 'time': time,
            'color': style['color'], 'read': n['read'] ?? false, 'type': type,
          };
        }).toList();
        setState(() { _notifs = mapped; _notifsLoaded = true; });
        _updateNotifCount();
      }
    } catch (_) {}
  }

  void _updateNotifCount() =>
      setState(() => _notifCount = _notifs.where((n) => !(n['read'] as bool)).length);

  Future<void> _loadStats() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as List;
        int rewards = 0;
        for (final c in data) {
          final req = c['merchants']?['stamps_required'] as int? ?? 10;
          if ((c['stamps_count'] as int? ?? 0) >= req) rewards++;
        }
        setState(() {
          _cards = data; _cardCount = data.length;
          _rewardCount = rewards; _statsLoaded = true;
        });
        WidgetService.updateFromCards(data);
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/users/me'),
          headers: {'Authorization': 'Bearer ${widget.token}'});
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() => _profilePictureUrl = data['profile_picture_url'] as String?);
      }
    } catch (_) {}
  }

  void _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _openNotifs() {
    setState(() => _notifOpen = true);
    _notifAnim.forward();
  }

  void _closeNotifs() {
    _notifAnim.reverse().then((_) { if (mounted) setState(() => _notifOpen = false); });
  }

  void _markAllRead() {
    setState(() { for (var n in _notifs) n['read'] = true; _notifCount = 0; });
    http.put(Uri.parse('$apiUrl/notifications/client/read-all'),
        headers: {'Authorization': 'Bearer ${widget.token}'});
  }

  String get _firstName {
    final parts = widget.userName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : widget.userName;
  }

  String get _initials {
    final parts = widget.userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 76 + MediaQuery.of(context).padding.bottom),
                    child: _buildTabContent(),
                  ),
                ),
              ],
            ),
            _buildBottomNav(),
            if (_notifOpen) _buildNotifOverlay(),
          ],
        ),
      ),
    );
  }

  // ─── Header (Figma dark navy) ─────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: _kNavy),
      clipBehavior: Clip.hardEdge,
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Logo en fond watermark — couvre tout le header
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    'assets/images/89.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Radial glow top-right
            Positioned(
              top: -60, right: -30,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_kPrimary.withOpacity(0.2), Colors.transparent],
                    stops: const [0.0, 0.68],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: avatar/name  |  notification bell
                  Row(children: [
                    GestureDetector(
                      onTap: _openProfil,
                      child: Row(children: [
                        // Avatar circle
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(color: _kBlueL.withOpacity(0.45), width: 2),
                          ),
                          child: Center(
                            child: Text(_initials,
                              style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: _kBlueL)),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Bonjour',
                            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4), height: 1)),
                          Text(_firstName,
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                        ]),
                      ]),
                    ),
                    const Spacer(),
                    // Notification bell — glass style
                    GestureDetector(
                      onTap: _openNotifs,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_outlined,
                            color: Colors.white.withOpacity(0.8), size: 18),
                        ),
                        if (_notifCount > 0)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              height: 16,
                              decoration: BoxDecoration(
                                color: _kError,
                                border: Border.all(color: _kNavy, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('$_notifCount',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ]), // fin Row

                  const SizedBox(height: 14),

                  // Subtitle
                  Text(
                    '$_cardCount carte${_cardCount > 1 ? 's' : ''} active${_cardCount > 1 ? 's' : ''}'
                    ' · $_rewardCount récompense${_rewardCount > 1 ? 's' : ''} disponible${_rewardCount > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Stats strip — 2 cards (Cartes | Récompenses)
                  Row(children: [
                    _statCard('$_cardCount', 'Cartes', isActive: _tab == 0,
                        onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: 8),
                    _statCard('$_rewardCount', 'Récompense', isActive: false, onTap: () {}),
                  ]),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String val, String label,
      {required bool isActive, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: isActive ? _kPrimary.withOpacity(0.18) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? _kBlueL.withOpacity(0.55) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(val, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab Content ──────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return CardsTab(
          token: widget.token,
          cards: _cards,
          onRefresh: _loadStats,
        );
      case 1:
        return _buildScanTab();
      case 2:
        return HistoryTab(token: widget.token);
      default:
        return CardsTab(token: widget.token, cards: _cards, onRefresh: _loadStats);
    }
  }

  // ─── Scan Tab ─────────────────────────────────────────────────────────────

  Widget _buildScanTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Scanner un QR code',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 6),
          Text('Scanne le QR code affiché en caisse',
            style: TextStyle(fontSize: 12, color: _kSub)),
          const SizedBox(height: 20),
          // Dark scanner box matching Figma
          Container(
            width: 210, height: 210,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1828),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(children: [
              Positioned(top: 18, left: 18,   child: _corner(isLeft: true,  isTop: true)),
              Positioned(top: 18, right: 18,  child: _corner(isLeft: false, isTop: true)),
              Positioned(bottom: 18, left: 18,  child: _corner(isLeft: true,  isTop: false)),
              Positioned(bottom: 18, right: 18, child: _corner(isLeft: false, isTop: false)),
              Center(child: Icon(Icons.qr_code_rounded,
                color: Colors.white.withOpacity(0.15), size: 36)),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Pointe ta caméra vers le QR code\ndu commerce',
            style: TextStyle(fontSize: 12, color: _kSub, height: 1.6),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _corner({required bool isLeft, required bool isTop}) =>
      SizedBox(width: 32, height: 32,
          child: CustomPaint(painter: _CornerPainter(isLeft: isLeft, isTop: isTop)));

  // ─── Bottom Nav (Figma: Cartes | Scan FAB | Historique) ───────────────────

  Widget _buildBottomNav() {
    final isDark = context.isDark;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 76 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1D2A).withOpacity(0.7)
              : Colors.white.withOpacity(0.7),
          border: Border(top: BorderSide(color: _kBorder.withOpacity(0.5))),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10),
        child: Row(children: [
          _navItem(Icons.credit_card_outlined, 'Cartes', 0),
          _navFab(),
          _navItem(Icons.history_rounded, 'Historique', 2),
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
          Icon(icon, size: 20, color: active ? _kPrimary : const Color(0xFFBBBBBB)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: active ? _kPrimary : const Color(0xFFBBBBBB),
          )),
        ]),
      ),
    );
  }

  Widget _navFab() {
    return Expanded(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(
          onTap: () => setState(() => _tab = 1),
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: _kBlueL,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBlueL.withOpacity(0.35), width: 1.5),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
              color: _kDark, size: 22),
          ),
        ),
      ]),
    );
  }

  // ─── Notification Overlay (slide from top) ────────────────────────────────

  Widget _buildNotifOverlay() {
    return AnimatedBuilder(
      animation: _notifAnim,
      builder: (_, __) => Stack(children: [
        GestureDetector(
          onTap: _closeNotifs,
          child: Container(color: Colors.black.withOpacity(0.4 * _notifAnim.value)),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: FractionalTranslation(
            translation: Offset(0, -1 + _notifAnim.value),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header — dark navy like Figma
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 14,
                    left: 20, right: 20, bottom: 14,
                  ),
                  color: _kNavy,
                  child: Row(children: [
                    const Text('Notifications',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Spacer(),
                    TextButton(
                      onPressed: _markAllRead,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: Text('Tout lu',
                        style: TextStyle(color: _kBlueL.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _closeNotifs,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ]),
                ),
                // Filter tabs
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  decoration: BoxDecoration(
                    color: _kWhite,
                    border: Border(bottom: BorderSide(color: _kBorder)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final f in [
                        {'key': 'tout',       'label': 'Tout'},
                        {'key': 'tampon',     'label': 'Tampons'},
                        {'key': 'recompense', 'label': 'Récompenses'},
                        {'key': 'promo',      'label': 'Promos'},
                      ])
                        GestureDetector(
                          onTap: () => setState(() => _notifFilter = f['key']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _notifFilter == f['key'] ? _kPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _notifFilter == f['key'] ? _kPrimary : _kBorder,
                              ),
                            ),
                            child: Text(f['label']!, style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: _notifFilter == f['key'] ? Colors.white : _kSub,
                            )),
                          ),
                        ),
                    ]),
                  ),
                ),
                // List
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Text("Aujourd'hui",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: _kSub, letterSpacing: 0.06)),
                      ),
                      ...(_notifFilter == 'tout'
                          ? _notifs
                          : _notifs.where((n) => n['type'] == _notifFilter).toList())
                          .map((n) => _notifItem(n)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _notifItem(Map n) {
    final color  = Color(n['color'] as int);
    final unread = !(n['read'] as bool);
    return GestureDetector(
      onTap: () => setState(() {
        n['read'] = true;
        _notifCount = _notifs.where((x) => !(x['read'] as bool)).length;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _kBorder),
            left: unread ? BorderSide(color: color, width: 3) : BorderSide.none,
          ),
          color: unread ? color.withOpacity(0.04) : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(n['icon'], style: const TextStyle(fontSize: 15))),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(n['commerce'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
              Text(n['time'],     style: TextStyle(fontSize: 10, color: _kSub)),
            ]),
            const SizedBox(height: 2),
            Text(n['title'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            const SizedBox(height: 1),
            Text(n['body'],  style: TextStyle(fontSize: 11, color: _kSub, height: 1.4)),
          ])),
          if (unread) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(width: 7, height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
          ],
        ]),
      ),
    );
  }

  // ─── Profile Sheet ────────────────────────────────────────────────────────

  void _openProfil() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfilSheet(
        userName: widget.userName,
        initials: _initials,
        token: widget.token,
        profilePictureUrl: _profilePictureUrl,
        onImagePicked: (url) async => setState(() => _profilePictureUrl = url),
        onLogout: _logout,
        onShowPerso: () => _showPersoSheet(context),
        onShowPwd: () => _showPwdSheet(context),
        onShowDelete: () => _showDeleteSheet(context),
      ),
    );
  }

  Widget _buildSheet({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
            const SizedBox(height: 16),
            child,
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, bool obscure = false, Function(String)? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSub)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, keyboardType: type, obscureText: obscure, onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: _kText),
        decoration: InputDecoration(
          filled: true, fillColor: _kBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    ]);
  }

  Widget _sheetBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 46,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
      ),
    );
  }

  void _showPersoSheet(BuildContext ctx) {
    final nameCtrl  = TextEditingController(text: widget.userName);
    final emailCtrl = TextEditingController();
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _buildSheet(title: 'Informations personnelles', child: Column(children: [
          _field('Prénom / Nom', nameCtrl),
          const SizedBox(height: 12),
          _field('Email', emailCtrl, type: TextInputType.emailAddress),
          const SizedBox(height: 20),
          _sheetBtn('Enregistrer', _kPrimary, () => Navigator.pop(ctx)),
        ])));
  }

  void _showPwdSheet(BuildContext ctx) {
    final ctrl1    = TextEditingController();
    final ctrl2    = TextEditingController();
    final ctrl3    = TextEditingController();
    final strength = ValueNotifier<double>(0);
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => StatefulBuilder(builder: (ctx2, ss) => _buildSheet(
          title: 'Changer le mot de passe',
          child: Column(children: [
            _field('Mot de passe actuel', ctrl1, obscure: true),
            const SizedBox(height: 12),
            _field('Nouveau mot de passe', ctrl2, obscure: true, onChanged: (v) {
              double s = 0;
              if (v.length >= 8)                       s += 0.25;
              if (RegExp(r'[A-Z]').hasMatch(v))        s += 0.25;
              if (RegExp(r'[0-9]').hasMatch(v))        s += 0.25;
              if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s += 0.25;
              ss(() => strength.value = s);
            }),
            const SizedBox(height: 6),
            ValueListenableBuilder<double>(
              valueListenable: strength,
              builder: (_, s, __) => ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: s, backgroundColor: _kBorder, minHeight: 3,
                  color: s <= 0.25 ? _kError : s <= 0.5 ? _kGold : _kSuccess,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field('Confirmer', ctrl3, obscure: true),
            const SizedBox(height: 20),
            _sheetBtn('Enregistrer', _kPrimary, () => Navigator.pop(ctx)),
          ]),
        )));
  }

  void _showDeleteSheet(BuildContext ctx) {
    final ctrl = TextEditingController();
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => StatefulBuilder(builder: (ctx2, ss) => _buildSheet(
          title: 'Supprimer mon compte',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kError.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kError.withOpacity(0.2)),
              ),
              child: const Text('⚠️ Action irréversible. Toutes tes cartes et données seront supprimées.',
                  style: TextStyle(fontSize: 13, color: _kError, height: 1.5)),
            ),
            const SizedBox(height: 14),
            Text('Tape « SUPPRIMER » pour confirmer',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSub)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              onChanged: (_) => ss(() {}),
              decoration: InputDecoration(
                hintText: 'SUPPRIMER',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kError)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: ctrl.text == 'SUPPRIMER' ? () => Navigator.pop(ctx) : null,
              child: Container(
                width: double.infinity, height: 46,
                decoration: BoxDecoration(
                  color: ctrl.text == 'SUPPRIMER' ? _kError : _kBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text('Supprimer définitivement',
                    style: TextStyle(
                      color: ctrl.text == 'SUPPRIMER' ? Colors.white : _kSub,
                      fontSize: 14, fontWeight: FontWeight.w700,
                    ))),
              ),
            ),
          ]),
        )));
  }
}

// ─── Profile Sheet ─────────────────────────────────────────────────────────────

class _ProfilSheet extends StatefulWidget {
  final String userName;
  final String initials;
  final String token;
  final String? profilePictureUrl;
  final Future<void> Function(String url) onImagePicked;
  final VoidCallback onLogout;
  final VoidCallback? onShowPerso;
  final VoidCallback? onShowPwd;
  final VoidCallback? onShowDelete;

  const _ProfilSheet({
    required this.userName, required this.initials, required this.token,
    this.profilePictureUrl, required this.onImagePicked, required this.onLogout,
    this.onShowPerso, this.onShowPwd, this.onShowDelete,
  });

  @override
  State<_ProfilSheet> createState() => _ProfilSheetState();
}

class _ProfilSheetState extends State<_ProfilSheet> {
  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

  String? _localUrl;
  File?   _localFile;
  bool    _uploading = false;

  @override
  void initState() {
    super.initState();
    _localUrl = widget.profilePictureUrl;
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (img == null) return;
    final file = File(img.path);
    setState(() { _localFile = file; _uploading = true; });
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/users/profile-picture'))
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final url  = data['profile_picture_url'] as String;
        setState(() => _localUrl = url);
        await widget.onImagePicked(url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo mise à jour ✓'),
                backgroundColor: _kSuccess,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2)));
      } else {
        setState(() => _localFile = null);
      }
    } catch (_) {
      setState(() => _localFile = null);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Padding(padding: const EdgeInsets.only(top: 12),
              child: Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))))),
          // Profile header — blue band
          Container(
            color: _kPrimary,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(children: [
              GestureDetector(
                onTap: _uploading ? null : _pickAndUpload,
                child: Stack(children: [
                  _localFile != null
                      ? ClipOval(child: Image.file(_localFile!, width: 68, height: 68, fit: BoxFit.cover))
                      : UserAvatar(imageUrl: _localUrl, name: widget.userName, size: 68),
                  if (_uploading)
                    Container(width: 68, height: 68,
                        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                  Positioned(bottom: 0, right: 0,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: _kWhite, shape: BoxShape.circle,
                          border: Border.all(color: _kPrimary, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: _kPrimary, size: 11),
                      )),
                ]),
              ),
              const SizedBox(height: 10),
              Text(widget.userName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Settings rows
              _section([
                _row(Icons.person_outline_rounded, _kPrimary.withOpacity(0.12), _kPrimary,
                    'Informations personnelles', 'Nom, email, téléphone',
                    onTap: () { Navigator.pop(context); widget.onShowPerso?.call(); }),
                _row(Icons.lock_outline_rounded, const Color(0xFF27AE60).withOpacity(0.12),
                    const Color(0xFF27AE60),
                    'Changer le mot de passe', 'Sécurité du compte',
                    onTap: () { Navigator.pop(context); widget.onShowPwd?.call(); }),
                _row(Icons.credit_card_outlined, const Color(0xFF27AE60).withOpacity(0.12),
                    const Color(0xFF27AE60),
                    'Mes cartes', 'Gérer et supprimer',
                    onTap: () => Navigator.pop(context), noBorder: true),
              ]),

              const SizedBox(height: 10),

              _section([
                // Dark mode toggle
                _darkModeRow(),
                _row(Icons.help_outline_rounded, const Color(0xFFF4F2EE), const Color(0xFF888888),
                    'Aide & Support', 'FAQ, nous contacter',
                    onTap: () => Navigator.pop(context), noBorder: true),
              ]),

              const SizedBox(height: 14),

              // Logout
              GestureDetector(
                onTap: () { Navigator.pop(context); widget.onLogout(); },
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(
                    color: _kWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE8E7), width: 1.5),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.logout_rounded, color: _kError, size: 16),
                    SizedBox(width: 8),
                    Text('Se déconnecter',
                      style: TextStyle(color: _kError, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),

              // Delete account
              GestureDetector(
                onTap: () { Navigator.pop(context); widget.onShowDelete?.call(); },
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder, width: 1.5),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.delete_outline_rounded, color: _kSub, size: 15),
                    const SizedBox(width: 8),
                    Text('Supprimer mon compte',
                      style: TextStyle(color: _kSub, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _section(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
    child: Column(children: rows),
  );

  Widget _darkModeRow() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder))),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1828),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dark_mode_outlined, color: Color(0xFF4A9EFF), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mode sombre',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            Text("Thème de l'interface",
              style: TextStyle(fontSize: 11, color: _kSub)),
          ])),
          // Custom toggle matching Figma
          GestureDetector(
            onTap: () async {
              final val = mode != ThemeMode.dark;
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              final p = await SharedPreferences.getInstance();
              await p.setBool('dark_mode', val);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38, height: 22,
              decoration: BoxDecoration(
                color: mode == ThemeMode.dark ? _kPrimary : _kBorder,
                borderRadius: BorderRadius.circular(11),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: mode == ThemeMode.dark
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 18, height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, Color iconBg, Color iconColor, String label, String sub,
      {required VoidCallback onTap, bool noBorder = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: noBorder ? null : Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            Text(sub,   style: TextStyle(fontSize: 11, color: _kSub)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18, color: _kSub.withOpacity(0.3)),
        ]),
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;
  const _CornerPainter({required this.isLeft, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kPrimary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x  = isLeft ? 0.0 : size.width;
    final y  = isTop  ? 0.0 : size.height;
    final dx = isLeft ? size.width : -size.width;
    final dy = isTop  ? size.height : -size.height;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
