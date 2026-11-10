import 'package:flutter/cupertino.dart';
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

    if (kIsIOS) return _buildIOS(context, r, delta, deltaStr, isDark);
    return _buildMaterial(context, r, delta, deltaStr, isDark);
  }

  // ─── Android ────────────────────────────────────────────────────────────────
  Widget _buildMaterial(BuildContext context,
      ({int pct, int returning, int total}) r,
      int delta, String deltaStr, bool isDark) {
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

  // ─── iOS : fond gris clair, CupertinoSlidingSegmentedControl ────────────────
  Widget _buildIOS(BuildContext context,
      ({int pct, int returning, int total}) r,
      int delta, String deltaStr, bool isDark) {
    final cardBg     = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final cardBorder = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E5);
    final iconBg     = kPrimary.withValues(alpha: 0.14);
    final titleColor = isDark ? Colors.white : const Color(0xFF000000);
    final subColor   = const Color(0xFF8E8E93);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(CupertinoIcons.arrow_counterclockwise, color: kPrimary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Taux de retour',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor)),
            Text('Clients qui reviennent', style: TextStyle(fontSize: 11, color: subColor)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${r.pct}%',
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: kPrimary, height: 1,
                fontFamily: '.SF Pro Display')),
            Text('$deltaStr ${retPeriod == 'sem' ? "cette sem." : "ce mois"}',
              style: TextStyle(
                fontSize: 10,
                color: delta < 0 ? kError : kSuccess)),
          ]),
        ]),
        const SizedBox(height: 10),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: retPeriod,
          onValueChanged: (v) { if (v != null) onPeriodChanged(v); },
          thumbColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE9E9EE),
          children: const {
            'sem':  Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('Semaine', style: TextStyle(fontSize: 12))),
            'mois': Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('Mois',    style: TextStyle(fontSize: 12))),
          },
        ),
      ]),
    );
  }
}

// ─── Android uniquement ───────────────────────────────────────────────────────
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
