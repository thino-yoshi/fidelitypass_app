import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';
import '../../../main.dart' show themeNotifier;
import 'client_notifications_ios.dart' show GlassBackButton;

/// Profil iOS façon Réglages : grande photo, nom, puis listes groupées
/// avec petites icônes carrées de couleur.
class ClientProfileIos extends StatelessWidget {
  final String name;
  final String subtitle;          // ex. « Compte Apple · 5 cartes »
  final String initials;
  final ImageProvider? avatar;
  final int cardCount;
  final bool showPassword;        // false pour les comptes Apple / Google
  final VoidCallback onBack;
  final VoidCallback onAvatarTap;
  final VoidCallback onPersonalInfo;
  final VoidCallback onPassword;
  final VoidCallback onCards;
  final VoidCallback onNotifSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;
  final VoidCallback onDelete;

  const ClientProfileIos({
    super.key,
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.avatar,
    required this.cardCount,
    required this.showPassword,
    required this.onBack,
    required this.onAvatarTap,
    required this.onPersonalInfo,
    required this.onPassword,
    required this.onCards,
    required this.onNotifSettings,
    required this.onHelp,
    required this.onLogout,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, MediaQuery.of(context).padding.bottom + 30),
      children: [
        Align(alignment: Alignment.centerLeft, child: GlassBackButton(onTap: onBack)),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: kPrimary, shape: BoxShape.circle,
                image: avatar != null ? DecorationImage(image: avatar!, fit: BoxFit.cover) : null,
              ),
              alignment: Alignment.center,
              child: avatar == null
                  ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w600))
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(name, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: context.cText)),
        const SizedBox(height: 2),
        Text(subtitle, textAlign: TextAlign.center, style: QText.body.copyWith(fontSize: 17, color: context.cSub)),
        const SizedBox(height: 22),
        _group(context, [
          _Row(icon: CupertinoIcons.person_fill, color: kPrimary, label: 'Informations personnelles', onTap: onPersonalInfo),
          if (showPassword)
            _Row(icon: CupertinoIcons.lock_fill, color: kGold, label: 'Mot de passe', onTap: onPassword),
          _Row(icon: CupertinoIcons.creditcard_fill, color: kSuccess, label: 'Mes cartes', value: '$cardCount', onTap: onCards),
        ]),
        const SizedBox(height: 18),
        _group(context, [
          _Row(icon: CupertinoIcons.bell_fill, color: kError, label: 'Notifications', onTap: onNotifSettings),
          const _DarkModeRow(),
          _Row(icon: CupertinoIcons.question, color: const Color(0xFF9096A4), label: 'Aide et support', onTap: onHelp),
        ]),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: onLogout,
          child: Container(
            height: 52,
            decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const Text('Se déconnecter', style: TextStyle(color: kError, fontSize: 17, fontWeight: FontWeight.w400)),
          ),
        ),
        const SizedBox(height: 6),
        CupertinoButton(
          onPressed: onDelete,
          child: Text('Supprimer mon compte', style: QText.caption.copyWith(color: context.cSub)),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Padding(padding: const EdgeInsets.only(left: 58), child: Container(height: 0.5, color: context.cBorder)),
          rows[i],
        ],
      ]),
    );
  }
}

class _Icon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Icon(this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.color, required this.label, required this.onTap, this.value});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _Icon(icon, color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: QText.body.copyWith(fontSize: 17, color: context.cText))),
            if (value != null) ...[
              Text(value!, style: QText.body.copyWith(fontSize: 17, color: context.cSub)),
              const SizedBox(width: 6),
            ],
            Icon(CupertinoIcons.chevron_forward, size: 16, color: context.cSub.withValues(alpha: 0.7)),
          ]),
        ),
      ),
    );
  }
}

class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const _Icon(CupertinoIcons.moon_fill, kNavy),
            const SizedBox(width: 12),
            Expanded(child: Text('Mode sombre', style: QText.body.copyWith(fontSize: 17, color: context.cText))),
            CupertinoSwitch(
              value: mode == ThemeMode.dark,
              activeTrackColor: kSuccess,
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
