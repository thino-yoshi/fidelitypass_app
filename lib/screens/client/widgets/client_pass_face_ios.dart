import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../cards_tab.dart' show CardStyle;

/// Carte de fidélité iOS (maquette validée) : le fond, la couleur du texte
/// et le logo viennent du design du commerçant.
///  • entière  : « CARTE DE FIDÉLITÉ », nom, pastille, tampons (ou points),
///               « Plus que 3 tampons avant : un MC Burger » et « 7/10 »
///  • rangée   : nom + compteur (8/8, 45/100 pts) + petite barre
/// Pas de « TITULAIRE » : c'est le téléphone du client.
class ClientPassFaceIos extends StatelessWidget {
  final Map card;
  final CardStyle style;
  final bool collapsed;
  /// Carte ouverte (comme Apple Wallet) : le QR code est DANS la carte, en bas.
  final Widget? qr;

  const ClientPassFaceIos({super.key, required this.card, required this.style, this.collapsed = false, this.qr});

  Map get _m => (card['merchants'] as Map?) ?? const {};
  bool get _isPoints => (_m['program_type'] as String? ?? 'stamps') == 'points';
  int get _count => _isPoints ? (card['points_count'] as int? ?? 0) : (card['stamps_count'] as int? ?? 0);
  int get _goal => _isPoints
      ? (style.pointsGoal ?? _m['points_required'] as int? ?? 100)
      : (style.stampsRequired ?? _m['stamps_required'] as int? ?? 10);
  String get _name {
    final n = (style.cardName ?? '').trim();
    return n.isNotEmpty ? n : (_m['business_name'] as String? ?? '');
  }
  String get _reward => (style.rewardDescription ?? _m['reward_description'] as String? ?? '').trim();

  String get _initials {
    // Seulement les mots qui commencent par une lettre (« Fleurs & Co » → FC).
    final w = _name.trim().split(RegExp(r'\s+')).where((e) => RegExp(r'^[A-Za-zÀ-ÿ0-9]').hasMatch(e)).toList();
    if (w.isEmpty) return '';
    return (w.length >= 2 ? '${w[0][0]}${w[1][0]}' : w[0].substring(0, min(2, w[0].length))).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fg = style.textColor;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: style.primary.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: style.buildBackground()),
          // léger reflet en haut, comme les cartes Wallet
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: collapsed ? _collapsed(fg) : _full(fg),
          ),
        ]),
      ),
    );
  }

  // ── Carte rangée : nom, compteur, petite barre ────────────────────────────
  Widget _collapsed(Color fg) {
    final pct = _goal == 0 ? 0.0 : (_count / _goal).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        ),
        const SizedBox(width: 10),
        Text(_isPoints ? '$_count/$_goal pts' : '$_count/$_goal',
            style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      const SizedBox(height: 8),
      _bar(fg, pct, width: 70),
    ]);
  }

  Widget _bar(Color fg, double pct, {double? width}) => SizedBox(
        width: width,
        height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: fg.withValues(alpha: 0.28))),
            Positioned.fill(
              child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct, child: ColoredBox(color: fg)),
            ),
          ]),
        ),
      );

  // ── Carte entière ────────────────────────────────────────────────────────
  Widget _full(Color fg) {
    final left = (_goal - _count).clamp(0, _goal);
    final full = _count >= _goal;
    final unit = _isPoints ? 'pts' : (left > 1 ? 'tampons' : 'tampon');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CARTE DE FIDÉLITÉ',
                style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          ]),
        ),
        const SizedBox(width: 10),
        _badge(fg),
      ]),
      const SizedBox(height: 8),
      Expanded(child: _isPoints ? _points(fg) : _stamps(fg)),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          // Une seule ligne comme sur la maquette (réduite si la récompense est longue).
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Text.rich(
            full
                ? TextSpan(text: _reward.isNotEmpty ? 'Carte complète : $_reward' : 'Carte complète')
                : TextSpan(children: [
                    const TextSpan(text: 'Plus que '),
                    TextSpan(text: '$left', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: _reward.isNotEmpty ? ' $unit avant : $_reward' : ' $unit avant ta récompense'),
                  ]),
            maxLines: 1,
            style: TextStyle(color: fg, fontSize: 15, height: 1.2, letterSpacing: -0.3),
          ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$_count/$_goal',
            style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      if (qr != null) ...[
        const SizedBox(height: 18),
        Center(child: qr!),
        const SizedBox(height: 10),
        Center(
          child: Text('Montre ce code en caisse',
              style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
        ),
      ],
    ]);
  }

  Widget _badge(Color fg) {
    final logo = style.logoUrl;
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
        image: logo != null && logo.isNotEmpty ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: logo != null && logo.isNotEmpty
          ? null
          : Text(_initials, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  // Tampons : ronds pleins avec coche, ronds en pointillés pour ceux qui restent.
  Widget _stamps(Color fg) {
    final fill = style.accentColor ?? fg;
    final n = _goal.clamp(1, 30);
    final cols = n <= 5 ? n : (n <= 10 ? (n / 2).ceil() : min(6, (n / 3).ceil()));
    final rows = (n / cols).ceil();
    return LayoutBuilder(builder: (_, c) {
      const gap = 10.0;
      final byW = (c.maxWidth - gap * (cols - 1)) / cols;
      final byH = (c.maxHeight - gap * (rows - 1)) / rows;
      final d = min(min(byW, byH), 46.0);
      Widget dot(int i) => SizedBox(
            width: d, height: d,
            child: i >= n
                ? null
                : i < _count
                    ? Container(
                        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                        child: Icon(CupertinoIcons.checkmark_alt, size: d * 0.5, color: style.primary),
                      )
                    : CustomPaint(painter: _DashedCircle(fg.withValues(alpha: 0.55))),
          );
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          Row(
            // Ronds répartis sur toute la largeur de la carte.
            mainAxisAlignment: cols >= 3 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceEvenly,
            children: [for (var k = 0; k < cols; k++) dot(r * cols + k)],
          ),
        ],
      ]);
    });
  }

  Widget _points(Color fg) {
    final pct = _goal == 0 ? 0.0 : (_count / _goal).clamp(0.0, 1.0);
    final fill = style.accentColor ?? fg;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: '$_count', style: TextStyle(color: fill, fontSize: 48, fontWeight: FontWeight.w800, height: 1, letterSpacing: -1)),
        TextSpan(text: '  pts', style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 17, fontWeight: FontWeight.w600)),
      ])),
      const SizedBox(height: 12),
      _bar(fg, pct),
    ]);
  }
}

class _DashedCircle extends CustomPainter {
  final Color color;
  _DashedCircle(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6;
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    const dashes = 18;
    for (var i = 0; i < dashes; i++) {
      final a = 2 * pi * i / dashes;
      canvas.drawArc(r, a, 2 * pi / dashes * 0.55, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}
