import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';

class HelpPageAndroid extends StatefulWidget {
  final List<({String q, String a})> faqs;
  final String email;

  const HelpPageAndroid({
    super.key,
    required this.faqs,
    required this.email,
  });

  @override
  State<HelpPageAndroid> createState() => _HelpPageAndroidState();
}

class _HelpPageAndroidState extends State<HelpPageAndroid> {
  int? _open;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.email));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDark ? const Color(0xFF0F1923) : const Color(0xFFF5F7FA);
    final cardBg     = isDark ? const Color(0xFF1A2535) : Colors.white;
    final textMain   = isDark ? Colors.white : const Color(0xFF0D1B2A);
    final sub        = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF4A6080);
    final borderNorm = isDark ? kBlueLight.withValues(alpha: 0.14) : const Color(0xFFBDD3F8);
    final labelColor = isDark ? kBlueLight.withValues(alpha: 0.7) : const Color(0xFF7A99C0);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: _AppBar(isDark: isDark, textMain: textMain),
      body: Stack(
        children: [
          _Bg(isDark: isDark),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                const SizedBox(height: 8),

                // Label section
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('QUESTIONS FRÉQUENTES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: labelColor)),
                ),

                // FAQ accordéon
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderNorm),
                    boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: isDark ? 0.04 : 0.07), blurRadius: 12)],
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < widget.faqs.length; i++)
                        _FaqTile(
                          faq: widget.faqs[i],
                          isOpen: _open == i,
                          isLast: i == widget.faqs.length - 1,
                          isDark: isDark,
                          textMain: textMain,
                          sub: sub,
                          borderNorm: borderNorm,
                          onTap: () => setState(() => _open = _open == i ? null : i),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Label section contact
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('NOUS CONTACTER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: labelColor)),
                ),

                // Email contact
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderNorm),
                    boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: isDark ? 0.04 : 0.07), blurRadius: 12)],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: isDark ? 0.18 : 1.0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.email_rounded, color: isDark ? kBlueLight : Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.email,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _copy,
                      child: Text(
                        _copied ? 'Copié ✓' : 'Copier',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _copied ? kSuccess : kPrimary,
                        ),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('On te répond sous 24 h.',
                      style: TextStyle(fontSize: 12, color: sub)),
                ),
              ],
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
        title: Text('Aide et support',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain)),
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
            title: const Text('Aide et support',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
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
        child: CustomPaint(painter: isDark ? _DarkOrb(size) : _LightOrb(size)),
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
    o(0.85, 0.08, 90, kPrimary.withValues(alpha: 0.08));
    o(0.10, 0.60, 100, kBlueLight.withValues(alpha: 0.06));
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
    o(0.85, 0.08, 100, kBlueLight.withValues(alpha: 0.14));
    o(0.10, 0.70, 110, kNavy.withValues(alpha: 0.60));
  }
  @override bool shouldRepaint(_) => false;
}

// ── Tuile FAQ accordéon ────────────────────────────────────────────────────────

class _FaqTile extends StatelessWidget {
  final ({String q, String a}) faq;
  final bool isOpen;
  final bool isLast;
  final bool isDark;
  final Color textMain, sub, borderNorm;
  final VoidCallback onTap;

  const _FaqTile({
    required this.faq,
    required this.isOpen,
    required this.isLast,
    required this.isDark,
    required this.textMain,
    required this.sub,
    required this.borderNorm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(faq.q,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right_rounded, size: 20, color: sub),
                  ),
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: isOpen
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(faq.a,
                              style: TextStyle(fontSize: 13, color: sub, height: 1.45)),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: borderNorm),
      ],
    );
  }
}
