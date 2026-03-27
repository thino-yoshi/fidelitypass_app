import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class StoresTab extends StatefulWidget {
  final String token;
  const StoresTab({super.key, required this.token});

  @override
  State<StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends State<StoresTab> {
  List<dynamic> merchants = [];
  List<dynamic> myCards = [];
  bool loading = true;
  String search = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      final mRes = await http.get(
        Uri.parse('$apiUrl/merchants/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final cRes = await http.get(
        Uri.parse('$apiUrl/cards/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (mounted) {
        setState(() {
          merchants = jsonDecode(mRes.body);
          myCards = jsonDecode(cRes.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  bool hasCard(String merchantId) =>
      myCards.any((c) => c['merchant_id'] == merchantId);

  Future<void> createCard(Map merchant) async {
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/cards/'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'merchant_id': merchant['id']}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Carte créée chez ${merchant['business_name']} ! 🎉'),
            backgroundColor: const Color(0xFF2C7BE5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } else {
        final body = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? 'Erreur'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur createCard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2C7BE5)));
    }

    final filtered = merchants.where((m) {
      final name = (m['business_name'] ?? '').toLowerCase();
      final cat = (m['category'] ?? '').toLowerCase();
      return name.contains(search.toLowerCase()) || cat.contains(search.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: loadData,
      color: const Color(0xFF2C7BE5),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Barre de recherche
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE9E3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: TextField(
              onChanged: (v) => setState(() => search = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher un commerce...',
                hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Color(0xFFBBBBBB), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            '${filtered.length} commerce${filtered.length > 1 ? 's' : ''} partenaire${filtered.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w700, letterSpacing: 0.06),
          ),
          const SizedBox(height: 12),

          // Liste des commerces
          ...filtered.map((m) {
            final alreadyHas = hasCard(m['id'] as String? ?? '');
            final name = m['business_name'] as String? ?? '';
            final category = m['category'] as String? ?? '';
            final rewardDesc = m['reward_description'] as String? ?? '';
            final stampsReq = m['stamps_required'] as int? ?? 10;
            final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDE9E3)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(initials, style: const TextStyle(color: Color(0xFF2C7BE5), fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1828))),
                        const SizedBox(height: 1),
                        Text(category, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1FD),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🎁 $rewardDesc · $stampsReq tampons',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF2C7BE5), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  alreadyHas
                      ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F5EB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Color(0xFF27AE60), size: 12),
                        SizedBox(width: 3),
                        Text('Active', style: TextStyle(color: Color(0xFF27AE60), fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )
                      : ElevatedButton(
                    onPressed: () => createCard(m),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C7BE5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                    ),
                    child: const Text('+ Carte', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
