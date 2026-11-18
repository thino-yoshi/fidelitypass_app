import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';
import '../../../main.dart' show themeNotifier;

/// Regroupe tous les callbacks du popover profil.
class ProfileActions {
  final VoidCallback onPersonalInfo;
  final VoidCallback onPassword;
  final VoidCallback onCards;
  final VoidCallback onNotifSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;
  final VoidCallback onDelete;
  final VoidCallback? onClearData;
  final bool previewEmpty;
  final bool showPassword;

  const ProfileActions({
    required this.onPersonalInfo,
    required this.onPassword,
    required this.onCards,
    required this.onNotifSettings,
    required this.onHelp,
    required this.onLogout,
    required this.onDelete,
    this.onClearData,
    this.previewEmpty = false,
    this.showPassword = true,
  });
}

/// En-tête Android (layout D — pill flottante).
/// Tap cloche → popover notifications. Tap avatar → popover paramètres complets.
class ClientHeader extends StatefulWidget {
  final String caption;
  final String title;
  final String firstName;
  final int notifCount;
  final int cardCount;
  final int rewardCount;
  final List<Map> recentNotifs;
  final VoidCallback onNotifTap;
  final ProfileActions profileActions;
  final ImageProvider? avatarImage;
  final String initials;

  const ClientHeader({
    super.key,
    required this.caption,
    required this.title,
    required this.firstName,
    required this.notifCount,
    required this.cardCount,
    required this.rewardCount,
    required this.recentNotifs,
    required this.onNotifTap,
    required this.profileActions,
    required this.avatarImage,
    required this.initials,
  });

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  static const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  static String today() {
    final d = DateTime.now();
    return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  @override
  State<ClientHeader> createState() => _ClientHeaderState();
}

class _ClientHeaderState extends State<ClientHeader> {
  OverlayEntry? _overlay;
  final _pillKey = GlobalKey();

  @override
  void dispose() {
    _closePopover();
    super.dispose();
  }

  void _closePopover() {
    _overlay?.remove();
    _overlay = null;
  }

