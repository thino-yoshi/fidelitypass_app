import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';
import 'package:flutter/services.dart';
import '../cards_tab.dart' show CardStyle;
import 'client_sheets_ios.dart' show capFirst;

/// Onglet Récompenses iOS : un bloc bleu nuit par récompense prête
/// (bouton or « Utiliser ma récompense »), puis « Les plus proches »
/// avec un anneau de progression par carte.
class ClientRewardsIos extends StatelessWidget {
  final List<dynamic> rewards;
  final List<dynamic> cards;
  final void Function(String merchantName, Map reward) onUse;
  final void Function(Map card) onCardTap;
  final Future<void> Function() onRefresh;

  const ClientRewardsIos({
    super.key,
    required this.rewards,
    required this.cards,
    required this.onUse,
    required this.onCardTap,
    required this.onRefresh,
  });

  // Regroupe par commerce (la plus ancienne d'abord, déjà triée par le serveur).
  Map<String, List<dynamic>> get _byMerchant {
    final map = <String, List<dynamic>>{};
    for (final r in rewards) {
      map.putIfAbsent('${r['merchant_id']}', () => []).add(r);
    }
    // Dans chaque commerce : la plus ancienne d'abord (c'est elle qu'on utilise en premier).
    for (final l in map.values) {
      l.sort((a, b) => '${a['earned_at'] ?? ''}'.compareTo('${b['earned_at'] ?? ''}'));
    }
    return map;
  }

  static bool _isPoints(Map c) => (c['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
  static int _count(Map c) => _isPoints(c) ? (c['points_count'] as int? ?? 0) : (c['stamps_count'] as int? ?? 0);
  static int _goal(Map c) => _isPoints(c)
      ? (c['merchants']?['points_required'] as int? ?? 100)
      : (c['merchants']?['stamps_required'] as int? ?? 10);

  // Cartes pas encore pleines, les plus avancées d'abord (3 maximum).
  List<Map> get _closest {
    final list = cards.whereType<Map>().where((c) => _count(c) > 0 && _count(c) < _goal(c)).toList();
    list.sort((a, b) => (_count(b) / _goal(b)).compareTo(_count(a) / _goal(a)));
    return list.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _byMerchant;
    final closest = _closest;
    final bottomPad = MediaQuery.of(context).padding.bottom + 110;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, bottomPad),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (groups.isEmpty) _empty(context),
              if (groups.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text('PRÊTES À UTILISER', style: QText.label.copyWith(color: context.cSub)),
                ),
                const SizedBox(height: 12), // place pour la languette « ×2 » de la 1re carte
                for (var i = 0; i < groups.length; i++)
                  _stacked(context, groups.values.elementAt(i), first: i == 0, last: i == groups.length - 1),
              ],
              if (closest.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text('LES PLUS PROCHES', style: QText.label.copyWith(color: context.cSub)),
                ),
                Container(
                  decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    for (var i = 0; i < closest.length; i++) _row(context, closest[i], divider: i > 0),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  // Récompenses empilées comme les cartes : une par commerce, aux couleurs
  // du commerce. Plusieurs récompenses au même endroit → languette « ×2 ».
  static const double passHeight = 150;
  static const double peek = 64;

  Widget _stacked(BuildContext context, List<dynamic> list, {required bool first, required bool last}) {
    // La dernière carte rangée est courte (pas de grand vide sous son nom).
    final h = first ? passHeight : (last ? peek + 8 : passHeight);
    final pass = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context, list),
      child: SizedBox(height: h, child: RewardPassIos(rewards: list, collapsed: !first)),
    );
    if (first) return Padding(padding: EdgeInsets.only(bottom: last ? 0 : 8), child: pass);
    if (last) return pass;
    // Comme l'accueil : on ne garde que le bandeau (+ un peu caché sous la suivante).
    const keep = peek + 18;
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: peek / keep,
      child: ClipRect(child: Align(alignment: Alignment.topCenter, heightFactor: keep / passHeight, child: pass)),
    );
  }

  void _open(BuildContext context, List<dynamic> list) {
    HapticFeedback.selectionClick();
    final first = list.first as Map;
    final name = first['merchant_name'] as String? ?? (first['merchant'] as Map?)?['business_name'] as String? ?? 'Commerce';
    if (list.length == 1) {
      onUse(name, first);
      return;
    }
    showRewardGroupIos(context, rewards: list, merchantName: name, onUse: (r) => onUse(name, r));
  }

  Widget _empty(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: kGold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
            child: const Icon(CupertinoIcons.gift, color: kGold, size: 30),
          ),
          const SizedBox(height: 12),
          Text("Pas encore de récompense", style: QText.blockTitle.copyWith(color: context.cText)),
          const SizedBox(height: 4),
          Text('Complète une carte pour en débloquer une.',
              textAlign: TextAlign.center, style: QText.caption.copyWith(color: context.cSub)),
        ]),
      );

  Widget _row(BuildContext context, Map c, {required bool divider}) {
    final isPoints = _isPoints(c);
    final n = _count(c), goal = _goal(c);
    final left = goal - n;
    final reward = c['merchants']?['reward_description'] as String? ?? '';
    final name = c['merchants']?['business_name'] as String? ?? '';
    final sub = isPoints
        ? 'Plus que $left pts avant : $reward'
        : 'Plus que $left tampon${left > 1 ? 's' : ''} avant : $reward';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onCardTap(c),
      child: Column(children: [
        if (divider) Padding(padding: const EdgeInsets.only(left: 64), child: Container(height: 0.5, color: context.cBorder)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            SizedBox(width: 34, height: 34, child: CustomPaint(painter: _Ring(n / goal))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: QText.body.copyWith(fontSize: 17, color: context.cText)),
                Text(sub, style: QText.caption.copyWith(color: context.cSub)),
              ]),
            ),
            const SizedBox(width: 10),
            Text('$n/$goal', style: QText.body.copyWith(fontSize: 17, color: context.cSub)),
          ]),
        ),
      ]),
    );
  }
}

