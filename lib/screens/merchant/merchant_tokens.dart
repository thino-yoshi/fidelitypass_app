// Les constantes de couleur (kPrimary, kNavy, kNavyCard, etc.) viennent de app_colors.dart.
// Ce fichier n'exporte que les tokens spécifiques aux widgets marchands.
export 'package:fidelitypass_app/config/app_colors.dart'
    show kPrimary, kBlueLight, kNavy, kNavyCard, kError, kGold, kSuccess, kPurple;

const double kMaxContentWidth = 500;

const Map<String, Map<String, dynamic>> kCategoryStyles = {
  'Café':        {'emoji': '☕', 'color': Color(0xFF2C7BE5)},
  'Boulangerie': {'emoji': '🥐', 'color': Color(0xFFD4A017)},
  'Restaurant':  {'emoji': '🍽',  'color': Color(0xFFC0392B)},
  'Healthy':     {'emoji': '🥗', 'color': Color(0xFF27AE60)},
  'Librairie':   {'emoji': '📚', 'color': Color(0xFF8E44AD)},
  'Coiffeur':    {'emoji': '✂',  'color': Color(0xFF2980B9)},
};
