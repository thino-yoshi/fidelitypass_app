import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';

class ScanTab extends StatefulWidget {
  final String token;
  final VoidCallback onCardAdded;

  const ScanTab({super.key, required this.token, required this.onCardAdded});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _scanning = true;
  bool _loading  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  void _startCamera() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
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

    setState(() { _scanning = false; _loading = true; _error = null; });
    _controller?.stop();

    final token = _extractToken(raw);

    try {
      final res = await http.post(
        Uri.parse('$apiUrl/cards/join'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'static_qr_token': token}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final alreadyMember = data['already_member'] as bool? ?? false;
        final merchant = data['merchant'] as Map<String, dynamic>? ?? {};
        final name = merchant['business_name'] as String? ?? '';

        _showResult(
          success: true,
          alreadyMember: alreadyMember,
          merchantName: name,
        );
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _showError(body['detail'] as String? ?? 'QR code invalide');
      }
    } catch (_) {
      _showError('Erreur réseau. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
  }) {
    if (!mounted) return;
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
          if (!alreadyMember) widget.onCardAdded();
          _resetScan();
        },
      ),
    );
  }

  void _resetScan() {
    if (!mounted) return;
    setState(() { _scanning = true; _error = null; });
    _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Caméra ──────────────────────────────────────────────────────
        if (_controller != null)
          MobileScanner(
            controller: _controller!,
            onDetect: _onDetect,
          ),

        // ── Overlay sombre avec fenêtre de scan ──────────────────────────
        _ScanOverlay(),

        // ── UI au-dessus ──────────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Titre
              Text(
                'Scanner le QR du commerce',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pointe la caméra vers le QR code affiché en caisse',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                ),

              const SizedBox(height: 40),

              // Bouton torche
              GestureDetector(
                onTap: () => _controller?.toggleTorch(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
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
}

// ── Overlay de scan (fond sombre + fenêtre transparente) ──────────────────────
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = size.width * 0.65;
    final top = (size.height - boxSize) / 2 - 30;

    return CustomPaint(
      size: Size(size.width, size.height),
      painter: _OverlayPainter(
        scanRect: Rect.fromLTWH(
          (size.width - boxSize) / 2,
          top,
          boxSize,
          boxSize,
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect scanRect;
  const _OverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = Colors.black.withOpacity(0.60);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    // Fond sombre avec trou transparent
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(18)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

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
              color: iconColor.withOpacity(0.12),
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
