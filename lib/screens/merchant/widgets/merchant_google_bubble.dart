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
}
