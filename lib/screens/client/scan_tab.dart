import '../merchant/merchant_tokens.dart' show kIsIOS;
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

class ScanTab extends StatefulWidget {
  final String token;
  final void Function(Map<String, dynamic> card, Map<String, dynamic> merchant) onCardAdded;
  final VoidCallback? onBack;
  /// iOS : carte ajoutée mais le client veut « Scanner une autre carte ».
  final void Function(Map<String, dynamic> card, Map<String, dynamic> merchant)? onCardAddedStay;
  final String userName;

  const ScanTab({super.key, required this.token, required this.onCardAdded, this.onBack,
      this.onCardAddedStay, this.userName = ''});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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
    AppLogger.client('ScanTab → caméra initialisée');
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

  // Extrait le token brut (UUID) depuis la valeur scannée (URL ou UUID direct)
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
    AppLogger.client('ScanTab → QR détecté (brut): $raw');
    setState(() { _scanning = false; _loading = true; _error = null; });
    _controller?.stop();

    final token = _extractToken(raw);
    AppLogger.client('ScanTab → token extrait: $token');

    final r = await ApiService.instance.joinMerchant(token);
    if (!mounted) return;
    setState(() => _loading = false);

    if (r.isOk) {
      final alreadyMember = r.value['already_member'] as bool? ?? false;
      final merchant = r.value['merchant'] as Map<String, dynamic>? ?? {};
      final card    = r.value['card']     as Map<String, dynamic>? ?? {};
      final name = merchant['business_name'] as String? ?? '';
      AppLogger.client('ScanTab → joinMerchant ✓ already_member: $alreadyMember, commerce: $name');
      _showResult(success: true, alreadyMember: alreadyMember, merchantName: name, card: card, merchant: merchant);
    } else {
      AppLogger.error('ScanTab → joinMerchant erreur: ${r.error}');
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
    if (kIsIOS) {
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
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _ResultSheet(
        success: success,
        alreadyMember: alreadyMember,
        merchantName: merchantName,
        onDone: () {
          Navigator.pop(context);
          if (!alreadyMember) widget.onCardAdded(card, merchant);
          _resetScan();
        },
      ),
    );
  }

  void _resetScan() {
    if (!mounted) return;
    AppLogger.client('ScanTab → scan réinitialisé, caméra relancée');
    setState(() { _scanning = true; _error = null; });
    _controller?.start();
  }

  Rect _scanRect(Size size) {
    final boxSize = size.width * 0.65 > 320 ? 320.0 : size.width * 0.65; // iPad : cadre de taille normale
    final top = (size.height - boxSize) / 2 - 30;
    return Rect.fromLTWH((size.width - boxSize) / 2, top, boxSize, boxSize);
  }

  // Aperçu design : un tap dans le cadre simule le scan d'un QR commerçant.
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
    if (kIsIOS) return _buildIos(rect);

    return Stack(
      children: [
        // ── Caméra ──────────────────────────────────────────────────────
        if (_controller != null)
          MobileScanner(
            controller: _controller!,
            onDetect: _onDetect,
            scanWindow: rect,
          ),

        // ── Overlay sombre + ligne animée ────────────────────────────────
        _ScanOverlay(scanRect: rect, lineAnim: _lineAnim),

        // ── UI au-dessus ──────────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Flèche retour uniquement
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ]),
              ),
              const Spacer(),

              // ── Erreur ────────────────────────────────────────────────
              if (_error != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Chargement ────────────────────────────────────────────
              if (_loading)
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator.adaptive(),
                ),

              const SizedBox(height: 40),

              // Bouton torche
              GestureDetector(
                onTap: () => _controller?.toggleTorch(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flashlight_on_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 7),
                      Text('Lampe torche', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }

  // ── iOS : caméra plein écran, titre, cadre à coins arrondis, boutons verre ──
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
      _ScanOverlay(scanRect: rect, lineAnim: _lineAnim, corners: false),
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

// ── Overlay de scan (fond sombre + fenêtre + ligne animée) ───────────────────
class _ScanOverlay extends StatelessWidget {
  final Rect scanRect;
  final Animation<double> lineAnim;
  final bool corners;
  const _ScanOverlay({required this.scanRect, required this.lineAnim, this.corners = true});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        CustomPaint(
          size: Size(size.width, size.height),
          painter: _OverlayPainter(scanRect: scanRect, corners: corners),
        ),
        // Ligne de scan animée
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

class _OverlayPainter extends CustomPainter {
  final Rect scanRect;
  final bool corners;
  const _OverlayPainter({required this.scanRect, this.corners = true});

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.60);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    // Fond sombre avec trou transparent
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(18)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    if (!corners) return;

    // Coins du cadre de scan
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cLen = 28.0;
    final r = scanRect;

    // Top-left
    canvas.drawLine(Offset(r.left, r.top + cLen), Offset(r.left, r.top + 14), corner);
    canvas.drawLine(Offset(r.left + 14, r.top), Offset(r.left + cLen, r.top), corner);
    // Top-right
    canvas.drawLine(Offset(r.right, r.top + cLen), Offset(r.right, r.top + 14), corner);
    canvas.drawLine(Offset(r.right - 14, r.top), Offset(r.right - cLen, r.top), corner);
    // Bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - cLen), Offset(r.left, r.bottom - 14), corner);
    canvas.drawLine(Offset(r.left + 14, r.bottom), Offset(r.left + cLen, r.bottom), corner);
    // Bottom-right
    canvas.drawLine(Offset(r.right, r.bottom - cLen), Offset(r.right, r.bottom - 14), corner);
    canvas.drawLine(Offset(r.right - 14, r.bottom), Offset(r.right - cLen, r.bottom), corner);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Feuille de résultat ────────────────────────────────────────────────────────
class _ResultSheet extends StatelessWidget {
  final bool success;
  final bool alreadyMember;
  final String merchantName;
  final VoidCallback onDone;

  const _ResultSheet({
    required this.success,
    required this.alreadyMember,
    required this.merchantName,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1D2A) : Colors.white;

    final iconColor = alreadyMember
        ? const Color(0xFFF59E0B)
        : const Color(0xFF27AE60);
    final iconData = alreadyMember
        ? Icons.info_outline_rounded
        : Icons.check_circle_rounded;
    final title = alreadyMember
        ? 'Déjà membre !'
        : 'Carte ajoutée !';
    final subtitle = alreadyMember
        ? 'Tu as déjà une carte de fidélité chez\n$merchantName'
        : 'Ta carte de fidélité chez\n$merchantName a été ajoutée.';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: context.qText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.qSub,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C7BE5),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS : grands coins arrondis blancs autour du cadre (comme l'appareil photo).
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
