/// Fonctions pures de calcul stats — aucune dépendance Flutter/UI.

/// Agrège les KPIs (scans + rewards) selon la période choisie.
Map<String, int?> computePeriodAgg(List<dynamic> daily, String period) {
  if (daily.isEmpty) {
    return {'scans': 0, 'rewards': 0, 'scansDelta': null, 'rewardsDelta': null};
  }
  int sumScans(List<dynamic> l)   => l.fold(0, (s, d) => s + ((d['scans']   as int?) ?? 0));
  int sumRewards(List<dynamic> l) => l.fold(0, (s, d) => s + ((d['rewards'] as int?) ?? 0));

  if (period == 'today') {
    final today = daily.last;
    final yest  = daily.length >= 2 ? daily[daily.length - 2] : null;
    final s = (today['scans']   as int?) ?? 0;
    final r = (today['rewards'] as int?) ?? 0;
    return {
      'scans': s, 'rewards': r,
      'scansDelta':   yest != null ? s - ((yest['scans']   as int?) ?? 0) : null,
      'rewardsDelta': yest != null ? r - ((yest['rewards'] as int?) ?? 0) : null,
    };
  }
  final n    = period == '7j' ? 7 : 30;
  final cur  = daily.length >= n ? daily.sublist(daily.length - n) : daily;
  final prev = daily.length >= n * 2
      ? daily.sublist(daily.length - n * 2, daily.length - n)
      : null;
  return {
    'scans': sumScans(cur), 'rewards': sumRewards(cur),
    'scansDelta':   prev != null ? sumScans(cur)   - sumScans(prev)   : null,
    'rewardsDelta': prev != null ? sumRewards(cur) - sumRewards(prev) : null,
  };
}

/// Taux de retour estimé sur la période courante.
({int pct, int returning, int total}) computeRetention(
    List<dynamic> scanHistory, String period) {
  final cutoff = DateTime.now().subtract(Duration(days: period == 'sem' ? 7 : 30));
  final counts = <String, int>{};
  for (final s in scanHistory) {
    final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
    if (t == null || t.isBefore(cutoff)) continue;
    final cid = (s['client_id'] ?? '').toString();
    if (cid.isEmpty) continue;
    counts[cid] = (counts[cid] ?? 0) + 1;
  }
  final total     = counts.length;
  final returning = counts.values.where((c) => c >= 2).length;
  final pct       = total > 0 ? (returning / total * 100).round() : 0;
  return (pct: pct, returning: returning, total: total);
}

/// Taux de retour de la période précédente (pour calculer le delta).
int computeRetentionPrev(List<dynamic> scanHistory, String period) {
  final days = period == 'sem' ? 7 : 30;
  final now  = DateTime.now();
  final from = now.subtract(Duration(days: days * 2));
  final to   = now.subtract(Duration(days: days));
  final counts = <String, int>{};
  for (final s in scanHistory) {
    final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
    if (t == null || t.isBefore(from) || !t.isBefore(to)) continue;
    final cid = (s['client_id'] ?? '').toString();
    if (cid.isEmpty) continue;
    counts[cid] = (counts[cid] ?? 0) + 1;
  }
  if (counts.isEmpty) return 0;
  final returning = counts.values.where((c) => c >= 2).length;
  return (returning / counts.length * 100).round();
}

/// Construit les groupes de données pour le graphique barres.
List<Map<String, dynamic>> buildGraphGroups(
    List<dynamic> daily, String graphRange) {
  if (daily.isEmpty) return [];
  const wd = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  if (graphRange == '7j') {
    final days = daily.length >= 7 ? daily.sublist(daily.length - 7) : daily;
    return days.map((d) {
      final date = DateTime.tryParse(d['date'] as String? ?? '');
      return {
        'label':   date != null ? wd[(date.weekday - 1).clamp(0, 6)] : '',
        'stamps':  (d['scans']   as int?) ?? 0,
        'rewards': (d['rewards'] as int?) ?? 0,
      };
    }).toList();
  }

  // 30j → 4 semaines agrégées sur les 28 derniers jours
  final last28  = daily.length >= 28 ? daily.sublist(daily.length - 28) : daily;
  final perWeek = (last28.length / 4).ceil().clamp(1, last28.length);
  final groups  = <Map<String, dynamic>>[];
  for (int w = 0; w < 4; w++) {
    final start = w * perWeek;
    if (start >= last28.length) break;
    final end   = (start + perWeek).clamp(0, last28.length);
    final slice = last28.sublist(start, end);
    groups.add({
      'label':   'S${w + 1}',
      'stamps':  slice.fold<int>(0, (a, d) => a + ((d['scans']   as int?) ?? 0)),
      'rewards': slice.fold<int>(0, (a, d) => a + ((d['rewards'] as int?) ?? 0)),
    });
  }
  return groups;
}
