import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../utils/platform_route.dart';
import '../../../config/app_colors.dart';
import '../google_auto_screen.dart';

class MerchantGoogleBubbleIos extends StatelessWidget {
  final String token;
  final Map merchantInfo;

  const MerchantGoogleBubbleIos({
    super.key,
    required this.token,
    required this.merchantInfo,
  });

  void _navigate(BuildContext context) {
    Navigator.push(context, platformRoute(
      builder: (_) => GoogleAutoScreen(token: token, merchantInfo: merchantInfo)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = context.isDark;
    final cardBg     = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E5);
    final titleColor = isDark ? Colors.white : const Color(0xFF000000);

    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Image.asset('assets/images/google_icon.png'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Demander un avis Google',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor)),
            const Text('+5 pts offerts · Envoi automatique',
              style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
          ])),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
        ]),
      ),
    );
  }
}
