import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════
// SPLASH SCREEN — remplace le SplashRouter dans main.dart
// ═══════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Couleurs
  static const kBg      = Color(0xFF0B1220);

  // Controllers
  late AnimationController _bgCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _nameCtrl;
  late AnimationController _subCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _ring1Ctrl;
  late AnimationController _ring2Ctrl;
  late AnimationController _scanCtrl;
  late AnimationController _dotsCtrl;
  late AnimationController _verCtrl;
  late List<AnimationController> _dotCtrl;

  // Animations
  late Animation<double> _bgOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoY;
  late Animation<double> _nameOpacity;
  late Animation<double> _nameY;
  late Animation<double> _subOpacity;
  late Animation<double> _subY;
  late Animation<double> _glowOpacity;
  late Animation<double> _ring1Opacity;
  late Animation<double> _ring1Scale;
  late Animation<double> _ring2Opacity;
  late Animation<double> _ring2Scale;
  late Animation<double> _scanY;
  late Animation<double> _scanOpacity;
  late Animation<double> _dotsOpacity;
  late Animation<double> _verOpacity;
  late List<Animation<double>> _dotPulse;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Background fade
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _bgOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn));

    // Logo spring élastique (scale .7 → 1.05 → 1)
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    _logoScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 35),
    ]).animate(_logoCtrl);
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4, curve: Curves.easeIn)));
    _logoY = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 16.0, end: -3.0).chain(CurveTween(curve: Curves.easeOut)), weight: 65),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 35),
    ]).animate(_logoCtrl);

    // Nom app
    _nameCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _nameOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _nameCtrl, curve: Curves.easeOut));
    _nameY = Tween<double>(begin: 8, end: 0).animate(CurvedAnimation(parent: _nameCtrl, curve: Curves.easeOut));

    // Subtitle
    _subCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _subOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _subCtrl, curve: Curves.easeOut));
    _subY = Tween<double>(begin: 6, end: 0).animate(CurvedAnimation(parent: _subCtrl, curve: Curves.easeOut));

    // Glow pulsant
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);
    _glowOpacity = Tween<double>(begin: 0.15, end: 0.28).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Ring 1
    _ring1Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ring1Opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut));
    _ring1Scale = Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut));

    // Ring 2
    _ring2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ring2Opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut));
    _ring2Scale = Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut));

    // Scanline
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat();
    _scanY = Tween<double>(begin: 0.15, end: 0.84).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));
    _scanOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 84),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 8),
    ]).animate(_scanCtrl);

    // Dots loader
    _dotsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _dotsOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _dotsCtrl, curve: Curves.easeOut));

    // Version
    _verCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _verOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _verCtrl, curve: Curves.easeOut));

    // 3 dots pulsants (offset 220ms chacun)
    _dotCtrl = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 1250))..repeat(reverse: true));
    _dotPulse = _dotCtrl.map((c) => Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
    Future.delayed(const Duration(milliseconds: 220), () { if (mounted) _dotCtrl[1].forward(); });
    Future.delayed(const Duration(milliseconds: 440), () { if (mounted) _dotCtrl[2].forward(); });
  }

  Future<void> _startSequence() async {
    // bg fade delay 200ms
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _bgCtrl.forward();

    // logo delay 450ms
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    _logoCtrl.forward();

    // nom delay 1250ms
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _nameCtrl.forward();

    // ring1 delay 1400ms
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _ring1Ctrl.forward();

    // ring2 delay 1600ms
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _ring2Ctrl.forward();

    // subtitle delay 1850ms
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _subCtrl.forward();

    // dots loader delay 2100ms
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _dotsCtrl.forward();
    _dotCtrl[0].repeat(reverse: true);

    // version delay 2300ms
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _verCtrl.forward();

    // Transition vers l'app après 3.5s
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _logoCtrl.dispose();
    _nameCtrl.dispose();
    _subCtrl.dispose();
    _glowCtrl.dispose();
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    _scanCtrl.dispose();
    _dotsCtrl.dispose();
    _verCtrl.dispose();
    for (final c in _dotCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [

          // ── Grid background ──
          AnimatedBuilder(
            animation: _bgOpacity,
            builder: (_, __) => Opacity(
              opacity: _bgOpacity.value,
              child: CustomPaint(
                size: size,
                painter: _GridPainter(),
              ),
            ),
          ),

          // ── Glow orb ──
          AnimatedBuilder(
            animation: _glowOpacity,
            builder: (_, __) => Positioned(
              left: size.width / 2 - 150,
              top: size.height / 2 - 220,
              child: Opacity(
                opacity: _glowOpacity.value,
                child: Container(
                  width: 300, height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x383A82F6), Colors.transparent],
                      stops: [0, 0.68],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Ring 1 ──
          AnimatedBuilder(
            animation: _ring1Ctrl,
            builder: (_, __) => Positioned(
              left: size.width / 2 - 100,
              top: size.height / 2 - 100,
              child: Opacity(
                opacity: _ring1Opacity.value,
                child: Transform.scale(
                  scale: _ring1Scale.value,
                  child: Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x1F4A9EFF), width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Ring 2 ──
          AnimatedBuilder(
            animation: _ring2Ctrl,
            builder: (_, __) => Positioned(
              left: size.width / 2 - 135,
              top: size.height / 2 - 135,
              child: Opacity(
                opacity: _ring2Opacity.value,
                child: Transform.scale(
                  scale: _ring2Scale.value,
                  child: Container(
                    width: 270, height: 270,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x124A9EFF), width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Scanline ──
          AnimatedBuilder(
            animation: _scanCtrl,
            builder: (_, __) => Positioned(
              left: 0, right: 0,
              top: size.height * _scanY.value,
              child: Opacity(
                opacity: _scanOpacity.value,
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0x8C4A9EFF), Colors.transparent],
                      stops: [0.05, 0.5, 0.95],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Coins (corner accents) ──
          ..._buildCorners(size),

          // ── Centre : logo + nom + subtitle ──
          Center(
            child: AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => Opacity(
                opacity: _logoOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _logoY.value),
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // Logo box
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2044),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: const Color(0x4D4A9EFF), width: 1),
                          ),
                          child: Stack(
                            children: [
                              // Gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0x244A9EFF), Colors.transparent],
                                    stops: [0, 0.55],
                                  ),
                                ),
                              ),
                              // Q
                              const Center(
                                child: Text('Q', style: TextStyle(
                                  fontSize: 52, fontWeight: FontWeight.w800,
                                  color: Color(0xFF4A9EFF),
                                  letterSpacing: -2, height: 1,
                                )),
                              ),
                              // Dots décoratifs
                              Positioned(
                                top: 12, right: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF4A9EFF), borderRadius: BorderRadius.circular(2.5))),
                                      const SizedBox(width: 3),
                                      Container(width: 7, height: 7, decoration: BoxDecoration(color: const Color(0x6B4A9EFF), borderRadius: BorderRadius.circular(2.5))),
                                    ]),
                                    const SizedBox(height: 3),
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      const SizedBox(width: 15),
                                      Container(width: 7, height: 7, decoration: BoxDecoration(color: const Color(0x6B4A9EFF), borderRadius: BorderRadius.circular(2.5))),
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Nom app
                        const SizedBox(height: 20),
                        AnimatedBuilder(
                          animation: _nameCtrl,
                          builder: (_, __) => Opacity(
                            opacity: _nameOpacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _nameY.value),
                              child: const Text('Qarta', style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: 1.3,
                              )),
                            ),
                          ),
                        ),

                        // Subtitle
                        const SizedBox(height: 6),
                        AnimatedBuilder(
                          animation: _subCtrl,
                          builder: (_, __) => Opacity(
                            opacity: _subOpacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _subY.value),
                              child: RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'LA FIDÉLITÉ ',
                                      style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w400,
                                        color: Color(0x994A9EFF), letterSpacing: 3,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'EN UN SCAN',
                                      style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w400,
                                        color: Colors.white, letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 3 dots loader ──
          Positioned(
            bottom: 62, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _dotsOpacity,
              builder: (_, __) => Opacity(
                opacity: _dotsOpacity.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => AnimatedBuilder(
                    animation: _dotPulse[i],
                    builder: (_, __) => Container(
                      width: 5, height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.fromRGBO(74, 158, 255, _dotPulse[i].value * 0.5),
                      ),
                      transform: Matrix4.identity()..scale(_dotPulse[i].value * 0.25 + 0.75),
                      transformAlignment: Alignment.center,
                    ),
                  )),
                ),
              ),
            ),
          ),

          // ── Version ──
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _verOpacity,
              builder: (_, __) => Opacity(
                opacity: _verOpacity.value,
                child: const Text('v1.0', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Color(0x244A9EFF), letterSpacing: 2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners(Size size) {
    const c = Color(0x334A9EFF);
    const s = 52.0;
    const t = 26.0;
    const w = 1.0;
    return [
      // Top left
      const Positioned(top: t, left: t, child: _Corner(size: s, color: c, top: true, left: true, width: w)),
      // Top right
      const Positioned(top: t, right: t, child: _Corner(size: s, color: c, top: true, left: false, width: w)),
      // Bottom left
      const Positioned(bottom: t, left: t, child: _Corner(size: s, color: c, top: false, left: true, width: w)),
      // Bottom right
      const Positioned(bottom: t, right: t, child: _Corner(size: s, color: c, top: false, left: false, width: w)),
    ];
  }
}

// ── Corner widget ──
class _Corner extends StatelessWidget {
  final double size;
  final Color color;
  final bool top;
  final bool left;
  final double width;
  const _Corner({required this.size, required this.color, required this.top, required this.left, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(painter: _CornerPainter(color: color, top: top, left: left, width: width)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool top;
  final bool left;
  final double width;
  const _CornerPainter({required this.color, required this.top, required this.left, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke;
    final path = Path();
    const r = 5.0;
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, r);
      path.arcToPoint(const Offset(r, 0), radius: const Radius.circular(r));
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width - r, 0);
      path.arcToPoint(Offset(size.width, r), radius: const Radius.circular(r));
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - r);
      path.arcToPoint(Offset(r, size.height), radius: const Radius.circular(r));
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - r);
      path.arcToPoint(Offset(size.width - r, size.height), radius: const Radius.circular(r));
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Grid painter ──
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0F3A82F6)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}