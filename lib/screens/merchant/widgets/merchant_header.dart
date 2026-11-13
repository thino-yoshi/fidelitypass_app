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
}

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
