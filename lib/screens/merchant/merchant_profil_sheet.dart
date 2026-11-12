import 'package:flutter/cupertino.dart';
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
      // Mode écran plein avec flèche retour
      return Scaffold(
        backgroundColor: kIsIOS
            ? (context.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7))
            : context.cBg,
        body: SafeArea(
          child: Column(children: [
            // En-tête avec flèche retour
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: kIsIOS
                      ? const Icon(CupertinoIcons.chevron_left, size: 20)
                      : const Icon(Icons.arrow_back_rounded, size: 22),
                  color: context.cText,
                  onPressed: () => Navigator.pop(context),
                ),
                Text('Profil',
                  style: TextStyle(
                    fontSize: kIsIOS ? 17 : 18,
                    fontWeight: FontWeight.w700,
                    color: context.cText,
                  )),
              ]),
            ),
            Expanded(child: kIsIOS ? _buildIOS(context) : _buildMaterial(context)),
          ]),
        ),
      );
    }
    if (kIsIOS) return _buildIOS(context);
    return _buildMaterial(context);
  }

  // ─── Android : bottom sheet Material ────────────────────────────────────────
  Widget _buildMaterial(BuildContext context) {
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

  // ─── iOS : style Apple HIG — CupertinoListSection ───────────────────────────
  Widget _buildIOS(BuildContext context) {
    final isDark     = context.isDark;
    final sheetBg    = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final handleColor = isDark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6);
    final titleColor  = isDark ? Colors.white            : const Color(0xFF000000);
    final subColor    = const Color(0xFF8E8E93);

    final name     = merchantInfo?['business_name'] as String? ?? 'Commerce';
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

    return Container(
      color: sheetBg,
      child: Column(mainAxisSize: isTab ? MainAxisSize.max : MainAxisSize.min, children: [
        // Handle iOS style (seulement en mode sheet)
        if (!isTab) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(child: Container(
            width: 36, height: 5,
            decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(3))))),
        // En-tête profil
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
              Text('Mon commerce', style: TextStyle(fontSize: 12, color: subColor)),
            ])),
          ]),
        ),
        // Corps scrollable
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(children: [
            // Section MON COMMERCE
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
            // Section MARKETING
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
            // Section AIDE
            _IosSection(
              header: 'AIDE',
              rows: [
                _IosRow(
                  icon: CupertinoIcons.question_circle,
                  iconBg: const Color(0xFF636366),
                  label: 'Aide & Support', sub: 'FAQ, nous contacter',
                  onTap: () { if (!isTab) Navigator.pop(context); }),
                // Toggle mode sombre
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
            // Bouton déconnexion
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

// ─── iOS : Section groupée ────────────────────────────────────────────────────
class _IosSection extends StatelessWidget {
  final String header;
  final List<Widget> rows;

  const _IosSection({required this.header, required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark   = context.isDark;
    final cardBg   = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final hdrColor = const Color(0xFF8E8E93);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(header,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: hdrColor, letterSpacing: 0.5)),
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

// ─── iOS : Ligne de liste ─────────────────────────────────────────────────────
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

// ─── iOS : Ligne mode sombre ──────────────────────────────────────────────────
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

// ─── Android uniquement ───────────────────────────────────────────────────────
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
