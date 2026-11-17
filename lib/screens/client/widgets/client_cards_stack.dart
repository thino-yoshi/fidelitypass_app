import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';

/// Liste des cartes Android : barre de recherche, puis les cartes en liste verticale.
///  • toucher une carte → ouverture via [onOpen]
/// Le design de chaque carte reste celui choisi par le commerçant (LoyaltyCardFace).
class ClientCardsStack extends StatefulWidget {
  final List<Widget> cards;
  final ValueChanged<String> onSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onScanTap;
  final ValueChanged<int> onOpen;
  final bool hasAnyCard;
  final ValueChanged<bool>? onSearchActive;

  const ClientCardsStack({
    super.key,
    required this.cards,
    required this.onSearch,
    required this.onRefresh,
    required this.onScanTap,
    required this.onOpen,
    required this.hasAnyCard,
    this.onSearchActive,
  });

  static const double cardHeight = 220;
  static const double peek = 64;

  @override
  State<ClientCardsStack> createState() => _ClientCardsStackState();
}

class _ClientCardsStackState extends State<ClientCardsStack> {
  int _out = 0;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_syncSearch);
    _searchCtrl.addListener(_syncSearch);
  }

  void _syncSearch() {
    final active = _searchFocus.hasFocus || _searchCtrl.text.isNotEmpty;
    if (active != _searching) {
      setState(() => _searching = active);
      widget.onSearchActive?.call(active);
    } else {
      setState(() {});
    }
  }

  void _cancelSearch() {
    _searchCtrl.clear();
    widget.onSearch('');
    _searchFocus.unfocus();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ClientCardsStack old) {
    super.didUpdateWidget(old);
    if (_out >= widget.cards.length) _out = 0;
  }

  void _tap(int i, bool isOut) {
    HapticFeedback.selectionClick();
    widget.onOpen(i);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                widget.hasAnyCard ? _withCards(context) : [ClientWelcomeCard(onScanTap: widget.onScanTap)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withCards(BuildContext context) {
    final cards = widget.cards;
    return [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: widget.onSearch,
            style: QText.body.copyWith(fontSize: 17, color: context.cText),
            decoration: InputDecoration(
              hintText: 'Rechercher une carte',
              hintStyle: TextStyle(color: context.cSub),
              prefixIcon: Icon(Icons.search, color: context.cSub, size: 20),
              filled: true,
              fillColor: context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _searching
              ? TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 12)),
                  onPressed: _cancelSearch,
                  child: const Text('Annuler', style: TextStyle(fontSize: 17, color: kPrimary)),
                )
              : const SizedBox.shrink(),
        ),
      ]),
      if (_searchCtrl.text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text('${cards.length} CARTE${cards.length > 1 ? 'S' : ''}', style: QText.label.copyWith(color: context.cSub)),
        ),
      const SizedBox(height: 16),
      if (cards.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: Text('Aucune carte trouvée', style: QText.body.copyWith(color: context.cSub))),
        ),
      for (var i = 0; i < cards.length; i++) ...[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onOpen(i),
          child: SizedBox(
            height: ClientCardsStack.cardHeight,
            child: cards[i],
          ),
        ),
        if (i < cards.length - 1) const SizedBox(height: 14),
      ],
    ];
  }
}

/// Accueil d'un nouveau client sans carte : carte bleu nuit Qarta
/// « Ajoute ta première carte » + les 3 étapes.
class ClientWelcomeCard extends StatelessWidget {
  final VoidCallback onScanTap;
  const ClientWelcomeCard({super.key, required this.onScanTap});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: kNavy.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [kNavyCard.withValues(alpha: 0.55), kNavy.withValues(alpha: 0.62)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: CustomPaint(
                painter: _DashedRRect(kBlueLight.withValues(alpha: 0.45)),
                child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: kPrimary,
              boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.45), blurRadius: 24)],
            ),
            child: const Icon(Icons.qr_code, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 14),
          const Text('Ajoute ta première carte', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text('Scanne le QR code affiché en caisse chez ton commerçant.', textAlign: TextAlign.center,
              style: QText.caption.copyWith(color: Colors.white.withValues(alpha: 0.65))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onScanTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.qr_code, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Scanner un QR code', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
          ),
        ),
      ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 6),
        child: Text('COMMENT ÇA MARCHE', style: QText.label.copyWith(color: context.cSub)),
      ),
      Container(
        decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
        child: Column(children: const [
          _Step(n: 1, title: 'Scanne le QR code en caisse', sub: "Ta carte s'ajoute ici."),
          _Step(n: 2, title: 'Montre ta carte à chaque passage', sub: 'Le commerçant ajoute ton tampon.', divider: true),
          _Step(n: 3, title: 'Profite de ta récompense', sub: "Elle t'attend dans Récompenses.", divider: true),
        ]),
      ),
    ]);
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  final String sub;
  final bool divider;
  const _Step({required this.n, required this.title, required this.sub, this.divider = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (divider) Padding(padding: const EdgeInsets.only(left: 58), child: Container(height: 0.5, color: context.cBorder)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(children: [
          _num(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: QText.body.copyWith(fontSize: 17, color: context.cText)),
              Text(sub, style: QText.caption.copyWith(color: context.cSub)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _num() => Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('$n', style: const TextStyle(color: kPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

class _DashedRRect extends CustomPainter {
  final Color color;
  _DashedRRect(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color;
}
