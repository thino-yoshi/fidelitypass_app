import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class GoogleAutoScreen extends StatefulWidget {
  final String token;
  final Map merchantInfo;
  const GoogleAutoScreen({super.key, required this.token, required this.merchantInfo});

  @override
  State<GoogleAutoScreen> createState() => _GoogleAutoScreenState();
}

class _GoogleAutoScreenState extends State<GoogleAutoScreen> {
  bool   _enabled = false;
  String _trigger = 'visite';
  String _target  = 'all';

  String get _businessName =>
      (widget.merchantInfo['business_name'] ?? 'votre commerce').toString();

  String get _preview =>
      'Merci pour votre visite chez $_businessName ! Laissez-nous un avis '
      'Google et recevez +5 points sur votre carte fidélité.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
          decoration: const BoxDecoration(color: kNavy),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 17, color: Colors.white),
            ),
            const Text('Avis Google',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
          children: [
            _buildCard(context),
            const SizedBox(height: 12),
            _buildInfo(context),
          ],
        )),
      ]),
    );
  }

  // ── Carte principale ─────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1a3a6b), Color(0xFF0f2044)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF4A9EF5).withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header toggle
      Row(children: [
        Container(
          width: 34, height: 34, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: const Text('G',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Avis Google automatique',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Le client reçoit +5 points s\'il laisse un avis',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF93c5fd))),
        ])),
        _ToggleSwitch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
      ]),
      const SizedBox(height: 12),

      // Aperçu message
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MESSAGE ENVOYÉ', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.6)),
          const SizedBox(height: 5),
          Text('"$_preview"', style: const TextStyle(
              fontSize: 10.5, color: Colors.white, fontStyle: FontStyle.italic, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 12),

      // Déclencheur
      Text('ENVOYER AUTOMATIQUEMENT', style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.6)),
      const SizedBox(height: 6),
      Row(children: [
        _triggerBtn('visite',    'Après chaque visite', '1h après le tampon'),
        const SizedBox(width: 5),
        _triggerBtn('recompense', 'À la récompense',    'Quand carte complète'),
        const SizedBox(width: 5),
        _triggerBtn('3tampons',  '3ème tampon',         'Client régulier'),
      ]),
      const SizedBox(height: 12),

      // Cible
      Text('ENVOYER À', style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.6)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _targetChip('all',    'Tous les clients'),
        _targetChip('loyal',  'Fidèles 5+ tampons'),
        _targetChip('recent', 'Récents 7j'),
      ]),
      const SizedBox(height: 14),

      // Bouton activer
      SizedBox(
        width: double.infinity, height: 40,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C7BE5), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _onActivate,
          icon: const Icon(Icons.check, size: 14),
          label: const Text('Activer cette automatisation',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  );

  // ── Notice bientôt disponible ────────────────────────────────────────────────

  Widget _buildInfo(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFDE68A))),
    child: const Text(
      'Cette fonctionnalité sera disponible prochainement. '
      'Ton lien Google Avis sera configuré automatiquement depuis ton profil qarta.be.',
      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.5)),
  );

  // ── Widgets ──────────────────────────────────────────────────────────────────

  Widget _triggerBtn(String value, String label, String sub) {
    final sel = _trigger == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _trigger = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF2C7BE5) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? const Color(0xFF2C7BE5) : Colors.white.withValues(alpha: 0.15))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(sub,   style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.6))),
        ]),
      ),
    ));
  }

  Widget _targetChip(String value, String label) {
    final sel = _target == value;
    return GestureDetector(
      onTap: () => setState(() => _target = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF2C7BE5) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? const Color(0xFF2C7BE5) : Colors.white.withValues(alpha: 0.15))),
        child: Text(label,
            style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _onActivate() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Cette automatisation sera disponible prochainement'),
      backgroundColor: Color(0xFF1a3a6b),
      behavior: SnackBarBehavior.floating));
  }
}

// ── Toggle switch ─────────────────────────────────────────────────────────────

class _ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF2C7BE5) : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(11)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ),
    );
  }
}
