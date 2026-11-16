import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../auth_screen_ios.dart' show SfIcon, FillOrScroll;

/// Affiche l'espace client, puis la feuille « Bienvenue dans Qarta » par-dessus
/// (une seule fois, juste après la création du compte). iPhone uniquement.
class ClientWelcomeGate extends StatefulWidget {
  final Widget child;
  const ClientWelcomeGate({super.key, required this.child});

  @override
  State<ClientWelcomeGate> createState() => _ClientWelcomeGateState();
}

class _ClientWelcomeGateState extends State<ClientWelcomeGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 450));
      if (mounted) showClientWelcomeSheet(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showClientWelcomeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: kNavy.withValues(alpha: .35),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(38))),
    builder: (ctx) => const _WelcomeSheet(),
  );
}

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet();

  static const _text = Color(0xFF1A1828);
  static const _sub = Color(0xFF9096A4);

  Widget _row(String icon, Color color, String title, String sub) => Row(children: [
        SizedBox(width: 52, child: Center(child: SfIcon(icon, size: 36, color: color))),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: _sub, fontSize: 15, height: 1.35, letterSpacing: -0.2)),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return SizedBox(
      height: h * 0.92,
      child: FillOrScroll(
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(children: [
          const SizedBox(height: 32), // marge du haut minimum (petit iPhone)
          const Spacer(flex: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(16.5),
            child: Image.asset('assets/images/89.png', width: 72, height: 72),
          ),
          const SizedBox(height: 22),
          const Text('Bienvenue\ndans Qarta', textAlign: TextAlign.center,
              style: TextStyle(color: _text, fontSize: 34, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: 0.4)),
          const SizedBox(height: 24), // écart minimum (petit iPhone)
          const Spacer(flex: 2),
          _row('rectangle.stack.fill', kPrimary, 'Toutes tes cartes au même endroit',
              'Tes cartes de fidélité, ton historique et tes récompenses.'),
          const SizedBox(height: 30),
          _row('qrcode.viewfinder', kSuccess, 'Scanne pour ajouter une carte',
              'Scanne le QR code de ton commerce, ta carte arrive tout de suite.'),
          const SizedBox(height: 30),
          _row('gift.fill', kGold, "Tes récompenses t'attendent",
              "À chaque passage, un tampon. Ta carte remplie, c'est cadeau."),
          const SizedBox(height: 24),
          const Spacer(flex: 4),
          SizedBox(
            width: double.infinity, height: 52,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: kPrimary,
              borderRadius: BorderRadius.circular(26),
              onPressed: () => Navigator.pop(context),
              child: const Text('Continuer',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
            ),
          ),
          const SizedBox(height: 24),
        ]),
        ),
      ),
    );
  }
}
