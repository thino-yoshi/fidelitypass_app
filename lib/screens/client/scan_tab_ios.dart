import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../config/demo_mode.dart';
import 'widgets/client_sheets_ios.dart' show showCardAddedIos;

class ScanTabIos extends StatefulWidget {
  final String token;
  final void Function(Map<String, dynamic> card, Map<String, dynamic> merchant) onCardAdded;
  final VoidCallback? onBack;
  final void Function(Map<String, dynamic> card, Map<String, dynamic> merchant)? onCardAddedStay;
  final String userName;

  const ScanTabIos({super.key, required this.token, required this.onCardAdded, this.onBack,
      this.onCardAddedStay, this.userName = ''});

  @override
  State<ScanTabIos> createState() => _ScanTabIosState();
}

class _ScanTabIosState extends State<ScanTabIos> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _scanning = true;
  bool _loading  = false;
  bool _torch    = false;
  String? _error;
  late AnimationController _lineAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
    _lineAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  void _startCamera() {
    AppLogger.client('ScanTabIos → caméra initialisée');
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _lineAnim.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed && _scanning) {
      _controller?.start();
    }
  }

  String _extractToken(String raw) {
    final uuid = RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    );
    final match = uuid.firstMatch(raw);
    return match?.group(0) ?? raw.trim();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning || _loading) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    HapticFeedback.mediumImpact();
    AppLogger.client('ScanTabIos → QR détecté (brut): $raw');
    setState(() { _scanning = false; _loading = true; _error = null; });
    _controller?.stop();

    final token = _extractToken(raw);
    final r = await ApiService.instance.joinMerchant(token);
    if (!mounted) return;
    setState(() => _loading = false);

    if (r.isOk) {
      final alreadyMember = r.value['already_member'] as bool? ?? false;
      final merchant = r.value['merchant'] as Map<String, dynamic>? ?? {};
      final card    = r.value['card']     as Map<String, dynamic>? ?? {};
      final name = merchant['business_name'] as String? ?? '';
      AppLogger.client('ScanTabIos → joinMerchant ✓ already_member: $alreadyMember, commerce: $name');
      _showResult(success: true, alreadyMember: alreadyMember, merchantName: name, card: card, merchant: merchant);
    } else {
      AppLogger.error('ScanTabIos → joinMerchant erreur: ${r.error}');
      _showError(r.error ?? 'QR code invalide');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
    Future.delayed(const Duration(seconds: 3), _resetScan);
  }

  void _showResult({
    required bool success,
    required bool alreadyMember,
    required String merchantName,
    Map<String, dynamic> card     = const {},
    Map<String, dynamic> merchant = const {},
  }) {
    if (!mounted) return;
    showCardAddedIos(context,
            merchant: merchant, design: card['card_design'] ?? merchant['card_design'],
            userName: widget.userName, alreadyMember: alreadyMember)
        .then((seeCard) {
      if (!mounted) return;
      if (seeCard == false) {
        if (!alreadyMember) widget.onCardAddedStay?.call(card, merchant);
        _resetScan();
      } else if (!alreadyMember) {
        widget.onCardAdded(card, merchant);
      } else {
        widget.onBack?.call();
      }
    });
  }

  void _resetScan() {
    if (!mounted) return;
    AppLogger.client('ScanTabIos → scan réinitialisé, caméra relancée');
    setState(() { _scanning = true; _error = null; });
    _controller?.start();
  }

  Rect _scanRect(Size size) {
    final boxSize = size.width * 0.65 > 320 ? 320.0 : size.width * 0.65;
    final top = (size.height - boxSize) / 2 - 30;
    return Rect.fromLTWH((size.width - boxSize) / 2, top, boxSize, boxSize);
  }

  void _demoDetect() {
    final fake = QartaDemo.fakeJoin?.call();
    if (fake == null || !_scanning) return;
    HapticFeedback.mediumImpact();
    setState(() => _scanning = false);
    final merchant = Map<String, dynamic>.from(fake['merchant'] as Map);
    _showResult(success: true, alreadyMember: false,
        merchantName: merchant['business_name'] as String? ?? '',
        card: Map<String, dynamic>.from(fake['card'] as Map), merchant: merchant);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rect = _scanRect(size);
    return _buildIos(rect);
  }

  Widget _buildIos(Rect rect) {
    return Stack(children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1,
                colors: [Color(0xFF2A3140), Color(0xFF0B1220)]),
          ),
        ),
      ),
      if (_controller != null && !QartaDemo.enabled)
        MobileScanner(controller: _controller!, onDetect: _onDetect, scanWindow: rect),
      _ScanOverlayIos(scanRect: rect, lineAnim: _lineAnim, corners: false),
      IgnorePointer(child: CustomPaint(size: MediaQuery.of(context).size, painter: _IosCornersPainter(rect.inflate(16)))),
      Positioned.fromRect(
        rect: rect,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: QartaDemo.enabled ? _demoDetect : null),
      ),
      SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              _glass(CupertinoIcons.xmark, widget.onBack ?? () {}),
              const Spacer(),
              _glass(_torch ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt, () {
                _controller?.toggleTorch();
                setState(() => _torch = !_torch);
              }),
            ]),
          ),
          SizedBox(height: (rect.top - MediaQuery.of(context).padding.top - 190).clamp(12, 200)),
          const Text('Ajouter une carte',
              style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          const SizedBox(height: 6),
          Text('Scanne le QR code affiché en caisse',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 17)),
          const Spacer(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFE24B4A), borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          if (_loading) const Padding(padding: EdgeInsets.only(bottom: 30), child: CupertinoActivityIndicator(color: Colors.white, radius: 14)),
          if (QartaDemo.enabled && _scanning)
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Text('Aperçu : touche le cadre pour simuler un scan',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            ),
        ]),
      ),
    ]);
  }

  Widget _glass(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E2D45).withValues(alpha: 0.55),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      );
}

