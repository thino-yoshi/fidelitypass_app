import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class PersonalInfoPageAndroid extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final bool emailLocked;
  final String? lockedBy;
  final Future<void> Function(String name, String email, String phone) onSave;

  const PersonalInfoPageAndroid({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.emailLocked,
    required this.onSave,
    this.lockedBy,
  });

  @override
  State<PersonalInfoPageAndroid> createState() => _PersonalInfoPageAndroidState();
}

class _PersonalInfoPageAndroidState extends State<PersonalInfoPageAndroid> {
  late final TextEditingController _nameCtrl  = TextEditingController(text: widget.name);
  late final TextEditingController _emailCtrl = TextEditingController(text: widget.email);
  late final TextEditingController _phoneCtrl = TextEditingController(text: widget.phone);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _changed =>
      _nameCtrl.text.trim() != widget.name ||
      (!widget.emailLocked && _emailCtrl.text.trim() != widget.email) ||
      _phoneCtrl.text.trim() != widget.phone;

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _phoneCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bg          = isDark ? const Color(0xFF0F1923) : const Color(0xFFF5F7FA);
    final cardBg      = isDark ? const Color(0xFF1A2535) : Colors.white;
    final textMain    = isDark ? Colors.white : const Color(0xFF0D1B2A);
    final sub         = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF4A6080);
    final borderNorm  = isDark ? kBlueLight.withValues(alpha: 0.14) : const Color(0xFFBDD3F8);
    final iconBg      = isDark ? kBlueLight.withValues(alpha: 0.14) : kPrimary.withValues(alpha: 0.10);
    final iconColor   = isDark ? kBlueLight : kPrimary;

    final canSave = _changed && _nameCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: _AppBarAndroid(
        isDark: isDark,
        textMain: textMain,
        iconColor: iconColor,
        canSave: canSave,
        saving: _saving,
        onSave: _save,
      ),
      body: Stack(
        children: [
          _AndroidBg(isDark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Badge compte OAuth
                  if (widget.emailLocked) ...[
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (widget.lockedBy == 'Google' ? Colors.orange : Colors.grey)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Compte ${widget.lockedBy ?? 'OAuth'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.lockedBy == 'Google' ? Colors.orange : Colors.grey,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Email géré par ${widget.lockedBy ?? 'ton compte'}. Il se change depuis ce compte.',
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 4),

                  // Champs
                  _Field(
                    icon: Icons.person_rounded,
                    label: 'Nom & Prénom',
                    ctrl: _nameCtrl,
                    isDark: isDark,
                    cardBg: cardBg,
                    textMain: textMain,
                    sub: sub,
                    borderNorm: borderNorm,
                    iconBg: iconBg,
                    iconColor: iconColor,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    ctrl: _emailCtrl,
                    keyboard: TextInputType.emailAddress,
                    readOnly: widget.emailLocked,
                    isDark: isDark,
                    cardBg: cardBg,
                    textMain: textMain,
                    sub: sub,
                    borderNorm: borderNorm,
                    iconBg: iconBg,
                    iconColor: iconColor,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    ctrl: _phoneCtrl,
                    keyboard: TextInputType.phone,
                    isDark: isDark,
                    cardBg: cardBg,
                    textMain: textMain,
                    sub: sub,
                    borderNorm: borderNorm,
                    iconBg: iconBg,
                    iconColor: iconColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AppBar glassmorphism ──────────────────────────────────────────────────────

class _AppBarAndroid extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final Color textMain;
  final Color iconColor;
  final bool canSave;
  final bool saving;
  final VoidCallback onSave;

  const _AppBarAndroid({
    required this.isDark,
    required this.textMain,
    required this.iconColor,
    required this.canSave,
    required this.saving,
    required this.onSave,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (!isDark) {
      return AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: const Color(0xFF0D1B2A),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Informations personnelles',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain),
        ),
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: canSave ? onSave : null,
              child: Text(
                'Enregistrer',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: canSave ? kPrimary : const Color(0xFF4A6080).withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      );
    }

    // Mode nuit : glassmorphism
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [kBlueLight.withValues(alpha: 0.22), kNavy.withValues(alpha: 0.50)],
            ),
            border: Border(bottom: BorderSide(color: kBlueLight.withValues(alpha: 0.14))),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Informations personnelles',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            actions: [
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))),
                )
              else
                TextButton(
                  onPressed: canSave ? onSave : null,
                  child: Text(
                    'Enregistrer',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: canSave ? kBlueLight : Colors.white.withValues(alpha: 0.3),
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

// ── Orbes de fond ─────────────────────────────────────────────────────────────

class _AndroidBg extends StatelessWidget {
  final bool isDark;
  const _AndroidBg({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (!isDark) {
      return Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _LightOrbPainter(size)),
        ),
      );
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _DarkOrbPainter(size)),
      ),
    );
  }
}

class _LightOrbPainter extends CustomPainter {
  final Size size;
  const _LightOrbPainter(this.size);

  @override
  void paint(Canvas canvas, Size _) {
    void orb(double x, double y, double r, Color c) {
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70),
      );
    }
    orb(0.15, 0.08, 90, kPrimary.withValues(alpha: 0.08));
    orb(0.90, 0.22, 110, kBlueLight.withValues(alpha: 0.07));
    orb(0.50, 0.70, 100, kPrimary.withValues(alpha: 0.05));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DarkOrbPainter extends CustomPainter {
  final Size size;
  const _DarkOrbPainter(this.size);

  @override
  void paint(Canvas canvas, Size _) {
    void orb(double x, double y, double r, Color c) {
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
      );
    }
    orb(0.10, 0.10, 100, kBlueLight.withValues(alpha: 0.14));
    orb(0.90, 0.30, 120, kNavy.withValues(alpha: 0.60));
    orb(0.40, 0.80, 100, kPrimary.withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Champ éditable ────────────────────────────────────────────────────────────

class _Field extends StatefulWidget {
  final IconData icon;
  final String label;
  final TextEditingController ctrl;
  final TextInputType keyboard;
  final bool readOnly;
  final bool isDark;
  final Color cardBg, textMain, sub, borderNorm, iconBg, iconColor;

  const _Field({
    required this.icon,
    required this.label,
    required this.ctrl,
    this.keyboard = TextInputType.text,
    this.readOnly = false,
    required this.isDark,
    required this.cardBg,
    required this.textMain,
    required this.sub,
    required this.borderNorm,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final borderFoc = widget.isDark
        ? kBlueLight.withValues(alpha: 0.50)
        : kPrimary.withValues(alpha: 0.45);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _focused ? borderFoc : widget.borderNorm),
        boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: widget.isDark ? 0.04 : 0.06), blurRadius: 8)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: widget.iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(widget.icon, color: widget.iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v && !widget.readOnly),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: TextStyle(fontSize: 11, color: widget.sub)),
                widget.readOnly
                    ? Text(
                        widget.ctrl.text.isEmpty ? 'Non renseigné' : widget.ctrl.text,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: widget.textMain),
                      )
                    : TextField(
                        controller: widget.ctrl,
                        keyboardType: widget.keyboard,
                        cursorColor: widget.iconColor,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: widget.textMain),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: widget.ctrl.text.isEmpty ? 'Non renseigné' : null,
                          hintStyle: TextStyle(color: widget.sub, fontWeight: FontWeight.w400),
                        ),
                      ),
              ],
            ),
          ),
        ),
        if (widget.readOnly)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.lock_outline_rounded, color: widget.sub, size: 16),
          ),
      ]),
    );
  }
}
