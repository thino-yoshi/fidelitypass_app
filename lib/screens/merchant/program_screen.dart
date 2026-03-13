import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class ProgramScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  final VoidCallback? onSaved;
  const ProgramScreen({super.key, required this.token, this.merchantInfo, this.onSaved});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  late TextEditingController rewardCtrl;
  late TextEditingController nameCtrl;
  late TextEditingController categoryCtrl;
  late int stampsRequired;
  bool saving = false;
  static const gold = Color(0xFFC8822A);

  @override
  void initState() {
    super.initState();
    rewardCtrl = TextEditingController(text: widget.merchantInfo?['reward_description'] ?? '');
    nameCtrl = TextEditingController(text: widget.merchantInfo?['business_name'] ?? '');
    categoryCtrl = TextEditingController(text: widget.merchantInfo?['category'] ?? '');
    stampsRequired = widget.merchantInfo?['stamps_required'] ?? 10;
  }

  Future<void> saveProgram() async {
    setState(() => saving = true);
    try {
      final body = jsonEncode({
        'business_name': nameCtrl.text,
        'category': categoryCtrl.text,
        'stamps_required': stampsRequired,
        'reward_description': rewardCtrl.text,
      });

      print('📤 Envoi: $body');

      final res = await http.post(
        Uri.parse('$apiUrl/merchants/setup'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      print('📥 Status: ${res.statusCode}');
      print('📥 Response: ${res.body}');

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Programme mis à jour ! ✓'),
            backgroundColor: const Color(0xFF2ECC71),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSaved?.call();
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['detail'] ?? 'Erreur');
      }
    } catch (e) {
      print('❌ Erreur: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: const Color(0xFFE74C3C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚙️ Configuration du programme',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1828))),
            const SizedBox(height: 20),

            // Nom du commerce
            const Text('Nom du commerce',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1828))),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl, decoration: _inputDeco('Ex: Café Lumière')),
            const SizedBox(height: 16),

            // Catégorie
            const Text('Catégorie',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1828))),
            const SizedBox(height: 8),
            TextField(controller: categoryCtrl, decoration: _inputDeco('Ex: Café, Restaurant, Boulangerie...')),
            const SizedBox(height: 16),

            // Nombre de tampons
            const Text('Nombre de tampons requis',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1828))),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () { if (stampsRequired > 2) setState(() => stampsRequired--); },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: gold, iconSize: 28,
                ),
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFEDEAE4), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$stampsRequired',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1828))),
                ),
                IconButton(
                  onPressed: () { if (stampsRequired < 50) setState(() => stampsRequired++); },
                  icon: const Icon(Icons.add_circle_outline),
                  color: gold, iconSize: 28,
                ),
              ],
            ),
            const Text('Nombre de visites pour obtenir la récompense',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),

            // Récompense
            const Text('Description de la récompense',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1828))),
            const SizedBox(height: 8),
            TextField(controller: rewardCtrl, decoration: _inputDeco('Ex: 1 café offert')),
            const SizedBox(height: 20),

            // Aperçu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.08),
                border: Border.all(color: gold.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Après $stampsRequired visites',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1828))),
                      const SizedBox(height: 2),
                      Text('🎁 ${rewardCtrl.text}',
                          style: const TextStyle(fontSize: 13, color: gold, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Text('🏪', style: TextStyle(fontSize: 32)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bouton
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : saveProgram,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer les modifications',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEDEAE4), width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEDEAE4), width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold, width: 2)),
    );
  }
}