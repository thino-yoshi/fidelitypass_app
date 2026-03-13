import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class ScannerScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const ScannerScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String phase = 'ready';
  Map? scanResult;
  final qrCtrl = TextEditingController();
  static const gold = Color(0xFFC8822A);

  Future<void> handleScan() async {
    if (qrCtrl.text.trim().isEmpty) return;
    setState(() { phase = 'scanning'; scanResult = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => phase = 'validating');
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/scan/'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'qr_token': qrCtrl.text.trim()}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          scanResult = data;
          phase = data['reward_reached'] ? 'reward' : 'success';
        });
      } else {
        setState(() => phase = 'error');
      }
    } catch (e) {
      setState(() => phase = 'error');
    }
  }

  void reset() {
    setState(() { phase = 'ready'; scanResult = null; qrCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final color = gold;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Titre
                    Text(
                      widget.merchantInfo?['business_name'] ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _phaseTitle(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 40),

                    // Contenu selon phase
                    if (phase == 'ready') _readyWidget(color),
                    if (phase == 'scanning' || phase == 'validating') _loadingWidget(color),
                    if (phase == 'success' || phase == 'reward') _resultWidget(color),
                    if (phase == 'error') _errorWidget(color),
                  ],
                ),
              ),
            ),

            // Bouton fermer
            Positioned(
              top: 16, right: 16,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('✕ Fermer', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseTitle() {
    switch (phase) {
      case 'ready': return 'Scanner le QR code client';
      case 'scanning': return 'Lecture...';
      case 'validating': return 'Validation en cours...';
      case 'success': return '✓ Tampon ajouté !';
      case 'reward': return '🎉 Récompense débloquée !';
      case 'error': return '✗ QR invalide';
      default: return '';
    }
  }

  Widget _readyWidget(Color color) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          TextField(
            controller: qrCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Colle le QR token ici...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => handleScan(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: handleScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Valider le scan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('En production : scan caméra direct', style: TextStyle(color: Colors.white24, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _loadingWidget(Color color) {
    return Column(
      children: [
        CircularProgressIndicator(color: color, strokeWidth: 3),
        const SizedBox(height: 20),
        Text(
          phase == 'scanning' ? 'Lecture du QR code...' : 'Vérification backend...',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _resultWidget(Color color) {
    final isReward = phase == 'reward';
    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isReward ? const Color(0xFFF5C842) : const Color(0xFF27AE60)).withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(isReward ? '🏆' : '✅', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            scanResult?['message'] ?? '',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  const Text('Tampons', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Text('${scanResult?['stamps_count']}', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
                  Text('/ ${scanResult?['stamps_required']}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: reset,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Nouveau scan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget(Color color) {
    return Column(
      children: [
        const Text('❌', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        const Text('QR code invalide ou expiré', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: reset,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}