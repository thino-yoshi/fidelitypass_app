import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../config/app_colors.dart';

class MerchantKpiGridIos extends StatelessWidget {
  final Map<String, int?> agg;
  final String period;
  final bool isPoints;

  const MerchantKpiGridIos({
    super.key,
    required this.agg,
    required this.period,
    required this.isPoints,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _KpiCardIos(
          value: '0',
          label: "Clients ${period == 'today' ? "aujourd'hui" : 'actifs'}",
          delta: null,
          period: period,
        ),
        const SizedBox(width: 8),
        _KpiCardIos(
          value: '${agg['scans'] ?? 0}',
          label: isPoints ? 'Points ajoutés' : 'Tampons ajoutés',
          delta: agg['scansDelta'],
          period: period,
        ),
        const SizedBox(width: 8),
        _KpiCardIos(
          value: '0',
          label: 'Nouveaux clients',
          delta: null,
          period: period,
        ),
      ]),
    );
  }
}

class _KpiCardIos extends StatelessWidget {
  final String value;
  final String label;
  final int? delta;
  final String period;

  const _KpiCardIos({
    required this.value, required this.label, required this.delta,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    Widget? deltaChip;
    if (delta != null) {
      final ref  = period == 'today' ? 'hier' : 'préc.';
      final up   = delta! > 0;
      final flat = delta == 0;
      final c    = flat ? context.cSub : (up ? kSuccess : kError);
      final bg   = flat
          ? context.cBg
          : (up ? const Color(0xFFE4F5EB) : const Color(0xFFFDE8E7));
      deltaChip = Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(flat ? "= même qu'$ref" : '${up ? "↑ +" : "↓ "}$delta vs $ref',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
      );
    }

    final isDark     = context.isDark;
    final cardBg     = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final cardBorder = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E5);
    final lblColor   = const Color(0xFF8E8E93);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
            style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w700,
              color: kPrimary, height: 1,
              fontFamily: '.SF Pro Display')),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9.5, color: lblColor)),
          if (deltaChip != null) deltaChip,
        ]),
      ),
    );
  }
}
