import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Fond clair de l'espace client iOS avec un léger halo bleu ciel en haut
/// à droite (touche Qarta discrète).
class ClientGlowBackground extends StatelessWidget {
  const ClientGlowBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.isDark ? 0.14 : 0.20;
    return IgnorePointer(
      child: Stack(children: [
        Positioned.fill(child: ColoredBox(color: context.cBg)),
        Positioned(
          top: -170, right: -150,
          child: Container(
            width: 440, height: 440,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [kBlueLight.withValues(alpha: a), kBlueLight.withValues(alpha: 0)]),
            ),
          ),
        ),
        Positioned(
          top: -120, left: -110,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [kPrimary.withValues(alpha: 0.07), kPrimary.withValues(alpha: 0)]),
            ),
          ),
        ),
      ]),
    );
  }
}
