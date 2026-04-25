import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/api.dart';
import '../../config/app_colors.dart';

const _kPrimary = Color(0xFF2C7BE5);
const _kGold    = Color(0xFFF59E0B);
const _kError   = Color(0xFFE24B4A);

// Palette de couleurs pour les cartes (matching Figma)
const _kCardPalette = [
  Color(0xFF2C7BE5), // bleu
  Color(0xFFC0392B), // rouge
  Color(0xFF27AE60), // vert
  Color(0xFF8E44AD), // violet
  Color(0xFFE67E22), // orange
  Color(0xFF16A085), // teal
  Color(0xFF2980B9), // bleu moyen
  Color(0xFFD35400), // orange foncé
];

Color _cardColor(String merchantName) {
  int hash = 0;
  for (final c in merchantName.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  return _kCardPalette[hash % _kCardPalette.length];
}

// ─── CardsTab ─────────────────────────────────────────────────────────────────

class CardsTab extends StatefulWidget {
  final String token;
  final List<dynamic> cards;
  final VoidCallback onRefresh;

  const CardsTab({super.key, required this.token, required this.cards, required this.onRefresh});

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

  void _showQRModal(Map card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRModal(token: widget.token, card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;

    if (cards.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        color: _kPrimary,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 60),
          Center(child: Column(children: [
            const Text('💳', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text("Tu n'as pas encore de carte.",
              style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text("Scanne un QR code en caisse pour commencer !",
              style: TextStyle(color: _kSub, fontSize: 13), textAlign: TextAlign.center),
          ])),
        ]),
      );
    }

    // Cartes avec récompense disponible
    final rewardCards = cards.where((c) {
      final s = c['stamps_count'] as int? ?? 0;
      final r = c['merchants']?['stamps_required'] as int? ?? 10;
      return s >= r;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: _kPrimary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 100 + MediaQuery.of(context).padding.bottom),
        children: [

          // ── Badge récompense disponible ──────────────────────────────────
          if (rewardCards.isNotEmpty) ...[
            _RewardBadge(card: rewardCards.first),
          ],

          // ── Section header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Row(children: [
              Text('Tes cartes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
              const Spacer(),
              Text('Historique',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimary)),
            ]),
          ),

          // ── Cartes fidélité (style Figma : fond coloré) ───────────────────
          ...cards.asMap().entries.map((entry) {
            final card    = entry.value as Map;
            final name    = card['merchants']?['business_name'] as String? ?? '';
            final reward  = card['merchants']?['reward_description'] as String? ?? '';
            final stamps  = card['stamps_count'] as int? ?? 0;
            final total   = card['merchants']?['stamps_required'] as int? ?? 10;
            final color   = _cardColor(name);
            final pct     = (stamps / total).clamp(0.0, 1.0);
            final isFull  = stamps >= total;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _showQRModal(card),
                child: _LoyaltyCard(
                  name: name,
                  reward: reward,
                  stamps: stamps,
                  total: total,
                  color: color,
                  pct: pct,
                  isFull: isFull,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Loyalty Card (style Figma) ───────────────────────────────────────────────

class _LoyaltyCard extends StatelessWidget {
  final String name;
  final String reward;
  final int stamps;
  final int total;
  final Color color;
  final double pct;
  final bool isFull;

  const _LoyaltyCard({
    required this.name, required this.reward,
    required this.stamps, required this.total,
    required this.color, required this.pct, required this.isFull,
  });

  String get _logo {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '??';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          // Shine circles (Figma decorations)
          Positioned(
            top: -30, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -40, left: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: tag+name | logo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CARTE FIDÉLITÉ',
                      style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 0.12 * 9,
                      )),
                    const SizedBox(height: 3),
                    Text(name,
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ])),
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isFull
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(_logo,
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stamp dots grid (Figma style)
              Wrap(
                spacing: 5, runSpacing: 5,
                children: List.generate(total, (i) => Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: i < stamps ? Colors.white.withOpacity(0.9) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: i < stamps ? Colors.transparent : Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: i < stamps
                      ? Center(child: CustomPaint(
                          size: const Size(10, 10),
                          painter: _CheckPainter(color: color),
                        ))
                      : null,
                )),
              ),

              const SizedBox(height: 10),

              // Bottom row: reward text | count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: isFull
                        ? Text(reward,
                            style: const TextStyle(
                              fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))
                        : Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: 'Encore ',
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                              ),
                              TextSpan(
                                text: '${total - stamps} tampon${(total - stamps) > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: ' pour $reward',
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                              ),
                            ]),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text('$stamps/$total',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFull ? Colors.white : Colors.white.withOpacity(0.85)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reward Badge ─────────────────────────────────────────────────────────────

class _RewardBadge extends StatelessWidget {
  final Map card;
  const _RewardBadge({required this.card});

  @override
  Widget build(BuildContext context) {
    final name   = card['merchants']?['business_name'] as String? ?? '';
    final reward = card['merchants']?['reward_description'] as String? ?? '';
    final kWhite = context.cSurface;
    final kText  = context.cText;
    final kSub   = context.cSub;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: _kGold, width: 1.5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF4A9EFF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Center(
            child: Text('🏆', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        // Text
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$name — $reward',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
          Text('Récompense disponible !',
            style: TextStyle(fontSize: 11, color: kSub)),
        ])),
      ]),
    );
  }
}

