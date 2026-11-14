import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/logger.dart';
import 'widgets/client_history_ios.dart';
import 'cards_tab.dart' show CardStyle;

const _kPrimary = Color(0xFF2C7BE5);
const _kGold    = Color(0xFFF59E0B);

class HistoryTab extends StatefulWidget {
  final String token;
  final List<dynamic> history;
  final Future<void> Function() onRefresh;
  final List<dynamic> cards;
  const HistoryTab({super.key, required this.token, required this.history, required this.onRefresh, this.cards = const []});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _filter = 'all';

  static const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  static const _mois  = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                          'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

  Color? _cardColor(String? merchantId) {
    if (merchantId == null) return null;
    for (final c in widget.cards) {
      if (c['merchant_id'] == merchantId || c['merchants']?['id'] == merchantId) {
        return CardStyle.fromDesign(c['card_design'], fallbackColor: _kPrimary).primary;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _flatItems() {
    final items = <Map<String, dynamic>>[];
    for (final scan in widget.history) {
      final isReward = scan['reward_reached'] == true;
      final type     = isReward ? 'reward' : 'stamp';
      final name     = scan['merchant']?['business_name'] as String? ?? 'Commerce';
      final isPoints = (scan['merchant']?['program_type'] as String?) == 'points';
      final stamps   = scan['stamps_count'] as int? ?? 0;
      final delta    = (scan['delta'] as int?) ?? (isPoints ? stamps : 1);
      final dt       = DateTime.tryParse(scan['scanned_at'] as String? ?? '')?.toLocal();
      final time     = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '';

      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      String day  = 'Autre';
      if (dt != null) {
        final itemDay = DateTime(dt.year, dt.month, dt.day);
        final diff    = today.difference(itemDay).inDays;
        if (diff == 0)      day = "Aujourd'hui";
        else if (diff == 1) day = 'Hier';
        else                day = '${_jours[dt.weekday - 1]} ${dt.day} ${_mois[dt.month - 1]}';
      }

      items.add({
        'type':      type,
        'name':      name,
        'time':      time,
        'info':      isReward
            ? 'Carte complète'
            : (isPoints
                ? '$stamps/${scan['merchant']?['points_required'] ?? 100} pts'
                : '$stamps/${scan['merchant']?['stamps_required'] ?? 10} tampons'),
        'cardColor': _cardColor(scan['merchant']?['id'] as String?),
        'isPoints':  isPoints,
        'delta':     delta,
        'color':     isReward ? _kGold : _kPrimary,
        'day':       day,
        'dt':        dt,
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

  Map<String, List<Map<String, dynamic>>> _byDay(List<Map<String, dynamic>> items) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      map.putIfAbsent(item['day'] as String, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final allItems      = _flatItems();
    final filteredItems = _filtered(allItems);
    final grouped       = _byDay(filteredItems);
    final now = DateTime.now();
    bool thisMonth(Map i) {
      final d = i['dt'] as DateTime?;
      return d != null && d.year == now.year && d.month == now.month;
    }
    // ── DESIGN ANDROID À IMPLÉMENTER ─────────────────────────────────────────
    // ignore: dead_code
    if (true) return const SizedBox.expand();
    // ── Ancien design (iOS historique) — gardé pour référence ─────────────
    // ignore: dead_code
    return ClientHistoryIos(
      grouped:      grouped,
      monthVisits:  allItems.where((i) => i['type'] == 'stamp'  && thisMonth(i)).length,
      monthRewards: allItems.where((i) => i['type'] == 'reward' && thisMonth(i)).length,
      filter:       _filter,
      onFilter:     (k) { AppLogger.client('HistoryTab → filtre: $k'); setState(() => _filter = k); },
      onRefresh:    widget.onRefresh,
    );
  }
}
