import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../logic/merchant_stats_logic.dart';
import '../../../utils/platform_route.dart';
import '../../../config/app_colors.dart';
import '../stats_screen.dart';

class MerchantGraphCardIos extends StatelessWidget {
  final List<dynamic> daily;
  final String graphRange;
  final void Function(String) onRangeChanged;
  final String token;
  final Map? merchantInfo;
  final Map? stats;
  final List<dynamic> scanHistory;
  final List<dynamic> recentClients;

  const MerchantGraphCardIos({
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

    final isDark     = context.isDark;
    final cardBg     = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final cardBorder = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E5);
    final titleColor = isDark ? Colors.white : const Color(0xFF000000);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Fréquence des clients',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor))),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _openStats(context),
            child: const Text('Voir stats',
              style: TextStyle(fontSize: 12, color: kPrimary))),
        ]),
        const SizedBox(height: 8),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: graphRange,
          onValueChanged: (v) { if (v != null) onRangeChanged(v); },
          thumbColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE9E9EE),
          children: const {
            '7j':  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Text('7 jours',  style: TextStyle(fontSize: 12))),
            '30j': Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Text('Mois',     style: TextStyle(fontSize: 12))),
          },
        ),
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
