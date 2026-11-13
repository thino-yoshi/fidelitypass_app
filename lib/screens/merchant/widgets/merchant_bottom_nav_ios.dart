import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../config/app_colors.dart';

class MerchantBottomNavIos extends StatelessWidget {
  final int currentTab;
  final void Function(int) onTabChanged;
  final VoidCallback onScanTap;

  const MerchantBottomNavIos({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark       = context.isDark;
    final dividerColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE0E0E5);
    final barBg        = (isDark ? const Color(0xFF1C1C1E) : Colors.white).withValues(alpha: 0.85);
    final bottom       = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 83 + bottom,
            decoration: BoxDecoration(
              color: barBg,
              border: Border(top: BorderSide(color: dividerColor, width: 0.5)),
            ),
            padding: EdgeInsets.only(bottom: bottom),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Row(children: [
                _IosNavItem(icon: CupertinoIcons.house_fill,  label: 'Accueil',    index: 0, currentTab: currentTab, onTap: onTabChanged),
                _IosNavScanBtn(onTap: onScanTap),
                _IosNavItem(icon: CupertinoIcons.clock_fill,  label: 'Historique', index: 2, currentTab: currentTab, onTap: onTabChanged),
              ]),
            )),
          ),
        ),
      ),
    );
  }
}

class _IosNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentTab;
  final void Function(int) onTap;

  const _IosNavItem({
    required this.icon, required this.label, required this.index,
    required this.currentTab, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = currentTab == index;
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => onTap(index),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
            color: active ? CupertinoColors.activeBlue : const Color(0xFF8E8E93),
            size: 24),
          const SizedBox(height: 3),
          Text(label,
            style: TextStyle(
              fontSize: 10,
              color: active ? CupertinoColors.activeBlue : const Color(0xFF8E8E93),
            )),
        ]),
      ),
    );
  }
}

class _IosNavScanBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _IosNavScanBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: kPrimary.withValues(alpha: 0.4),
                  blurRadius: 14, offset: const Offset(0, 4),
                )],
              ),
              child: const Icon(CupertinoIcons.qrcode_viewfinder, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 3),
            const Text('Scanner',
              style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }
}
