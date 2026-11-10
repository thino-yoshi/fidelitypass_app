import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../../../config/app_colors.dart';

class MerchantPeriodToggle extends StatelessWidget {
  final String period;
  final void Function(String) onChanged;

  const MerchantPeriodToggle({
    super.key,
    required this.period,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) return _buildIOS(context);
    return _buildMaterial(context);
  }

  // ─── Android : toggle custom ────────────────────────────────────────────────
  Widget _buildMaterial(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        _PeriodBtn(value: 'today', label: "Aujourd'hui", current: period, onTap: onChanged),
        _PeriodBtn(value: '7j',    label: '7 jours',     current: period, onTap: onChanged),
        _PeriodBtn(value: '30j',   label: '30 jours',    current: period, onTap: onChanged),
      ]),
    );
  }

  // ─── iOS : CupertinoSlidingSegmentedControl ─────────────────────────────────
  Widget _buildIOS(BuildContext context) {
    return CupertinoSlidingSegmentedControl<String>(
      groupValue: period,
      onValueChanged: (v) { if (v != null) onChanged(v); },
      thumbColor: context.isDark ? const Color(0xFF3A3A3C) : Colors.white,
      backgroundColor: context.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EE),
      children: const {
        'today': Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text("Aujourd'hui", style: TextStyle(fontSize: 12))),
        '7j': Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text('7 jours', style: TextStyle(fontSize: 12))),
        '30j': Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text('30 jours', style: TextStyle(fontSize: 12))),
      },
    );
  }
}

// ─── Android uniquement ───────────────────────────────────────────────────────
class _PeriodBtn extends StatelessWidget {
  final String value;
  final String label;
  final String current;
  final void Function(String) onTap;

  const _PeriodBtn({
    required this.value, required this.label,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? Colors.white : context.cSub)),
        ),
      ),
    );
  }
}
