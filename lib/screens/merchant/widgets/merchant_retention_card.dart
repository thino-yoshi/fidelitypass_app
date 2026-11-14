import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../logic/merchant_stats_logic.dart';
import '../../../config/app_colors.dart';

class MerchantRetentionCard extends StatelessWidget {
  final List<dynamic> scanHistory;
  final String retPeriod;
  final void Function(String) onPeriodChanged;

  const MerchantRetentionCard({
    super.key,
    required this.scanHistory,
    required this.retPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r       = computeRetention(scanHistory, retPeriod);
    final prevPct = computeRetentionPrev(scanHistory, retPeriod);
    final delta   = r.pct - prevPct;
    final deltaStr = delta > 0 ? '+$delta%' : (delta < 0 ? '$delta%' : '= même');
    final isDark   = context.isDark;

    final bg     = isDark ? kNavyCard : const Color(0xFFEFF5FE);
    final border = isDark ? const Color(0xFF2A3D5A) : const Color(0xFFD6E6FB);
    final iconBg = isDark ? kPrimary.withValues(alpha: 0.25) : const Color(0xFFDBEAFB);

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.replay_rounded, color: kPrimary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Taux de retour',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.cText)),
            Text('Clients qui reviennent',
              style: TextStyle(fontSize: 9, color: context.cSub)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${r.pct}%',
              style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w800, color: kPrimary, height: 1)),
            Text('$deltaStr ${retPeriod == 'sem' ? "cette sem." : "ce mois"}',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: delta < 0 ? kError : kSuccess)),
          ]),
        ]),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Pill(value: 'sem',  label: 'Semaine', current: retPeriod, onTap: onPeriodChanged),
            _Pill(value: 'mois', label: 'Mois',    current: retPeriod, onTap: onPeriodChanged),
          ]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String value;
  final String label;
  final String current;
  final void Function(String) onTap;

  const _Pill({
    required this.value, required this.label,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: active ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 9.5, fontWeight: FontWeight.w700,
            color: active ? Colors.white : context.cSub)),
      ),
    );
  }
}
