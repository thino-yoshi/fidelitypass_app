/// Horaires d'un commerce, tels que le commerçant les enregistre :
///   opening_days  = « Lun,Mar,Mer,Jeu,Ven,Sam »
///   opening_hours = « 08:00-20:00 » (ou « 08:00 » ouverture seule, « -20:00 » fermeture seule)
/// Les mêmes heures valent pour tous les jours ouverts.
class MerchantHours {
  static const keys = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  static const names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  static const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

  final Set<String> days;
  final String? open;  // « 08:00 »
  final String? close; // « 20:00 »

  MerchantHours._(this.days, this.open, this.close);

  factory MerchantHours.fromMerchant(Map? m) {
    final d = (m?['opening_days'] ?? '').toString();
    final h = (m?['opening_hours'] ?? '').toString().trim();
    final days = d.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    String? o, c;
    if (h.isNotEmpty) {
      final i = h.indexOf('-', 1);
      if (i > 0) {
        o = h.substring(0, i).trim();
        c = h.substring(i + 1).trim();
      } else if (h.startsWith('-')) {
        c = h.substring(1).trim();
      } else {
        o = h;
      }
    }
    return MerchantHours._(days, (o ?? '').isEmpty ? null : o, (c ?? '').isEmpty ? null : c);
  }

  bool get isEmpty => days.isEmpty && open == null && close == null;

  static int _min(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  /// « 08:00 – 20:00 », « Dès 08:00 », « Jusqu'à 20:00 »
  String get range {
    if (open != null && close != null) return '$open – $close';
    if (open != null) return 'Dès $open';
    if (close != null) return 'Jusqu\'à $close';
    return '';
  }

  bool openOn(int weekday) => days.isEmpty || days.contains(keys[weekday - 1]);

  /// « Jeudi 12 novembre »
  static String todayLabel([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${names[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  /// État maintenant : (ouvert ?, texte). Ex. « Ouvert · ferme à 20:00 ».
  (bool, String) statusNow([DateTime? now]) {
    final d = now ?? DateTime.now();
    if (!openOn(d.weekday)) return (false, 'Fermé aujourd\'hui');
    final m = d.hour * 60 + d.minute;
    if (open != null && m < _min(open!)) return (false, 'Fermé · ouvre à $open');
    if (close != null && m >= _min(close!)) return (false, 'Fermé · a fermé à $close');
    if (close != null) return (true, 'Ouvert · ferme à $close');
    return (true, 'Ouvert aujourd\'hui');
  }
}