class _Ring extends CustomPainter {
  final double v;
  _Ring(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawArc(r, 0, 2 * pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = kPrimary.withValues(alpha: 0.12));
    canvas.drawArc(r, -pi / 2, 2 * pi * v.clamp(0, 1), false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = kPrimary);
  }

  @override
  bool shouldRepaint(_Ring old) => old.v != v;
}


String rewardTitle(Map r) {
  final m = (r['merchant'] as Map?) ?? const {};
  return capFirst((m['reward_description'] as String?) ?? (r['description'] as String?) ?? 'Récompense');
}

/// Carte « récompense » (fond = design du commerçant).
///  • entière : cadeau or, « RÉCOMPENSE PRÊTE », la récompense, le commerce
///  • rangée  : la récompense + le commerce sur une ligne
/// Languette or « ×N » en haut à droite s'il y en a plusieurs.
class RewardPassIos extends StatelessWidget {
  final List<dynamic> rewards;
  final bool collapsed;
  const RewardPassIos({super.key, required this.rewards, this.collapsed = false});

  @override
  Widget build(BuildContext context) {
    final r = rewards.first as Map;
    final m = (r['merchant'] as Map?) ?? const {};
    final name = r['merchant_name'] as String? ?? m['business_name'] as String? ?? '';
    final style = CardStyle.fromDesign(r['card_design'], merchantLogoUrl: m['logo_url'] as String?, fallbackColor: kNavyCard);
    final fg = style.textColor;
    final n = rewards.length;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: kNavy.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, -2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(fit: StackFit.expand, children: [
              style.buildBackground(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0)]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: collapsed ? _collapsed(fg, name, rewardTitle(r)) : _full(fg, name, rewardTitle(r)),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  // Carré or du cadeau. S'il y a plusieurs récompenses, le nombre est
  // écrit dans ce même carré (×2, ×3…).
  Widget _gift(double size) {
    final n = rewards.length;
    final box = BoxDecoration(
      color: kGold,
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
    );
    if (n <= 1) {
      return Container(
        width: size, height: size, decoration: box,
        child: Icon(CupertinoIcons.gift, color: Colors.white, size: size * 0.52),
      );
    }
    // Cadeau puis « ×2 » sur une ligne, comme sur les cartes rangées.
    final h = size >= 40 ? 40.0 : size;
    return Container(
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: box.copyWith(borderRadius: BorderRadius.circular(h * 0.3)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(CupertinoIcons.gift, color: Colors.white, size: h * 0.5),
        const SizedBox(width: 5),
        Text('×$n', style: TextStyle(color: Colors.white, fontSize: h >= 40 ? 15 : 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // Même place que sur la carte entière : texte à gauche, cadeau en haut à droite.
  Widget _collapsed(Color fg, String name, String title) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: title, style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              TextSpan(text: '  $name', style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 15, fontWeight: FontWeight.w500)),
            ]),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        _gift(30),
      ]);

  // Texte à gauche, cadeau centré verticalement sur la droite.
  Widget _full(Color fg, String name, String title) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RÉCOMPENSE PRÊTE',
                style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            Text('chez $name', style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 15)),
            const Spacer(),
            Row(children: [
              Text(rewards.length > 1 ? 'Touche pour choisir' : 'Touche pour l\'utiliser',
                  style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_forward, size: 15, color: fg.withValues(alpha: 0.85)),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        _gift(52),
      ]);
}

const _monthsFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// Plusieurs récompenses chez le même commerce : on les voit toutes,
/// on en utilise une (la plus ancienne en premier), les autres restent.
Future<void> showRewardGroupIos(
  BuildContext context, {
  required List<dynamic> rewards,
  required String merchantName,
  required void Function(Map reward) onUse,
}) {
  final title = rewardTitle(rewards.first as Map);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).padding.bottom;
      return Container(
        decoration: BoxDecoration(color: ctx.cBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 5, decoration: BoxDecoration(color: ctx.cSub.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(3)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 0, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: ctx.cText)),
                  Text('$merchantName · ${rewards.length} récompenses', style: QText.body.copyWith(fontSize: 17, color: ctx.cSub)),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF767680).withValues(alpha: 0.12)),
                  child: Icon(CupertinoIcons.xmark, color: ctx.cSub, size: 14),
                ),
              ),
            ]),
          ),
          Container(
            decoration: BoxDecoration(color: ctx.cSurface, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              for (var i = 0; i < rewards.length; i++) ...[
                if (i > 0) Padding(padding: const EdgeInsets.only(left: 62), child: Container(height: 0.5, color: ctx.cBorder)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(CupertinoIcons.gift, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: QText.body.copyWith(fontSize: 17, color: ctx.cText)),
                        Text(_earned(rewards[i] as Map), style: QText.caption.copyWith(color: ctx.cSub)),
                      ]),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      minimumSize: const Size(0, 34),
                      color: kGold,
                      borderRadius: BorderRadius.circular(999),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onUse(rewards[i] as Map);
                      },
                      child: const Text('Utiliser', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Les autres restent dans tes récompenses.', style: QText.label.copyWith(color: ctx.cSub)),
          ),
        ]),
      );
    },
  );
}

String _earned(Map r) {
  final d = DateTime.tryParse(r['earned_at'] as String? ?? '')?.toLocal();
  if (d == null) return 'Prête à utiliser';
  return 'Gagnée le ${d.day} ${_monthsFr[d.month - 1]}';
}
