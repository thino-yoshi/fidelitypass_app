import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../utils/logger.dart';

// ── Couleurs ──────────────────────────────────────────────────────────────────
const _kNight      = Color(0xFF0D1B2A); // bleu nuit
const _kBeige      = Color(0xFFE8D5B7); // beige/crème pill active
const _kLightBlue  = Color(0xFF5BB8FF); // bleu clair — icône scan dans la bulle

// ── Widget principal ──────────────────────────────────────────────────────────

class ClientBottomNav extends StatelessWidget {
  final int currentTab;
  final void Function(int) onTabChanged;
  final VoidCallback onScanTap;
  final String? profileImageUrl; // URL de la photo de profil

  const ClientBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Positioned(
      bottom: bottomPad + 14,
      left: 16,
      right: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Barre principale (3/4) ───────────────────────────────────────
          Expanded(
            flex: 3,
            child: _FloatingBar(
              currentTab: currentTab,
              onTabChanged: onTabChanged,
              profileImageUrl: profileImageUrl,
            ),
          ),
          const SizedBox(width: 10),
          // ── Bulle scanner ronde (1/4) ────────────────────────────────────
          _ScanBubble(onTap: onScanTap),
        ],
      ),
    );
  }
}

// ── Barre principale : Cartes · Historique · Profil ───────────────────────────

class _FloatingBar extends StatelessWidget {
  final int currentTab;
  final void Function(int) onTabChanged;
  final String? profileImageUrl;

  const _FloatingBar({
    required this.currentTab,
    required this.onTabChanged,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PillItem(
                icon: Icons.credit_card_outlined,
                label: 'Cartes',
                index: 0,
                currentTab: currentTab,
                onTap: onTabChanged,
              ),
              _PillItem(
                icon: Icons.history_rounded,
                label: 'Historique',
                index: 2,
                currentTab: currentTab,
                onTap: onTabChanged,
              ),
              // Profil : photo ronde si disponible, sinon icône
              _PillItem(
                icon: Icons.person_outline_rounded,
                label: 'Profil',
                index: 3,
                currentTab: currentTab,
                onTap: onTabChanged,
                profileImageUrl: profileImageUrl,
                iconScale: 1.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bulle scanner ronde ───────────────────────────────────────────────────────

class _ScanBubble extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanBubble({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppLogger.client('Dock → Scanner');
        onTap();
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: _kNight,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Item avec pill animée ─────────────────────────────────────────────────────

class _PillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentTab;
  final void Function(int) onTap;
  final String? profileImageUrl; // uniquement pour l'item Profil
  final double iconScale;

  const _PillItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentTab,
    required this.onTap,
    this.profileImageUrl,
    this.iconScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final active = currentTab == index;

    // Icône ou photo de profil
    Widget iconWidget;
    Widget rawIcon;
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      rawIcon = CircleAvatar(
        radius: 11,
        backgroundImage: NetworkImage(profileImageUrl!),
        backgroundColor: active ? _kNight.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1),
      );
    } else {
      rawIcon = Icon(
        icon,
        size: 22,
        color: active ? _kLightBlue : _kNight,
      );
    }
    iconWidget = Transform.scale(scale: iconScale, child: rawIcon);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppLogger.client('Dock → $label');
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 14 : 10,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: active ? _kNight : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: active
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kLightBlue,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
