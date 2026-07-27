import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';

class StaticQRScreen extends StatefulWidget {
  final String token;
  final String businessName;
  final Color accentColor;

  const StaticQRScreen({
    super.key,
    required this.token,
    required this.businessName,
    required this.accentColor,
  });

  @override
  State<StaticQRScreen> createState() => _StaticQRScreenState();
}

class _StaticQRScreenState extends State<StaticQRScreen> {
  String? qrToken;
  bool loading = true;
  String? error;

  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

  @override
  void initState() {
    super.initState();
    _loadQR();
  }

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.check_circle_rounded, size: 15, color: widget.accentColor),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: _kSub, height: 1.4))),
    ]),
  );

  Future<void> _loadQR() async {
    AppLogger.merchant('StaticQRScreen → chargement QR statique pour ${widget.businessName}...');
    setState(() { loading = true; error = null; });
    final r = await ApiService.instance.getStaticQR();
    if (mounted) {
      if (r.isOk) {
        AppLogger.merchant('StaticQRScreen → QR statique chargé ✓ token: ${r.value.substring(0, 8)}...');
      } else {
        AppLogger.error('StaticQRScreen → getStaticQR erreur: ${r.error}');
      }
      setState(() {
        qrToken = r.isOk  ? r.value : null;
        error   = r.isErr ? r.error : null;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kWhite,
        foregroundColor: _kText,
        title: Text('QR code caisse',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        elevation: 0,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: widget.accentColor))
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Color(0xFFE24B4A))))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Affichez ce QR code en caisse',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kText),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vos clients le scannent pour rejoindre votre programme de fidélité.',
                        style: TextStyle(color: _kSub, fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // QR code
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _kWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _kBorder),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: qrToken!,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: widget.accentColor,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF1A1828),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.businessName,
                                style: TextStyle(
                                  color: widget.accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Boutons d'action
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Impression bientôt disponible'), duration: Duration(seconds: 2))),
                          icon: Icon(Icons.print_outlined, size: 16, color: widget.accentColor),
                          label: Text('Imprimer', style: TextStyle(fontWeight: FontWeight.w700, color: widget.accentColor)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: widget.accentColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Téléchargement bientôt disponible'), duration: Duration(seconds: 2))),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Télécharger', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accentColor, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )),
                      ]),

                      const SizedBox(height: 24),

                      // Conseils d'affichage
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _kWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Conseils d\'affichage',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
                          const SizedBox(height: 10),
                          _tip('Placez-le à hauteur des yeux, bien visible en caisse'),
                          _tip('Plastifiez-le pour le protéger et le garder propre'),
                          _tip('Ajoutez une courte note : "Scannez pour gagner des points"'),
                        ]),
                      ),
                    ],
                  ),
                ),
    );
  }
}
