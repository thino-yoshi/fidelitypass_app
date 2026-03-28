import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/api.dart';

class CardsTab extends StatefulWidget {
  final String token;
  final List<dynamic> cards;
  final VoidCallback onRefresh;

  const CardsTab({
    super.key,
    required this.token,
    required this.cards,
    required this.onRefresh,
  });

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  // Couleurs par défaut pour les cartes
  static const List<Color> _palette = [
    Color(0xFF2C7BE5),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFF7B4FBF),
    Color(0xFF0097A7),
    Color(0xFFE67E22),
  ];

  Color _cardColor(int i) => _palette[i % _palette.length];

  // Cartes avec récompense disponible
  List<dynamic> get _rewardCards => widget.cards.where((c) {
    final stamps = c['stamps_count'] as int? ?? 0;
    final req = c['merchants']?['stamps_required'] as int? ?? 10;
    return stamps >= req;
  }).toList();

  void _showQRModal(Map card, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRModal(token: widget.token, card: card, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;

    if (cards.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        color: const Color(0xFF2C7BE5),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  const Text('💳', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text("Tu n'as pas encore de carte.", style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                  const SizedBox(height: 4),
                  Text("Va dans Commerces pour en créer une !", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: const Color(0xFF2C7BE5),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // Badge récompense si dispo
          if (_rewardCards.isNotEmpty) ...[
            const _SectionHeader(title: 'Récompense disponible'),
            _RewardBadge(
              rewardCards: _rewardCards,
              onTap: (card, color) => _showQRModal(card, color),
              palette: _palette,
              allCards: cards,
            ),
          ],

          _SectionHeader(title: 'Tes cartes', action: 'Voir tout', onAction: () {}),

          // Liste des cartes
          ...List.generate(cards.length, (i) {
            final card = cards[i];
            final color = _cardColor(i);
            final stamps = card['stamps_count'] as int? ?? 0;
            final required = card['merchants']?['stamps_required'] as int? ?? 10;
            final businessName = card['merchants']?['business_name'] as String? ?? '';
            final reward = card['merchants']?['reward_description'] as String? ?? '';
            final initials = businessName.length >= 2
                ? businessName.substring(0, 2).toUpperCase()
                : businessName.toUpperCase();
            final pct = (stamps / required).clamp(0.0, 1.0);
            final full = stamps >= required;

            return GestureDetector(
              onTap: () => _showQRModal(card, color),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CARTE FIDÉLITÉ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.12, color: Colors.white.withOpacity(0.55), height: 1)),
                            const SizedBox(height: 3),
                            Text(businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(
                            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tampons
                    Wrap(
                      spacing: 5, runSpacing: 5,
                      children: List.generate(required, (j) => Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: j < stamps ? Colors.white.withOpacity(0.9) : Colors.transparent,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        ),
                        child: j < stamps
                            ? Center(child: Icon(Icons.check, size: 11, color: color))
                            : null,
                      )),
                    ),
                    const SizedBox(height: 10),

                    // Bottom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            full ? '$reward disponible !' : 'Encore ${required - stamps} tampon${(required - stamps) > 1 ? 's' : ''} pour $reward',
                            style: TextStyle(
                              color: Colors.white.withOpacity(full ? 1 : 0.7),
                              fontSize: 11,
                              fontWeight: full ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                        Text('$stamps/$required', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 3,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Widget badge récompense ───────────────────────────────────────────────────

class _RewardBadge extends StatelessWidget {
  final List<dynamic> rewardCards;
  final List<dynamic> allCards;
  final List<Color> palette;
  final void Function(Map, Color) onTap;

  const _RewardBadge({required this.rewardCards, required this.allCards, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = rewardCards.first;
    final i = allCards.indexOf(card);
    final color = palette[i % palette.length];
    final name = card['merchants']?['business_name'] as String? ?? '';
    final reward = card['merchants']?['reward_description'] as String? ?? '';

    return GestureDetector(
      onTap: () => onTap(card, color),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.12), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(11)),
              child: const Center(child: Text('⭐', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Récompense chez $name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1828))),
                  const SizedBox(height: 1),
                  Text(reward, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(9)),
              child: const Text('Voir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1828))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 12, color: Color(0xFF2C7BE5), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Modal QR dynamique (inchangée) ───────────────────────────────────────────

class QRModal extends StatefulWidget {
  final String token;
  final Map card;
  final Color color;
  const QRModal({super.key, required this.token, required this.card, required this.color});

  @override
  State<QRModal> createState() => _QRModalState();
}

class _QRModalState extends State<QRModal> with TickerProviderStateMixin {
  String? dynamicToken;
  int timeLeft = 60;
  bool loadingQR = true;
  Timer? _timer;
  late AnimationController _confettiCtrl;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    fetchDynamicQR();
    final stamps = widget.card['stamps_count'] as int? ?? 0;
    final required = widget.card['merchants']?['stamps_required'] as int? ?? 10;
    if (stamps >= required) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) { setState(() => _showConfetti = true); _confettiCtrl.forward(); }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchDynamicQR() async {
    setState(() { loadingQR = true; dynamicToken = null; });
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/qr/${widget.card['id']}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          dynamicToken = data['dynamic_token'];
          timeLeft = data['expires_in'] ?? 60;
          loadingQR = false;
        });
        startTimer();
      }
    } catch (e) {
      setState(() => loadingQR = false);
    }
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => timeLeft--);
      if (timeLeft <= 0) {
        t.cancel();
        fetchDynamicQR();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stamps = widget.card['stamps_count'] as int? ?? 0;
    final required = widget.card['merchants']?['stamps_required'] as int? ?? 10;
    final reward = widget.card['merchants']?['reward_description'] as String? ?? '';
    final businessName = widget.card['merchants']?['business_name'] as String? ?? '';
    final color = widget.color;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text(
                    businessName.length >= 2 ? businessName.substring(0, 2).toUpperCase() : businessName.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(businessName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('Carte de fidélité', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
            ),
            child: loadingQR
                ? SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator(color: color)))
                : QrImageView(data: dynamicToken ?? '', version: QrVersions.auto, size: 180, foregroundColor: color),
          ),
          const SizedBox(height: 12),

          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔒 QR sécurisé · renouvellement auto', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text('${timeLeft}s', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: timeLeft < 15 ? Colors.red : Colors.grey[600],
              )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: timeLeft / 60,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(timeLeft < 15 ? Colors.red : color),
            ),
          ),
          const SizedBox(height: 20),

          // Tampons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mes tampons', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('$stamps/$required', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(required, (i) => Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < stamps ? color : Colors.transparent,
                      border: Border.all(color: i < stamps ? color : Colors.grey[300]!, width: 2.5),
                    ),
                    child: Center(child: Text(i < stamps ? '★' : '', style: const TextStyle(color: Colors.white, fontSize: 16))),
                  )),
                ),
                if (stamps >= required) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('🎉 $reward disponible !',
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14), textAlign: TextAlign.center),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100], foregroundColor: Colors.grey[700],
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      'Rejoins le programme de fidélité de $businessName sur l\'app Qarta !',
                      subject: 'Carte fidélité $businessName',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
        ),
        if (_showConfetti)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ConfettiPainter(_confettiCtrl.value, color),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  static final _rng = Random(42);
  static final _particles = List.generate(60, (_) => _Particle(_rng));

  _ConfettiPainter(this.progress, this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;
    for (final p in _particles) {
      final t = (progress * 1.3 - p.delay).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = p.x * size.width;
      final y = p.startY * size.height - t * size.height * p.speed;
      final opacity = (1.0 - t * 0.8).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin * pi * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  final double x, startY, speed, delay, spin, w, h;
  final Color color;

  _Particle(Random rng)
      : x = rng.nextDouble(),
        startY = rng.nextDouble() * 0.3 + 0.8,
        speed = rng.nextDouble() * 0.8 + 0.5,
        delay = rng.nextDouble() * 0.4,
        spin = (rng.nextBool() ? 1 : -1) * (rng.nextDouble() + 0.5),
        w = rng.nextDouble() * 8 + 4,
        h = rng.nextDouble() * 6 + 3,
        color = [
          const Color(0xFFFBBF24),
          const Color(0xFF2C7BE5),
          const Color(0xFF27AE60),
          const Color(0xFFE24B4A),
          const Color(0xFF7B4FBF),
          Colors.white,
        ][rng.nextInt(6)];
}
