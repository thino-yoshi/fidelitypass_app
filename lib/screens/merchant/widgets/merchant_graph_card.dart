import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../logic/merchant_stats_logic.dart';
import '../../../utils/platform_route.dart';
import '../../../config/app_colors.dart';
import '../stats_screen.dart';

class MerchantGraphCard extends StatelessWidget {
  final List<dynamic> daily;
  final String graphRange;
  final void Function(String) onRangeChanged;
  final String token;
  final Map? merchantInfo;
  final Map? stats;
  final List<dynamic> scanHistory;
  final List<dynamic> recentClients;

  const MerchantGraphCard({
    super.key,
    required this.daily,
    required this.graphRange,
    required this.onRangeChanged,
    required this.token,
    required this.merchantInfo,
    required this.stats,
    required this.scanHistory,
    required this.recentClients,
  });

  void _openStats(BuildContext context) {
    Navigator.push(context, platformRoute(
      builder: (_) => StatsScreen(
        token: token,
        merchantInfo: merchantInfo,
        initialStats:   stats,
        initialDaily:   daily,
        initialHistory: scanHistory,
        initialClients: recentClients,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final groups  = buildGraphGroups(daily, graphRange);
    final maxV    = groups.fold<double>(
        1, (m, g) => (g['stamps'] as int) > m ? (g['stamps'] as int).toDouble() : m);
    final headroom = maxV * 1.28;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Fréquence des clients',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText))),
          GestureDetector(
            onTap: () => _openStats(context),
            child: const Text('Voir stats →',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimary))),
          const SizedBox(width: 8),
          _RangeBtn(value: '7j',  label: '7j',   current: graphRange, onTap: onRangeChanged),
          const SizedBox(width: 4),
          _RangeBtn(value: '30j', label: 'Mois', current: graphRange, onTap: onRangeChanged),
        ]),
        const SizedBox(height: 14),
        _buildBars(context, groups, headroom),
        const SizedBox(height: 8),
        Row(children: [
          _Legend(color: kPrimary,  label: 'Clients'),
          const SizedBox(width: 14),
          _Legend(color: kSuccess, label: 'Récompenses'),
        ]),
      ]),
    );
  }

  Widget _buildBars(BuildContext context,
      List<Map<String, dynamic>> groups, double headroom) {
    return SizedBox(
      height: 88,
      child: groups.isEmpty
          ? Center(child: Text('Pas encore de données',
              style: TextStyle(fontSize: 11, color: context.cSub)))
          : Row(
              children: groups.map((g) {
                final s = g['stamps']  as int;
                final r = g['rewards'] as int;
                return Expanded(
                  child: Column(children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Bar(value: s, maxV: headroom, color: kPrimary,  isNarrow: graphRange == '7j'),
                          if (r > 0) ...[
                            const SizedBox(width: 3),
                            _Bar(value: r, maxV: headroom, color: kSuccess, isNarrow: graphRange == '7j'),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(g['label'] as String,
                      style: TextStyle(fontSize: 8, color: context.cSub)),
                  ]),
                );
              }).toList(),
            ),
    );
  }
}

class _RangeBtn extends StatelessWidget {
  final String value;
  final String label;
  final String current;
  final void Function(String) onTap;

  const _RangeBtn({
    required this.value, required this.label,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kPrimary : context.cBorder),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: active ? Colors.white : context.cSub)),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int value;
  final double maxV;
  final Color color;
  final bool isNarrow;

  const _Bar({
    required this.value, required this.maxV,
    required this.color, required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final h = maxV > 0
        ? (value / maxV * 60).clamp(value > 0 ? 4.0 : 2.0, 60.0)
        : 2.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Container(
          width: isNarrow ? 9.0 : 16.0, height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 9, color: context.cSub)),
    ]);
  }
}
