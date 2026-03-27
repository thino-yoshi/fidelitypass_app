import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class HistoryTab extends StatefulWidget {
  final String token;
  const HistoryTab({super.key, required this.token});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<dynamic> history = [];
  bool loading = true;
  static const blue = Color(0xFF2C7BE5);

  // Styles par catégorie (identiques au merchant home)
  static const Map<String, String> _categoryEmoji = {
    'Café': '☕',
    'Boulangerie': '🥐',
    'Restaurant': '🍽',
    'Healthy': '🥗',
    'Librairie': '📚',
    'Coiffeur': '✂',
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/my-history'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (mounted && res.statusCode == 200) {
        setState(() {
          history = jsonDecode(res.body);
          loading = false;
        });
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // Grouper par commerce
  Map<String, List<dynamic>> _groupByMerchant() {
    final grouped = <String, List<dynamic>>{};
    for (final scan in history) {
      final name = scan['merchant']?['business_name'] as String? ?? 'Commerce inconnu';
      grouped.putIfAbsent(name, () => []).add(scan);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: blue));
    }

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🕐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Aucune visite pour l\'instant',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            Text('Tes visites apparaîtront ici après ton premier scan.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final grouped = _groupByMerchant();

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: blue,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
        children: grouped.entries.map((entry) {
          final merchantName = entry.key;
          final scans = entry.value;
          final category = scans.first['merchant']?['category'] as String? ?? '';
          final emoji = _categoryEmoji[category] ?? '🏪';
          final totalStamps = scans.where((s) => s['reward_reached'] != true).length;
          final totalRewards = scans.where((s) => s['reward_reached'] == true).length;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDE9E3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Column(
              children: [
                // En-tête commerce
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(merchantName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1828))),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (totalStamps > 0) ...[
                                  _badge('$totalStamps tampon${totalStamps > 1 ? 's' : ''}', blue),
                                  const SizedBox(width: 6),
                                ],
                                if (totalRewards > 0)
                                  _badge('$totalRewards récompense${totalRewards > 1 ? 's' : ''}', const Color(0xFFF59E0B)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Liste des visites
                ...scans.take(5).map((scan) {
                  final reward = scan['reward_reached'] == true;
                  final stamps = scan['stamps_count'] as int? ?? 0;
                  final date = _formatDate(scan['scanned_at'] ?? '');
                  final isManual = scan['manual'] == true;

                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF4F2EE))),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          reward ? '🏆' : (isManual ? '✏️' : '✅'),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reward
                                ? 'Récompense débloquée !'
                                : (isManual ? 'Tampon manuel → $stamps tampons' : 'Tampon ajouté → $stamps tampons'),
                            style: TextStyle(
                              fontSize: 13,
                              color: reward ? const Color(0xFFF59E0B) : const Color(0xFF555555),
                              fontWeight: reward ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(date, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                      ],
                    ),
                  );
                }),
                if (scans.length > 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '+ ${scans.length - 5} visites supplémentaires',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
