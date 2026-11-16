import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

// Écrans de lancement / connexion iPhone (style Apple).
// Android garde les écrans d'origine : rien ici n'est utilisé sur Android.
// auth_screen.dart garde toute la logique (connexion, inscription) et affiche
// ces écrans quand kIsIOS est vrai.

/// Écran plein qui remplit la hauteur sur les grands iPhone et défile
/// seulement si l'écran est trop petit (iPhone SE).
class FillOrScroll extends StatelessWidget {
  final Widget child;
  const FillOrScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        ),
      );
}

/// Compte créé il y a moins de 10 minutes = nouveau client (feuille « Bienvenue »).
bool isFreshAccount() {
  final created = DateTime.tryParse(Supabase.instance.client.auth.currentUser?.createdAt ?? '');
  return created != null && DateTime.now().toUtc().difference(created.toUtc()).inMinutes < 10;
}

/// Message simple quand « Continuer avec Apple » échoue (rien si la personne a fermé la fenêtre).
String appleErrorText(Object e) =>
    e.toString().contains('canceled') ? '' : "La connexion avec Apple n'a pas marché. Réessaie.";

/// Icône Apple (SF Symbol) exportée en image blanche, teintée à l'affichage.
class SfIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const SfIcon(this.name, {super.key, this.size = 22, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Image.asset('assets/images/sf/$name.png',
      height: size, color: color, colorBlendMode: BlendMode.srcIn, filterQuality: FilterQuality.high);
}

/// Fond bleu nuit Qarta : dégradé nuit + halo bleu ciel en haut à droite.
/// Met aussi la barre d'état (heure, batterie) en blanc.
class QartaNightBackground extends StatelessWidget {
  const QartaNightBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final mid = Color.lerp(kNavy, kNavyCard, 0.3)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: IgnorePointer(
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [kNavy, mid, kNavy], stops: const [0, .55, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.75, -1.05), radius: 1.0,
              colors: [kBlueLight.withValues(alpha: .42), kBlueLight.withValues(alpha: 0)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.2, 1.1), radius: 0.9,
              colors: [kPrimary.withValues(alpha: .30), kPrimary.withValues(alpha: 0)],
            ),
          ),
        ),
      ]),
      ),
    );
  }
}

/// Logo Qarta avec un léger halo bleu.
class QartaGlowLogo extends StatelessWidget {
  final double size;
  const QartaGlowLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .23),
          boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: .45), blurRadius: 60, offset: const Offset(0, 20))],
          border: Border.all(color: kBlueLight.withValues(alpha: .25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .23),
          child: Image.asset('assets/images/89.png', fit: BoxFit.cover),
        ),
      );
}

/// Écran de chargement iPhone : logo seul sur le fond bleu nuit.
class SplashIos extends StatelessWidget {
  const SplashIos({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: kNavy,
        body: Stack(fit: StackFit.expand, children: [
          QartaNightBackground(),
          Center(child: QartaGlowLogo(size: 120)),
        ]),
      );
}

/// Bouton plein, en forme de pilule (52 pt).
class QPillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final Color? border;
  const QPillButton({super.key, required this.child, required this.onTap, required this.bg, required this.fg, this.border});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52, width: double.infinity,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Container(
            decoration: ShapeDecoration(
              color: bg,
              shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border!)),
            ),
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4),
              child: child,
            ),
          ),
        ),
      );
}

Widget _labelRow(Widget icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
      icon, const SizedBox(width: 8), Text(text),
    ]);

/// Accueil iPhone : logo, phrase, Continuer avec Apple / Google / email, J'ai un commerce.
class AuthLandingIos extends StatelessWidget {
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onEmail;
  final VoidCallback onMerchant;
  final bool appleLoading;
  final bool googleLoading;
  final String error;

  const AuthLandingIos({
    super.key,
    required this.onApple,
    required this.onGoogle,
    required this.onEmail,
    required this.onMerchant,
    this.appleLoading = false,
    this.googleLoading = false,
    this.error = '',
  });

