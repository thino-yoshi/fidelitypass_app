import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';

const _kPrimary = Color(0xFF2C7BE5);
const _kGold    = Color(0xFFF59E0B);

class HistoryTab extends StatefulWidget {
  final String token;
  const HistoryTab({super.key, required this.token});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;
  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;

  List<dynamic> _history = [];
  bool          _loading = true;
  String        _filter  = 'all'; // 'all' | 'stamp' | 'reward'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/my-history'),
        headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? widget.token}'},
      );
      if (mounted && res.statusCode == 200) {
        setState(() { _history = jsonDecode(res.body); _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Convert API data to flat list of items sorted by date
  List<Map<String, dynamic>> _flatItems() {
    final items = <Map<String, dynamic>>[];
    for (final scan in _history) {
      final isReward  = scan['reward_reached'] == true;
      final type      = isReward ? 'reward' : 'stamp';
      final name      = scan['merchant']?['business_name'] as String? ?? 'Commerce';
      final stamps    = scan['stamps_count'] as int? ?? 0;
      final dt        = DateTime.tryParse(scan['scanned_at'] as String? ?? '')?.toLocal();
      final time      = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '';

      // Day label
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      String day  = 'Autre';
      if (dt != null) {
        final itemDay = DateTime(dt.year, dt.month, dt.day);
        final diff    = today.difference(itemDay).inDays;
        if (diff == 0)      day = "Aujourd'hui";
        else if (diff == 1) day = 'Hier';
        else                day = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
      }

      items.add({
        'type':  type,
        'name':  name,
        'time':  time,
        'info':  isReward ? 'Récompense débloquée' : '$stamps tampons',
        'color': isReward ? _kGold : _kPrimary,
        'day':   day,
        'dt':    dt,
      });
    }
    return items;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    if (_filter == 'all')    return all;
    if (_filter == 'stamp')  return all.where((i) => i['type'] == 'stamp').toList();
    if (_filter == 'reward') return all.where((i) => i['type'] == 'reward').toList();
    return all;
  }

  // Group items by day label (preserving order)
  Map<String, List<Map<String, dynamic>>> _byDay(List<Map<String, dynamic>> items) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final day = item['day'] as String;
      map.putIfAbsent(day, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final allItems      = _flatItems();
    final filteredItems = _filtered(allItems);
    final grouped       = _byDay(filteredItems);

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: _kPrimary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 96 + MediaQuery.of(context).padding.bottom),
        children: [

          // ── Filter chips (Figma: Tout | Tampons | Récompenses) ─────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('all',    'Tout'),
                const SizedBox(width: 6),
                _chip('stamp',  'Tampons'),
                const SizedBox(width: 6),
                _chip('reward', 'Récompenses'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Empty state ────────────────────────────────────────────────────
          if (filteredItems.isEmpty) ...[
            const SizedBox(height: 60),
            Center(child: Column(children: [
              const Text('🕐', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text('Aucune activité', style: TextStyle(
                color: _kText, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Tes visites apparaîtront ici après ton premier scan.',
                style: TextStyle(color: _kSub, fontSize: 13), textAlign: TextAlign.center),
            ])),
          ],

          // ── Grouped by day ─────────────────────────────────────────────────
          for (final entry in grouped.entries) ...[
            // Day label
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 5),
              child: Text(entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kSub, letterSpacing: 0.06,
                )),
            ),
            // Items
            ...entry.value.map((item) => _historyItem(item)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String key, String label) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _kPrimary : _kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kPrimary : _kBorder),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: active ? Colors.white : _kSub,
        )),
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> item) {
    final color    = item['color'] as Color;
    final isReward = item['type'] == 'reward';

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: _kWhite,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        // Colored dot
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        // Name + info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['name'] as String,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 1),
          Text('${item['time']} · ${item['info']}',
            style: TextStyle(fontSize: 11, color: _kSub)),
        ])),
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isReward
                ? const Color(0xFFFEF3C7) // gold bg
                : const Color(0xFFE8F1FD), // blue bg
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            isReward ? 'Récompense' : '+1 tampon',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: isReward ? const Color(0xFF92400E) : _kPrimary,
            ),
          ),
        ),
      ]),
    );
  }
}
