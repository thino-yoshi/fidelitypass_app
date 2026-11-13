import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../config/app_colors.dart';

class MerchantBottomNav extends StatelessWidget {
  final int currentTab;
  final void Function(int) onTabChanged;
  final VoidCallback onScanTap;

  const MerchantBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 74 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(
          color: context.cSurface,
          border: Border(top: BorderSide(color: context.cBorder)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 2),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Row(children: [
            _NavItem(icon: Icons.home,    label: 'Accueil',    index: 0, currentTab: currentTab, onTap: onTabChanged),
            _NavScanFab(onTap: onScanTap),
            _NavItem(icon: Icons.history, label: 'Historique', index: 2, currentTab: currentTab, onTap: onTabChanged),
          ]),
        )),
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
        onTap: () => onTap(index),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? kPrimary : context.cSub, size: 22),
          const SizedBox(height: 3),
          Text(label,
            style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600,
              color: active ? kPrimary : context.cSub)),
        ]),
      ),
    );
  }
}

class _NavScanFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NavScanFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: kBlueLight,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                  color: kBlueLight.withValues(alpha: 0.5),
                  blurRadius: 18, offset: const Offset(0, 6),
                )],
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 2),
            Text('Scanner',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: context.cSub)),
          ],
        ),
      ),
    );
  }
}
