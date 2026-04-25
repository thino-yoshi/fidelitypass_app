import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';

const _kPrimary = Color(0xFF2C7BE5);
const _kSuccess = Color(0xFF27AE60);

class StoresTab extends StatefulWidget {
  final String token;
  const StoresTab({super.key, required this.token});

  @override
  State<StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends State<StoresTab> {
  Color get _kBg    => context.cBg;
  Color get _kWhite => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText  => context.cText;
  Color get _kSub   => context.cSub;

  List<dynamic> merchants = [];
  List<dynamic> myCards   = [];
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
      final mRes = await http.get(Uri.parse('$apiUrl/merchants/'), headers: {'Authorization': 'Bearer ${widget.token}'});
      final cRes = await http.get(Uri.parse('$apiUrl/cards/me'),    headers: {'Authorization': 'Bearer ${widget.token}'});
      if (mounted) {
        setState(() { merchants = jsonDecode(mRes.body); myCards = jsonDecode(cRes.body); loading = false; });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  bool hasCard(String merchantId) => myCards.any((c) => c['merchant_id'] == merchantId);

  Future<void> createCard(Map merchant) async {
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/cards/'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'merchant_id': merchant['id']}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Carte créée chez ${merchant['business_name']} ! 🎉'),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      } else {
        final body = jsonDecode(res.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? 'Erreur'), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint('Erreur createCard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: _kPrimary));

    final filtered = merchants.where((m) {
      final name = (m['business_name'] ?? '').toLowerCase();
      final cat  = (m['category'] ?? '').toLowerCase();
      return name.contains(search.toLowerCase()) || cat.contains(search.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: loadData,
      color: _kPrimary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // Barre de recherche
          TextField(
            onChanged: (v) => setState(() => search = v),
            style: TextStyle(fontSize: 14, color: _kText),
            decoration: InputDecoration(
              hintText: 'Rechercher un commerce...',
              hintStyle: TextStyle(color: _kSub, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: _kSub, size: 20),
              filled: true, fillColor: _kWhite,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _kPrimary)),
            ),
          ),
          const SizedBox(height: 12),

          Text('${filtered.length} commerce${filtered.length > 1 ? 's' : ''} partenaire${filtered.length > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: _kSub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          // Liste des commerces
          ...filtered.map((m) {
            final alreadyHas = hasCard(m['id'] as String? ?? '');
            final name       = m['business_name'] as String? ?? '';
            final category   = m['category'] as String? ?? '';
            final rewardDesc = m['reward_description'] as String? ?? '';
            final stampsReq  = m['stamps_required'] as int? ?? 10;
            final initials   = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Row(children: [
                // Initiales
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(initials,
                      style: const TextStyle(color: _kPrimary, fontSize: 14, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kText)),
                  Text(category, style: TextStyle(fontSize: 11, color: _kSub)),
                  const SizedBox(height: 4),
                  Text('🎁 $rewardDesc · $stampsReq tampons',
                      style: const TextStyle(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600)),
                ])),
                const SizedBox(width: 8),
                alreadyHas
                    ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _kSuccess.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: _kSuccess, size: 12),
                    SizedBox(width: 3),
                    Text('Active', style: TextStyle(color: _kSuccess, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                )
                    : ElevatedButton(
                  onPressed: () => createCard(m),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('+ Carte'),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
