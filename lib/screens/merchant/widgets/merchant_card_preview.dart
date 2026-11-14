import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../config/app_colors.dart';
import '../../client/cards_tab.dart' show LoyaltyCardFace, CardStyle;

class MerchantCardPreview extends StatelessWidget {
  final Map? cardDesign;
  final Map? merchantInfo;
  final VoidCallback onEditTap;

  const MerchantCardPreview({
    super.key,
    required this.cardDesign,
    required this.merchantInfo,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = {
      'stamps_count': 0,
      'card_design':  cardDesign,
      'merchants':    merchantInfo ?? {},
    };
    final style = CardStyle.fromDesign(
      cardDesign,
      merchantLogoUrl: merchantInfo?['logo_url'] as String?,
      fallbackColor: kPrimary,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Ma carte fidélité',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cText)),
        GestureDetector(
          onTap: onEditTap,
          child: const Text('Modifier',
            style: TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onEditTap,
        child: SizedBox(
          height: 220,
          child: LoyaltyCardFace(card: card, style: style, userName: 'Client'),
        ),
      ),
      const SizedBox(height: 8),
      Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit_outlined, size: 11, color: context.cSub),
        const SizedBox(width: 5),
        Text('Appuyer pour modifier la carte',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.cSub)),
      ])),
    ]);
  }
}
