import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

class CardsTab extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> cards;
  final VoidCallback onRefresh;

  const CardsTab({
    super.key,
    required this.token,
    required this.userName,
    required this.cards,
    required this.onRefresh,
  });

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  // Palette de secours si le commerçant n'a pas de design personnalisé
  static const List<Color> _palette = [
    Color(0xFF2C7BE5),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFF7B4FBF),
    Color(0xFF0097A7),
    Color(0xFFE67E22),
  ];

  /// Parse le card_design du site qarta.be (table merchant_card_designs.card_design).
  /// Champs réels : bgType, bgColors, accentColors, textColor, fontFamily,
  /// bgImageUrl, bgGradientAngle, bgImageOpacity, accentAngle, cardName, stampLabel.
  CardStyle _styleFromCard(Map card, int fallbackIndex) {
    return CardStyle.fromDesign(
      card['card_design'],
      merchantLogoUrl: (card['merchants']?['logo_url'] as String?),
      fallbackColor: _palette[fallbackIndex % _palette.length],
    );
  }

  // Les cartes arrivent déjà enrichies depuis client_home._loadStats()
  List<dynamic> get _rewardCards => widget.cards.where((c) {
    final val  = c['stamps_count'] as int? ?? 0;
    final type = c['merchants']?['program_type'] as String? ?? 'stamps';
    final req  = type == 'points'
        ? (c['merchants']?['points_required'] as int? ?? 100)
        : (c['merchants']?['stamps_required'] as int? ?? 10);
    return val >= req;
  }).toList();

  void _showQRModal(Map card, CardStyle style) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRModal(
        token: widget.token,
        card: card,
        style: style,
        onStampAdded: widget.onRefresh, // rafraîchit les cartes après tampon
      ),
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
          _SectionHeader(title: 'Tes cartes', action: 'Voir tout', onAction: () {}),

          // Liste des cartes
          ...List.generate(cards.length, (i) {
            final card        = cards[i];
            final style       = _styleFromCard(card, i);
            final programType = card['merchants']?['program_type'] as String? ?? 'stamps';
            final isPoints    = programType == 'points';
            return GestureDetector(
              onTap: () => _showQRModal(card, style),
              child: isPoints
                  ? _buildPointsCard(card, style)
                  : _buildStampsCard(card, style),
            );
          }),
        ],
      ),
    );
  }

  // ── Carte Tampons (layout aligné sur qarta.be) ───────────────────────────────

  Widget _buildStampsCard(Map card, CardStyle style) {
    final stamps       = card['stamps_count'] as int? ?? 0;
    // Le site lit stampsRequired depuis card_design → on fait pareil (fallback merchants).
    final required     = style.stampsRequired
        ?? card['merchants']?['stamps_required'] as int? ?? 10;
    final businessName = card['merchants']?['business_name'] as String? ?? '';
    // Reward : prioriser card_design.rewardDescription (édité sur qarta.be),
    // fallback sur merchants.reward_description.
    final reward       = (style.rewardDescription ??
                          card['merchants']?['reward_description'] as String? ??
                          '').trim();
    final pct          = (stamps / required).clamp(0.0, 1.0);
    final full         = stamps >= required;
    // Le site privilégie cardName (le "nom du commerce" édité par le marchand),
    // et l'affiche en MAJUSCULES via CSS text-transform.
    final rawTitle     = (style.cardName ?? '').trim().isNotEmpty
        ? style.cardName!.trim()
        : businessName;
    final title        = rawTitle.toUpperCase();
    // ⚠️ Le site applique textColor BRUT (aucun auto-contraste, aucune opacité).
    final textColor    = style.textColor;
    final stampLabel   = style.stampLabel ?? 'POINTS COLLECTÉS';
    final stampFill    = style.accentColor ?? const Color(0xFFFF2D78);

    // 2 rangées de N/2 (alignement avec le site)
    final perRow       = (required / 2).ceil();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: style.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background (color / gradient / image)
            Positioned.fill(child: style.buildBackground()),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header : "CARTE DE FIDÉLITÉ" + titre  |  "TITULAIRE" + nom client
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CARTE DE FIDÉLITÉ',
                                style: TextStyle(
                                    fontFamily: style.fontFamily,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    letterSpacing: 1.3)),
                            const SizedBox(height: 2),
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: style.fontFamily,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    height: 1.1)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('TITULAIRE',
                              style: TextStyle(
                                  fontFamily: style.fontFamily,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  letterSpacing: 1.3)),
                          const SizedBox(height: 2),
                          Text(widget.userName,
                              style: TextStyle(
                                  fontFamily: style.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Label "POINTS COLLECTÉS"
                  Text(stampLabel,
                      style: TextStyle(
                          fontFamily: style.fontFamily,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 6),
                  // ── Tampons : 2 rangées réparties sur TOUTE la largeur (spaceBetween)
                  LayoutBuilder(builder: (ctx, c) {
                    const vSpacing = 5.0; // espacement vertical entre les 2 rangées
                    // Taille du cercle : ~68% de la cellule → laisse un gap homogène,
                    // les 1er et dernier cercles touchent les bords (comme le site).
                    final size = (c.maxWidth / perRow * 0.68).clamp(22.0, 42.0);

                    Widget buildCell(int idx) {
                      if (idx >= required) {
                        return SizedBox(width: size, height: size);
                      }
                      final filled = idx < stamps;
                      return Container(
                        width: size, height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? stampFill : Colors.transparent,
                          border: Border.all(
                              color: stampFill.withOpacity(0.27), width: 1.5),
                        ),
                        child: filled
                            ? Center(
                                child: Icon(Icons.check,
                                    size: size * 0.5,
                                    color: _contrastOn(stampFill)),
                              )
                            : null,
                      );
                    }

                    Widget buildRow(int row) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                              perRow, (col) => buildCell(row * perRow + col)),
                        );

                    return Column(
                      children: [
                        buildRow(0),
                        const SizedBox(height: vSpacing),
                        buildRow(1),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  _progressBar(pct, full, stampFill),
                  const SizedBox(height: 6),
                  // ── Footer : "Encore X pour [reward]"  |  "stamps / required"
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _footerLine(
                          remaining: required - stamps,
                          reward: reward,
                          full: full,
                          style: style,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$stamps / $required',
                          style: TextStyle(
                              fontFamily: style.fontFamily,
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phrase "Encore X pour votre Y" avec le "X" en bold (comme sur le site).
  Widget _footerLine({
    required int remaining,
    required String reward,
    required bool full,
    required CardStyle style,
    required Color textColor,
  }) {
    final baseStyle = TextStyle(
      fontFamily: style.fontFamily,
      color: textColor,
      fontSize: 10,
      fontWeight: full ? FontWeight.w700 : FontWeight.w400,
    );
    if (full) {
      final suffix = reward.isEmpty ? 'récompense disponible !' : '$reward disponible !';
      return Text(suffix, maxLines: 2, overflow: TextOverflow.ellipsis, style: baseStyle);
    }
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Encore '),
          TextSpan(
              text: '$remaining',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: ' pour votre ${reward.isEmpty ? "récompense" : reward}'),
        ],
      ),
    );
  }

  /// Retourne noir ou blanc — celui qui a le MEILLEUR contraste WCAG sur [bg].
  /// (Sur l'orange #ff6251, le noir gagne 7:1 vs 3:1 pour le blanc — comme sur le site.)
  Color _contrastOn(Color bg) {
    final lum = bg.computeLuminance();
    const dark = Color(0xFF0B1220);
    // Ratio de contraste = (L_clair + 0.05) / (L_sombre + 0.05)
    final contrastWithBlack = (lum + 0.05) / 0.05;          // noir : L≈0
    final contrastWithWhite = 1.05 / (lum + 0.05);          // blanc : L≈1
    return contrastWithBlack >= contrastWithWhite ? dark : Colors.white;
  }

  // ── Carte Points (layout aligné sur qarta.be) ────────────────────────────────

  Widget _buildPointsCard(Map card, CardStyle style) {
    final points       = card['stamps_count'] as int? ?? 0;
    final required     = style.pointsGoal
        ?? card['merchants']?['points_required'] as int?
        ?? card['merchants']?['stamps_required'] as int? ?? 100;
    final businessName = card['merchants']?['business_name'] as String? ?? '';
    final reward       = (style.rewardDescription ??
                          card['merchants']?['reward_description'] as String? ??
                          '').trim();
    final pct          = (points / required).clamp(0.0, 1.0);
    final full         = points >= required;
    final remaining    = required - points;
    final rawTitle     = (style.cardName ?? '').trim().isNotEmpty
        ? style.cardName!.trim()
        : businessName;
    final title        = rawTitle.toUpperCase();
    final textColor    = style.textColor;  // brut, comme le site
    final accent       = style.accentColor ?? const Color(0xFFFF2D78);
    final pointsLabel  = style.pointsLabel ?? style.stampLabel ?? 'POINTS COLLECTÉS';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: style.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(child: style.buildBackground()),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header : titre  |  TITULAIRE
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CARTE DE FIDÉLITÉ',
                                style: TextStyle(
                                    fontFamily: style.fontFamily,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: textColor.withOpacity(0.55),
                                    letterSpacing: 1.4)),
                            const SizedBox(height: 4),
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: style.fontFamily,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    height: 1)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('TITULAIRE',
                              style: TextStyle(
                                  fontFamily: style.fontFamily,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: textColor.withOpacity(0.55),
                                  letterSpacing: 1.4)),
                          const SizedBox(height: 4),
                          Text(widget.userName,
                              style: TextStyle(
                                  fontFamily: style.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(pointsLabel,
                      style: TextStyle(
                          fontFamily: style.fontFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: textColor.withOpacity(0.55),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  // ── Gros compteur de points
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$points',
                          style: TextStyle(
                              fontFamily: style.fontFamily,
                              color: accent,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Text('/ $required pts',
                            style: TextStyle(
                                fontFamily: style.fontFamily,
                                color: textColor.withOpacity(0.55),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _progressBar(pct, full, accent),
                  const SizedBox(height: 8),
                  Text(
                    full
                        ? '$reward disponible !'
                        : (reward.isEmpty
                            ? 'Encore $remaining pts pour votre récompense'
                            : 'Encore $remaining pts pour votre $reward'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: style.fontFamily,
                        color: textColor.withOpacity(full ? 1.0 : 0.85),
                        fontSize: 11,
                        fontWeight: full ? FontWeight.w700 : FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets partagés cartes ───────────────────────────────────────────────────

  Widget _cardTopRow(String name, String initials, bool full, CardStyle style, {Widget? badge}) {
    final logoUrl = style.logoUrl;
    final textColor = style.textColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null) ...[badge, const SizedBox(height: 3)],
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: style.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor)),
            ],
          ),
        ),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: full ? textColor.withOpacity(0.25) : textColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(11),
          ),
          child: logoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    logoUrl,
                    width: 38, height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(initials, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                )
              : Center(child: Text(initials, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800))),
        ),
      ],
    );
  }

  Widget _orb(double size, Color tint, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withOpacity(opacity)),
    );
  }

  /// Barre de progression — track = blanc 10% (comme le site : rgba(255,255,255,0.1)),
  /// remplissage = couleur d'accent.
  Widget _progressBar(double pct, bool full, Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 2,
        backgroundColor: Colors.white.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation(accent),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CardStyle : parse le card_design (qarta.be) en un style Flutter directement utilisable
// ════════════════════════════════════════════════════════════════════════════

class CardStyle {
  final String bgType;           // 'color' | 'gradient' | 'image'
  final List<Color> bgColors;    // 1 si color, 2+ si gradient
  final double bgGradientAngle;  // degrés
  final String? bgImageUrl;
  final double bgImageOpacity;
  final Color textColor;
  final List<Color> accentColors;
  final double accentAngle;
  final String? fontFamily;
  final String? cardName;
  final String? stampLabel;
  final String? pointsLabel;
  final String? rewardDescription;  // depuis card_design (prioritaire sur merchants.reward_description)
  final int? stampsRequired;        // depuis card_design (prioritaire sur merchants.stamps_required)
  final int? pointsGoal;            // depuis card_design (prioritaire sur merchants.points_required)
  final String? logoUrl;
  final Color fallback;

  CardStyle({
    required this.bgType,
    required this.bgColors,
    required this.bgGradientAngle,
    required this.bgImageUrl,
    required this.bgImageOpacity,
    required this.textColor,
    required this.accentColors,
    required this.accentAngle,
    required this.fontFamily,
    required this.cardName,
    required this.stampLabel,
    required this.pointsLabel,
    required this.rewardDescription,
    required this.stampsRequired,
    required this.pointsGoal,
    required this.logoUrl,
    required this.fallback,
  });

  /// Couleur "principale" — sert d'ombrage et de fallback.
  Color get primary => bgColors.isNotEmpty ? bgColors.first : fallback;

  /// Couleur d'accent (utilisée pour tampons cochés, compteur points).
  Color? get accentColor => accentColors.isNotEmpty ? accentColors.first : null;

  /// Couleur de texte effective : si textColor a un mauvais contraste sur le fond,
  /// on bascule sur blanc/noir auto. Le site qarta.be a un bouton "Auto" qui fait
  /// pareil — on émule ce comportement quand textColor=#000000 sur fond sombre.
  Color get effectiveTextColor {
    final bg = primary;
    final txt = textColor;
    final bgLum = bg.computeLuminance();
    final txtLum = txt.computeLuminance();
    // contraste approximatif WCAG : (L1+0.05)/(L2+0.05)
    final lighter = txtLum > bgLum ? txtLum : bgLum;
    final darker  = txtLum > bgLum ? bgLum  : txtLum;
    final ratio   = (lighter + 0.05) / (darker + 0.05);
    if (ratio >= 3.5) return txt; // contraste suffisant → respecter textColor
    // Sinon : noir si fond clair, blanc si fond sombre
    return bgLum > 0.5 ? const Color(0xFF0B1220) : Colors.white;
  }

  /// Couleur de remplissage des tampons cochés (basée sur textColor pour bon contraste).
  Color get stampFillColor => effectiveTextColor.withOpacity(0.9);

  factory CardStyle.fromDesign(
    dynamic design, {
    String? merchantLogoUrl,
    required Color fallbackColor,
  }) {
    if (design is! Map) {
      return CardStyle(
        bgType: 'color',
        bgColors: [fallbackColor],
        bgGradientAngle: 135,
        bgImageUrl: null,
        bgImageOpacity: 0.3,
        textColor: Colors.white,
        accentColors: const [],
        accentAngle: 135,
        fontFamily: null,
        cardName: null,
        stampLabel: null,
        pointsLabel: null,
        rewardDescription: null,
        stampsRequired: null,
        pointsGoal: null,
        logoUrl: merchantLogoUrl,
        fallback: fallbackColor,
      );
    }
    return CardStyle(
      bgType:             (design['bgType']           as String?) ?? 'color',
      bgColors:           _parseColors(design['bgColors'])       ?? [fallbackColor],
      bgGradientAngle:    _toDouble(design['bgGradientAngle'])   ?? 135,
      bgImageUrl:         _str(design['bgImageUrl']),
      bgImageOpacity:     _toDouble(design['bgImageOpacity'])    ?? 0.3,
      textColor:          _parseColor(design['textColor'])       ?? Colors.white,
      accentColors:       _parseColors(design['accentColors'])   ?? const [],
      accentAngle:        _toDouble(design['accentAngle'])       ?? 135,
      fontFamily:         _str(design['fontFamily']),
      cardName:           _str(design['cardName']),
      stampLabel:         _str(design['stampLabel']),
      pointsLabel:        _str(design['pointsLabel']),
      rewardDescription:  _str(design['rewardDescription']),
      stampsRequired:     _toInt(design['stampsRequired']),
      pointsGoal:         _toInt(design['pointsGoal']),
      logoUrl:            _str(design['logoUrl']) ?? _str(design['logo_url']) ?? merchantLogoUrl,
      fallback:           fallbackColor,
    );
  }

  /// Construit le widget de fond (couleur, gradient, ou image).
  Widget buildBackground() {
    switch (bgType) {
      case 'image':
        if (bgImageUrl != null && bgImageUrl!.isNotEmpty) {
          return Stack(fit: StackFit.expand, children: [
            Container(color: primary),
            Opacity(
              opacity: bgImageOpacity.clamp(0.0, 1.0),
              child: Image.network(bgImageUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ]);
        }
        return Container(color: primary);
      case 'gradient':
        if (bgColors.length >= 2) {
          // Convention CSS linear-gradient(Ndeg, …) :
          //   0° = bas→haut, 90° = gauche→droite, 180° = haut→bas, 270° = droite→gauche.
          //   L'angle est mesuré dans le sens horaire depuis le haut.
          // En coords écran (y vers le bas) : direction = (sin θ, -cos θ).
          //   begin = -direction (1ère couleur), end = +direction (dernière couleur).
          final rad = bgGradientAngle * pi / 180;
          final dx = sin(rad);
          final dy = -cos(rad);
          // On étire le vecteur pour que la composante dominante atteigne ±1
          // (le dégradé couvre bien toute la carte, y compris en diagonale).
          final m = (dx.abs() > dy.abs() ? dx.abs() : dy.abs());
          final scale = m == 0 ? 1.0 : 1 / m;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-dx * scale, -dy * scale),
                end:   Alignment( dx * scale,  dy * scale),
                colors: bgColors,
              ),
            ),
          );
        }
        return Container(color: primary);
      case 'color':
      default:
        return Container(color: primary);
    }
  }

  // ── Helpers de parsing ──────────────────────────────────────────────────────

  static String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static Color? _parseColor(dynamic raw) {
    if (raw is! String) return null;
    final hex = raw.replaceAll('#', '').trim();
    try {
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex,     radix: 16));
    } catch (_) {}
    return null;
  }

  static List<Color>? _parseColors(dynamic raw) {
    if (raw is List) {
      final out = <Color>[];
      for (final c in raw) {
        final col = _parseColor(c);
        if (col != null) out.add(col);
      }
      return out.isEmpty ? null : out;
    }
    final single = _parseColor(raw);
    return single == null ? null : [single];
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
          color: context.qSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.12), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(11)),
              child: const Center(child: Icon(Icons.star_rounded, size: 20, color: Color(0xFFF59E0B))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Récompense chez $name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.qText)),
                  const SizedBox(height: 1),
                  Text(reward, style: TextStyle(fontSize: 11, color: context.qSub)),
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
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.qText)),
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
  final CardStyle style;
  final VoidCallback? onStampAdded;
  const QRModal({super.key, required this.token, required this.card, required this.style, this.onStampAdded});

  // Compat : raccourcis pour l'ancien code interne
  Color get color => style.primary;
  String? get logoUrl => style.logoUrl;

  @override
  State<QRModal> createState() => _QRModalState();
}