  void _openPopover({required bool isNotif}) {
    _closePopover();
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos  = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlay = OverlayEntry(builder: (_) => _PopoverOverlay(
      pillTopLeft: pos,
      pillSize: size,
      isNotif: isNotif,
      firstName: widget.firstName,
      initials: widget.initials,
      avatarImage: widget.avatarImage,
      cardCount: widget.cardCount,
      rewardCount: widget.rewardCount,
      notifCount: widget.notifCount,
      recentNotifs: widget.recentNotifs,
      profileActions: widget.profileActions,
      onNotifFullTap: () { _closePopover(); widget.onNotifTap(); },
      onDismiss: _closePopover,
    ));
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(widget.title, maxLines: 1,
                      style: QText.largeTitle(context).copyWith(color: context.cText)),
                ),
                const SizedBox(height: 3),
                Text(widget.caption.toUpperCase(),
                    style: QText.label.copyWith(fontWeight: FontWeight.w600, color: context.cSub)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
            key: _pillKey,
            decoration: BoxDecoration(
              gradient: isDark ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kBlueLight.withValues(alpha: 0.28), kNavy.withValues(alpha: 0.55)],
              ) : null,
              color: isDark ? null : const Color(0xFFF0F1F5),
              border: Border.all(
                color: isDark ? kBlueLight.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _openPopover(isNotif: true),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 30, height: 30,
                      alignment: Alignment.center,
                      child: Icon(CupertinoIcons.bell, size: 19,
                          color: context.cText.withValues(alpha: 0.72)),
                    ),
                    if (widget.notifCount > 0)
                      Positioned(
                        top: 1, right: 1,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: kError, shape: BoxShape.circle,
                            border: Border.all(color: context.cSurface, width: 1.5),
                          ),
                        ),
                      ),
                  ]),
                ),
                Container(
                  width: 1, height: 18,
                  color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.10),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
                GestureDetector(
                  onTap: () => _openPopover(isNotif: false),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: kPrimary, shape: BoxShape.circle,
                      image: widget.avatarImage != null
                          ? DecorationImage(image: widget.avatarImage!, fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: widget.avatarImage == null
                        ? Text(widget.initials,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))
                        : null,
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay plein écran ─────────────────────────────────────────────────────

class _PopoverOverlay extends StatefulWidget {
  final Offset pillTopLeft;
  final Size pillSize;
  final bool isNotif;
  final String firstName;
  final String initials;
  final ImageProvider? avatarImage;
  final int cardCount;
  final int rewardCount;
  final int notifCount;
  final List<Map> recentNotifs;
  final ProfileActions profileActions;
  final VoidCallback onNotifFullTap;
  final VoidCallback onDismiss;

  const _PopoverOverlay({
    required this.pillTopLeft,
    required this.pillSize,
    required this.isNotif,
    required this.firstName,
    required this.initials,
    required this.avatarImage,
    required this.cardCount,
    required this.rewardCount,
    required this.notifCount,
    required this.recentNotifs,
    required this.profileActions,
    required this.onNotifFullTap,
    required this.onDismiss,
  });

  @override
  State<_PopoverOverlay> createState() => _PopoverOverlayState();
}

class _PopoverOverlayState extends State<_PopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  // Ferme le popover puis exécute l'action
  void _act(VoidCallback action) {
    _dismiss().then((_) => action());
  }

  @override
  Widget build(BuildContext context) {
    final popWidth = widget.isNotif ? 230.0 : 260.0;
    final pillRight = widget.pillTopLeft.dx + widget.pillSize.width;
    final left = (pillRight - popWidth)
        .clamp(12.0, MediaQuery.of(context).size.width - popWidth - 12);
    final top = widget.pillTopLeft.dy + widget.pillSize.height + 10;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: SizedBox.expand(
        child: Stack(children: [
          Positioned(
            left: left, top: top, width: popWidth,
            child: GestureDetector(
              onTap: () {},
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.topRight,
                  child: _PopoverCard(
                    isNotif: widget.isNotif,
                    firstName: widget.firstName,
                    initials: widget.initials,
                    avatarImage: widget.avatarImage,
                    cardCount: widget.cardCount,
                    rewardCount: widget.rewardCount,
                    notifCount: widget.notifCount,
                    recentNotifs: widget.recentNotifs,
                    profileActions: widget.profileActions,
                    onNotifFullTap: widget.onNotifFullTap,
                    act: _act,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
      ),
    );
  }
}

// ── Contenu du popover ──────────────────────────────────────────────────────

class _PopoverCard extends StatelessWidget {
  final bool isNotif;
  final String firstName;
  final String initials;
  final ImageProvider? avatarImage;
  final int cardCount;
  final int rewardCount;
  final int notifCount;
  final List<Map> recentNotifs;
  final ProfileActions profileActions;
  final VoidCallback onNotifFullTap;
  final void Function(VoidCallback) act;

  const _PopoverCard({
    required this.isNotif,
    required this.firstName,
    required this.initials,
    required this.avatarImage,
    required this.cardCount,
    required this.rewardCount,
    required this.notifCount,
    required this.recentNotifs,
    required this.profileActions,
    required this.onNotifFullTap,
    required this.act,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBlueLight.withValues(alpha: 0.28), kNavy.withValues(alpha: 0.55)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBlueLight.withValues(alpha: 0.22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: CustomPaint(size: const Size(14, 7), painter: _EarPainter()),
                ),
              ),
              isNotif
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        child: _notifContent(context),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 460),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        child: _profileContent(context),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notifs ──────────────────────────────────────────────────────────────────

  Widget _notifContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('Notifications',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 0.07, color: kBlueLight.withValues(alpha: 0.7))),
          if (notifCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kError.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$notifCount',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: kError)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        if (recentNotifs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Aucune notification',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65))),
          )
        else
          ...recentNotifs.map((n) => _RealNotifRow(notif: n)),
      ],
    );
  }

  // ── Profil / paramètres ─────────────────────────────────────────────────────

  Widget _profileContent(BuildContext context) {
    final pa = profileActions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête avatar
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kPrimary, shape: BoxShape.circle,
              image: avatarImage != null
                  ? DecorationImage(image: avatarImage!, fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: avatarImage == null
                ? Text(initials,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(firstName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(
                '$cardCount carte${cardCount > 1 ? 's' : ''} · '
                '$rewardCount récompense${rewardCount > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.70)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        // Groupe 1
        _group(context, [
          _Item(icon: CupertinoIcons.person_fill, color: kPrimary,
              label: 'Informations personnelles', onTap: () => act(pa.onPersonalInfo)),
          if (pa.showPassword)
            _Item(icon: CupertinoIcons.lock_fill, color: kGold,
                label: 'Mot de passe', onTap: () => act(pa.onPassword)),
          _Item(icon: CupertinoIcons.creditcard_fill, color: kSuccess,
              label: 'Mes cartes',
              trailing: Text('$cardCount',
                  style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.70))),
              onTap: () => act(pa.onCards)),
        ]),
        const SizedBox(height: 10),
        // Groupe 2
        _group(context, [
          _Item(icon: CupertinoIcons.bell_fill, color: kError,
              label: 'Notifications', onTap: () => act(pa.onNotifSettings)),
          _DarkModeItem(),
          _Item(icon: CupertinoIcons.question, color: const Color(0xFF9096A4),
              label: 'Aide et support', onTap: () => act(pa.onHelp)),
        ]),
        // Bouton prévisualisation (optionnel)
        if (pa.onClearData != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => act(pa.onClearData!),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kBlueLight.withValues(alpha: 0.14), kNavy.withValues(alpha: 0.32)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: pa.previewEmpty ? kSuccess : kGold, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  pa.previewEmpty
                      ? CupertinoIcons.eye_fill
                      : CupertinoIcons.eye_slash_fill,
                  size: 15,
                  color: pa.previewEmpty ? kSuccess : kGold,
                ),
                const SizedBox(width: 6),
                Text(
                  pa.previewEmpty ? 'Restaurer les données' : 'Vider la vue',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: pa.previewEmpty ? kSuccess : kGold),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 10),
        // Déconnexion
        GestureDetector(
          onTap: () => act(pa.onLogout),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kBlueLight.withValues(alpha: 0.14), kNavy.withValues(alpha: 0.32)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kError.withValues(alpha: 0.35), width: 1.2),
            ),
            alignment: Alignment.center,
            child: const Text('Se déconnecter',
                style: TextStyle(
                    color: kError, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 4),
        // Supprimer compte
        GestureDetector(
          onTap: () => act(pa.onDelete),
          child: Center(
            child: Text('Supprimer mon compte',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.55))),
          ),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBlueLight.withValues(alpha: 0.12), kNavy.withValues(alpha: 0.28)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBlueLight.withValues(alpha: 0.10)),
      ),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Container(height: 0.4, color: Colors.white.withValues(alpha: 0.08)),
            ),
          items[i],
        ],
      ]),
    );
  }
}

