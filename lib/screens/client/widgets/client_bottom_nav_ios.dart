import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Barre du bas iOS de l'espace client : pilule « Liquid Glass » bleu nuit
/// (signature Qarta), Cartes · Scanner (au milieu, bleu ciel) · Historique.
/// La bulle sous l'onglet actif glisse d'un onglet à l'autre.
class ClientBottomNavIos extends StatelessWidget {
  final int currentTab; // 0 = Cartes, 2 = Historique
  final void Function(int) onTabChanged;
  final VoidCallback onScanTap;

  const ClientBottomNavIos({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.onScanTap,
  });

  static const double barHeight = 66;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 20, right: 20,
      // Quand le clavier est ouvert, la marge du bas vaut 0 : on garde 8 au minimum.
      bottom: bottom - 14 < 8 ? 8 : bottom - 14,
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(barHeight / 2),
          boxShadow: [
            BoxShadow(color: kNavy.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(barHeight / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barHeight / 2),
                // Verre bleu nuit, légèrement plus clair en haut (reflet).
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  // Plus transparent (verre) : on devine les cartes derrière la barre.
                  colors: [kNavyCard.withValues(alpha: 0.55), kNavy.withValues(alpha: 0.62)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              padding: const EdgeInsets.all(5),
              child: LayoutBuilder(builder: (context, c) {
                final slot = c.maxWidth / 3;
                final bubbleIndex = currentTab == 2 ? 2 : 0;
                return Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: slot * bubbleIndex, top: 0, bottom: 0, width: slot,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        color: kBlueLight.withValues(alpha: 0.14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                    ),
                  ),
                  Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Item(icon: CupertinoIcons.rectangle_stack, label: 'Cartes', active: currentTab == 0, onTap: () => onTabChanged(0)),
                    _ScanBtn(onTap: onScanTap),
                    _Item(icon: CupertinoIcons.clock, label: 'Historique', active: currentTab == 2, onTap: () => onTabChanged(2)),
                  ]),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? kBlueLight : Colors.white.withValues(alpha: 0.55);
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(height: 30, child: Center(child: Icon(icon, color: color, size: 24))),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _ScanBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Center(
          child: Container(
            width: 72, height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [kBlueLight, kPrimary],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: 0.65), blurRadius: 18)],
            ),
            child: const Icon(CupertinoIcons.qrcode_viewfinder, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
