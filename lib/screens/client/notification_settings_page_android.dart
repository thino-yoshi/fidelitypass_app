import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class NotificationSettingsPageAndroid extends StatefulWidget {
  final bool push;
  final bool offres;
  final bool visites;
  final Future<bool> Function(bool push, bool offres, bool visites) onSave;

  const NotificationSettingsPageAndroid({
    super.key,
    required this.push,
    required this.offres,
    required this.visites,
    required this.onSave,
  });

  @override
  State<NotificationSettingsPageAndroid> createState() =>
      _NotificationSettingsPageAndroidState();
}

class _NotificationSettingsPageAndroidState
    extends State<NotificationSettingsPageAndroid> {
  late bool _push    = widget.push;
  late bool _offres  = widget.offres;
  late bool _visites = widget.visites;
  bool _failed = false;

  Future<void> _set(void Function() change, void Function() undo) async {
    setState(() { change(); _failed = false; });
    final ok = await widget.onSave(_push, _offres, _visites);
    if (!ok && mounted) setState(() { undo(); _failed = true; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDark ? const Color(0xFF0F1923) : const Color(0xFFF5F7FA);
    final cardBg     = isDark ? const Color(0xFF1A2535) : Colors.white;
    final textMain   = isDark ? Colors.white : const Color(0xFF0D1B2A);
    final sub        = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF4A6080);
    final borderNorm = isDark ? kBlueLight.withValues(alpha: 0.14) : const Color(0xFFBDD3F8);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: _AppBar(isDark: isDark, textMain: textMain),
      body: Stack(
        children: [
          _Bg(isDark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Groupe de switches
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderNorm),
                      boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: isDark ? 0.04 : 0.07), blurRadius: 12)],
                    ),
                    child: Column(children: [
                      _SwitchTile(
                        title: 'Notifications',
                        subtitle: 'Tampons et récompenses',
                        value: _push,
                        isDark: isDark,
                        textMain: textMain,
                        sub: sub,
                        borderNorm: borderNorm,
                        isLast: false,
                        onChanged: (v) => _set(() => _push = v, () => _push = !v),
                      ),
                      _SwitchTile(
                        title: 'Offres',
                        subtitle: 'Promos de tes commerces',
                        value: _offres,
                        isDark: isDark,
                        textMain: textMain,
                        sub: sub,
                        borderNorm: borderNorm,
                        isLast: false,
                        onChanged: (v) => _set(() => _offres = v, () => _offres = !v),
                      ),
                      _SwitchTile(
                        title: 'Rappels de visite',
                        subtitle: 'Un petit mot après un passage',
                        value: _visites,
                        isDark: isDark,
                        textMain: textMain,
                        sub: sub,
                        borderNorm: borderNorm,
                        isLast: true,
                        onChanged: (v) => _set(() => _visites = v, () => _visites = !v),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _failed
                          ? 'Pas enregistré. Vérifie ta connexion et réessaie.'
                          : 'Choisis ce que Qarta peut t\'envoyer sur ce téléphone.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _failed ? kError : sub,
                      ),
                    ),
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

// ── AppBar ────────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final Color textMain;
  const _AppBar({required this.isDark, required this.textMain});

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
        title: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain)),
      );
    }
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
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// ── Orbes ─────────────────────────────────────────────────────────────────────

class _Bg extends StatelessWidget {
  final bool isDark;
  const _Bg({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: isDark ? _DarkOrb(size) : _LightOrb(size),
        ),
      ),
    );
  }
}

class _LightOrb extends CustomPainter {
  final Size s;
  const _LightOrb(this.s);
  @override
  void paint(Canvas c, Size _) {
    void o(double x, double y, double r, Color col) => c.drawCircle(
      Offset(x * s.width, y * s.height), r,
      Paint()..color = col..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70),
    );
    o(0.15, 0.15, 90, kPrimary.withValues(alpha: 0.08));
    o(0.90, 0.40, 110, kBlueLight.withValues(alpha: 0.07));
  }
  @override bool shouldRepaint(_) => false;
}

class _DarkOrb extends CustomPainter {
  final Size s;
  const _DarkOrb(this.s);
  @override
  void paint(Canvas c, Size _) {
    void o(double x, double y, double r, Color col) => c.drawCircle(
      Offset(x * s.width, y * s.height), r,
      Paint()..color = col..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );
    o(0.10, 0.10, 100, kBlueLight.withValues(alpha: 0.14));
    o(0.90, 0.50, 120, kNavy.withValues(alpha: 0.60));
  }
  @override bool shouldRepaint(_) => false;
}

// ── Ligne Switch ──────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final bool isLast;
  final Color textMain, sub, borderNorm;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.isLast,
    required this.textMain,
    required this.sub,
    required this.borderNorm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textMain)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: sub)),
              ]),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: kPrimary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFD0D8E4),
            ),
          ]),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16, color: borderNorm),
      ],
    );
  }
}