// ── Widgets internes ────────────────────────────────────────────────────────

class _Item extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _Item({
    required this.icon, required this.color,
    required this.label, required this.onTap, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
            Icon(CupertinoIcons.chevron_forward,
                size: 13, color: Colors.white.withValues(alpha: 0.55)),
          ]),
        ),
      ),
    );
  }
}

class _DarkModeItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(7)),
              child: const Icon(CupertinoIcons.moon_fill, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Mode sombre',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
            ),
            Switch(
              value: mode == ThemeMode.dark,
              activeTrackColor: kSuccess,
              activeThumbColor: Colors.white,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Icon(Icons.check_rounded, size: 14, color: kSuccess);
                }
                return null;
              }),
              onChanged: (val) async {
                themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                final p = await SharedPreferences.getInstance();
                await p.setBool('dark_mode', val);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _RealNotifRow extends StatelessWidget {
  final Map notif;
  const _RealNotifRow({required this.notif});

  static String _relTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    if (diff.inDays == 1)    return 'hier';
    return '${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context) {
    final color    = Color(notif['color'] as int? ?? 0xFF2C7BE5);
    final icon     = notif['icon'] as String? ?? '→';
    final title    = notif['title'] as String? ?? '';
    final commerce = notif['commerce'] as String? ?? '';
    final dt       = notif['dt'] as DateTime?;
    final isUnread = !(notif['read'] as bool? ?? true);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: TextStyle(fontSize: 13, color: color)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white.withValues(alpha: isUnread ? 0.95 : 0.7),
                    )),
              ),
              if (isUnread)
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(left: 4, top: 2),
                  decoration: const BoxDecoration(color: kBlueLight, shape: BoxShape.circle),
                ),
            ]),
            Text(
              commerce.isNotEmpty ? '$commerce · ${_relTime(dt)}' : _relTime(dt),
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.65)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBlueLight.withValues(alpha: 0.28), kNavy.withValues(alpha: 0.55)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBlueLight.withValues(alpha: 0.22)),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: kBlueLight)),
      ),
    );
  }
}

class _EarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kBlueLight.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_EarPainter _) => false;
}