class _ScanOverlayIos extends StatelessWidget {
  final Rect scanRect;
  final Animation<double> lineAnim;
  final bool corners;
  const _ScanOverlayIos({required this.scanRect, required this.lineAnim, this.corners = true});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        CustomPaint(
          size: Size(size.width, size.height),
          painter: _OverlayPainterIos(scanRect: scanRect, corners: corners),
        ),
        AnimatedBuilder(
          animation: lineAnim,
          builder: (_, __) {
            final y = scanRect.top + 8 + (scanRect.height - 16) * lineAnim.value;
            return Positioned(
              left: scanRect.left + 14,
              top: y,
              child: Container(
                width: scanRect.width - 28,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.85),
                    Colors.transparent,
                  ]),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OverlayPainterIos extends CustomPainter {
  final Rect scanRect;
  final bool corners;
  const _OverlayPainterIos({required this.scanRect, this.corners = true});

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.60);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(18)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    if (!corners) return;

    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cLen = 28.0;
    final r = scanRect;

    canvas.drawLine(Offset(r.left, r.top + cLen), Offset(r.left, r.top + 14), corner);
    canvas.drawLine(Offset(r.left + 14, r.top), Offset(r.left + cLen, r.top), corner);
    canvas.drawLine(Offset(r.right, r.top + cLen), Offset(r.right, r.top + 14), corner);
    canvas.drawLine(Offset(r.right - 14, r.top), Offset(r.right - cLen, r.top), corner);
    canvas.drawLine(Offset(r.left, r.bottom - cLen), Offset(r.left, r.bottom - 14), corner);
    canvas.drawLine(Offset(r.left + 14, r.bottom), Offset(r.left + cLen, r.bottom), corner);
    canvas.drawLine(Offset(r.right, r.bottom - cLen), Offset(r.right, r.bottom - 14), corner);
    canvas.drawLine(Offset(r.right - 14, r.bottom), Offset(r.right - cLen, r.bottom), corner);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _IosCornersPainter extends CustomPainter {
  final Rect r;
  const _IosCornersPainter(this.r);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 50.0, rad = 26.0;
    void corner(Offset o, double sx, double sy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + sy * len)
        ..lineTo(o.dx, o.dy + sy * rad)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + sx * rad, o.dy)
        ..lineTo(o.dx + sx * len, o.dy);
      canvas.drawPath(path, p);
    }
    corner(r.topLeft, 1, 1);
    corner(r.topRight, -1, 1);
    corner(r.bottomLeft, 1, -1);
    corner(r.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_IosCornersPainter old) => old.r != r;
}
