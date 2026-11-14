import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class ClientNotifsAndroid extends StatelessWidget {
  final List<Map> notifs;
  final String filter;
  final void Function(Map) onTap;

  const ClientNotifsAndroid({
    super.key,
    required this.notifs,
    required this.filter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'tout'
        ? notifs
        : notifs.where((n) => n['type'] == filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Aucune notification', style: TextStyle(color: context.qSub, fontSize: 14)))
              : ListView(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 76),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text("Aujourd'hui", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.06)),
                    ),
                    ...filtered.map((n) => _NotifItem(n: n, onTap: onTap)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NotifItem extends StatelessWidget {
  final Map n;
  final void Function(Map) onTap;
  const _NotifItem({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(n['color'] as int);
    final unread = !(n['read'] as bool);
    return GestureDetector(
      onTap: () => onTap(n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.qDivider),
            left: unread ? BorderSide(color: color, width: 3) : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: CustomPaint(
                  size: const Size(20, 20),
                  painter: _NotifIconPainter(type: n['type'] as String, color: color),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(n['commerce'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.qText)),
                      Text(n['time'] as String, style: TextStyle(fontSize: 10, color: context.qSub)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n['title'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
                  const SizedBox(height: 2),
                  Text(n['body'] as String, style: TextStyle(fontSize: 11, color: context.qSub, height: 1.4)),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifIconPainter extends CustomPainter {
  final String type;
  final Color color;
  const _NotifIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    switch (type) {
      case 'tampon':
      case 'stamp':
        _drawStamp(canvas, s);
      case 'recompense':
      case 'reward':
        _drawReward(canvas, s);
      default:
        _drawPromo(canvas, s);
    }
  }

  void _drawStamp(Canvas canvas, double s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2 * s, 2 * s, 14 * s, 14 * s), Radius.circular(4 * s)), p);
    final check = Path()
      ..moveTo(6 * s, 9 * s)
      ..lineTo(8.5 * s, 11.5 * s)
      ..lineTo(12.5 * s, 7.5 * s);
    canvas.drawPath(check, p);
  }

  void _drawReward(Canvas canvas, double s) {
    canvas.drawCircle(Offset(9 * s, 9 * s), 8.5 * s, Paint()..color = color);
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? 4.5 : 2.0;
      final angle = -pi / 2 + (pi * i / 5);
      final x = 9 * s + r * s * cos(angle);
      final y = 9 * s + r * s * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  void _drawPromo(Canvas canvas, double s) {
    final p = Paint()..color = color;
    canvas.drawCircle(Offset(5 * s, 5 * s), 1.5 * s, p);
    canvas.drawCircle(Offset(13 * s, 13 * s), 1.5 * s, p);
    canvas.drawLine(Offset(4 * s, 14 * s), Offset(14 * s, 4 * s),
        Paint()..color = color..strokeWidth = 1.8 * s..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_NotifIconPainter old) => old.type != type || old.color != color;
}
