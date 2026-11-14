import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../config/app_colors.dart';
import '../../client/cards_tab.dart' show LoyaltyCardFace, CardStyle;

class MerchantCardPreviewIos extends StatelessWidget {
  final Map? cardDesign;
  final Map? merchantInfo;
  final VoidCallback onEditTap;

  const MerchantCardPreviewIos({
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

    final isDark     = context.isDark;
    final titleColor = isDark ? Colors.white : const Color(0xFF000000);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Ma carte fidélité',
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: titleColor, letterSpacing: -0.3)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onEditTap,
          child: const Text('Modifier',
            style: TextStyle(fontSize: 14, color: kPrimary))),
      ]),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: onEditTap,
        child: SizedBox(
          height: 220,
          child: LoyaltyCardFace(card: card, style: style, userName: 'Client'),
        ),
      ),
      const SizedBox(height: 8),
      Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(CupertinoIcons.pencil, size: 11, color: Color(0xFF8E8E93)),
        const SizedBox(width: 5),
        const Text('Appuyer pour modifier la carte',
          style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
      ])),
    ]);
  }
}
