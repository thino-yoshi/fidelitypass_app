import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/api.dart';

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

  @override
  void initState() {
    super.initState();
    _loadQR();
  }

  Future<void> _loadQR() async {
    setState(() { loading = true; error = null; });
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/merchants/me/static-qr'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        setState(() {
          qrToken = jsonDecode(res.body)['static_qr_token'];
          loading = false;
        });
      } else {
        setState(() { error = 'Erreur lors du chargement'; loading = false; });
      }
    } catch (e) {
      setState(() { error = 'Erreur réseau'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        title: const Text('QR code caisse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: widget.accentColor))
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Affichez ce QR code en caisse',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1828),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vos clients le scannent pour rejoindre votre programme de fidélité.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // QR code
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8)),
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
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: const Color(0xFF1A1828),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.accentColor.withOpacity(0.1),
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

                      // Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEDE9E3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: widget.accentColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Ce QR code est permanent et unique à votre commerce. Imprimez-le et collez-le en caisse.',
                                style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