// ─── Check Painter (tick inside stamp dot) ────────────────────────────────────

class _CheckPainter extends CustomPainter {
  final Color color;
  const _CheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.4, size.height * 0.7)
      ..lineTo(size.width * 0.8, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── QR Modal ──────────────────────────────────────────────────────────────────

class QRModal extends StatefulWidget {
  final String token;
  final Map card;
  const QRModal({super.key, required this.token, required this.card});

  @override
  State<QRModal> createState() => _QRModalState();
}

class _QRModalState extends State<QRModal> {
  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

  String? _qrToken;
  bool    _loading = true;
  int     _seconds = 60;
  Timer?  _timer;
  Timer?  _renewTimer;

  String get _businessName => widget.card['merchants']?['business_name'] as String? ?? '';
  String get _reward       => widget.card['merchants']?['reward_description'] as String? ?? '';
  int    get _stamps       => widget.card['stamps_count'] as int? ?? 0;
  int    get _required     => widget.card['merchants']?['stamps_required'] as int? ?? 10;
  bool   get _isFull       => _stamps >= _required;

  Color  get _color        => _cardColor(_businessName);

  @override
  void initState() {
    super.initState();
    _fetchQR();
  }

  Future<void> _fetchQR() async {
    setState(() { _loading = true; _seconds = 60; });
    try {
      final id  = widget.card['id'];
      final res = await http.get(
        Uri.parse('$apiUrl/cards/qr/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() { _qrToken = data['qr_token']; _loading = false; });
        _startTimer();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _renewTimer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds--);
      if (_seconds <= 0) { _timer?.cancel(); _fetchQR(); }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _renewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_stamps / _required).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220), // dark navy like Figma card detail
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Row(children: [
            Expanded(child: Text(_businessName,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                color: _color.withOpacity(0.8)))),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ]),
        ),

        // Flippable card area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Card top
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CARTE FIDÉLITÉ', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2,
                      color: Colors.white.withOpacity(0.55))),
                    const SizedBox(height: 3),
                    Text(_businessName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  ])),
                  // Share button
                  GestureDetector(
                    onTap: _qrToken == null ? null : () {
                      Share.share('Ma carte fidélité $_businessName — $_stamps/$_required tampons');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.share_outlined, color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text('Partager',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stamp grid
              Wrap(
                spacing: 5, runSpacing: 5,
                children: List.generate(_required, (i) => Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: i < _stamps ? Colors.white.withOpacity(0.9) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: i < _stamps ? Colors.transparent : Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: i < _stamps
                      ? Center(child: CustomPaint(
                          size: const Size(10, 10),
                          painter: _CheckPainter(color: _color),
                        ))
                      : null,
                )),
              ),

              const SizedBox(height: 10),

              // Reward + count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isFull ? _reward
                          : 'Encore ${_required - _stamps} tampon${(_required - _stamps) > 1 ? 's' : ''} pour $_reward',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                  Text('$_stamps/$_required',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(height: 3, child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.85)),
                )),
              ),

              // QR code
              const SizedBox(height: 16),
              Center(child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: _loading
                    ? const SizedBox(width: 80, height: 80,
                        child: Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2)))
                    : _qrToken != null
                        ? QrImageView(data: _qrToken!, version: QrVersions.auto, size: 80)
                        : const Icon(Icons.qr_code, size: 80),
              )),

              if (!_loading && _qrToken != null) ...[
                const SizedBox(height: 10),
                Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 13,
                    color: _seconds <= 15 ? _kError : Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text('Expire dans $_seconds s', style: TextStyle(
                    fontSize: 11,
                    color: _seconds <= 15 ? _kError : Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  )),
                ])),
              ],
            ]),
          ),
        ),

        const SizedBox(height: 20),
      ]),
    );
  }
}
