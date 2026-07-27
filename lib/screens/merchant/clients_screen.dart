import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import 'fiche_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  final Map? cardDesign;
  final List<dynamic> initialClients;
  final List<dynamic> initialScanHistory;
  const ClientsScreen({
    super.key,
    required this.token,
    this.merchantInfo,
    this.cardDesign,
    this.initialClients     = const [],
    this.initialScanHistory = const [],
  });

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<dynamic> clients = [];
  bool loading = true;
  String _search = '';
  String _sortBy = 'name';

  static const _blue = Color(0xFF2C7BE5);
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialClients.isNotEmpty) {
      clients = List<dynamic>.from(widget.initialClients);
      loading = false;
    } else {
      _loadClients();
    }
  }

  Future<void> _loadClients() async {
    AppLogger.merchant('ClientsScreen → chargement clients...');
    setState(() => loading = true);
    final r = await ApiService.instance.getMerchantClients();
    if (mounted) {
      if (r.isOk) {
        AppLogger.merchant('ClientsScreen → ${r.value.length} client(s) chargé(s)');
      } else {
        AppLogger.error('ClientsScreen → erreur: ${r.error}');
      }
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
        ? List<dynamic>.from(clients)
        : clients.where((c) {
            final user = c['client'] as Map? ?? {};
            final name = ((user['name'] ?? user['email'] ?? '').toString()).toLowerCase();
            return name.contains(_search.toLowerCase());
          }).toList();

    if (_sortBy == 'stamps_desc') {
      filtered.sort((a, b) => (b['stamps_count'] as int? ?? 0).compareTo(a['stamps_count'] as int? ?? 0));
    } else if (_sortBy == 'stamps_asc') {
      filtered.sort((a, b) => (a['stamps_count'] as int? ?? 0).compareTo(b['stamps_count'] as int? ?? 0));
    } else {
      filtered.sort((a, b) {
        final ua = (a['client'] as Map?)?['name'] ?? (a['client'] as Map?)?['email'] ?? '';
        final ub = (b['client'] as Map?)?['name'] ?? (b['client'] as Map?)?['email'] ?? '';
        return ua.toString().compareTo(ub.toString());
      });
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;
    final stamps_required = widget.merchantInfo?['stamps_required'] as int? ?? 10;
    final programType = widget.merchantInfo?['program_type'] as String? ?? 'stamps';
    final isPoints = programType == 'points';

    return RefreshIndicator(
      onRefresh: _loadClients,
      color: _blue,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compteur
                  Text(
                    '${clients.length} client${clients.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: _kSub, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  // Tri
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _sortChip('name', 'A–Z'),
                      const SizedBox(width: 8),
                      _sortChip('stamps_desc', isPoints ? '+ Points' : '+ Tampons'),
                      const SizedBox(width: 8),
                      _sortChip('stamps_asc', isPoints ? '– Points' : '– Tampons'),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Recherche
                  Container(
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomPad),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final card = filtered[i];
                  final user = card['client'] as Map? ?? {};
                  final name = (user['name'] ?? user['email'] ?? 'Client') as String;
                  final email = user['email'] as String?;
                  final avatarUrl = user['profile_picture_url'] as String?;
                  final stamps = card['stamps_count'] as int? ?? 0;
                  final full = stamps >= stamps_required;

                  final clientId = (card['client_id'] ?? '').toString();
                  final clientScans = widget.initialScanHistory
                      .where((s) => (s['client_id'] ?? '').toString() == clientId)
                      .toList();
                  final joinDate = DateTime.tryParse(card['created_at'] as String? ?? '');
                  final note = card['merchant_note'] as String? ?? '';

                  return GestureDetector(
                    onTap: () {
                      AppLogger.merchant('ClientsScreen → fiche: $name');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FicheClientScreen(
                            token:              widget.token,
                            clientId:           clientId,
                            cardId:             (card['id'] ?? '').toString(),
                            clientName:         name,
                            clientEmail:        email,
                            clientPic:          avatarUrl,
                            merchantInfo:       widget.merchantInfo ?? {},
                            initialScans:       clientScans.isNotEmpty ? clientScans : null,
                            initialStamps:      stamps,
                            initialJoinDate:    joinDate,
                            initialNote:        note,
                            initialCardDesign:  widget.cardDesign,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(children: [
                        // Avatar
                        _avatar(name, avatarUrl),
                        const SizedBox(width: 12),
                        // Nom + progression
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _kText,
                                  )),
                              const SizedBox(height: 3),
                              Text(
                                isPoints
                                    ? '$stamps pts'
                                    : '$stamps / $stamps_required tampon${stamps > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: full ? _blue : _kSub,
                                  fontWeight: full ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge récompense ou flèche
                        if (full)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('🎁',
                                style: TextStyle(fontSize: 12)),
                          )
                        else
                          Icon(Icons.chevron_right_rounded, color: _kSub, size: 20),
                      ]),
                    ),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name, String? avatarUrl) {
    const size = 44.0;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          avatarUrl,
          width: size, height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(name, size),
        ),
      );
    }
    return _initialsAvatar(name, size);
  }

  Widget _initialsAvatar(String name, double size) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : (parts.first[0] + parts.last[0]).toUpperCase();
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF4A9EF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(initials,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  Widget _sortChip(String value, String label) {
    final selected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _blue.withValues(alpha: 0.12) : _kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _blue.withValues(alpha: 0.5) : _kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? _blue : _kSub,
          ),
        ),
      ),
    );
  }
}
