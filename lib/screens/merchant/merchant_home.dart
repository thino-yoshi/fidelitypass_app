import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../services/auth_service.dart';
import '../auth_screen.dart';
import 'scanner_screen.dart';
import 'program_screen.dart';

class MerchantHome extends StatefulWidget {
  final String token;
  final String merchantName;
  const MerchantHome({super.key, required this.token, required this.merchantName});

  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome> {
  int currentTab = 0;
  Map? merchantInfo;
  bool loading = true;
  static const gold = Color(0xFFC8822A);

  final Map<String, Map<String, dynamic>> styles = {
    'Café':        {'emoji': '☕', 'color': Color(0xFFC8822A)},
    'Boulangerie': {'emoji': '🥐', 'color': Color(0xFFD4A017)},
    'Restaurant':  {'emoji': '🍽', 'color': Color(0xFFC0392B)},
    'Healthy':     {'emoji': '🥗', 'color': Color(0xFF27AE60)},
    'Librairie':   {'emoji': '📚', 'color': Color(0xFF8E44AD)},
    'Coiffeur':    {'emoji': '✂', 'color': Color(0xFF2980B9)},
  };

  Map<String, dynamic> getStyle(String category) {
    return styles[category] ?? {'emoji': '🏪', 'color': gold};
  }

  @override
  void initState() {
    super.initState();
    loadMerchantInfo();
  }

  Future<void> loadMerchantInfo() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/merchants/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      final data = jsonDecode(res.body) as List;
      print('🏪 Tous les merchants: ${data.length}');

      // Décoder le JWT pour récupérer le user_id
      final parts = widget.token.split('.');
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final myId = decoded['sub'];
      print('👤 Mon ID: $myId');

      // Trouver MON commerce par ID
      final me = data.firstWhere(
            (m) => m['id'] == myId,
        orElse: () => null,
      );

      print('✅ Mon commerce: $me');

      setState(() {
        merchantInfo = me;
        loading = false;
      });
    } catch (e) {
      print('❌ Erreur: $e');
      setState(() => loading = false);
    }
  }

  void logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = merchantInfo != null ? getStyle(merchantInfo!['category']) : {'emoji': '🏪', 'color': gold};
    final color = s['color'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      body: Column(
        children: [
          // Top bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 24, right: 24, bottom: 16,
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Center(child: Text(s['emoji'] as String, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchantInfo?['business_name'] ?? widget.merchantName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1A1828)),
                      ),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF27AE60))),
                          const SizedBox(width: 4),
                          const Text('Connecté', style: TextStyle(fontSize: 12, color: Color(0xFF27AE60), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerScreen(token: widget.token, merchantInfo: merchantInfo))),
                  icon: const Text('📷', style: TextStyle(fontSize: 16)),
                  label: const Text('Scanner', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: logout,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: const Text('Sortir', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _tab('📊', 'Tableau de bord', 0, color),
                _tab('⚙️', 'Programme', 1, color),
              ],
            ),
          ),

          // Content
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator(color: color))
                : currentTab == 0
                ? _dashboard(color, s)
                : ProgramScreen(
              token: widget.token,
              merchantInfo: merchantInfo,
              onSaved: () async {
                setState(() {
                  loading = true;
                  currentTab = 0;
                });
                await loadMerchantInfo();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboard(Color color, Map s) {
    if (merchantInfo == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Profil non configuré', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Va dans Programme pour configurer ton commerce.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => currentTab = 1),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Configurer →'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerScreen(token: widget.token, merchantInfo: merchantInfo))),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Action principale', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('Scanner un client', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Valider un tampon de fidélité', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('📷', style: TextStyle(fontSize: 32))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Programme actuel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1828))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          children: [
                            Text('${merchantInfo!['stamps_required']}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color)),
                            const SizedBox(height: 4),
                            const Text('tampons requis', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFF8F6F3), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Récompense', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('🎁 ${merchantInfo!['reward_description']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1828))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String icon, String label, int index, Color color) {
    final active = currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? color : Colors.transparent, width: 2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: active ? color : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}