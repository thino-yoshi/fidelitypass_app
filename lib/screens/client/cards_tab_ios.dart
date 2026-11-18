import 'package:flutter/material.dart';
import 'cards_tab.dart' show CardStyle, StampEvent;
import 'widgets/client_open_card_ios.dart';
import 'widgets/client_cards_stack_ios.dart';
import 'widgets/client_pass_face_ios.dart';

class CardsTabIos extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> cards;
  final VoidCallback onRefresh;
  final void Function(StampEvent)? onStampEvent;
  final String? cardIdToAnimate;
  final String? cardIdToSlideIn;
  final VoidCallback? onAnimationDone;
  final VoidCallback? onScanTap;
  final ValueChanged<bool>? onSearchActive;

  const CardsTabIos({
    super.key,
    required this.token,
    required this.userName,
    required this.cards,
    required this.onRefresh,
    this.onStampEvent,
    this.cardIdToAnimate,
    this.cardIdToSlideIn,
    this.onAnimationDone,
    this.onScanTap,
    this.onSearchActive,
  });

  @override
  State<CardsTabIos> createState() => _CardsTabIosState();
}

class _CardsTabIosState extends State<CardsTabIos> {
  String _search = '';

  static const List<Color> _palette = [
    Color(0xFF2C7BE5),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFF7B4FBF),
    Color(0xFF0097A7),
    Color(0xFFE67E22),
  ];

  CardStyle _styleFromCard(Map card, int fallbackIndex) {
    return CardStyle.fromDesign(
      card['card_design'],
      merchantLogoUrl: (card['merchants']?['logo_url'] as String?),
      fallbackColor: _palette[fallbackIndex % _palette.length],
    );
  }

  static RectTween _straightRect(Rect? b, Rect? e) => RectTween(begin: b, end: e);

  /// Carte en vol entre la pile et le milieu de l'écran (ou la carte ouverte).
  /// Une carte rangée ne montre qu'une bande en haut (le reste est caché sous la
  /// suivante) : pendant le vol, la carte se replie en douceur jusqu'à cette bande,
  /// pour qu'à l'arrivée il n'y ait aucune coupure.
  static Widget _passShuttle(Map card, CardStyle style, Animation<double> anim,
      {required bool collapsedAtRest, bool lastAtRest = false}) {
    final full = ClientPassFaceIos(card: card, style: style);
    if (!collapsedAtRest) return Material(type: MaterialType.transparency, child: full);
    final t = CurvedAnimation(parent: anim, curve: const Interval(0.0, 0.3, curve: Curves.easeOut));
    final fold = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
    // Hauteur visible au repos dans la pile (comme dans ClientCardsStackIos).
    final rest = (lastAtRest ? ClientCardsStackIos.peek + 14 : ClientCardsStackIos.peek) / ClientCardsStackIos.cardHeight;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          final face = t.value >= 1
              ? full
              : Stack(fit: StackFit.expand, children: [
                  ClientPassFaceIos(card: card, style: style, collapsed: true),
                  Opacity(opacity: t.value, child: full),
                ]);
          final visible = rest + (1 - rest) * fold.value;
          final clip = lastAtRest || visible > 0.99
              ? ClipRRect(borderRadius: BorderRadius.circular(18), child: _topPart(face, visible))
              : ClipRRect(
                  // Bas carré : la carte suivante se pose dessus, comme dans la pile.
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: _topPart(face, visible));
          // Align : le vol impose la taille entière ; on la relâche pour pouvoir replier.
          return Align(alignment: Alignment.topCenter, child: clip);
        },
      ),
    );
  }

  // Garde la carte à sa taille entière et n'en montre que le haut.
  static Widget _topPart(Widget face, double visible) => LayoutBuilder(
        builder: (_, c) => SizedBox(
          width: c.maxWidth,
          height: c.maxHeight * visible,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: c.maxHeight, maxHeight: c.maxHeight,
            child: face,
          ),
        ),
      );

  void _popOutCard(Map card, CardStyle style) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, _) => CardPopOutIos(
        heroTag: 'card-${card['id']}',
        animation: anim,
        face: ClientPassFaceIos(card: card, style: style),
        onOpen: () {
          Navigator.of(ctx).pushReplacement(_openCardRoute(card, style));
        },
      ),
    ));
  }

  Route<void> _openCardRoute(Map card, CardStyle style, {double restFraction = 1}) => PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 340),
        pageBuilder: (ctx, anim, _) => OpenCardPageIos(
          animation: anim,
          child: QRModalIos(
            token: widget.token,
            card: card,
            style: style,
            userName: widget.userName,
            onStampAdded: widget.onRefresh,
            onStampEvent: widget.onStampEvent,
            // À l'ouverture, la carte vole depuis la pile et grandit. À la fermeture,
            // elle redescend avec la page (voir OpenCardPageIos : vol coupé au retour).
            heroTag: 'card-${card['id']}',
            heroRestFraction: restFraction,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cards = _search.isEmpty
        ? widget.cards
        : widget.cards.where((c) {
            final q        = _search.toLowerCase();
            final name     = (c['merchants']?['business_name'] as String? ?? '').toLowerCase();
            final cardName = ((c['card_design'] as Map?)?['cardName'] as String? ?? '').toLowerCase();
            return name.contains(q) || cardName.contains(q);
          }).toList();

    return ClientCardsStackIos(
      hasAnyCard: widget.cards.isNotEmpty,
      onSearchActive: widget.onSearchActive,
      onSearch: (v) => setState(() => _search = v),
      onRefresh: () async => widget.onRefresh(),
      onScanTap: widget.onScanTap ?? () {},
      cards: List.generate(cards.length, (i) {
        final card  = cards[i];
        final style = _styleFromCard(card, i);
        final face = Hero(
          tag: 'card-${card['id']}',
          createRectTween: _straightRect,
          // Pas de dessin de vol ici : à l'aller comme au retour, c'est celui de la
          // carte ouverte (QRModalIos) qui sert, donc la carte ne se déforme jamais.
          child: ClientPassFaceIos(card: card, style: style, collapsed: i != 0),
        );
        return face;
      }),
      onOpen: (i) {
        final card = cards[i];
        if (card['id'] == widget.cardIdToAnimate) return;
        // Une seule touche : la carte s'ouvre directement (comme Apple Wallet).
        // Ancienne version en deux temps (carte au milieu, puis ouverte) :
        //   _popOutCard(card, _styleFromCard(card, i));
        final rest = i == 0
            ? 1.0
            : (i == cards.length - 1 ? ClientCardsStackIos.peek + 14 : ClientCardsStackIos.peek) / ClientCardsStackIos.cardHeight;
        Navigator.of(context).push(_openCardRoute(card, _styleFromCard(card, i), restFraction: rest));
      },
    );
  }
}
