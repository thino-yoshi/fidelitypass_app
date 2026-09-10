import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import 'cards_tab.dart' show CardStyle, LoyaltyCardFace;

enum _SortMode { recent, oldest, mostStamps, leastStamps }

class ManageCardsScreen extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> cards;
  final List<dynamic> rewards;
  final VoidCallback onRefresh;

  const ManageCardsScreen({
    super.key,
    required this.token,
    required this.userName,
    required this.cards,
    this.rewards = const [],
    required this.onRefresh,
  });

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  _SortMode _sort = _SortMode.recent;
  String _search = '';
  final Set<String> _selected = {};
  bool _deleting = false;
  late List<dynamic> _cards;

  static const List<Color> _palette = [
    Color(0xFF2C7BE5),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFF7B4FBF),
    Color(0xFF0097A7),
    Color(0xFFE67E22),
  ];

  CardStyle _styleFromCard(Map card, int index) {
    return CardStyle.fromDesign(
      card['card_design'],
      merchantLogoUrl: card['merchants']?['logo_url'] as String?,
      fallbackColor: _palette[index % _palette.length],
    );
  }

  @override
  void initState() {
    super.initState();
    _cards = List<dynamic>.from(widget.cards);
  }

  List<dynamic> get _sorted {
    var list = _search.isEmpty
        ? List<dynamic>.from(_cards)
        : _cards.where((c) {
            final q        = _search.toLowerCase();
            final name     = ((c['merchants']?['business_name'] ?? '') as String).toLowerCase();
            final cardName = ((c['card_design'] as Map?)?['cardName'] as String? ?? '').toLowerCase();
            return name.contains(q) || cardName.contains(q);
          }).toList();
    switch (_sort) {
      case _SortMode.recent:
        list.sort((a, b) {
          final da = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
          return db.compareTo(da);
        });
      case _SortMode.oldest:
        list.sort((a, b) {
          final da = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
          return da.compareTo(db);
        });
      case _SortMode.mostStamps:
        list.sort((a, b) =>
            (b['stamps_count'] as int? ?? 0).compareTo(a['stamps_count'] as int? ?? 0));
      case _SortMode.leastStamps:
        list.sort((a, b) =>
            (a['stamps_count'] as int? ?? 0).compareTo(b['stamps_count'] as int? ?? 0));
    }
    return list;
  }

  void _toggle(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  Future<void> _deleteSelected() async {
    final n = _selected.length;

    // Compter les récompenses perdues pour les marchands sélectionnés
    final selectedMerchantIds = _cards
        .where((c) => _selected.contains(c['id'] as String?))
        .map((c) => c['merchant_id'] as String?)
        .toSet();
    final lostRewards = widget.rewards
        .where((r) => selectedMerchantIds.contains(r['merchant_id'] as String?))
        .length;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int countdown = 5;
        Timer? t;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            t ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (!ctx.mounted) { t?.cancel(); return; }
              if (countdown > 0) setSt(() => countdown--);
              else t?.cancel();
            });
            return PopScope(
              onPopInvokedWithResult: (_, __) => t?.cancel(),
              child: AlertDialog.adaptive(
                backgroundColor: context.qSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  'Supprimer $n carte${n > 1 ? 's' : ''} ?',
                  style: TextStyle(color: context.qText, fontWeight: FontWeight.w800, fontSize: 17),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cette action est irréversible.\nTes tampons et ton historique seront perdus définitivement.',
                      style: TextStyle(color: context.qSub, fontSize: 13, height: 1.55),
                    ),
                    if (lostRewards > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFF92400E), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$lostRewards récompense${lostRewards > 1 ? 's' : ''} '
                              '${lostRewards > 1 ? 'seront perdues' : 'sera perdue'} définitivement.',
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () { t?.cancel(); Navigator.pop(ctx, false); },
                    child: Text('Annuler',
                        style: TextStyle(color: context.qSub, fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton(
                    onPressed: countdown == 0
                        ? () { t?.cancel(); Navigator.pop(ctx, true); }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53E3E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE53E3E).withValues(alpha: 0.45),
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: Text(
                      countdown > 0 ? 'Supprimer ($countdown)' : 'Supprimer',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    final toDelete = Set<String>.from(_selected);

    for (final id in toDelete) {
      try {
        await http.delete(
          Uri.parse('$apiUrl/cards/$id'),
          headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? widget.token}'},
        );
      } catch (_) {}
    }

    setState(() {
      _cards.removeWhere((c) => toDelete.contains(c['id'] as String?));
      _selected.clear();
      _deleting = false;
    });
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _sorted;
    final allSelected = cards.isNotEmpty && _selected.length == cards.length;

    return Scaffold(
      backgroundColor: context.qNavy,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          _buildHeader(allSelected, cards),
          _buildSortRow(),
          Expanded(
            child: Container(
              color: context.qBg,
              child: cards.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          16, 16, 16, _selected.isNotEmpty ? 100 : 40),
                      itemCount: cards.length,
                      itemBuilder: (_, i) {
                        final card = cards[i] as Map;
                        final id = card['id'] as String? ?? '';
                        final selected = _selected.contains(id);
                        final style = _styleFromCard(card, i);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _toggle(id),
                            child: Stack(
                              children: [
                                SizedBox(
                                  height: 220,
                                  child: LoyaltyCardFace(
                                    card: card,
                                    style: style,
                                    userName: widget.userName,
                                  ),
                                ),
                                if (selected)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        color: const Color(0xFFE53E3E).withValues(alpha: 0.32),
                                        child: const Center(
                                          child: Icon(Icons.check_circle_rounded,
                                              color: Colors.white, size: 40),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isNotEmpty ? _buildDeleteBar() : null,
    );
  }

  Widget _buildHeader(bool allSelected, List<dynamic> cards) {
    return Container(
      color: context.qNavy,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mes cartes',
                    style: TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                Text(
                  '${_cards.length} carte${_cards.length > 1 ? 's' : ''}'
                  '${_selected.isNotEmpty ? ' · ${_selected.length} sélectionnée${_selected.length > 1 ? 's' : ''}' : ''}',
                  style: TextStyle(
                    color: _selected.isNotEmpty
                        ? const Color(0xFFE53E3E).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (cards.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected.addAll(cards.map((c) => c['id'] as String));
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: allSelected
                      ? const Color(0xFFE53E3E).withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: allSelected
                        ? const Color(0xFFE53E3E).withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  allSelected ? 'Désélect.' : 'Tout',
                  style: TextStyle(
                    color: allSelected
                        ? const Color(0xFFE57373)
                        : const Color(0xFF4A9EFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortRow() {
    return Container(
      color: context.qNavy,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Récentes', _SortMode.recent, Icons.access_time_rounded),
                const SizedBox(width: 7),
                _chip('Anciennes', _SortMode.oldest, Icons.history_rounded),
                const SizedBox(width: 7),
                _chip('+ Tampons', _SortMode.mostStamps, Icons.trending_up_rounded),
                const SizedBox(width: 7),
                _chip('- Tampons', _SortMode.leastStamps, Icons.trending_down_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher un commerce…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: const Color(0xFF4A9EFF).withValues(alpha: 0.6), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _SortMode mode, IconData icon) {
    final active = _sort == mode;
    return GestureDetector(
      onTap: () => setState(() => _sort = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2C7BE5).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFF4A9EFF).withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12,
                color: active ? const Color(0xFF4A9EFF) : Colors.white38),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  color: active ? const Color(0xFF4A9EFF) : Colors.white38,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: context.qSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.qBorder),
            ),
            child: Icon(Icons.credit_card_off_outlined, size: 34, color: context.qSub),
          ),
          const SizedBox(height: 16),
          Text('Aucune carte',
              style: TextStyle(
                  color: context.qText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Scanne un QR pour rejoindre un programme',
              style: TextStyle(color: context.qSub, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDeleteBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: ElevatedButton.icon(
          onPressed: _deleting ? null : _deleteSelected,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _deleting
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator.adaptive())
              : const Icon(Icons.delete_rounded, size: 20),
          label: Text(
            _deleting
                ? 'Suppression en cours...'
                : 'Supprimer ${_selected.length} carte${_selected.length > 1 ? 's' : ''}',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ),
      ),
    );
  }
}