class _QRModalState extends State<QRModal> with TickerProviderStateMixin {
  String? dynamicToken;
  int timeLeft = 60;
  bool loadingQR = true;
  Timer? _timer;
  Timer? _pollTimer;        // ← polling détection tampon
  int _initialStamps = 0;   // ← valeur de référence au moment d'ouverture
  late AnimationController _confettiCtrl;
  bool _showConfetti = false;

  // ── Flip 3D ──────────────────────────────────────────────────────────────────
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  bool _isFlipped = false;

  void _toggleFlip() {
    if (_isFlipped) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
    fetchDynamicQR();
    final isPoints = (widget.card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    final stamps   = isPoints ? (widget.card['points_count'] as int? ?? 0) : (widget.card['stamps_count'] as int? ?? 0);
    final required = isPoints ? (widget.card['merchants']?['points_required'] as int? ?? 100) : (widget.card['merchants']?['stamps_required'] as int? ?? 10);
    _initialStamps = stamps; // ← mémoriser l'état initial
    _startPolling();         // ← démarrer le polling
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    _confettiCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  // ── Polling : détecte l'ajout d'un tampon en temps réel ──────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkForNewStamp());
  }

  Future<void> _checkForNewStamp() async {
    final r = await ApiService.instance.getMyCards();
    if (!mounted || r.isErr) return;
    final matching = r.value.where((c) => c['id'] == widget.card['id']).toList();
    if (matching.isEmpty) return;
    final updated = matching.first;
    final isPoints = (widget.card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    final newVal = isPoints
        ? (updated['points_count'] as int? ?? 0)
        : (updated['stamps_count'] as int? ?? 0);
    if (newVal > _initialStamps) {
      _pollTimer?.cancel();
      if (mounted) {
        final cb = widget.onStampAdded;
        Navigator.pop(context);
        if (cb != null) Future.microtask(cb);
      }
    }
  }

  Future<void> fetchDynamicQR() async {
    setState(() { loadingQR = true; dynamicToken = null; });
    final r = await ApiService.instance.getDynamicQR(widget.card['id'] as String);
    if (!mounted) return;
    if (r.isOk) {
      setState(() {
        dynamicToken = r.value['dynamic_token'] as String?;
        timeLeft     = r.value['expires_in'] as int? ?? 60;
        loadingQR    = false;
      });
      startTimer();
    } else {
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

  // ── ZOOM QR ──────────────────────────────────────────────────────────────────
  void _showQRZoom(BuildContext context, Color color) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'qr-${widget.card['id']}',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: QrImageView(
                    data: dynamicToken ?? '',
                    version: QrVersions.auto,
                    size: 240,
                    foregroundColor: const Color(0xFF0B1220),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '🔒 Renouvellement dans ${timeLeft}s',
                style: TextStyle(
                  color: timeLeft < 15 ? const Color(0xFFE24B4A) : Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Appuie n\'importe où pour fermer',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FACE AVANT : carte fidélité + QR ─────────────────────────────────────────
  Widget _buildCardFront(Color color, String businessName, int stamps, int required, String reward, bool full, double pct, [bool isPoints = false]) {
    final rawLogo  = widget.logoUrl;
    final logoUrl  = (rawLogo != null && rawLogo.isNotEmpty) ? rawLogo : null;
    final initials = businessName.length >= 2 ? businessName.substring(0, 2).toUpperCase() : businessName.toUpperCase();
    final txt      = widget.style.textColor;

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(child: widget.style.buildBackground()),
              Positioned(top: -30, right: -20, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: txt.withOpacity(0.07)))),
              Positioned(bottom: -40, left: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: txt.withOpacity(0.05)))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logo ou initiales
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    logoUrl,
                                    width: 44, height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                )
                              : Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('CARTE DE FIDÉLITÉ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.12, color: Colors.white.withOpacity(0.55))),
                            const SizedBox(height: 3),
                            Text(businessName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Share.share("Rejoins le programme de fidélité de $businessName sur l'app Qarta !", subject: 'Carte fidélité $businessName'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.25))),
                            child: const Row(children: [Icon(Icons.share_rounded, color: Colors.white, size: 12), SizedBox(width: 5), Text('Partager', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (isPoints) ...[
                      // ── Mode Points ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$stamps', style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 4),
                            child: Text('/ $required pts', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text(
                            full ? '$reward disponible !' : 'Encore ${required - stamps} pts pour $reward',
                            style: TextStyle(color: Colors.white.withOpacity(full ? 1 : 0.7), fontSize: 11, fontWeight: full ? FontWeight.w700 : FontWeight.w400),
                          )),
                        ],
                      ),
                    ] else ...[
                      // ── Mode Tampons ──
                      Wrap(
                        spacing: 5, runSpacing: 5,
                        children: List.generate(required, (j) => Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: j < stamps ? Colors.white.withOpacity(0.9) : Colors.transparent, border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)),
                          child: j < stamps ? Center(child: Icon(Icons.check, size: 13, color: color)) : null,
                        )),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(full ? '$reward disponible !' : 'Encore ${required - stamps} tampon${(required - stamps) > 1 ? 's' : ''} pour $reward', style: TextStyle(color: Colors.white.withOpacity(full ? 1 : 0.7), fontSize: 11, fontWeight: full ? FontWeight.w700 : FontWeight.w400))),
                          Text('$stamps/$required', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: pct, minHeight: 3, backgroundColor: Colors.white.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.85)))),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: loadingQR ? null : () => _showQRZoom(context, color),
                        child: Hero(
                          tag: 'qr-${widget.card['id']}',
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFF0B1220), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12)]),
                            child: loadingQR
                                ? SizedBox(width: 120, height: 120, child: Center(child: CircularProgressIndicator(color: color, strokeWidth: 2)))
                                : QrImageView(data: dynamicToken ?? '', version: QrVersions.auto, size: 120, foregroundColor: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: Text('🔒 Renouvellement dans ${timeLeft}s', style: TextStyle(fontSize: 11, color: timeLeft < 15 ? const Color(0xFFE24B4A) : Colors.white.withOpacity(0.45), fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),
                    ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: timeLeft / 60, minHeight: 2, backgroundColor: Colors.white.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(timeLeft < 15 ? const Color(0xFFE24B4A) : Colors.white.withOpacity(0.5)))),
                    const SizedBox(height: 10),
                    Center(child: Text('Tapez pour voir les infos', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FACE ARRIÈRE : infos du commerce ─────────────────────────────────────────
  Widget _buildCardBack(Color color, String businessName) {
    final address  = widget.card['merchants']?['address'] as String? ?? '—';
    final phone    = widget.card['merchants']?['phone']   as String? ?? '—';
    final hours    = widget.card['merchants']?['hours']   as String? ?? '—';
    final rawLogo  = widget.logoUrl;
    final logoUrl  = (rawLogo != null && rawLogo.isNotEmpty) ? rawLogo : null;
    final initials = businessName.length >= 2 ? businessName.substring(0, 2).toUpperCase() : businessName.toUpperCase();
    final txt      = widget.style.textColor;

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(child: widget.style.buildBackground()),
              Positioned(top: -30, right: -20, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: txt.withOpacity(0.07)))),
              Positioned(bottom: -40, left: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: txt.withOpacity(0.05)))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (logoUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              logoUrl,
                              width: 36, height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          _backInfoRow(Icons.location_on_outlined, 'Adresse', address),
                          const SizedBox(height: 14),
                          _backInfoRow(Icons.phone_outlined, 'Téléphone', phone),
                          const SizedBox(height: 14),
                          _backInfoRow(Icons.access_time_rounded, 'Horaires', hours),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: Text('Tapez pour voir la carte', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final programType = widget.card['merchants']?['program_type'] as String? ?? 'stamps';
    final isPoints = programType == 'points';
    final stamps   = isPoints
        ? (widget.card['points_count'] as int? ?? 0)
        : (widget.card['stamps_count'] as int? ?? 0);
    final required = isPoints
        ? (widget.card['merchants']?['points_required'] as int? ?? 100)
        : (widget.card['merchants']?['stamps_required'] as int? ?? 10);
    final reward = widget.card['merchants']?['reward_description'] as String? ?? '';
    final businessName = widget.card['merchants']?['business_name'] as String? ?? '';
    final color = widget.color;
    final pct = (stamps / required).clamp(0.0, 1.0);
    final full = stamps >= required;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Fond sombre (style design) ────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B1220),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 0),
                child: Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: Color(0xFF8F85D0),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              // Corps scrollable
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 63),
                child: Column(
                  children: [
                    // ── Carte avec flip 3D ───────────────────────────
                    Stack(
                      children: [
                        // Face avant invisible — maintient la hauteur
                        Opacity(
                          opacity: 0,
                          child: _buildCardFront(color, businessName, stamps, required, reward, full, pct, isPoints),
                        ),
                        // Animation flip par-dessus (même taille grâce à Positioned.fill)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _flipAnim,
                            builder: (_, __) {
                              final angle = _flipAnim.value;
                              final showFront = angle < pi / 2;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(angle),
                                child: showFront
                                    ? _buildCardFront(color, businessName, stamps, required, reward, full, pct, isPoints)
                                    : Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()..rotateY(pi),
                                        child: _buildCardBack(color, businessName),
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
