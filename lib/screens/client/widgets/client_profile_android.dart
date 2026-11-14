import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/app_colors.dart';
import '../../../main.dart';

class ClientProfileAndroid extends StatelessWidget {
  final bool isOAuth;
  final bool isGoogle;
  final VoidCallback onPersonalInfo;
  final VoidCallback onPassword;
  final VoidCallback onCards;
  final VoidCallback onNotifSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;
  final VoidCallback onDelete;

  const ClientProfileAndroid({
    super.key,
    required this.isOAuth,
    required this.isGoogle,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 76),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _profSec(context, [
            _profRow(context,
              iconBg: const Color(0xFFE8F1FD),
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF2C7BE5),
              label: 'Informations personnelles',
              sub: 'Nom, email, téléphone',
              onTap: onPersonalInfo,
            ),
            if (!isOAuth)
              _profRow(context,
                iconBg: const Color(0xFFFEF3C7),
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Changer le mot de passe',
                sub: 'Sécurité du compte',
                onTap: onPassword,
              ),
            _profRow(context,
              iconBg: const Color(0xFFE4F5EB),
              icon: Icons.credit_card_outlined,
              iconColor: const Color(0xFF27AE60),
              label: 'Mes cartes',
              sub: 'Gérer et supprimer',
              onTap: onCards,
            ),
          ]),
          const SizedBox(height: 12),
          _profSec(context, [
            _darkModeRow(context),
            _profRow(context,
              iconBg: const Color(0xFFE8F1FD),
              icon: Icons.notifications_outlined,
              iconColor: const Color(0xFF2C7BE5),
              label: 'Notifications',
              sub: 'Push, offres, visites',
              onTap: onNotifSettings,
            ),
            _profRow(context,
              iconBg: const Color(0xFFF4F2EE),
              icon: Icons.help_outline_rounded,
              iconColor: const Color(0xFF888888),
              label: 'Aide et Support',
              sub: 'FAQ, nous contacter',
              onTap: onHelp,
            ),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onLogout,
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(
                color: context.qSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE8E7), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFE24B4A), size: 16),
                  SizedBox(width: 8),
                  Text('Se déconnecter', style: TextStyle(color: Color(0xFFE24B4A), fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.qBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, color: context.qSub, size: 15),
                  const SizedBox(width: 6),
                  Text('Supprimer mon compte', style: TextStyle(color: context.qSub, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profSec(BuildContext context, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: context.qSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.qBorder),
      ),
      child: Column(children: rows),
    );
  }

  Widget _profRow(BuildContext context, {
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sub,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.qDivider)),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
              Text(sub,   style: TextStyle(fontSize: 11, color: context.qSub)),
            ],
          )),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: context.qMuted, size: 18),
        ]),
      ),
    );
  }

  Widget _darkModeRow(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.qDivider))),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF428CE3) : const Color(0xFF061324),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.dark_mode_outlined,
              color: context.isDark ? const Color(0xFF061324) : const Color(0xFF428CE3), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mode sombre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
              Text("Thème de l'interface", style: TextStyle(fontSize: 11, color: context.qSub)),
            ],
          )),
          Switch.adaptive(
            value: mode == ThemeMode.dark,
            onChanged: (val) async {
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              final p = await SharedPreferences.getInstance();
              await p.setBool('dark_mode', val);
            },
            activeColor: const Color(0xFF2C7BE5),
          ),
        ]),
      ),
    );
  }
}