  @override
  Widget build(BuildContext context) {
    final busy = appleLoading || googleLoading;
    final glassBorder = Colors.white.withValues(alpha: .16);
    return SafeArea(
      child: FillOrScroll(
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const Spacer(flex: 5),
          const QartaGlowLogo(size: 96),
          const SizedBox(height: 26),
          const Text('Qarta', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Text('La fidélité, entre toi\net tes commerces.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: .62), fontSize: 17, height: 1.35, letterSpacing: -0.4)),
          const Spacer(flex: 4),
          if (error.isNotEmpty) ...[
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: kError, fontSize: 15)),
            const SizedBox(height: 12),
          ],
          QPillButton(
            bg: Colors.white, fg: Colors.black,
            onTap: busy ? null : onApple,
            child: appleLoading
                ? const CupertinoActivityIndicator(color: Colors.black)
                : _labelRow(const SfIcon('apple.logo', size: 20, color: Colors.black), 'Continuer avec Apple'),
          ),
          const SizedBox(height: 12),
          QPillButton(
            bg: Colors.white, fg: Colors.black,
            onTap: busy ? null : onGoogle,
            child: googleLoading
                ? const CupertinoActivityIndicator(color: Colors.black)
                : _labelRow(Image.asset('assets/images/google_icon.png', width: 20, height: 20), 'Continuer avec Google'),
          ),
          const SizedBox(height: 12),
          QPillButton(
            bg: Colors.white.withValues(alpha: .10), fg: Colors.white, border: glassBorder,
            onTap: busy ? null : onEmail,
            child: const Text("Continuer avec l'email"),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 18),
            child: Container(height: 1, color: Colors.white.withValues(alpha: .12)),
          ),
          QPillButton(
            bg: Colors.transparent, fg: Colors.white, border: glassBorder,
            onTap: busy ? null : onMerchant,
            child: _labelRow(const SfIcon('storefront.fill', size: 20, color: kBlueLight), "J'ai un commerce"),
          ),
          const SizedBox(height: 16),
        ]),
        ),
      ),
    );
  }
}

/// « Qarta pour ton commerce » : présente l'offre et envoie vers le site.
/// Renvoie 'login' si le commerçant veut se connecter.
class MerchantIntroIos extends StatelessWidget {
  const MerchantIntroIos({super.key});

  static Future<String?> open(BuildContext context) => Navigator.of(context).push<String>(
      CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const MerchantIntroIos()));

  Widget _row(String icon, Color color, String title, String sub) => Row(children: [
        SizedBox(width: 48, child: Center(child: SfIcon(icon, size: 34, color: color))),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: .62), fontSize: 15, height: 1.35, letterSpacing: -0.2)),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: Stack(fit: StackFit.expand, children: [
        const QartaNightBackground(),
        SafeArea(
          child: FillOrScroll(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Semantics(
                  button: true, label: 'Fermer',
                  child: CupertinoButton(
                    padding: EdgeInsets.zero, minimumSize: const Size(44, 44),
                    onPressed: () => Navigator.pop(context),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .12),
                        border: Border.all(color: Colors.white.withValues(alpha: .16)),
                      ),
                      alignment: Alignment.center,
                      child: const SfIcon('xmark', size: 16),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            const Center(child: QartaGlowLogo(size: 72)),
            const SizedBox(height: 20),
            const Text('Qarta pour\nton commerce', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.3)),
            const SizedBox(height: 24), // écart minimum (petit iPhone)
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(children: [
                _row('rectangle.stack.fill', kBlueLight, 'Tes clients ne te perdent plus',
                    "Ta carte de fidélité est dans leur appli Qarta, avec leur historique et leurs récompenses."),
                const SizedBox(height: 26),
                _row('bell.badge.fill', kGold, 'Parle à tes clients, gratuitement',
                    "Des notifications dans l'appli, sans SMS ni numéro de téléphone."),
                const SizedBox(height: 26),
                _row('person.crop.circle.badge.checkmark', kSuccess, 'Connais tes clients',
                    'Qui vient, combien de fois, et quand.'),
              ]),
            ),
            const SizedBox(height: 24),
            const Spacer(flex: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: QPillButton(
                bg: kPrimary, fg: Colors.white,
                onTap: () => launchUrl(Uri.parse('https://qarta.be'), mode: LaunchMode.externalApplication),
                child: const Text('Créer mon espace pro'),
              ),
            ),
            CupertinoButton(
              onPressed: () => Navigator.pop(context, 'login'),
              child: Text.rich(TextSpan(
                style: TextStyle(color: Colors.white.withValues(alpha: .62), fontSize: 17, letterSpacing: -0.4),
                children: const [
                  TextSpan(text: 'Déjà un compte ? '),
                  TextSpan(text: 'Se connecter', style: TextStyle(color: kBlueLight, fontWeight: FontWeight.w600)),
                ],
              )),
            ),
            const SizedBox(height: 8),
          ]),
          ),
        ),
      ]),
    );
  }
}

