// ─────────────────────────────────────────────────────────────────────────────
// MerchantStatList — liste des chiffres de la période (style Apple, accueil iOS)
//
//   👥 Clients venus            2
//   🎁 Récompenses données       0
//   ⊕  Nouveaux clients          1
//   ↺  Taux de retour          0 %
//
// Fichier autonome : il n'utilise que lib/config/app_colors.dart (déjà dans le
// projet) et le paquet cupertino_icons (à ajouter dans pubspec.yaml :
// `cupertino_icons: ^1.0.8`, sinon les icônes s'affichent en « ? »).
//
// Utilisation :
//   MerchantStatList(rows: [
//     MerchantStatRow(icon: CupertinoIcons.person_2, label: 'Clients venus', value: '2'),
//     MerchantStatRow(icon: CupertinoIcons.gift, label: 'Récompenses données', value: '0'),
//     MerchantStatRow(icon: CupertinoIcons.plus_circle, label: 'Nouveaux clients', value: '1'),
//     MerchantStatRow(icon: CupertinoIcons.arrow_counterclockwise, label: 'Taux de retour', value: '0 %'),
//   ])
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_colors.dart';

/// Une ligne de la liste : icône bleue, libellé à gauche, valeur à droite.
class MerchantStatRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor; // facultatif (ex. kGold pour « Proches du cadeau »)
  final VoidCallback? onTap; // facultatif : rend la ligne cliquable

  const MerchantStatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });
}

/// Bloc blanc arrondi avec des lignes séparées par un trait fin
/// (comme les Réglages de l'iPhone). Couleurs Qarta, mode sombre compris.
class MerchantStatList extends StatelessWidget {
  final List<MerchantStatRow> rows;
  const MerchantStatList({super.key, required this.rows});

  // Mesures validées (iPhone) : texte 16, ligne de 18 en haut et en bas.
  static const double _fontSize = 16;
  static const double _letterSpacing = -0.3;
  static const double _rowPaddingV = 18;
  static const double _rowPaddingH = 14;
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final radius = Theme.of(context).platform == TargetPlatform.iOS ? 14.0 : 16.0;
    final textStyle = GoogleFonts.inter(
      fontSize: _fontSize,
      letterSpacing: _letterSpacing,
      color: context.cText,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: context.cBorder),
          InkWell(
            onTap: rows[i].onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _rowPaddingH, vertical: _rowPaddingV),
              child: Row(children: [
                Icon(rows[i].icon, size: _iconSize, color: kPrimary),
                const SizedBox(width: 10),
                Expanded(child: Text(rows[i].label, style: textStyle)),
                Text(
                  rows[i].value,
                  style: textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: rows[i].valueColor ?? context.cText,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
