import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class MerchantPeriodToggleIos extends StatelessWidget {
  final String period;
  final void Function(String) onChanged;

  const MerchantPeriodToggleIos({
    super.key,
    required this.period,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
