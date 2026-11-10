import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../utils/platform_route.dart';
import '../../../config/app_colors.dart';
import '../google_auto_screen.dart';

class MerchantGoogleBubble extends StatelessWidget {
  final String token;
  final Map merchantInfo;

  const MerchantGoogleBubble({
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
    if (Platform.isIOS) return _buildIOS(context);
    return _buildMaterial(context);
  }

  // ─── Android : gradient sombre ──────────────────────────────────────────────
  Widget _buildMaterial(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A3A6B), Color(0xFF0F2044)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBlueLight.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Image.asset('assets/images/google_icon.png', width: 18, height: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Demander un avis Google',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
            child: const Text('+5 pts offerts',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFFBBF24))),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.5), size: 16),
        ]),
      ),
    );
  }

  // ─── iOS : carte blanche claire style HIG ───────────────────────────────────
  Widget _buildIOS(BuildContext context) {
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
