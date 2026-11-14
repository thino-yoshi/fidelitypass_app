import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';
import 'client_notifications_ios.dart' show GlassBackButton;
import 'client_header_ios.dart' show iosReadableWidth;

// Écrans du profil en style Réglages iPhone :
// grand titre, listes blanches arrondies, textes 17 pt, aucun cadre coloré.

/// Page de réglages : bouton retour en verre, action à droite (ex. « Enregistrer »),
/// grand titre, puis les groupes.
class IosSettingsPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? action;
  const IosSettingsPage({super.key, required this.title, required this.children, this.action});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.cBg,
        body: iosReadableWidth(ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, MediaQuery.of(context).padding.bottom + 30),
          children: [
            Row(children: [
              GlassBackButton(onTap: () => Navigator.maybePop(context)),
              const Spacer(),
              if (action != null) action!,
            ]),
            const SizedBox(height: 14),
            Text(title, style: QText.largeTitle(context).copyWith(color: context.cText)),
            const SizedBox(height: 8),
            ...children,
          ],
        )),
      ),
    );
  }
}

/// Bouton texte en haut à droite (« Enregistrer », « OK »…).
class IosTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const IosTextAction({super.key, required this.label, this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    if (busy) return const Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator());
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: onTap,
      child: Text(label,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
              color: onTap == null ? context.cSub.withValues(alpha: 0.6) : kPrimary)),
    );
  }
}

/// Groupe façon Réglages : titre en petites majuscules, liste blanche, note dessous.
class IosGroup extends StatelessWidget {
  final String? header;
  final String? footer;
  final Color? footerColor;
  final List<Widget> children;
  final double dividerInset;
  const IosGroup({super.key, this.header, this.footer, this.footerColor, required this.children, this.dividerInset = 16});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(header!.toUpperCase(), style: QText.label.copyWith(color: context.cSub)),
          ),
        Container(
          decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Padding(padding: EdgeInsets.only(left: dividerInset), child: Container(height: 0.5, color: context.cBorder)),
              children[i],
            ],
          ]),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(footer!, style: QText.label.copyWith(color: footerColor ?? context.cSub)),
          ),
      ]),
    );
  }
}

/// Ligne de saisie : libellé à gauche, champ à droite (ou cadenas si non modifiable).
class IosFieldRow extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboard;
  final bool readOnly;
  final bool obscure;
  final double labelWidth;
  const IosFieldRow({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder = '',
    this.keyboard = TextInputType.text,
    this.readOnly = false,
    this.obscure = false,
    this.labelWidth = 104,
  });

  @override
  State<IosFieldRow> createState() => _IosFieldRowState();
}

class _IosFieldRowState extends State<IosFieldRow> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Row(children: [
          SizedBox(width: widget.labelWidth, child: Text(widget.label, style: QText.body.copyWith(fontSize: 17, color: context.cText))),
          Expanded(
            child: CupertinoTextField.borderless(
              controller: widget.controller,
              readOnly: widget.readOnly,
              obscureText: _hidden,
              keyboardType: widget.keyboard,
              placeholder: widget.placeholder,
              padding: EdgeInsets.zero,
              style: QText.body.copyWith(fontSize: 17, color: widget.readOnly ? context.cSub : context.cText),
              placeholderStyle: QText.body.copyWith(fontSize: 17, color: context.cSub.withValues(alpha: 0.7)),
            ),
          ),
          if (widget.readOnly) Icon(CupertinoIcons.lock_fill, size: 15, color: context.cSub.withValues(alpha: 0.7)),
          if (widget.obscure)
            GestureDetector(
              onTap: () => setState(() => _hidden = !_hidden),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(_hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 20, color: context.cSub),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Ligne avec interrupteur et petite explication.
class IosSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const IosSwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: QText.body.copyWith(fontSize: 17, color: context.cText)),
            if (subtitle != null) Text(subtitle!, style: QText.caption.copyWith(fontSize: 14, color: context.cSub)),
          ]),
        ),
        CupertinoSwitch(value: value, activeTrackColor: kSuccess, onChanged: onChanged),
      ]),
    );
  }
}

// ── Informations personnelles ────────────────────────────────────────────────

class PersonalInfoPageIos extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final bool emailLocked;         // compte Apple ou Google
  final String? lockedBy;         // « Apple » | « Google »
  final Future<void> Function(String name, String email, String phone) onSave;
  const PersonalInfoPageIos({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.emailLocked,
    required this.onSave,
    this.lockedBy,
  });

  @override
  State<PersonalInfoPageIos> createState() => _PersonalInfoPageIosState();
}

class _PersonalInfoPageIosState extends State<PersonalInfoPageIos> {
  late final _name = TextEditingController(text: widget.name);
  late final _email = TextEditingController(text: widget.email);
  late final _phone = TextEditingController(text: widget.phone);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _phone]) {
      c.addListener(() => setState(() {}));
    }
  }

  bool get _changed =>
      _name.text.trim() != widget.name ||
      (!widget.emailLocked && _email.text.trim() != widget.email) ||
      _phone.text.trim() != widget.phone;

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_name.text.trim(), _email.text.trim(), _phone.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return IosSettingsPage(
      title: 'Informations personnelles',
      action: IosTextAction(label: 'Enregistrer', busy: _saving, onTap: _changed && _name.text.trim().isNotEmpty ? _save : null),
      children: [
        IosGroup(
          footer: widget.emailLocked ? 'Ton email est géré par ${widget.lockedBy ?? 'Apple'}. Il se change depuis ce compte.' : null,
          children: [
            IosFieldRow(label: 'Nom', controller: _name, placeholder: 'Prénom et nom'),
            IosFieldRow(label: 'Email', controller: _email, placeholder: 'ton@email.fr',
                keyboard: TextInputType.emailAddress, readOnly: widget.emailLocked),
            IosFieldRow(label: 'Téléphone', controller: _phone, placeholder: 'Facultatif', keyboard: TextInputType.phone),
          ],
        ),
      ],
    );
  }
}