/// Connexion par email iPhone : champs groupés façon Réglages.
/// La logique (connexion, inscription, code) reste dans auth_screen.dart.
class AuthLoginIos extends StatefulWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMe;
  final bool loading;
  final String error;
  final VoidCallback onLogin;
  final VoidCallback onBack;
  final VoidCallback onCreateAccount;
  final VoidCallback onHaveCode;

  const AuthLoginIos({
    super.key,
    required this.emailCtrl,
    required this.passCtrl,
    required this.rememberMe,
    required this.onRememberMe,
    required this.loading,
    required this.error,
    required this.onLogin,
    required this.onBack,
    required this.onCreateAccount,
    required this.onHaveCode,
  });

  @override
  State<AuthLoginIos> createState() => _AuthLoginIosState();
}

class _AuthLoginIosState extends State<AuthLoginIos> {
  bool _showPass = false;

  @override
  Widget build(BuildContext context) {
    final sub = Colors.white.withValues(alpha: .62);
    final line = Colors.white.withValues(alpha: .12);
    const fieldStyle = TextStyle(color: Colors.white, fontSize: 17, letterSpacing: -0.4);
    final hint = TextStyle(color: Colors.white.withValues(alpha: .38), fontSize: 17, letterSpacing: -0.4);

    Widget field(String label, Widget input) => SizedBox(
          height: 52,
          child: Row(children: [
            SizedBox(width: 112, child: Text(label, style: fieldStyle)),
            Expanded(child: input),
          ]),
        );

    BoxDecoration group() => BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: line),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            button: true, label: 'Retour',
            child: CupertinoButton(
              padding: EdgeInsets.zero, minimumSize: const Size(44, 44),
              onPressed: widget.onBack,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .12),
                  border: Border.all(color: Colors.white.withValues(alpha: .16)),
                ),
                alignment: Alignment.center,
                child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Connexion', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Entre ton email et ton mot de passe.', style: TextStyle(color: sub, fontSize: 17, letterSpacing: -0.4)),
          ),
          const SizedBox(height: 28),
          AutofillGroup(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: group(),
              child: Column(children: [
                field('Email', CupertinoTextField.borderless(
                  controller: widget.emailCtrl,
                  placeholder: 'toi@email.com',
                  placeholderStyle: hint,
                  style: fieldStyle,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  padding: EdgeInsets.zero,
                )),
                Container(height: 0.5, color: line),
                field('Mot de passe', Row(children: [
                  Expanded(
                    child: CupertinoTextField.borderless(
                      controller: widget.passCtrl,
                      placeholder: 'Obligatoire',
                      placeholderStyle: hint,
                      style: fieldStyle,
                      obscureText: !_showPass,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) { if (!widget.loading) widget.onLogin(); },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  Semantics(
                    button: true, label: _showPass ? 'Cacher le mot de passe' : 'Voir le mot de passe',
                    child: CupertinoButton(
                      padding: EdgeInsets.zero, minimumSize: const Size(44, 44),
                      onPressed: () => setState(() => _showPass = !_showPass),
                      child: Icon(_showPass ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                          color: Colors.white.withValues(alpha: .5), size: 20),
                    ),
                  ),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: group(),
            child: Row(children: [
              const Expanded(child: Text('Se souvenir de moi', style: fieldStyle)),
              CupertinoSwitch(value: widget.rememberMe, activeTrackColor: kPrimary, onChanged: widget.onRememberMe),
            ]),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: () {},
              child: const Text('Mot de passe oublié ?',
                  style: TextStyle(color: kBlueLight, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            ),
          ),
          if (widget.error.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(widget.error, style: const TextStyle(color: kError, fontSize: 15)),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: QPillButton(
              bg: kPrimary, fg: Colors.white,
              onTap: widget.loading ? null : widget.onLogin,
              child: widget.loading ? const CupertinoActivityIndicator(color: Colors.white) : const Text('Se connecter'),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: CupertinoButton(
              onPressed: widget.onCreateAccount,
              child: Text.rich(TextSpan(
                style: TextStyle(color: sub, fontSize: 15, letterSpacing: -0.2),
                children: const [
                  TextSpan(text: 'Pas encore de compte ? '),
                  TextSpan(text: 'Créer un compte', style: TextStyle(color: kBlueLight, fontWeight: FontWeight.w600)),
                ],
              ), textAlign: TextAlign.center),
            ),
          ),
          Center(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: widget.onHaveCode,
              child: Text("J'ai déjà un code de vérification",
                  style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 15, letterSpacing: -0.2)),
            ),
          ),
        ]),
      ),
    );
  }
}
