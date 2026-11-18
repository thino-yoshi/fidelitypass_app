import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';

/// Écran Notifications iOS : retour + « Tout lire », grand titre,
/// sélecteur Tout / Tampons / Cadeaux / Messages (envoyés par les commerçants), listes groupées par jour.
class ClientNotificationsIos extends StatelessWidget {
  final List<Map> notifs;          // {commerce, title, body, time, read, type, dt}
  final String filter;             // 'tout' | 'tampon' | 'recompense' | 'offre'
  final ValueChanged<String> onFilter;
  final VoidCallback onBack;
  final VoidCallback onReadAll;
  final void Function(Map n) onTap;

  const ClientNotificationsIos({
    super.key,
    required this.notifs,
    required this.filter,
    required this.onFilter,
    required this.onBack,
    required this.onReadAll,
    required this.onTap,
  });

  static bool _isOffer(String t) => t == 'promo' || t == 'targeted' || t == 'scheduled';

  List<Map> get _filtered => notifs.where((n) {
        final t = n['type'] as String? ?? 'promo';
        switch (filter) {
          case 'tampon': return t == 'tampon';
          case 'recompense': return t == 'recompense';
          case 'offre': return _isOffer(t);
          default: return true;
        }
      }).toList();

  static const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

  String _dayLabel(DateTime? d) {
    if (d == null) return 'Récentes';
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map>>{};
    for (final n in _filtered) {
      groups.putIfAbsent(_dayLabel(n['dt'] as DateTime?), () => []).add(n);
    }
    final hasUnread = notifs.any((n) => !(n['read'] as bool? ?? true));
    final top = MediaQuery.of(context).padding.top;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, MediaQuery.of(context).padding.bottom + 30),
      children: [
        Row(children: [
          _Glass(onTap: onBack, child: Icon(CupertinoIcons.chevron_back, size: 22, color: context.cText)),
          const Spacer(),
          // Toujours visible ; grisé quand tout est déjà lu.
          _Glass(
            onTap: hasUnread ? onReadAll : () {},
            wide: true,
            child: Text('Tout lire',
                style: QText.body.copyWith(fontSize: 17, color: hasUnread ? context.cText : context.cSub.withValues(alpha: 0.6))),
          ),
        ]),
        const SizedBox(height: 18),
        Text('Notifications', style: QText.largeTitle(context).copyWith(color: context.cText)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: filter,
            padding: const EdgeInsets.all(2),
            children: {
              'tout': _seg('Tout', context),
              'tampon': _seg('Tampons', context),
              'recompense': _seg('Cadeaux', context),
              'offre': _seg('Messages', context),
            },
            onValueChanged: (v) { if (v != null) onFilter(v); },
          ),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(children: [
              Icon(CupertinoIcons.bell, size: 40, color: context.cSub),
              const SizedBox(height: 12),
              Text('Aucune notification', style: QText.blockTitle.copyWith(color: context.cText)),
              const SizedBox(height: 4),
              Text('Tes tampons et les messages de tes commerces apparaîtront ici.',
                  textAlign: TextAlign.center, style: QText.caption.copyWith(color: context.cSub)),
            ]),
          ),
        for (final e in groups.entries) ...[
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
      ],
    );
  }

  Widget _seg(String t, BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.cText)),
      );

  Widget _row(BuildContext context, Map n, {required bool divider}) {
    final type = n['type'] as String? ?? 'promo';
    final unread = !(n['read'] as bool? ?? true);
    final (Color bg, IconData icon) = switch (type) {
      'tampon' => (kNavyCard, CupertinoIcons.checkmark_alt),
      'recompense' => (kGold, CupertinoIcons.gift),
      _ => (kSuccess, CupertinoIcons.tag),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(n),
      child: Column(children: [
        if (divider) Padding(padding: const EdgeInsets.only(left: 70), child: Container(height: 0.5, color: context.cBorder)),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(
              width: 14,
              child: unread
                  ? Center(child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: 4),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(n['commerce'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: QText.blockTitle.copyWith(color: context.cText)),
                  ),
                  Text(n['time'] as String? ?? '', style: QText.caption.copyWith(color: context.cSub)),
                ]),
                if ((n['title'] as String? ?? '').isNotEmpty)
                  Text(n['title'] as String, style: QText.body.copyWith(color: context.cText)),
                if ((n['body'] as String? ?? '').isNotEmpty)
                  Text(n['body'] as String, style: QText.caption.copyWith(color: context.cSub)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool wide;
  const _Glass({required this.child, required this.onTap, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 44,
            width: wide ? null : 44,
            padding: wide ? const EdgeInsets.symmetric(horizontal: 18) : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: context.cSurface.withValues(alpha: context.isDark ? 0.5 : 0.85),
              border: Border.all(color: Colors.white.withValues(alpha: context.isDark ? 0.12 : 0.9)),
              boxShadow: [BoxShadow(color: kNavy.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bouton rond « retour » en verre, réutilisé par le profil.
class GlassBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const GlassBackButton({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      _Glass(onTap: onTap, child: Icon(CupertinoIcons.chevron_back, size: 22, color: context.cText));
}
