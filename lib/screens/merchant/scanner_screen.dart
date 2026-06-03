import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const ScannerScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String phase = 'scanning';
  Map? scanResult;
  bool processing = false;
  MobileScannerController cameraController = MobileScannerController();
  static const gold = Color(0xFF2C7BE5);

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> handleScan(String qrToken) async {
    if (processing) return;
    setState(() { processing = true; phase = 'validating'; });

    final r = await ApiService.instance.scanQR(qrToken);
    if (mounted) {
      setState(() {
        if (r.isOk) {
          scanResult = r.value;
          phase = (r.value['reward_reached'] == true) ? 'reward' : 'success';
        } else {
          phase = 'error';
        }
        processing = false;
      });
    }
  }

  void reset() {
    setState(() {
      phase = 'scanning';
      scanResult = null;
      processing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Stack(
          children: [

            // ── Caméra ──
            if (phase == 'scanning')
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.merchantInfo?['business_name'] ?? '',
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                              const Text('Scanner le QR client',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white12,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('✕ Fermer', style: TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            MobileScanner(
                              controller: cameraController,
                              onDetect: (capture) {
                                final barcode = capture.barcodes.firstOrNull;
                                if (barcode?.rawValue != null) {
                                  handleScan(barcode!.rawValue!);
                                }
                              },
                            ),
                            Center(
                              child: Container(
                                width: 220, height: 220,
                                decoration: BoxDecoration(
                                  border: Border.all(color: gold, width: 3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Pointe la caméra vers le QR code du client',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(height: 24),
                ],
              ),

            // ── Validation ──
            if (phase == 'validating')
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: gold, strokeWidth: 3),
                    SizedBox(height: 20),
                    Text('Validation en cours...', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),

            // ── Succès ──
            if (phase == 'success' || phase == 'reward')
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(phase == 'reward' ? Icons.emoji_events_rounded : Icons.check_circle_rounded, size: 80, color: Colors.white),
                      const SizedBox(height: 20),
                      Text(
                        scanResult?['message'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${scanResult?['stamps_count']}',
                              style: const TextStyle(color: gold, fontSize: 40, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              ' / ${scanResult?['stamps_required']}',
                              style: const TextStyle(color: Colors.white38, fontSize: 24),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: reset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        ),
                        child: const Text('Scanner suivant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Erreur ──
            if (phase == 'error')
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('❌', style: TextStyle(fontSize: 80)),
                      const SizedBox(height: 20),
                      const Text('QR code invalide ou expiré',
                          style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: reset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        ),
                        child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),

            // Bouton fermer (phases non-scanning)
            if (phase != 'scanning')
              Positioned(
                top: 16, right: 16,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('✕ Fermer', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}