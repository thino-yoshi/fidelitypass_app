import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

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

  static const _blue = Color(0xFF2C7BE5);
  Color get _kBg    => context.cBg;
  Color get _kWhite => context.cSurface;
  Color get _kText  => context.cText;
  Color get _kSub   => context.cSub;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    setState(() => loading = true);
    final r = await ApiService.instance.getMerchantScanHistory();
    if (mounted) {
      setState(() {
        history = r.isOk ? r.value : [];
        loading = false;
      });
      if (r.isErr) ApiService.showErrIfNeeded(context, r);
    }
  }

  String formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🕐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              "Aucun scan pour l'instant",
              style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Les scans apparaîtront ici',
              style: TextStyle(color: _kSub, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadHistory,
      color: _blue,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
        itemCount: history.length,
        itemBuilder: (_, i) {
          final scan = history[i];
          final client = scan['users'];
          final clientName = (client?['name'] ?? client?['email'] ?? 'Client inconnu') as String;
          final stamps = scan['stamps_count'] ?? 0;
          final reward = scan['reward_reached'] == true;
          final date = formatDate(scan['scanned_at'] ?? '');

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: reward
                        ? const Color(0xFFF59E0B).withOpacity(0.12)
                        : const Color(0xFF27AE60).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      reward ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                      size: 22,
                      color: reward ? const Color(0xFFF59E0B) : const Color(0xFF27AE60),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _kText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reward
                            ? 'Récompense débloquée !'
                            : 'Tampon ajouté — $stamps tampons',
                        style: TextStyle(
                          color: reward ? const Color(0xFFF59E0B) : _kSub,
                          fontSize: 13,
                          fontWeight: reward ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(date, style: TextStyle(color: _kSub, fontSize: 11), textAlign: TextAlign.right),
              ],
            ),
          );
        },
      ),
    );
  }
}
