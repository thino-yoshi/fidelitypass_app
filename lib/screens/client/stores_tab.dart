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
      print('Erreur loadData: $e');
      setState(() => loading = false);
    }
  }

  bool hasCard(String merchantId) {
    return myCards.any((c) => c['merchant_id'] == merchantId);
  }

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Carte créée chez ${merchant['business_name']} ! 🎉'),
              backgroundColor: const Color(0xFF2C7BE5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
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
      print('Erreur createCard: $e');
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
        padding: const EdgeInsets.all(16),
        children: [
          // Search
          TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: InputDecoration(
              hintText: '🔍  Rechercher un commerce...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          Text('${filtered.length} commerces partenaires',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 12),

          // List
          ...filtered.map((m) {
            final alreadyHas = hasCard(m['id']);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF5FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('🏪', style: TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['business_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(m['category'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '🎁 ${m['reward_description'] ?? ''} · ${m['stamps_required']} tampons',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF2C7BE5), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  alreadyHas
                      ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFFF5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('✓ Active', style: TextStyle(color: Color(0xFF2A9D5C), fontSize: 11, fontWeight: FontWeight.w800)),
                  )
                      : ElevatedButton(
                    onPressed: () => createCard(m),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C7BE5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    child: const Text('+ Carte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
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