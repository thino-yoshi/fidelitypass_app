import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/user_avatar.dart';
import 'fiche_client_screen.dart';

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
  String _search = '';

  static const _blue = Color(0xFF2C7BE5);
  Color get _kWhite => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText  => context.cText;
  Color get _kSub   => context.cSub;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => loading = true);
    final r = await ApiService.instance.getMerchantClients();
    if (mounted) {
      setState(() {
        clients = r.isOk ? r.value : [];
        loading = false;
      });
      if (r.isErr) ApiService.showErrIfNeeded(context, r);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    if (clients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Aucun client encore',
                style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Tes clients apparaîtront ici après leur premier scan.',
              style: TextStyle(color: _kSub, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filtered = _search.isEmpty
        ? clients
        : clients.where((c) {
            final user = c['client'] as Map? ?? {};
            final name = ((user['name'] ?? user['email'] ?? '').toString()).toLowerCase();
            return name.contains(_search.toLowerCase());
          }).toList();

    return RefreshIndicator(
      onRefresh: _loadClients,
      color: _blue,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: _kText, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Rechercher un client…',
                hintStyle: TextStyle(color: _kSub, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: _kSub, size: 20),
                filled: true,
                fillColor: _kWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _blue, width: 1.5),
                ),
              ),
            ),
          ),

          // Client list
          ...List.generate(filtered.length, (i) {
            final card = filtered[i];
            final user = card['client'] as Map? ?? {};
            final name = (user['name'] ?? user['email'] ?? 'Client inconnu') as String;
            final stamps = card['stamps_count'] as int? ?? 0;
            final stampsRequired = widget.merchantInfo?['stamps_required'] as int? ?? 10;
            final hasReward = stamps >= stampsRequired;

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FicheClientScreen(
                token: widget.token,
                clientId: (card['client_id'] ?? '').toString(),
                cardId: (card['id'] ?? '').toString(),
                clientName: name,
                clientEmail: user['email'] as String?,
                clientPic: user['profile_picture_url'] as String?,
                merchantInfo: widget.merchantInfo ?? {},
              ))).then((_) => _loadClients()),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      imageUrl: (card['client'] as Map?)?['profile_picture_url'] as String?,
                      name: name,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _kText)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: stampsRequired > 0 ? (stamps / stampsRequired).clamp(0.0, 1.0) : 0,
                              minHeight: 4,
                              backgroundColor: _kBorder,
                              valueColor: const AlwaysStoppedAnimation(_blue),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('$stamps / $stampsRequired tampons',
                              style: TextStyle(color: _kSub, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (hasReward)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.emoji_events_rounded, size: 13, color: Color(0xFFF59E0B)),
                      ),
                    const Icon(Icons.chevron_right_rounded, color: _blue),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