// ── Mot de passe ─────────────────────────────────────────────────────────────

class ChangePasswordPageIos extends StatefulWidget {
  /// Renvoie null si c'est bon, sinon le message d'erreur à afficher.
  final Future<String?> Function(String current, String next) onSave;
  const ChangePasswordPageIos({super.key, required this.onSave});

  @override
  State<ChangePasswordPageIos> createState() => _ChangePasswordPageIosState();
}

class _ChangePasswordPageIosState extends State<ChangePasswordPageIos> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _next, _confirm]) {
      c.addListener(() => setState(() => _error = null));
    }
  }

  bool get _filled => _current.text.isNotEmpty && _next.text.isNotEmpty && _confirm.text.isNotEmpty;

  Future<void> _save() async {
    if (_next.text != _confirm.text) {
      setState(() => _error = 'Les deux nouveaux mots de passe ne sont pas identiques.');
      return;
    }
    setState(() => _saving = true);
    final err = await widget.onSave(_current.text, _next.text);
    if (!mounted) return;
    if (err == null) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } else {
      setState(() { _saving = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IosSettingsPage(
      title: 'Mot de passe',
      action: IosTextAction(label: 'Enregistrer', busy: _saving, onTap: _filled ? _save : null),
      children: [
        IosGroup(children: [
          IosFieldRow(label: 'Actuel', controller: _current, placeholder: 'Mot de passe actuel', obscure: true),
        ]),
        IosGroup(
          footer: _error,
          footerColor: _error != null ? kError : null,
          children: [
            IosFieldRow(label: 'Nouveau', controller: _next, placeholder: 'Nouveau mot de passe', obscure: true),
            IosFieldRow(label: 'Confirmer', controller: _confirm, placeholder: 'Retape-le', obscure: true),
          ],
        ),
      ],
    );
  }
}

// ── Réglages des notifications ───────────────────────────────────────────────

class NotificationSettingsPageIos extends StatefulWidget {
  final bool push, offres, visites;
  /// Enregistre les 3 réglages ; renvoie false si l'envoi au serveur a raté.
  final Future<bool> Function(bool push, bool offres, bool visites) onSave;
  const NotificationSettingsPageIos({super.key, required this.push, required this.offres, required this.visites, required this.onSave});

  @override
  State<NotificationSettingsPageIos> createState() => _NotificationSettingsPageIosState();
}

class _NotificationSettingsPageIosState extends State<NotificationSettingsPageIos> {
  late bool _push = widget.push, _offres = widget.offres, _visites = widget.visites;
  bool _failed = false;

  // Comme dans Réglages : chaque interrupteur s'enregistre tout de suite.
  // Si l'envoi rate, on remet l'interrupteur comme avant et on le dit.
  Future<void> _set(void Function() change, void Function() undo) async {
    setState(() { change(); _failed = false; });
    final ok = await widget.onSave(_push, _offres, _visites);
    if (!ok && mounted) setState(() { undo(); _failed = true; });
  }

  @override
  Widget build(BuildContext context) {
    return IosSettingsPage(
      title: 'Notifications',
      children: [
        IosGroup(
          footer: _failed
              ? 'Pas enregistré. Vérifie ta connexion et réessaie.'
              : 'Choisis ce que Qarta peut t\'envoyer sur ce téléphone.',
          footerColor: _failed ? kError : null,
          children: [
            IosSwitchRow(title: 'Notifications', subtitle: 'Tampons et récompenses', value: _push,
                onChanged: (v) => _set(() => _push = v, () => _push = !v)),
            IosSwitchRow(title: 'Offres', subtitle: 'Promos de tes commerces', value: _offres,
                onChanged: (v) => _set(() => _offres = v, () => _offres = !v)),
            IosSwitchRow(title: 'Rappels de visite', subtitle: 'Un petit mot après un passage', value: _visites,
                onChanged: (v) => _set(() => _visites = v, () => _visites = !v)),
          ],
        ),
      ],
    );
  }
}

// ── Aide et support ──────────────────────────────────────────────────────────

class HelpPageIos extends StatefulWidget {
  final List<({String q, String a})> faqs;
  final String email;
  const HelpPageIos({super.key, required this.faqs, required this.email});

  @override
  State<HelpPageIos> createState() => _HelpPageIosState();
}

class _HelpPageIosState extends State<HelpPageIos> {
  int? _open;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.email));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copied = false); });
  }

  @override
  Widget build(BuildContext context) {
    return IosSettingsPage(
      title: 'Aide et support',
      children: [
        IosGroup(
          header: 'Questions fréquentes',
          children: [
            for (var i = 0; i < widget.faqs.length; i++) _faq(i),
          ],
        ),
        IosGroup(
          header: 'Nous contacter',
          footer: 'On te répond sous 24 h.',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(CupertinoIcons.mail_solid, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(child: SelectableText(widget.email, style: QText.body.copyWith(fontSize: 17, color: context.cText))),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: _copy,
                  child: Text(_copied ? 'Copié' : 'Copier',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _copied ? kSuccess : kPrimary)),
                ),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  // Question qui s'ouvre au toucher (une seule ouverte à la fois).
  Widget _faq(int i) {
    final f = widget.faqs[i];
    final open = _open == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = open ? null : i),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(f.q, style: QText.body.copyWith(fontSize: 17, color: context.cText))),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(CupertinoIcons.chevron_forward, size: 16, color: context.cSub.withValues(alpha: 0.7)),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(f.a, style: QText.caption.copyWith(color: context.cSub, height: 1.35)),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}
