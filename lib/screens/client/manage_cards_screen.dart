import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';

enum _SortMode { recent, oldest, mostStamps, leastStamps }

class ManageCardsScreen extends StatefulWidget {
  final String token;
  final List<dynamic> cards;
  final VoidCallback onRefresh;

  const ManageCardsScreen({
    super.key,
    required this.token,
    required this.cards,
    required this.onRefresh,
  });

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  _SortMode _sort = _SortMode.recent;
  final Set<String> _selected = {};
  bool _deleting = false;
  late List<dynamic> _cards;

  // Palette déterministe basée sur le merchant_id
  static const _kColors = [
    Color(0xFF2C7BE5),
    Color(0xFFE53E3E),
    Color(0xFF38A169),
    Color(0xFFD69E2E),
    Color(0xFF805AD5),
    Color(0xFFDD6B20),
    Color(0xFF319795),
    Color(0xFFD53F8C),
  ];

  @override
  void initState() {
    super.initState();
    _cards = List<dynamic>.from(widget.cards);
  }

  Color _cardColor(String? merchantId) {
    if (merchantId == null) return _kColors[0];
    return _kColors[merchantId.hashCode.abs() % _kColors.length];
  }

  List<dynamic> get _sortedCards {
    final list = List<dynamic>.from(_cards);
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

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.qSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Supprimer $n carte${n > 1 ? 's' : ''}',
          style: TextStyle(color: context.qText, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          'Cette action est irréversible.\nTes tampons et ton historique seront perdus.',
          style: TextStyle(color: context.qSub, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: context.qSub, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    final toDelete = Set<String>.from(_selected);

    for (final id in toDelete) {
      try {
        await http.delete(
          Uri.parse('$apiUrl/cards/$id'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
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
    final cards = _sortedCards;
    final allSelected = cards.isNotEmpty && _selected.length == cards.length;

    return Scaffold(
      backgroundColor: context.qBg,
      appBar: AppBar(
        backgroundColor: context.qNavy,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.qText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes cartes',
          style: TextStyle(color: context.qText, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (cards.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected.addAll(cards.map((c) => c['id'] as String));
                }
              }),
              child: Text(
                allSelected ? 'Désélect. tout' : 'Tout sélect.',
                style: const TextStyle(
                  color: Color(0xFF4A9EFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSortRow(),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.credit_card_off_outlined, size: 52, color: context.qSub),
                        const SizedBox(height: 14),
                        Text(
                          'Aucune carte',
                          style: TextStyle(color: context.qSub, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        16, 14, 16, _selected.isNotEmpty ? 100 : 24),
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildCardRow(cards[i] as Map),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(
                    _deleting
                        ? 'Suppression...'
                        : 'Supprimer ${_selected.length} carte${_selected.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSortRow() {
    return Container(
      color: context.qNavy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _sortChip('Récentes', _SortMode.recent, Icons.access_time_rounded),
            const SizedBox(width: 8),
            _sortChip('Anciennes', _SortMode.oldest, Icons.history_rounded),
            const SizedBox(width: 8),
            _sortChip('+ Tampons', _SortMode.mostStamps, Icons.arrow_upward_rounded),
            const SizedBox(width: 8),
            _sortChip('- Tampons', _SortMode.leastStamps, Icons.arrow_downward_rounded),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String label, _SortMode mode, IconData icon) {
    final active = _sort == mode;
    return GestureDetector(
      onTap: () => setState(() => _sort = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2C7BE5).withOpacity(0.18)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFF4A9EFF).withOpacity(0.55)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: active ? const Color(0xFF4A9EFF) : context.qSub),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF4A9EFF) : context.qSub,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow(Map card) {
    final id         = card['id'] as String? ?? '';
    final merchantId = card['merchant_id'] as String?;
    final name       = card['merchants']?['business_name'] as String? ?? '';
    final stamps     = card['stamps_count'] as int? ?? 0;
    final isPoints   = (card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    final required   = isPoints
        ? (card['merchants']?['points_required'] as int? ?? 100)
        : (card['merchants']?['stamps_required'] as int? ?? 10);
    final color      = _cardColor(merchantId);
    final selected   = _selected.contains(id);
    final initials   = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    final dateStr    = card['created_at'] as String? ?? '';
    final date       = DateTime.tryParse(dateStr)?.toLocal();
    final dateLabel  = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '';

    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE53E3E).withOpacity(0.07)
              : context.qSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFE53E3E).withOpacity(0.45)
                : context.qBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Indicateur de sélection
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFFE53E3E) : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE53E3E)
                      : context.qSub.withOpacity(0.35),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // Avatar commerce
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Nom + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.qText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Depuis le $dateLabel',
                      style: TextStyle(color: context.qSub, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Compteur tampons / points
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$stamps/$required',
                  style: TextStyle(
                    color: context.qText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isPoints ? 'pts' : 'tampons',
                  style: TextStyle(color: context.qSub, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
