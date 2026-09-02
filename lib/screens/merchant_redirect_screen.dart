import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchantRedirectScreen extends StatelessWidget {
  const MerchantRedirectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1526),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A9EFF).withValues(alpha: 0.12),
                  border: Border.all(
                    color: const Color(0xFF4A9EFF),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.store_outlined,
                  color: Color(0xFF4A9EFF),
                  size: 32,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Créez votre espace\ncommerçant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Pour choisir votre abonnement et\nconfigurer votre compte, rendez-vous\nsur notre site.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1E35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Column(
                  children: [
                    _RedirectFeature(
                      icon: Icons.inventory_2_outlined,
                      label: 'Choix de votre abonnement',
                    ),
                    _RedirectFeature(
                      icon: Icons.timer_outlined,
                      label: 'Activation en moins de 5 min',
                    ),
                    _RedirectFeature(
                      icon: Icons.star_outline_rounded,
                      label: 'Carte fidélité prête à l\'emploi',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://qarta.be');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Color(0xFF0D1526),
                  ),
                  label: const Text(
                    'Aller sur qarta.be',
                    style: TextStyle(
                      color: Color(0xFF0D1526),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A9EFF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () {
                  Navigator.pop(context); // ✅ retour propre
                },
                child: Text(
                  'Retour',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RedirectFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RedirectFeature({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4A9EFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4A9EFF), size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}