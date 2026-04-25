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

  // Même palette que cards_tab
  static const List<Color> _palette = [
    Color(0xFF2C7BE5),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFF7B4FBF),
    Color(0xFF0097A7),
    Color(0xFFE67E22),
  ];

  Color _cardColor(String? merchantId) {
    if (merchantId == null) return _palette[0];
    return _palette[merchantId.hashCode.abs() % _palette.length];
  }

  @override
  void initState() {
    super.initState();
    _cards = List<dynamic>.from(widget.cards);
  }

  List<dynamic> get _sorted {
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

  void _toggle(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.qSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Supprimer $n carte${n > 1 ? 's' : ''} ?',
          style: TextStyle(
            color: context.qText,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Cette action est irréversible.\nTes tampons et ton historique seront perdus définitivement.',
          style: TextStyle(color: context.qSub, fontSize: 13, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: TextStyle(color: context.qSub, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

  // ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cards = _sorted;
    final allSelected = cards.isNotEmpty && _selected.length == cards.length;

    return Scaffold(
      backgroundColor: context.qBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(allSelected, cards),
            _buildSortRow(),
            Expanded(
              child: cards.isEmpty
                  ? _buildEmpty()
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                          14, 14, 14, _selected.isNotEmpty ? 100 : 30),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (_, i) =>
                          _buildMiniCard(cards[i] as Map),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selected.isNotEmpty ? _buildDeleteBar() : null,
    );
  }

  // ── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader(bool allSelected, List<dynamic> cards) {
    return Container(
      color: context.qNavy,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Row(
        children: [
          // Bouton retour
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes cartes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_cards.length} carte${_cards.length > 1 ? 's' : ''}'
                  '${_selected.isNotEmpty ? ' · ${_selected.length} sélectionnée${_selected.length > 1 ? 's' : ''}' : ''}',
                  style: TextStyle(
                    color: _selected.isNotEmpty
                        ? const Color(0xFFE53E3E).withOpacity(0.85)
                        : Colors.white.withOpacity(0.4),
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
                      ? const Color(0xFFE53E3E).withOpacity(0.12)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: allSelected
                        ? const Color(0xFFE53E3E).withOpacity(0.35)
                        : Colors.white.withOpacity(0.1),
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

  // ── Sort chips ──────────────────────────────────────────────────────
  Widget _buildSortRow() {
    return Container(
      color: context.qNavy,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: SingleChildScrollView(
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
              ? const Color(0xFF2C7BE5).withOpacity(0.2)
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
            Icon(icon,
                size: 12,
                color: active ? const Color(0xFF4A9EFF) : Colors.white38),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF4A9EFF) : Colors.white38,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.qSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.qBorder),
            ),
            child: Icon(Icons.credit_card_off_outlined,
                size: 34, color: context.qSub),
          ),
          const SizedBox(height: 16),
          Text('Aucune carte',
              style: TextStyle(
                  color: context.qText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Scanne un QR pour rejoindre un programme',
              style: TextStyle(color: context.qSub, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Delete bar ──────────────────────────────────────────────────────
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
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

  // ── Mini card ───────────────────────────────────────────────────────
  Widget _buildMiniCard(Map card) {
    final id         = card['id'] as String? ?? '';
    final merchantId = card['merchant_id'] as String?;
    final name       = card['merchants']?['business_name'] as String? ?? '';
    final stamps     = card['stamps_count'] as int? ?? 0;
    final isPoints   =
        (card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    final required   = isPoints
        ? (card['merchants']?['points_required'] as int? ?? 100)
        : (card['merchants']?['stamps_required'] as int? ?? 10);
    final reward     = card['merchants']?['reward_description'] as String? ?? '';
    final color      = _cardColor(merchantId);
    final selected   = _selected.contains(id);
    final initials   = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    final pct        = (stamps / required.toDouble()).clamp(0.0, 1.0);
    final full       = stamps >= required;

    return GestureDetector(
      onTap: () => _toggle(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFFE53E3E).withOpacity(0.45)
                  : color.withOpacity(0.35),
              blurRadius: selected ? 18 : 14,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: selected
                ? const Color(0xFFE53E3E)
                : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Orbs décoratifs (comme les vraies cartes)
              Positioned(top: -20, right: -15, child: _orb(80, 0.07)),
              Positioned(bottom: -25, left: -15, child: _orb(65, 0.05)),

              // Contenu de la carte
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row : label + avatar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARTE FIDÉLITÉ',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: full
                                ? Colors.white.withOpacity(0.25)
                                : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Contenu central : tampons ou points
                    if (isPoints)
                      _miniPointsContent(stamps, required)
                    else
                      _miniStampsContent(stamps, required, color),

                    const SizedBox(height: 8),

                    // Info + barre
                    Text(
                      full
                          ? '🎁 $reward !'
                          : '$stamps/$required ${isPoints ? 'pts' : 'tampons'}',
                      style: TextStyle(
                        color: full ? Colors.white : Colors.white.withOpacity(0.75),
                        fontSize: 9,
                        fontWeight: full ? FontWeight.w700 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    _progressBar(pct, full),
                  ],
                ),
              ),

              // Overlay sélection
              if (selected)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: selected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53E3E).withOpacity(0.28),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE53E3E),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStampsContent(int stamps, int required, Color color) {
    // Affiche max 12 cases pour garder le design compact
    final displayCount = required.clamp(1, 12);
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: List.generate(displayCount, (j) {
        final filled = j < stamps;
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: filled ? Colors.white.withOpacity(0.9) : Colors.transparent,
            border: Border.all(
                color: Colors.white.withOpacity(0.35), width: 1.2),
          ),
          child: filled
              ? Icon(Icons.check, size: 9, color: color)
              : null,
        );
      }),
    );
  }

  Widget _miniPointsContent(int points, int required) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$points',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 3, left: 3),
          child: Text(
            '/ $required',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _orb(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  Widget _progressBar(double pct, bool full) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 3,
          backgroundColor: Colors.white.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation(
              full ? Colors.white : Colors.white.withOpacity(0.85)),
        ),
      );
}
