import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../utils/logger.dart';

class ClientBottomNav extends StatelessWidget {
  final int currentTab;
  final void Function(int) onTabChanged;
  final VoidCallback onScanTap;

  const ClientBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    // ── DESIGN ANDROID : Floating Dock ────────────────────────────────────
    return Positioned(
      bottom: bottomPad + 14,
      left: 0, right: 0,
      child: Center(
        child: _FloatingDock(
          isDark: isDark,
          currentTab: currentTab,
          onTabChanged: onTabChanged,
          onScanTap: onScanTap,
        ),
      ),
    );
    // ── Ancien design — gardé pour référence ──────────────────────────────
    // ignore: dead_code
    final navBg = isDark
        ? const Color(0xFF1E1D2A).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    // ignore: dead_code
    final navBorder = isDark
        ? const Color(0xFF2A2840).withValues(alpha: 0.50)
        : const Color(0xFFEDE9E3).withValues(alpha: 0.50);
    // ignore: dead_code
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 76 + bottomPad,
            decoration: BoxDecoration(
              color: navBg,
              border: Border(top: BorderSide(color: navBorder, width: 1)),
            ),
            padding: EdgeInsets.only(bottom: bottomPad + 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavItem(icon: Icons.credit_card_outlined, label: 'Cartes',     index: 0, currentTab: currentTab, onTap: onTabChanged),
                _NavFab(currentTab: currentTab, onTap: onScanTap),
                _NavItem(icon: Icons.history_rounded,      label: 'Historique', index: 2, currentTab: currentTab, onTap: onTabChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating Dock ────────────────────────────────────────────────────────────

class _FloatingDock extends StatelessWidget {
  final bool isDark;
  final int currentTab;
  final void Function(int) onTabChanged;
  final VoidCallback onScanTap;

  const _FloatingDock({
    required this.isDark,
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = const Color(0xFF0D1E37).withValues(alpha: isDark ? 0.94 : 0.90);
    final border = const Color(0xFF2C7BE5).withValues(alpha: 0.22);

    final screenW = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: screenW * 0.72,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DockItem(
                icon: Icons.credit_card_outlined,
                label: 'Cartes',
                index: 0,
                currentTab: currentTab,
                onTap: onTabChanged,
              ),
              _DockScan(onTap: onScanTap),
              _DockItem(
                icon: Icons.history_rounded,
                label: 'Histo',
                index: 2,
                currentTab: currentTab,
                onTap: onTabChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentTab;
  final void Function(int) onTap;

  const _DockItem({
    required this.icon, required this.label, required this.index,
    required this.currentTab, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = currentTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppLogger.client('Dock → $label');
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2C7BE5).withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: active ? 18.0 : 0.0,
              height: 2.5,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2C7BE5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              icon, size: 20,
              color: active
                  ? const Color(0xFF2C7BE5)
                  : Colors.white.withValues(alpha: 0.38),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.3,
              color: active
                  ? const Color(0xFF2C7BE5)
                  : Colors.white.withValues(alpha: 0.35),
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
          ],
        ),
      ),
    );
  }
}

class _DockScan extends StatelessWidget {
  final VoidCallback onTap;
  const _DockScan({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D94F7), Color(0xFF1A4FB3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C7BE5).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

// ── Arc inversé (ancien design, gardé pour référence) ────────────────────────

class _ArcNavBar extends StatelessWidget {
  final double bottomPad;
  final bool isDark;
  final int currentTab;
  final void Function(int) onTabChanged;
  final VoidCallback onScanTap;

  const _ArcNavBar({
    required this.bottomPad,
    required this.isDark,
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
  });

  static const double _arcH   = 26.0;  // hauteur de la bosse vers le haut
  static const double _arcW   = 80.0;  // largeur de la zone de courbe
  static const double _barH   = 64.0;  // hauteur de la barre (hors safe area)
  static const double _fabSz  = 54.0;  // taille du bouton scan

  @override
  Widget build(BuildContext context) {
    final navBg = isDark
        ? const Color(0xFF0F1E35).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94);
    final navBorder = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final total = _barH + bottomPad;

    return SizedBox(
      height: total + _arcH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Fond avec arc concave ──────────────────────────────────────────
          Positioned.fill(
            child: ClipPath(
              clipper: const _ArcClipper(arcH: _arcH, arcW: _arcW),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: navBg,
                    border: Border(top: BorderSide(color: navBorder)),
                  ),
                ),
              ),
            ),
          ),
          // ── Onglets gauche et droite ───────────────────────────────────────
          Positioned(
            bottom: bottomPad,
            left: 0, right: 0,
            height: _barH,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.credit_card_outlined,
                  label: 'Cartes',
                  index: 0,
                  currentTab: currentTab,
                  onTap: onTabChanged,
                ),
                const SizedBox(width: _arcW + 4),
                _NavItem(
                  icon: Icons.history_rounded,
                  label: 'Historique',
                  index: 2,
                  currentTab: currentTab,
                  onTap: onTabChanged,
                ),
              ],
            ),
          ),
          // ── Bouton Scan centré, surélevé dans la courbe ────────────────────
          Positioned(
            bottom: bottomPad + (_barH - _fabSz) / 2 + _arcH * 0.5,
            left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onScanTap,
                child: Container(
                  width: _fabSz, height: _fabSz,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF60A5FA), const Color(0xFF2563EB)]
                          : [const Color(0xFF3D94F7), const Color(0xFF1A4FB3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2C7BE5).withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcClipper extends CustomClipper<Path> {
  final double arcH;
  final double arcW;

  const _ArcClipper({required this.arcH, required this.arcW});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    return Path()
      ..moveTo(0, arcH)
      ..lineTo(cx - arcW / 2, arcH)
      // courbe quadratique vers le haut : point de contrôle au sommet de la bosse
      ..quadraticBezierTo(cx, 0, cx + arcW / 2, arcH)
      ..lineTo(w, arcH)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentTab;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon, required this.label, required this.index,
    required this.currentTab, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = currentTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppLogger.client('Onglet → $label');
          onTap(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? const Color(0xFF2C7BE5) : context.qNavInactive, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF2C7BE5) : context.qNavInactive,
            )),
          ],
        ),
      ),
    );
  }
}

class _NavFab extends StatelessWidget {
  final int currentTab;
  final VoidCallback onTap;
  const _NavFab({required this.currentTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark    = context.isDark;
    final bgColor   = isDark ? const Color(0xFF428CE3) : const Color(0xFF061324);
    final iconColor = isDark ? const Color(0xFF061324) : const Color(0xFF428CE3);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: bgColor.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Icon(Icons.qr_code_scanner_rounded, color: iconColor, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}
