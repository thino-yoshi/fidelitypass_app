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
    final navBg = isDark
        ? const Color(0xFF1E1D2A).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    final navBorder = isDark
        ? const Color(0xFF2A2840).withValues(alpha: 0.50)
        : const Color(0xFFEDE9E3).withValues(alpha: 0.50);

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
