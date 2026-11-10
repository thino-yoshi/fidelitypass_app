import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../config/app_colors.dart';

class MerchantHeader extends StatelessWidget {
  final String businessName;
  final String initials;
  final int clientsCount;
  final int rewardsCount;
  final bool isActive;
  final VoidCallback onProfileTap;
  final VoidCallback onClientsTap;

  const MerchantHeader({
    super.key,
    required this.businessName,
    required this.initials,
    required this.clientsCount,
    required this.rewardsCount,
    required this.isActive,
    required this.onProfileTap,
    required this.onClientsTap,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) return _buildIOS(context);
    return _buildMaterial(context);
  }

  // ─── Android : header navy sombre ──────────────────────────────────────────
  Widget _buildMaterial(BuildContext context) {
    return Container(
      color: kNavy,
      child: Stack(children: [
        Positioned(
          top: -60, right: -20,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [kPrimary.withValues(alpha: 0.25), Colors.transparent],
                stops: const [0, 0.7],
              ),
            ),
          ),
        ),
        Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Column(children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 14,
                left: 20, right: 20,
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: kBlueLight.withValues(alpha: 0.45), width: 1.5),
                    ),
                    child: Center(child: Text(initials,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: kBlueLight))),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(businessName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: Colors.white, height: 1.1)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Connecté · ${isActive ? "Plan Pro" : "Plan Free"}',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
                  ]),
                ])),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(children: [
                _StatCard(value: '$clientsCount', label: 'Clients carte', onTap: onClientsTap),
                const SizedBox(width: 7),
                _StatCard(value: '$rewardsCount', label: 'Récompenses', onTap: null),
              ]),
            ),
          ]),
        )),
      ]),
    );
  }

  // ─── iOS : header blanc épuré style HIG ────────────────────────────────────
  Widget _buildIOS(BuildContext context) {
    final isDark       = context.isDark;
    // Couleurs système iOS
    final bg           = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE0E0E5);
    final titleColor   = isDark ? Colors.white            : const Color(0xFF000000);
    final subColor     = const Color(0xFF8E8E93); // iOS label tertiary
    final cardBg       = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final cardBorder   = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E5);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(children: [
              // Ligne avatar + nom + bouton paramètres
              Row(children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: kPrimary.withValues(alpha: 0.28)),
                    ),
                    child: Center(child: Text(initials,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: kPrimary))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(businessName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600,
                      color: titleColor, letterSpacing: -0.4)),
                  const SizedBox(height: 1),
                  Row(children: [
                    Container(width: 5, height: 5,
                      decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(isActive ? 'Plan Pro · Actif' : 'Plan Free · Gratuit',
                      style: TextStyle(fontSize: 11, color: subColor)),
                  ]),
                ])),
                // Bouton ellipsis iOS
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onProfileTap,
                  child: const Icon(CupertinoIcons.ellipsis_circle, color: kPrimary, size: 24),
                ),
              ]),
              const SizedBox(height: 12),
              // Stat cards iOS : fond gris clair, pas de border dark
              Row(children: [
                _IosStatCard(
                  value: '$clientsCount',
                  label: 'Clients carte',
                  onTap: onClientsTap,
                  bg: cardBg, border: cardBorder,
                  titleColor: titleColor,
                ),
                const SizedBox(width: 8),
                _IosStatCard(
                  value: '$rewardsCount',
                  label: 'Récompenses',
                  onTap: null,
                  bg: cardBg, border: cardBorder,
                  titleColor: titleColor,
                ),
              ]),
            ]),
          ),
        )),
      ),
    );
  }
}

// ─── Carte stat Android ───────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatCard({required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kNavyCard),
          ),
          child: Column(children: [
            Text(value,
              style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
            const SizedBox(height: 2),
            Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.42))),
          ]),
        ),
      ),
    );
  }
}

// ─── Carte stat iOS ───────────────────────────────────────────────────────────
class _IosStatCard extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  final Color bg;
  final Color border;
  final Color titleColor;

  const _IosStatCard({
    required this.value, required this.label, required this.onTap,
    required this.bg, required this.border, required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: titleColor, height: 1,
                  fontFamily: '.SF Pro Display')),
              const SizedBox(height: 2),
              Text(label,
                style: const TextStyle(
                  fontSize: 10, color: Color(0xFF8E8E93))),
            ])),
            if (onTap != null)
              const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
          ]),
        ),
      ),
    );
  }
}
