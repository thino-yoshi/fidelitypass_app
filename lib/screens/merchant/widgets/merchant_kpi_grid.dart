import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class MerchantKpiGrid extends StatelessWidget {
  final Map<String, int?> agg;
  final String period;
  final bool isPoints;

  const MerchantKpiGrid({
    super.key,
    required this.agg,
    required this.period,
    required this.isPoints,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _KpiCard(
          value: '0',
          label: "Clients ${period == 'today' ? "aujourd'hui" : 'actifs'}",
          delta: null,
          period: period,
        ),
        const SizedBox(width: 8),
        _KpiCard(
          value: '${agg['scans'] ?? 0}',
          label: isPoints ? 'Points ajoutés' : 'Tampons ajoutés',
          delta: agg['scansDelta'],
          period: period,
        ),
        const SizedBox(width: 8),
        _KpiCard(
          value: '0',
          label: 'Nouveaux clients',
          delta: null,
          period: period,
        ),
      ]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final int? delta;
  final String period;

  const _KpiCard({
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

    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: kNavyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A3D5A)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
            style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800, color: kBlueLight, height: 1)),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.65))),
          if (deltaChip != null) deltaChip,
        ]),
      ),
    );
  }
}
