import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/user_avatar.dart';

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
  Color get _kBg    => context.cBg;
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

  Future<void> _adjustStamp(String cardId, int delta) async {
    final r = await ApiService.instance.adjustStamp(cardId, delta);
    if (r.isOk) {
      await _loadClients();
    } else if (mounted) {
      ApiService.showErrIfNeeded(context, r);
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
        onAdjust: (cardId, delta) async {
          Navigator.pop(context);
          await _adjustStamp(cardId, delta);
        },
      ),
    );
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
            final user = c['users'] as Map? ?? {};
            final name = ((user['name'] ?? user['email'] ?? '') as String).toLowerCase();
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
              onTap: () => _openClientSheet(card),
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
                          color: const Color(0xFFF59E0B).withOpacity(0.12),
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

// ── Fiche client bottom sheet ─────────────────────────────────────────────────

class _ClientSheet extends StatefulWidget {
  final Map client;
  final Map? merchantInfo;
  final void Function(String cardId, int delta) onAdjust;

  const _ClientSheet({
    required this.client,
    required this.merchantInfo,
    required this.onAdjust,
  });

  @override
  State<_ClientSheet> createState() => _ClientSheetState();
}

class _ClientSheetState extends State<_ClientSheet> {
  static const _blue = Color(0xFF2C7BE5);
  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2C7BE5);
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _showStampModal(BuildContext ctx, String cardId, String clientName, int currentStamps, int required) {
    int count = 1;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, ss) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom + 16),
          decoration: BoxDecoration(
            color: ctx2.cSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: ctx2.cBorder, borderRadius: BorderRadius.circular(2)),
              ),
              Text('Ajouter des tampons',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ctx2.cText)),
              const SizedBox(height: 4),
              Text(
                '$clientName · $currentStamps/$required tampons actuellement',
                style: TextStyle(fontSize: 11, color: ctx2.cSub),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _stepBtn(ctx2, '-', () { if (count > 1) ss(() => count--); }),
                const SizedBox(width: 20),
                Text('$count', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: _blue)),
                const SizedBox(width: 20),
                _stepBtn(ctx2, '+', () => ss(() => count++)),
              ]),
              const SizedBox(height: 4),
              Text('tampon(s) à ajouter', style: TextStyle(fontSize: 10, color: ctx2.cSub)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx2);
                  widget.onAdjust(cardId, count);
                },
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _blue.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: const Center(
                    child: Text("Confirmer l'ajout",
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(ctx2),
                child: Text('Annuler',
                    style: TextStyle(fontSize: 12, color: ctx2.cSub, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(BuildContext ctx, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: ctx.cBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ctx.cBorder, width: 1.5),
        ),
        child: Center(child: Text(label,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ctx.cText))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.client['client'] as Map? ?? {};
    final clientName = (user['name'] ?? user['email'] ?? 'Client inconnu') as String;
    final email = user['email'] ?? '';
    final stamps = widget.client['stamps_count'] as int? ?? 0;
    final stampsRequired = widget.merchantInfo?['stamps_required'] as int? ?? 10;
    final rewardDescription = widget.merchantInfo?['reward_description'] as String? ?? '';
    final businessName = widget.merchantInfo?['business_name'] as String? ?? 'Ma boutique';
    final cardId = widget.client['id'] as String? ?? '';
    final initials = _initials(clientName);
    final cardColor = _parseColor(widget.merchantInfo?['card_color'] as String?);

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 20),

            UserAvatar(
              imageUrl: (widget.client['client'] as Map?)?['profile_picture_url'] as String?,
              name: clientName,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(clientName,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _kText)),
            if ((email as String).isNotEmpty)
              Text(email, style: TextStyle(color: _kSub, fontSize: 13)),
            const SizedBox(height: 24),

            // Tampons actuels
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: [
                  Text('$stamps / $stampsRequired tampons',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: _kText)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: stampsRequired > 0 ? (stamps / stampsRequired).clamp(0.0, 1.0) : 0,
                      minHeight: 8,
                      backgroundColor: _kBorder,
                      valueColor: const AlwaysStoppedAnimation(_blue),
                    ),
                  ),
                  if (rewardDescription.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$rewardDescription',
                        style: const TextStyle(fontSize: 13, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Aperçu carte
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('APERÇU CARTE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.7)),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cardColor, cardColor.withOpacity(0.7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: cardColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Center(child: Text(initials,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(businessName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Carte fidélité',
                          style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.6))),
                    ]),
                  ]),
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Icon(Icons.qr_code_rounded, size: 16, color: Colors.white.withOpacity(0.8)),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 5, runSpacing: 5,
                  children: List.generate(stampsRequired, (i) => Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: i < stamps ? Colors.white.withOpacity(0.9) : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white.withOpacity(i < stamps ? 0 : 0.35), width: 1.5),
                    ),
                    child: i < stamps ? Icon(Icons.check_rounded, size: 12, color: cardColor) : null,
                  )),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(
                    child: Text(
                      stamps >= stampsRequired
                          ? 'Récompense disponible !'
                          : 'Encore ${stampsRequired - stamps} tampons pour\n$rewardDescription',
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.75), height: 1.4),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$stamps/$stampsRequired',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('tampons', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5))),
                  ]),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: stampsRequired > 0 ? (stamps / stampsRequired).clamp(0.0, 1.0) : 0,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.85)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text('👤 $clientName',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
              ]),
            ),
            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: stamps > 0
                  ? () {
                      Navigator.pop(context);
                      widget.onAdjust(cardId, -1);
                    }
                  : null,
              icon: const Icon(Icons.remove_rounded),
              label: const Text('Retirer un tampon'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE24B4A),
                side: const BorderSide(color: Color(0xFFE24B4A)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: () => _showStampModal(context, cardId, clientName, stamps, stampsRequired),
              child: Container(
                width: double.infinity, height: 48,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _blue.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Ajouter des tampons manuellement',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
