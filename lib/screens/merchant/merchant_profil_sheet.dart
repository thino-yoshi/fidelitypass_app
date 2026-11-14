import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../main.dart';
import 'merchant_tokens.dart';

class MerchantProfilSheet extends StatelessWidget {
  final String token;
  final Map? merchantInfo;
  final VoidCallback onLogout;
  final bool isTab;
  final VoidCallback? onNavigateToProgram;
  final VoidCallback? onNavigateToNotifs;
  final VoidCallback? onNavigateToQR;
  final VoidCallback? onNavigateToAbonnement;
  final VoidCallback? onNavigateToInfo;
  final VoidCallback? onNavigateToCarteEditor;
  final VoidCallback? onNavigateToStats;

  const MerchantProfilSheet({
    super.key,
    required this.token,
    required this.merchantInfo,
    required this.onLogout,
    this.isTab = false,
    this.onNavigateToProgram,
    this.onNavigateToNotifs,
    this.onNavigateToQR,
    this.onNavigateToAbonnement,
    this.onNavigateToInfo,
    this.onNavigateToCarteEditor,
    this.onNavigateToStats,
  });

  @override
  Widget build(BuildContext context) {
    if (isTab) {
      return Scaffold(
        backgroundColor: context.cBg,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  color: context.cText,
                  onPressed: () => Navigator.pop(context),
                ),
                Text('Profil',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: context.cText,
                  )),
              ]),
            ),
            Expanded(child: _buildContent(context)),
          ]),
        ),
      );
    }
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final kBg     = context.cBg;
    final kWhite  = context.cSurface;
    final kBorder = context.cBorder;
    final kText   = context.cText;
    final kSub    = context.cSub;

    final name     = merchantInfo?['business_name'] as String? ?? 'Commerce';
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

    return Container(
      color: kBg,
      child: Column(mainAxisSize: isTab ? MainAxisSize.max : MainAxisSize.min, children: [
        if (!isTab) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              child: Center(child: Text(initials,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kPrimary))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
              Text('Mon commerce', style: TextStyle(fontSize: 11, color: kSub)),
            ])),
          ]),
        ),
        Divider(height: 1, color: kBorder),
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MON COMMERCE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _Section(kWhite: kWhite, kBorder: kBorder, rows: [
              _Row(kBorder: kBorder, kText: kText, kSub: kSub,
                icon: Icons.description_outlined,
                iconBg: kPrimary.withValues(alpha: 0.12), iconColor: kPrimary,
                label: 'Informations', sub: 'Nom, adresse',
                onTap: () { if (!isTab) Navigator.pop(context); onNavigateToInfo?.call(); }),
              _Row(kBorder: kBorder, kText: kText, kSub: kSub,
                icon: Icons.credit_card_outlined,
                iconBg: kSuccess.withValues(alpha: 0.12), iconColor: kSuccess,
                label: 'Ma carte fidélité', sub: 'Tampons, récompense, couleur',
                onTap: () { if (!isTab) Navigator.pop(context); onNavigateToCarteEditor?.call(); },
                noBorder: true),
            ]),
            const SizedBox(height: 14),
            Text('MARKETING',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _Section(kWhite: kWhite, kBorder: kBorder, rows: [
              _Row(kBorder: kBorder, kText: kText, kSub: kSub,
                icon: Icons.notifications_outlined,
                iconBg: kGold.withValues(alpha: 0.12), iconColor: kGold,
                label: 'Notifications push', sub: 'Promos, rappels',
                onTap: () { if (!isTab) Navigator.pop(context); onNavigateToNotifs?.call(); }),
              _Row(kBorder: kBorder, kText: kText, kSub: kSub,
                icon: Icons.qr_code_2_rounded,
                iconBg: kPrimary.withValues(alpha: 0.12), iconColor: kPrimary,
                label: 'QR Code boutique', sub: 'Afficher en caisse',
                onTap: () { if (!isTab) Navigator.pop(context); onNavigateToQR?.call(); }),
              _Row(kBorder: kBorder, kText: kText, kSub: kSub,
                icon: Icons.show_chart_rounded,
                iconBg: kPurple.withValues(alpha: 0.12), iconColor: kPurple,
                label: 'Statistiques', sub: "Analyse de l'activité",
                onTap: () { if (!isTab) Navigator.pop(context); onNavigateToStats?.call(); },
                noBorder: true),
            ]),
            const SizedBox(height: 14),
            Text('AIDE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7)),
            const SizedBox(height: 8),
            _Section(kWhite: kWhite, kBorder: kBorder, rows: [
              _Row(kBorder: kBorder, kText: kText, kSub: kSub,
                icon: Icons.help_outline_rounded,
                iconBg: kBg, iconColor: kSub,
                label: 'Aide & Support', sub: 'FAQ, nous contacter',
                onTap: () { if (!isTab) Navigator.pop(context); }),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, mode, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: kPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.dark_mode_outlined, color: Color(0xFF7C3AED), size: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mode sombre',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                      Text("Thème de l'application",
                        style: TextStyle(fontSize: 11, color: kSub)),
                    ])),
                    Switch(
                      value: mode == ThemeMode.dark,
                      onChanged: (val) async {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        final p = await SharedPreferences.getInstance();
                        await p.setBool('dark_mode', val);
                      },
                      activeThumbColor: kPrimary,
                    ),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: double.infinity, height: 46,
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kError.withValues(alpha: 0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: kError, size: 16),
                  SizedBox(width: 8),
                  Text('Se déconnecter',
                    style: TextStyle(color: kError, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        )),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final Color kWhite;
  final Color kBorder;
  final List<Widget> rows;

  const _Section({required this.kWhite, required this.kBorder, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
    ),
    child: Column(children: rows),
  );
}

class _Row extends StatelessWidget {
  final Color kBorder;
  final Color kText;
  final Color kSub;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool noBorder;

  const _Row({
    required this.kBorder, required this.kText, required this.kSub,
    required this.icon, required this.iconBg, required this.iconColor,
    required this.label, required this.sub, required this.onTap,
    this.noBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: noBorder ? null : Border(bottom: BorderSide(color: kBorder))),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
            Text(sub,   style: TextStyle(fontSize: 11, color: kSub)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18, color: kSub),
        ]),
      ),
    );
  }
}
