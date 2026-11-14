import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../main.dart';
import 'merchant_tokens.dart';

class MerchantProfilSheetIos extends StatelessWidget {
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

  const MerchantProfilSheetIos({
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
        backgroundColor: context.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.chevron_left, size: 20),
                  color: context.cText,
                  onPressed: () => Navigator.pop(context),
                ),
                Text('Profil',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
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
    final isDark      = context.isDark;
    final sheetBg     = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final handleColor = isDark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6);
    final titleColor  = isDark ? Colors.white            : const Color(0xFF000000);

    final name     = merchantInfo?['business_name'] as String? ?? 'Commerce';
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

    return Container(
      color: sheetBg,
      child: Column(mainAxisSize: isTab ? MainAxisSize.max : MainAxisSize.min, children: [
        if (!isTab) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(child: Container(
            width: 36, height: 5,
            decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(3))))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(initials,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: kPrimary))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600,
                color: titleColor, letterSpacing: -0.4)),
              Text('Mon commerce', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ])),
          ]),
        ),
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(children: [
            _IosSection(
              header: 'MON COMMERCE',
              rows: [
                _IosRow(
                  icon: CupertinoIcons.doc_text,
                  iconBg: kPrimary, label: 'Informations',
                  sub: 'Nom, adresse',
                  onTap: () { if (!isTab) Navigator.pop(context); onNavigateToInfo?.call(); }),
                _IosRow(
                  icon: CupertinoIcons.creditcard,
                  iconBg: kSuccess, label: 'Ma carte fidélité',
                  sub: 'Tampons, récompense, couleur',
                  onTap: () { if (!isTab) Navigator.pop(context); onNavigateToCarteEditor?.call(); },
                  isLast: true),
              ],
            ),
            _IosSection(
              header: 'MARKETING',
              rows: [
                _IosRow(
                  icon: CupertinoIcons.bell,
                  iconBg: kGold, label: 'Notifications push',
                  sub: 'Promos, rappels',
                  onTap: () { if (!isTab) Navigator.pop(context); onNavigateToNotifs?.call(); }),
                _IosRow(
                  icon: CupertinoIcons.qrcode,
                  iconBg: kPrimary, label: 'QR Code boutique',
                  sub: 'Afficher en caisse',
                  onTap: () { if (!isTab) Navigator.pop(context); onNavigateToQR?.call(); }),
                _IosRow(
                  icon: CupertinoIcons.chart_bar,
                  iconBg: kPurple, label: 'Statistiques',
                  sub: "Analyse de l'activité",
                  onTap: () { if (!isTab) Navigator.pop(context); onNavigateToStats?.call(); },
                  isLast: true),
              ],
            ),
            _IosSection(
              header: 'AIDE',
              rows: [
                _IosRow(
                  icon: CupertinoIcons.question_circle,
                  iconBg: const Color(0xFF636366),
                  label: 'Aide & Support', sub: 'FAQ, nous contacter',
                  onTap: () { if (!isTab) Navigator.pop(context); }),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (_, mode, __) => _IosDarkModeRow(
                    isDark: mode == ThemeMode.dark,
                    onChanged: (val) async {
                      themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      final p = await SharedPreferences.getInstance();
                      await p.setBool('dark_mode', val);
                    },
                    isLast: true,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onLogout,
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(CupertinoIcons.square_arrow_left, color: kError, size: 18),
                    SizedBox(width: 8),
                    Text('Se déconnecter',
                      style: TextStyle(
                        color: kError, fontSize: 15, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ),
          ]),
        )),
      ]),
    );
  }
}

class _IosSection extends StatelessWidget {
  final String header;
  final List<Widget> rows;

  const _IosSection({required this.header, required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark   = context.isDark;
    final cardBg   = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(header,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93), letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg, borderRadius: BorderRadius.circular(12)),
          child: Column(children: rows),
        ),
      ]),
    );
  }
}

class _IosRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool isLast;

  const _IosRow({
    required this.icon, required this.iconBg,
    required this.label, required this.sub,
    required this.onTap, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = context.isDark;
    final divider  = isDark ? const Color(0xFF38383A) : const Color(0xFFE0E0E5);
    final lblColor = isDark ? Colors.white : const Color(0xFF000000);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: isLast ? null : BoxDecoration(
          border: Border(bottom: BorderSide(color: divider, width: 0.5))),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, color: Colors.white, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w400, color: lblColor)),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
          ])),
          const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
        ]),
      ),
    );
  }
}

class _IosDarkModeRow extends StatelessWidget {
  final bool isDark;
  final void Function(bool) onChanged;
  final bool isLast;

  const _IosDarkModeRow({
    required this.isDark, required this.onChanged, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final lblColor = isDark ? Colors.white : const Color(0xFF000000);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(7)),
          child: const Icon(CupertinoIcons.moon_fill, color: Colors.white, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Text('Mode sombre',
          style: TextStyle(fontSize: 14, color: lblColor))),
        CupertinoSwitch(
          value: isDark,
          onChanged: onChanged,
          activeTrackColor: kPrimary,
        ),
      ]),
    );
  }
}
