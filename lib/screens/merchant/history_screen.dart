import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class HistoryScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const HistoryScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> history = [];
  bool loading = true;
  static const blue = Color(0xFF2C7BE5);

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/scan-history'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (mounted) {
        setState(() {
          history = jsonDecode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  String formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
            Text('Aucun scan pour l\'instant',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            Text('Les scans apparaîtront ici',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadHistory,
      color: blue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (_, i) {
          final scan = history[i];
          final client = scan['client'];
          final clientName = client?['name'] ?? client?['email'] ?? 'Client inconnu';
          final stamps = scan['stamps_count'] ?? 0;
          final reward = scan['reward_reached'] == true;
          final date = formatDate(scan['scanned_at'] ?? '');

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: reward
                        ? Colors.amber.withOpacity(0.15)
                        : blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(reward ? '🏆' : '✅',
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        reward
                            ? '🎉 Récompense débloquée !'
                            : 'Tampon ajouté → $stamps tampons',
                        style: TextStyle(
                          color: reward ? Colors.amber[700] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(date,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}