import 'package:flutter/material.dart';

/// Échelle de texte Qarta (style Apple). Ne plus écrire fontSize à la main.
class QText {
  static TextStyle largeTitle(BuildContext context) => TextStyle(
        fontSize: Theme.of(context).platform == TargetPlatform.iOS ? 32 : 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
      );
  // Espacement des lettres = celui d'Apple pour chaque taille (SF Pro).
  // Tailles agrandies d'environ 15 % pour retrouver les proportions des échantillons
  // (dessinés sur un écran plus étroit qu'un vrai iPhone).
  static const bigNumber  = TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1, letterSpacing: -0.7);
  static const number     = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const blockTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4);
  static const body       = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: -0.3);
  static const caption    = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.2);
  static const label      = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.08);
}

/// Espacements et arrondis communs.
class QSpace {
  static const side   = 14.0; // marge gauche/droite de l'écran
  static const gap    = 18.0; // espace entre deux blocs
  static const pad    = 14.0; // marge intérieure d'un bloc
  static double radius(BuildContext c) =>
      Theme.of(c).platform == TargetPlatform.iOS ? 14 : 16; // arrondi des blocs
  static const radiusHero = 18.0; // arrondi du bloc bleu nuit
}
