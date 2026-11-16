import 'package:flutter/material.dart';
import 'cards_tab.dart' show CardStyle, StampEvent, QRModal, CardPopOut, OpenCardPage, LoyaltyCardFace;
import 'widgets/client_cards_stack_ios.dart';

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

  static RectTween _straightRect(Rect? b, Rect? e) => RectTween(begin: b, end: e);  // gardé pour Hero

  void _popOutCard(Map card, CardStyle style) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, _) => CardPopOut(
        heroTag: 'card-${card['id']}',
        animation: anim,
        face: LoyaltyCardFace(card: card, style: style, userName: widget.userName),
        onOpen: () {
          Navigator.of(ctx).pushReplacement(_openCardRoute(card, style));
        },
      ),
    ));
  }

  Route<void> _openCardRoute(Map card, CardStyle style) => PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 340),
        pageBuilder: (ctx, anim, _) => OpenCardPage(
          animation: anim,
          child: QRModal(
            token: widget.token,
            card: card,
            style: style,
            userName: widget.userName,
            onStampAdded: widget.onRefresh,
            onStampEvent: widget.onStampEvent,
            heroTag: 'card-${card['id']}',
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
        return Hero(
          tag: 'card-${card['id']}',
          createRectTween: _straightRect,
          child: LoyaltyCardFace(card: card, style: style, userName: widget.userName, decorPattern: i % 6),
        );
      }),
      onOpen: (i) {
        final card = cards[i];
        if (card['id'] == widget.cardIdToAnimate) return;
        _popOutCard(card, _styleFromCard(card, i));
      },
    );
  }
}
