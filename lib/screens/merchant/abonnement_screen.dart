import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class AbonnementScreen extends StatelessWidget {
  const AbonnementScreen({super.key});

  static const _blueLight = Color(0xFF4A9EFF);
  static const _green     = Color(0xFF27AE60);
  static const _error     = Color(0xFFE24B4A);

  @override
  Widget build(BuildContext context) {
    final kBg     = context.cBg;
    final kWhite  = context.cSurface;
    final kBorder = context.cBorder;
    final kText   = context.cText;
    final kSub    = context.cSub;

    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        // Header with gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF061028), Color(0xFF1A56DB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, 52 + MediaQuery.of(context).padding.top, 20, 20),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Mon abonnement',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ]),
        ),

        // Body
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Plan actuel Pro — blue gradient card (brand element, stays dark)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF0D2F7E)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _blueLight.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF1A56DB).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blueLight.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('✦ Plan actuel', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _blueLight)),
                ),
                const SizedBox(height: 10),
                const Text('Pro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('29€', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  Padding(
                    padding: EdgeInsets.only(bottom: 5, left: 4),
                    child: Text('/mois', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white54)),
                  ),
                ]),
                const SizedBox(height: 14),
                ...[
                  'Clients illimités',
                  'Notifications push',
                  'Statistiques avancées',
                  'Design carte personnalisé',
                ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: _blueLight.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, size: 11, color: _blueLight),
                    ),
                    const SizedBox(width: 8),
                    Text(f, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                  ]),
                )),
              ]),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'FACTURATION',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7),
              ),
            ),

            // Prochain paiement
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Prochain paiement', style: TextStyle(fontSize: 10, color: kSub)),
                  const SizedBox(height: 4),
                  Text(
                    '29€ le 24 avril 2026',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText),
                  ),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Actif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _green)),
                ),
              ]),
            ),

            const SizedBox(height: 10),

            // Méthode de paiement
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Méthode de paiement', style: TextStyle(fontSize: 10, color: kSub)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('VISA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kText)),
                  ),
                  const SizedBox(width: 10),
                  Text('•••• 4242', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
                ]),
              ]),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'AUTRES FORMULES',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kSub, letterSpacing: 0.7),
              ),
            ),

            // Plan Starter
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Gratuit', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kSub)),
                ),
                const SizedBox(height: 10),
                Text('Starter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kText)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('0€', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kText)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 4),
                    child: Text('/mois', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: kSub)),
                  ),
                ]),
                const SizedBox(height: 12),
                _feature(context, "Jusqu'à 50 clients", true),
                _feature(context, 'Notifications push', false),
                _feature(context, 'Statistiques avancées', false),
              ]),
            ),

            const SizedBox(height: 12),

            // Cancel button
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Résiliation envoyée au support'))),
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _error.withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    "Résilier l'abonnement",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _error),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ]),
        )),
      ]),
    );
  }

  Widget _feature(BuildContext context, String label, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: active ? _green.withValues(alpha: 0.12) : context.cBorder,
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.check_rounded : Icons.close_rounded,
            size: 11,
            color: active ? _green : context.cSub,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: active ? context.cText : context.cSub)),
      ]),
    );
  }
}
