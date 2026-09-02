import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class HeroBackground extends StatefulWidget {
  const HeroBackground({super.key});

  @override
  State<HeroBackground> createState() => HeroBackgroundState();
}

class HeroBackgroundState extends State<HeroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset('shaders/hero_gradient.frag');
      if (mounted) setState(() => _shader = prog.fragmentShader());
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        if (_shader != null) {
          return CustomPaint(
            painter: _ShaderPainter(_shader!, _ctrl.value * math.pi * 8),
            child: const SizedBox.expand(),
          );
        }
        // Fallback navy uni pendant le chargement du shader
        return const ColoredBox(color: Color(0xFF000060), child: SizedBox.expand());
      },
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  _ShaderPainter(this.shader, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter o) => o.time != time;
}
