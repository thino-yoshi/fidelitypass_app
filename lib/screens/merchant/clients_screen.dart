import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class ClientsScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const ClientsScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<dynamic> clients = [];
  bool loading = true;
  static const blue = Color(0xFF2C7BE5);

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/clients'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (mounted) {
        setState(() {
          clients = jsonDecode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _adjustStamp(String cardId, int delta) async {
    final res = await http.post(
      Uri.parse('$apiUrl/cards/$cardId/adjust-stamp'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'delta': delta}),
    );
    if (res.statusCode == 200) {
      await _loadClients();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonDecode(res.body)['detail'] ?? 'Erreur')),
        );
      }
    }
  }

  void _openClientSheet(Map client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClientSheet(
        client: client,
        merchantInfo: widget.merchantInfo,
        onAdjust: (delta) async {
          Navigator.pop(context);
          await _adjustStamp(client['id'] as String, delta);
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: blue));
    }

    if (clients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Aucun client encore',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            Text('Tes clients apparaîtront ici après leur premier scan.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClients,
      color: blue,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
        itemCount: clients.length,
        itemBuilder: (_, i) {
          final card = clients[i];
          final user = card['client'] as Map? ?? {};
          final name = user['name'] ?? user['email'] ?? 'Client inconnu';
          final stamps = card['stamps_count'] as int? ?? 0;
          final stampsRequired = widget.merchantInfo?['stamps_required'] as int? ?? 10;

          return GestureDetector(
            onTap: () => _openClientSheet(card),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(_initials(name as String),
                          style: const TextStyle(color: blue, fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: stamps / stampsRequired,
                            minHeight: 4,
                            backgroundColor: const Color(0xFFEDE9E3),
                            valueColor: const AlwaysStoppedAnimation(blue),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('$stamps / $stampsRequired tampons',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFBBBBBB)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Fiche client bottom sheet ─────────────────────────────────────────────────

class _ClientSheet extends StatelessWidget {
  final Map client;
  final Map? merchantInfo;
  final void Function(int delta) onAdjust;

  const _ClientSheet({
    required this.client,
    required this.merchantInfo,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final user = client['client'] as Map? ?? {};
    final name = user['name'] ?? user['email'] ?? 'Client inconnu';
    final email = user['email'] ?? '';
    final stamps = client['stamps_count'] as int? ?? 0;
    final stampsRequired = merchantInfo?['stamps_required'] as int? ?? 10;
    const blue = Color(0xFF2C7BE5);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar + nom
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: blue.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
            child: Center(
              child: Text(
                _initials(name as String),
                style: const TextStyle(color: blue, fontWeight: FontWeight.w800, fontSize: 22),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          if (email.isNotEmpty)
            Text(email, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 24),

          // Tampons actuels
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2EE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('$stamps / $stampsRequired tampons',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: stamps / stampsRequired,
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation(blue),
                  ),
                ),
                if (merchantInfo?['reward_description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '🎁 ${merchantInfo!['reward_description']}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Boutons +/-
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: stamps > 0 ? () => onAdjust(-1) : null,
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('Retirer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: stamps < stampsRequired ? () => onAdjust(1) : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';
  }
}
