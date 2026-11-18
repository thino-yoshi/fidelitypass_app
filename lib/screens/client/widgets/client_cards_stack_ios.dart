import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';

/// Liste des cartes iOS : barre de recherche, puis les cartes empilées.
/// Une seule carte est sortie (entière) ; les autres ne montrent que leur haut.
///  • toucher une carte → elle sort et apparaît au milieu de l'écran ([onOpen])
///  • toucher à côté → elle retourne à sa place dans la pile
/// Le design de chaque carte reste celui choisi par le commerçant.
class ClientCardsStackIos extends StatefulWidget {
  final List<Widget> cards;          // une carte par élément (hauteur [cardHeight])
  final ValueChanged<String> onSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onScanTap;
  final ValueChanged<int> onOpen;    // fait sortir la carte au milieu
  final bool hasAnyCard;             // false = nouveau client (aucune carte)
  final ValueChanged<bool>? onSearchActive; // true = mode recherche (titre caché)

  const ClientCardsStackIos({
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
  static const double peek = 64; // hauteur visible d'une carte rangée

  @override
  State<ClientCardsStackIos> createState() => _ClientCardsStackIosState();
}

class _ClientCardsStackIosState extends State<ClientCardsStackIos> {
  int _out = 0; // carte sortie de la pile
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_syncSearch);
    _searchCtrl.addListener(_syncSearch);
  }

  // Mode recherche (comme sur iPhone) : dès qu'on touche le champ, il monte en
  // haut, le titre se cache et « Annuler » apparaît.
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
  void didUpdateWidget(ClientCardsStackIos old) {
    super.didUpdateWidget(old);
    if (_out >= widget.cards.length) _out = 0;
  }

  // La carte touchée sort de la pile et vient au milieu de l'écran
  // (l'ordre de la pile ne change pas : elle y retourne quand on la range).
  void _tap(int i, bool isOut) {
    HapticFeedback.selectionClick();
    widget.onOpen(i);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              widget.hasAnyCard ? _withCards(context) : [ClientWelcomeCard(onScanTap: widget.onScanTap)],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _withCards(BuildContext context) {
    final cards = widget.cards;
    return [
      Row(children: [
        Expanded(
          child: CupertinoSearchTextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            placeholder: 'Rechercher une carte',
            onChanged: widget.onSearch,
            style: QText.body.copyWith(fontSize: 17, color: context.cText),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _searching
              ? CupertinoButton(
                  padding: const EdgeInsets.only(left: 12),
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
      for (var i = 0; i < cards.length; i++) _stacked(i, cards[i], last: i == cards.length - 1),
    ];
  }

  Widget _stacked(int i, Widget card, {required bool last}) {
    final isOut = i == _out; // seule la 1re (dernière utilisée) est entière
    final framed = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(i, isOut),
      child: SizedBox(
        height: ClientCardsStackIos.cardHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: kNavy.withValues(alpha: 0.16), blurRadius: 14, offset: Offset(0, i == 0 ? 8 : -3)),
            ],
          ),
          child: card,
        ),
      ),
    );
    // Les cartes rangées ne montrent que leur haut : la suivante se pose dessus.
    // Quand on en sort une, sa hauteur s'ouvre en douceur.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: isOut ? 1.0 : ClientCardsStackIos.peek / ClientCardsStackIos.cardHeight),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, f, child) {
        // La dernière carte rangée : courte et arrondie (pas de grand vide dessous).
        if (last && !isOut) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: (ClientCardsStackIos.peek + 14) / ClientCardsStackIos.cardHeight,
              child: child,
            ),
          );
        }
        if (!isOut && f < 0.99) {
          // Carte rangée : on ne garde que son bandeau (+ un peu caché sous la suivante),
          // pour que son corps ne dépasse jamais sous la pile.
          const keep = ClientCardsStackIos.peek + 18;
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: (f * ClientCardsStackIos.cardHeight) / keep,
            child: ClipRect(
              child: Align(alignment: Alignment.topCenter, heightFactor: keep / ClientCardsStackIos.cardHeight, child: child),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: isOut && !last ? 8 * f : 0),
          child: Align(alignment: Alignment.topCenter, heightFactor: f, child: child),
        );
      },
      child: framed,
    );
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
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kNavyCard, kNavy]),
          boxShadow: [BoxShadow(color: kNavy.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        // Contour en pointillés bleu ciel : « une carte vide à remplir ».
        child: CustomPaint(
          painter: _DashedRRect(kBlueLight.withValues(alpha: 0.45)),
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: kBlueLight.withValues(alpha: 0.16),
              border: Border.all(color: kBlueLight.withValues(alpha: 0.4)),
              boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: 0.45), blurRadius: 24)],
            ),
            child: const Icon(CupertinoIcons.qrcode_viewfinder, color: kBlueLight, size: 32),
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
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: kPrimary,
              onPressed: onScanTap,
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(CupertinoIcons.qrcode_viewfinder, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Scanner un QR code', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
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
