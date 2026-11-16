import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';

/// Historique iOS : bloc bleu nuit (chiffres du mois, centrés), sélecteur
/// Tout / Tampons / Récompenses, puis les passages groupés par jour
/// (listes façon Réglages).
class ClientHistoryIos extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> grouped; // jour → lignes
  final int monthVisits;
  final int monthRewards;
  final String filter; // 'all' | 'stamp' | 'reward'
  final ValueChanged<String> onFilter;
  final Future<void> Function() onRefresh;

  const ClientHistoryIos({
    super.key,
    required this.grouped,
    required this.monthVisits,
    required this.monthRewards,
    required this.filter,
    required this.onFilter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _hero(),
              const SizedBox(height: 18),
              _SegPill<String>(
                value: filter,
                onChanged: onFilter,
                children: const {
                  'all': Text('Tout'),
                  'stamp': Text('Tampons'),
                  'reward': Text('Récompenses'),
                },
              ),
              if (grouped.isEmpty) _empty(context),
              for (final e in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
                  child: Text(e.key.toUpperCase(), style: QText.label.copyWith(color: context.cSub)),
                ),
                Container(
                  decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    for (var i = 0; i < e.value.length; i++) _row(context, e.value[i], divider: i > 0),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ],
    ),
    );
  }

  // Bloc bleu nuit : les deux chiffres bien centrés chacun dans sa moitié.
  Widget _hero() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kNavy, kNavyCard]),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(child: _num('$monthVisits', monthVisits > 1 ? 'passages ce mois-ci' : 'passage ce mois-ci', Colors.white)),
          Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 6), color: Colors.white.withValues(alpha: 0.12)),
          Expanded(child: _num('$monthRewards', monthRewards > 1 ? 'récompenses' : 'récompense', kGold)),
        ]),
      ),
    );
  }

  Widget _num(String n, String label, Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(n, textAlign: TextAlign.center, style: QText.bigNumber.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: QText.label.copyWith(color: Colors.white.withValues(alpha: 0.62))),
        ],
      );

  Widget _row(BuildContext context, Map<String, dynamic> item, {required bool divider}) {
    final isReward = item['type'] == 'reward';
    final isPoints = item['isPoints'] as bool? ?? false;
    final delta = item['delta'] as int? ?? 1;
    // Rond aux couleurs de la carte du commerce ; or pour une récompense.
    final c = isReward ? kGold : (item['cardColor'] as Color? ?? kPrimary);
    return Column(children: [
      if (divider) Padding(padding: const EdgeInsets.only(left: 58), child: Container(height: 0.5, color: context.cBorder)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            child: Icon(isReward ? CupertinoIcons.gift : CupertinoIcons.checkmark_alt, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] as String, style: QText.body.copyWith(fontSize: 17, color: context.cText)),
              Text('${item['time']} · ${item['info']}', style: QText.caption.copyWith(color: context.cSub)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: (isReward ? kGold : kPrimary).withValues(alpha: isReward ? 0.16 : 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(
              isReward ? 'Récompense' : (isPoints ? '+$delta pts' : '+1'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isReward ? const Color(0xFFB26E00) : kPrimary),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(children: [
          Icon(CupertinoIcons.clock, size: 40, color: context.cSub),
          const SizedBox(height: 12),
          Text('Aucune activité', style: QText.blockTitle.copyWith(color: context.cText)),
          const SizedBox(height: 4),
          Text('Tes passages apparaîtront ici après ton premier scan.',
              textAlign: TextAlign.center, style: QText.caption.copyWith(color: context.cSub)),
        ]),
      );
}

class _SegPill<T> extends StatelessWidget {
  final T value;
  final Map<T, Widget> children;
  final ValueChanged<T> onChanged;
  const _SegPill({required this.value, required this.children, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        for (final e in children.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: e.key == value
                    ? (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: e.key == value
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))]
                    : [],
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.cText),
                  child: Center(child: e.value),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
