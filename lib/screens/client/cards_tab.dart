import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/api.dart';

class CardsTab extends StatefulWidget {
  final String token;
  const CardsTab({super.key, required this.token});

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  List<dynamic> cards = [];
  bool loading = true;

  final List<Color> cardColors = const [
    Color(0xFF2C7BE5), Color(0xFF2C7BE5), Color(0xFF2A9D5C),
    Color(0xFFD42B2B), Color(0xFF7B4FBF), Color(0xFF0097A7),
  ];

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (mounted) {
        setState(() {
          cards = jsonDecode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void showCardDetail(Map card, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRModal(
        token: widget.token,
        card: card,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2C7BE5)));
    }

    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text("Tu n'as pas encore de carte.", style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            Text("Va dans Commerces pour en créer une !", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadCards,
      color: const Color(0xFF2C7BE5),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final card = cards[i];
          final color = cardColors[i % cardColors.length];
          final stamps = card['stamps_count'] ?? 0;
          final required = card['merchants']?['stamps_required'] ?? 10;
          final businessName = card['merchants']?['business_name'] ?? '';
          final reward = card['merchants']?['reward_description'] ?? '';
          final pct = (stamps / required).clamp(0.0, 1.0);

          return GestureDetector(
            onTap: () => showCardDetail(card, color),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CARTE FIDÉLITÉ', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const Text('🏪', style: TextStyle(fontSize: 32)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: List.generate(required, (j) => Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: j < stamps ? Colors.white : Colors.white.withOpacity(0.25),
                      ),
                      child: Center(child: Text(j < stamps ? '★' : '', style: const TextStyle(fontSize: 13))),
                    )),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stamps >= required ? '🎉 $reward disponible !' : '${required - stamps} tampon(s) restant(s)',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                      ),
                      Text('$stamps/$required', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Modal QR dynamique ──────────────────────────────────────────────────────

class QRModal extends StatefulWidget {
  final String token;
  final Map card;
  final Color color;
  const QRModal({super.key, required this.token, required this.card, required this.color});

  @override
  State<QRModal> createState() => _QRModalState();
}

class _QRModalState extends State<QRModal> {
  String? dynamicToken;
  int timeLeft = 60;
  bool loadingQR = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchDynamicQR();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchDynamicQR() async {
    setState(() { loadingQR = true; dynamicToken = null; });
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/qr/${widget.card['id']}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          dynamicToken = data['dynamic_token'];
          timeLeft = data['expires_in'] ?? 60;
          loadingQR = false;
        });
        startTimer();
      }
    } catch (e) {
      setState(() => loadingQR = false);
    }
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => timeLeft--);
      if (timeLeft <= 0) {
        t.cancel();
        fetchDynamicQR(); // Renouvellement automatique
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stamps = widget.card['stamps_count'] ?? 0;
    final required = widget.card['merchants']?['stamps_required'] ?? 10;
    final reward = widget.card['merchants']?['reward_description'] ?? '';
    final businessName = widget.card['merchants']?['business_name'] ?? '';
    final color = widget.color;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('🏪', style: TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(businessName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('Carte de fidélité', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
            ),
            child: loadingQR
                ? SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator(color: color)))
                : QrImageView(data: dynamicToken ?? '', version: QrVersions.auto, size: 180, foregroundColor: color),
          ),
          const SizedBox(height: 12),

          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔒 QR sécurisé · renouvellement auto', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text('${timeLeft}s', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: timeLeft < 15 ? Colors.red : Colors.grey[600],
              )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: timeLeft / 60,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(timeLeft < 15 ? Colors.red : color),
            ),
          ),
          const SizedBox(height: 20),

          // Tampons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mes tampons', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('$stamps/$required', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(required, (i) => Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < stamps ? color : Colors.transparent,
                      border: Border.all(color: i < stamps ? color : Colors.grey[300]!, width: 2.5),
                    ),
                    child: Center(child: Text(i < stamps ? '★' : '', style: const TextStyle(color: Colors.white, fontSize: 16))),
                  )),
                ),
                if (stamps >= required) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('🎉 $reward disponible !',
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14), textAlign: TextAlign.center),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100], foregroundColor: Colors.grey[700],
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}