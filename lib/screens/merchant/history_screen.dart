import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF2C7BE5);
const _kGold    = Color(0xFFF59E0B);
const _kPurple  = Color(0xFF7C3AED);
const double _kMaxContentWidth = 500;

class HistoryScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const HistoryScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;
  String _filter = 'tout'; // 'tout' | 'tampons' | 'recompenses' | 'nouveaux'
  Set<String> _newScanIds = {}; // ids des scans = 1ʳᵉ apparition d'un client (≈ nouveau)

  int get _required => widget.merchantInfo?['stamps_required'] as int? ?? 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ApiService.instance.getMerchantScanHistory();
    if (!mounted) return;
    final h = r.isOk ? r.value : [];
    // Détecte les "nouveaux" : 1ʳᵉ apparition (scan le plus ancien) d'un client.
    final earliest = <String, dynamic>{}; // client_id → scan le plus ancien
    for (final s in h) {
      final cid = (s['client_id'] ?? '').toString();
      if (cid.isEmpty) continue;
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
      final prev = earliest[cid];
      final pt = prev != null ? DateTime.tryParse(prev['scanned_at'] as String? ?? '') : null;
      if (t != null && (pt == null || t.isBefore(pt))) earliest[cid] = s;
    }
    final ids = earliest.values
        .where((s) => ((s['stamps_count'] as int?) ?? 0) <= 1 && s['reward_reached'] != true)
        .map((s) => s['id'].toString())
        .toSet();
    setState(() { _history = h; _newScanIds = ids; _loading = false; });
  }

  bool _isNew(dynamic scan) => _newScanIds.contains(scan['id'].toString());

  // Groupe les scans filtrés par jour → [{label, items[]}]
  List<MapEntry<String, List<dynamic>>> _grouped() {
    final filtered = _history.where((s) {
      final reward = s['reward_reached'] == true;
      if (_filter == 'tampons') return !reward && !_isNew(s);
      if (_filter == 'recompenses') return reward;
      if (_filter == 'nouveaux') return _isNew(s);
      return true;
    }).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String bucket(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) return "Aujourd'hui";
      if (diff == 1) return 'Hier';
      if (diff == 2) return 'Avant-hier';
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    final map = <String, List<dynamic>>{};
    for (final s in filtered) {
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal();
      if (t == null) continue;
      map.putIfAbsent(bucket(t), () => []).add(s);
    }
    return map.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _filters(),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
              child: _list(),
            ))),
    ]);
  }

  Widget _filters() {
    Widget pill(String key, String label) {
      final active = _filter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = key),
          child: Container(
            height: 30, padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _kPrimary : context.cSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _kPrimary : context.cBorder),
            ),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : context.cSub)),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          pill('tout', 'Tout'),
          pill('tampons', 'Tampons'),
          pill('recompenses', 'Récompenses'),
          pill('nouveaux', 'Nouveaux'),
        ])),
      )),
    );
  }

  Widget _list() {
    final groups = _grouped();
    if (groups.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🕐', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 14),
        Text("Aucun scan pour l'instant", style: TextStyle(color: context.cText, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Les scans apparaîtront ici', style: TextStyle(color: context.cSub, fontSize: 13)),
      ]));
    }

    final children = <Widget>[];
    for (final g in groups) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
        child: Text(g.key.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.6)),
      ));
      children.addAll(g.value.map(_row));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _kPrimary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
        children: children,
      ),
    );
  }

  // Initiales 2 lettres (prénom + nom) à partir du nom complet.
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _row(dynamic scan) {
    final client = scan['client'] as Map? ?? {};
    final name   = (client['name'] ?? client['email'] ?? 'Client') as String;
    final stamps = (scan['stamps_count'] as int?) ?? 0;
    final reward = scan['reward_reached'] == true;
    final isNew  = !reward && _isNew(scan);
    final t = DateTime.tryParse(scan['scanned_at'] as String? ?? '')?.toLocal();
    final time = t != null ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}' : '';

    // Type → couleur d'accent + libellés.
    final Color accent = reward ? _kGold : (isNew ? _kPurple : _kPrimary);
    final Color tagBg  = reward ? const Color(0xFFFEF3C7) : (isNew ? const Color(0xFFF3E8FF) : const Color(0xFFE8F1FD));
    final Color tagFg  = reward ? const Color(0xFF92400E) : (isNew ? const Color(0xFF6B21A8) : _kPrimary);
    final String tag   = reward ? 'Récompense' : (isNew ? 'Nouveau' : '+1 tampon');
    final String sub    = reward
        ? 'Récompense débloquée'
        : (isNew ? '$stamps/$_required · Nouveau client' : '$stamps/$_required tampons');

    final avatarUrl = client['profile_picture_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(14),
        // Barre d'accent verticale à gauche.
        border: Border(
          left: BorderSide(color: accent, width: 3),
          top: BorderSide(color: context.cBorder),
          right: BorderSide(color: context.cBorder),
          bottom: BorderSide(color: context.cBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          // Avatar carré bleu avec initiales (photo si dispo).
          if (avatarUrl != null && avatarUrl.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(11),
                child: Image.network(avatarUrl, width: 36, height: 36, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initialsBox(name)))
          else
            _initialsBox(name),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText)),
            const SizedBox(height: 1),
            Text(sub, style: TextStyle(fontSize: 10.5, color: context.cSub)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
              child: Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tagFg)),
            ),
            const SizedBox(height: 4),
            Text(time, style: TextStyle(fontSize: 10, color: context.cSub)),
          ]),
        ]),
      ),
    );
  }

  Widget _initialsBox(String name) => Container(
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF4A9EF5), borderRadius: BorderRadius.circular(11)),
        child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      );
}
