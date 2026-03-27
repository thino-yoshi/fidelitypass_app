import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../config/api.dart';
import '../auth_screen.dart';
import 'cards_tab.dart';
import 'stores_tab.dart';
import 'history_tab.dart';

class ClientHome extends StatefulWidget {
  final String token;
  final String userName;
  const ClientHome({super.key, required this.token, required this.userName});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> with TickerProviderStateMixin {
  int _tab = 0; // 0=cartes, 1=historique, 2=scan, 3=commerces
  int _cardCount = 0;
  int _totalStamps = 0;
  int _rewardCount = 0;
  int _notifCount = 3;
  List<dynamic> _cards = [];
  bool _statsLoaded = false;
  bool _notifOpen = false;
  late AnimationController _notifAnim;

  // Notifications fictives (à remplacer par API plus tard)
  final List<Map> _notifs = [
    {'icon': '⭐', 'commerce': 'Bio & Green', 'title': 'Récompense débloquée !', 'body': 'Bravo ! Tu as gagné ta salade offerte.', 'time': '14:32', 'color': 0xFFFBBF24, 'read': false},
    {'icon': '✓', 'commerce': 'Café Lumière', 'title': 'Tampon ajouté !', 'body': '7/10 tampons. Plus que 3 pour ton café offert !', 'time': '11:15', 'color': 0xFF2C7BE5, 'read': false},
    {'icon': '→', 'commerce': 'Black & White', 'title': 'Promo ce soir -20%', 'body': '-20% sur tout le menu ce soir. On t\'attend !', 'time': '09:30', 'color': 0xFF27AE60, 'read': false},
  ];

  @override
  void initState() {
    super.initState();
    _notifAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadStats();
  }

  @override
  void dispose() {
    _notifAnim.dispose();
    super.dispose();
  }

  void _openProfil() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfilSheet(
        userName: widget.userName,
        initials: _initials,
        token: widget.token,
        onLogout: _logout,
      ),
    );
  }

  Future<void> _loadStats() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as List;
        int stamps = 0;
        int rewards = 0;
        for (final c in data) {
          stamps += (c['stamps_count'] as int? ?? 0);
          final req = c['merchants']?['stamps_required'] as int? ?? 10;
          if ((c['stamps_count'] as int? ?? 0) >= req) rewards++;
        }
        setState(() {
          _cards = data;
          _cardCount = data.length;
          _totalStamps = stamps;
          _rewardCount = rewards;
          _statsLoaded = true;
        });
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
    _notifAnim.reverse().then((_) {
      if (mounted) setState(() => _notifOpen = false);
    });
  }

  void _markAllRead() {
    setState(() {
      for (var n in _notifs) n['read'] = true;
      _notifCount = 0;
    });
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
                Expanded(child: _buildTabContent()),
              ],
            ),
            _buildBottomNav(),
            if (_notifOpen) _buildNotifOverlay(),
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
          // Grille de fond
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          // Orbe lumineux
          Positioned(
            top: -20, right: -10,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF2C7BE5).withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar + nom
                  GestureDetector(
                    onTap: () => _openProfil(),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2C7BE5).withOpacity(0.25),
                            border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.45), width: 2),
                          ),
                          child: Center(
                            child: Text(_initials, style: const TextStyle(color: Color(0xFF4A9EFF), fontSize: 13, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bonjour 👋', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, height: 1)),
                            const SizedBox(height: 2),
                            Text(_firstName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Bouton notifs
                  GestureDetector(
                    onTap: _openNotifs,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Icon(Icons.notifications_outlined, color: Colors.white.withOpacity(0.8), size: 18),
                        ),
                        if (_notifCount > 0)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE24B4A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF0B1220), width: 2),
                              ),
                              child: Center(
                                child: Text('$_notifCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _statsLoaded
                    ? '$_cardCount carte${_cardCount > 1 ? 's' : ''} active${_cardCount > 1 ? 's' : ''} · $_rewardCount récompense${_rewardCount > 1 ? 's' : ''} disponible${_rewardCount > 1 ? 's' : ''}'
                    : '···',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SUMMARY STRIP ──────────────────────────────────────────────────────────

  Widget _buildSummaryStrip() {
    return Container(
      color: const Color(0xFF0B1220),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 18),
      child: Row(
        children: [
          _sumCard('$_cardCount', 'Cartes', const Color(0xFFFFFFFF), isActive: true),
          const SizedBox(width: 8),
          _sumCard('$_totalStamps', 'Tampons', const Color(0xFF4A9EFF)),
          const SizedBox(width: 8),
          _sumCard('$_rewardCount', 'Récompense${_rewardCount > 1 ? 's' : ''}', const Color(0xFFFBBF24)),
        ],
      ),
    );
  }

  Widget _sumCard(String val, String label, Color valColor, {bool isActive = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2C7BE5).withOpacity(0.18) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF4A9EFF).withOpacity(0.55) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: TextStyle(color: isActive ? Colors.white : valColor, fontSize: 20, fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB CONTENT ────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return CardsTab(token: widget.token, cards: _cards, onRefresh: _loadStats);
      case 1:
        return HistoryTab(token: widget.token);
      case 2:
        return _buildScanTab();
      case 3:
        return StoresTab(token: widget.token);
      default:
        return CardsTab(token: widget.token, cards: _cards, onRefresh: _loadStats);
    }
  }

  Widget _buildScanTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Scanner un QR code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1828))),
            const SizedBox(height: 6),
            Text('Scanne le QR code affiché en caisse', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 24),
            Container(
              width: 210, height: 210,
              decoration: BoxDecoration(color: const Color(0xFF1A1828), borderRadius: BorderRadius.circular(22)),
              child: Stack(
                children: [
                  // Coins du scanner
                  ...[
                    Alignment.topLeft, Alignment.topRight,
                    Alignment.bottomLeft, Alignment.bottomRight,
                  ].map((a) => Align(
                    alignment: a,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _scanCorner(a),
                    ),
                  )),
                  const Center(
                    child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white24, size: 48),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Pointe ta caméra vers le QR code\ndu commerce',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.6), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _scanCorner(Alignment a) {
    final isLeft = a == Alignment.topLeft || a == Alignment.bottomLeft;
    final isTop = a == Alignment.topLeft || a == Alignment.topRight;
    return SizedBox(
      width: 32, height: 32,
      child: CustomPaint(
        painter: _CornerPainter(isLeft: isLeft, isTop: isTop),
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 76 + MediaQuery.of(context).padding.bottom,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDE9E3))),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10),
        child: Row(
          children: [
            _navItem(Icons.credit_card_outlined, 'Cartes', 0),
            _navItem(Icons.history_rounded, 'Historique', 1),
            _navFab(),
            _navItem(Icons.store_outlined, 'Commerces', 3),
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
            Icon(icon, color: active ? const Color(0xFF2C7BE5) : const Color(0xFFBBBBBB), size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF2C7BE5) : const Color(0xFFBBBBBB),
            )),
          ],
        ),
      ),
    );
  }

  Widget _navFab() {
    final active = _tab == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF0F2044),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.35), width: 1.5),
              ),
              child: Icon(Icons.qr_code_scanner_rounded,
                  color: active ? const Color(0xFF4A9EFF) : const Color(0xFF4A9EFF).withOpacity(0.7), size: 22),
            ),
            const SizedBox(height: 2),
            Text('Scan', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF2C7BE5) : const Color(0xFFBBBBBB),
            )),
          ],
        ),
      ),
    );
  }

  // ── NOTIF OVERLAY ──────────────────────────────────────────────────────────

  Widget _buildNotifOverlay() {
    return AnimatedBuilder(
      animation: _notifAnim,
      builder: (_, __) => Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: _closeNotifs,
            child: Container(color: Colors.black.withOpacity(0.4 * _notifAnim.value)),
          ),
          // Sheet
          Positioned(
            top: 0, left: 0, right: 0,
            child: FractionalTranslation(
              translation: Offset(0, -1 + _notifAnim.value),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      color: const Color(0xFF0B1220),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 20, right: 20, bottom: 16,
                      ),
                      child: Row(
                        children: [
                          const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          TextButton(
                            onPressed: _markAllRead,
                            child: const Text('Tout lu', style: TextStyle(color: Color(0xFF4A9EFF), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          GestureDetector(
                            onTap: _closeNotifs,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                              child: Text("Aujourd'hui", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.06)),
                            ),
                            ..._notifs.map((n) => _notifItem(n)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifItem(Map n) {
    final color = Color(n['color'] as int);
    final unread = !(n['read'] as bool);
    return GestureDetector(
      onTap: () => setState(() {
        n['read'] = true;
        _notifCount = _notifs.where((x) => !x['read']).length;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: const BorderSide(color: Color(0xFFF4F2EE)),
            left: unread ? BorderSide(color: color, width: 3) : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(n['icon'], style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(n['commerce'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1828))),
                      Text(n['time'], style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1828))),
                  const SizedBox(height: 2),
                  Text(n['body'], style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), height: 1.4)),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Profil bottom sheet ───────────────────────────────────────────────────────

class _ProfilSheet extends StatefulWidget {
  final String userName;
  final String initials;
  final String token;
  final VoidCallback onLogout;

  const _ProfilSheet({
    required this.userName,
    required this.initials,
    required this.token,
    required this.onLogout,
  });

  @override
  State<_ProfilSheet> createState() => _ProfilSheetState();
}

class _ProfilSheetState extends State<_ProfilSheet> {
  static const blue = Color(0xFF2C7BE5);

  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Changer le mot de passe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                try {
                  final res = await http.put(
                    Uri.parse('$apiUrl/users/change-password'),
                    headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
                    body: jsonEncode({'current_password': currentCtrl.text, 'new_password': newCtrl.text}),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res.statusCode == 200 ? 'Mot de passe mis à jour !' : jsonDecode(res.body)['detail'] ?? 'Erreur'),
                    backgroundColor: res.statusCode == 200 ? blue : Colors.red,
                  ));
                } catch (_) {
                  setDialogState(() => loading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white),
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccount() {
    final passCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Supprimer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFE24B4A))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cette action est irréversible. Toutes tes cartes et données seront supprimées.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirme ton mot de passe'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                try {
                  final res = await http.delete(
                    Uri.parse('$apiUrl/users/account'),
                    headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
                    body: jsonEncode({'password': passCtrl.text}),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (res.statusCode == 200) {
                    Navigator.pop(context);
                    widget.onLogout();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(jsonDecode(res.body)['detail'] ?? 'Erreur'),
                      backgroundColor: Colors.red,
                    ));
                  }
                } catch (_) {
                  setDialogState(() => loading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE24B4A), foregroundColor: Colors.white),
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }

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
            padding: const EdgeInsets.only(top: 12, bottom: 0),
            child: Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99))),
            ),
          ),
          Container(
            width: double.infinity,
            color: blue,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                  ),
                  child: Center(child: Text(widget.initials, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(height: 10),
                Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _profSection([
                  _profRow(Icons.lock_outline_rounded, const Color(0xFFE8F1FD), blue, 'Changer le mot de passe', 'Modifier ton mot de passe', onTap: _showChangePassword),
                  _profRow(Icons.notifications_outlined, const Color(0xFFFEF3C7), const Color(0xFFF59E0B), 'Notifications', 'Préférences de notifications', onTap: null),
                  _profRow(Icons.help_outline, const Color(0xFFF4F2EE), const Color(0xFF888888), 'Aide & Support', 'FAQ, nous contacter', onTap: null),
                ]),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () { Navigator.pop(context); widget.onLogout(); },
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
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _showDeleteAccount,
                  child: Text('Supprimer mon compte', style: TextStyle(color: Colors.grey[400], fontSize: 12, decoration: TextDecoration.underline)),
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

  static Widget _profRow(IconData icon, Color iconBg, Color iconColor, String label, String sub, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Icon(Icons.chevron_right, color: onTap != null ? const Color(0x4D1A1828) : Colors.transparent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

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

class _CornerPainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;
  const _CornerPainter({required this.isLeft, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2C7BE5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? size.width : -size.width;
    final dy = isTop ? size.height : -size.height;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}