import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF0B1220);
const _kPrimary = Color(0xFF2C7BE5);
const _kGold    = Color(0xFFF59E0B);
const _kSuccess = Color(0xFF27AE60);
const _kError   = Color(0xFFE24B4A);

enum _InboxType { reward, newClient, weekly, stamp, inactive }

class _InboxItem {
  final _InboxType type;
  final String title;
  final String subtitle;
  final DateTime time;
  final String? cta;
  const _InboxItem({required this.type, required this.title, required this.subtitle, required this.time, this.cta});
}

class MerchantInboxScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const MerchantInboxScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<MerchantInboxScreen> createState() => _MerchantInboxScreenState();
}

class _MerchantInboxScreenState extends State<MerchantInboxScreen> {
  final Set<int> _read = {};

  // Mock data — à remplacer par un endpoint API quand disponible
  late final List<_InboxItem> _items = [
    _InboxItem(
      type: _InboxType.reward, cta: 'Notifier',
      title: 'Récompense débloquée',
      subtitle: 'Marie D. a débloqué sa récompense — 1 café offert.',
      time: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    _InboxItem(
      type: _InboxType.newClient, cta: 'Accueillir',
      title: 'Nouveau client',
      subtitle: 'Thomas B. vient de rejoindre votre programme de fidélité.',
      time: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    _InboxItem(
      type: _InboxType.inactive, cta: 'Relancer',
      title: 'Client inactif',
      subtitle: 'Lucie M. n\'est pas revenue depuis 14 jours.',
      time: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _InboxItem(
      type: _InboxType.stamp,
      title: 'Tampon ajouté',
      subtitle: 'Jean P. a reçu un tampon — 6/10.',
      time: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _InboxItem(
      type: _InboxType.weekly,
      title: 'Rapport hebdomadaire',
      subtitle: '12 nouveaux tampons · 2 récompenses · +3 clients cette semaine.',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 9)),
    ),
    _InboxItem(
      type: _InboxType.reward, cta: 'Notifier',
      title: 'Récompense débloquée',
      subtitle: 'Sophie R. a débloqué sa récompense — 1 café offert.',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
    ),
    _InboxItem(
      type: _InboxType.newClient, cta: 'Accueillir',
      title: 'Nouveau client',
      subtitle: 'Pierre L. vient de rejoindre votre programme de fidélité.',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 16)),
    ),
  ];

  List<_InboxItem> get _today => _items.where((i) {
    final now = DateTime.now();
    return i.time.year == now.year && i.time.month == now.month && i.time.day == now.day;
  }).toList();

  List<_InboxItem> get _yesterday => _items.where((i) {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return i.time.year == yest.year && i.time.month == yest.month && i.time.day == yest.day;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final yesterday = _yesterday;

    return Scaffold(
      backgroundColor: context.cBg,
      body: Column(children: [
        _header(),
        Expanded(child: today.isEmpty && yesterday.isEmpty
            ? _empty()
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.of(context).padding.bottom),
                children: [
                  if (today.isNotEmpty) ...[
                    _groupLabel('AUJOURD\'HUI'),
                    ...today.asMap().entries.map((e) => _itemTile(e.value, e.key)),
                  ],
                  if (yesterday.isNotEmpty) ...[
                    _groupLabel('HIER'),
                    ...yesterday.asMap().entries.map((e) => _itemTile(e.value, _items.length - yesterday.length + e.key)),
                  ],
                ],
              )),
      ]),
    );
  }

  Widget _header() => Container(
    color: _kNavy,
    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 12),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
            child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 22)),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Text('Activité', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
      GestureDetector(
        onTap: () => setState(() => _read.addAll(List.generate(_items.length, (i) => i))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: const Text('Tout lu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
        ),
      ),
    ]),
  );

  Widget _groupLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.8)),
  );

  Widget _itemTile(_InboxItem item, int idx) {
    final isRead = _read.contains(idx);
    final (icon, color, bgColor) = _iconForType(item.type);
    final timeStr = _relTime(item.time);

    return GestureDetector(
      onTap: () => setState(() => _read.add(idx)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? context.cSurface : context.cSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isRead ? context.cBorder : color.withValues(alpha: 0.35), width: isRead ? 1 : 1.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: color)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.title,
                  style: TextStyle(fontSize: 12.5, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, color: context.cText))),
              const SizedBox(width: 6),
              Text(timeStr, style: TextStyle(fontSize: 10, color: context.cSub)),
            ]),
            const SizedBox(height: 3),
            Text(item.subtitle, style: TextStyle(fontSize: 11.5, color: context.cSub, height: 1.4)),
            if (item.cta != null && !isRead) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _read.add(idx)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Text(item.cta!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ])),
          if (!isRead) ...[
            const SizedBox(width: 8),
            Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ],
        ]),
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.notifications_none_rounded, size: 52, color: context.cSub),
      const SizedBox(height: 12),
      Text('Aucune activité récente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.cText)),
      const SizedBox(height: 6),
      Text('Les événements apparaîtront ici.', style: TextStyle(fontSize: 13, color: context.cSub)),
    ]),
  );

  (IconData, Color, Color) _iconForType(_InboxType type) => switch (type) {
    _InboxType.reward    => (Icons.star_rounded,           _kGold,    _kGold.withValues(alpha: 0.12)),
    _InboxType.newClient => (Icons.person_add_rounded,     _kSuccess, _kSuccess.withValues(alpha: 0.1)),
    _InboxType.weekly    => (Icons.bar_chart_rounded,      _kPrimary, _kPrimary.withValues(alpha: 0.1)),
    _InboxType.stamp     => (Icons.local_offer_rounded,    _kPrimary, _kPrimary.withValues(alpha: 0.1)),
    _InboxType.inactive  => (Icons.access_time_rounded,    _kError,   _kError.withValues(alpha: 0.1)),
  };

  String _relTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'il y a ${diff.inHours}h';
    return 'hier';
  }
}
