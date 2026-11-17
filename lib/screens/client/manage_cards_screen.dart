import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/platform_route.dart';
import 'cards_tab.dart' show CardStyle;
import '../../config/app_text.dart';
import 'widgets/client_header_ios.dart' show iosReadableWidth;
import '../merchant/merchant_tokens.dart' show kPrimary, kError;

// Fond clair bleuté — utilisé partout dans cet écran
const _kBg      = Color(0xFFF5F7FA);
const _kCardBg  = Color(0xFFFFFFFF);
const _kText    = Color(0xFF0D1B2A);  // = kNavy
const _kSub     = Color(0xFF4A6080);
const _kBorder  = Color(0xFFBDD3F8);  // bleu clair léger

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
  bool _editing  = false;
  late List<dynamic> _cards;

  static const List<Color> _palette = [
    Color(0xFF2C7BE5), Color(0xFFC0392B), Color(0xFF27AE60),
    Color(0xFF7B4FBF), Color(0xFF0097A7), Color(0xFFE67E22),
  ];

  CardStyle _styleFromCard(Map card, int index) => CardStyle.fromDesign(
    card['card_design'],
    merchantLogoUrl: card['merchants']?['logo_url'] as String?,
    fallbackColor: _palette[index % _palette.length],
  );

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
    if (_selected.contains(id)) _selected.remove(id);
    else _selected.add(id);
  });

  Widget _rewardsWarning(int lostRewards) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFCD34D)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: Color(0xFF92400E), size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(
        '$lostRewards récompense${lostRewards > 1 ? 's' : ''} '
        '${lostRewards > 1 ? 'seront perdues' : 'sera perdue'} définitivement.',
        style: const TextStyle(color: Color(0xFF92400E), fontSize: 12,
            fontWeight: FontWeight.w600, height: 1.4),
      )),
    ]),
  );

  Widget _buildDeleteDialog({
    required BuildContext ctx, required int n, required int lostRewards,
    required int countdown, required VoidCallback onCancel,
    required VoidCallback? onConfirm,
  }) {
    final title = 'Supprimer $n carte${n > 1 ? 's' : ''} ?';
    const body = 'Cette action est irréversible.\nTes tampons et ton historique seront perdus définitivement.';
    final confirmLabel = countdown > 0 ? 'Supprimer ($countdown)' : 'Supprimer';
    return CupertinoAlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 4), const Text(body),
        if (lostRewards > 0) _rewardsWarning(lostRewards),
      ]),
      actions: [
        CupertinoDialogAction(onPressed: onCancel, child: const Text('Annuler')),
        CupertinoDialogAction(
          isDestructiveAction: true, onPressed: onConfirm,
          child: Text(confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    final selectedMerchantIds = _cards
        .where((c) => _selected.contains(c['id'] as String?))
        .map((c) => c['merchant_id'] as String?).toSet();
    final lostRewards = widget.rewards
        .where((r) => selectedMerchantIds.contains(r['merchant_id'] as String?)).length;

    final confirm = await showCupertinoDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (ctx) {
        int countdown = 3;
        Timer? t;
        return StatefulBuilder(builder: (ctx, setSt) {
          t ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (!ctx.mounted) { t?.cancel(); return; }
            if (countdown > 0) setSt(() => countdown--); else t?.cancel();
          });
          return PopScope(
            onPopInvokedWithResult: (_, __) => t?.cancel(),
            child: _buildDeleteDialog(
              ctx: ctx, n: n, lostRewards: lostRewards, countdown: countdown,
              onCancel: () { t?.cancel(); Navigator.pop(ctx, false); },
              onConfirm: countdown == 0
                  ? () { t?.cancel(); Navigator.pop(ctx, true); } : null,
            ),
          );
        });
      },
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    final toDelete = Set<String>.from(_selected);
    for (final id in toDelete) {
      try {
        await http.delete(Uri.parse('$apiUrl/cards/$id'),
            headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? widget.token}'});
      } catch (_) {}
    }
    setState(() {
      _cards.removeWhere((c) => toDelete.contains(c['id'] as String?));
      _selected.clear();
      _deleting = false;
    });
    widget.onRefresh();
  }

  String _initials(String name) {
    final w = name.trim().split(RegExp(r'\s+')).where((e) =>
        RegExp(r'^[A-Za-zÀ-ÿ0-9]').hasMatch(e)).toList();
    if (w.isEmpty) return '';
    return (w.length >= 2
        ? '${w[0][0]}${w[1][0]}'
        : w[0].substring(0, w[0].length < 2 ? w[0].length : 2)).toUpperCase();
  }

  Widget _cardRow(Map card, int index) {
    final id       = card['id'] as String? ?? '';
    final m        = (card['merchants'] as Map?) ?? const {};
    final name     = m['business_name'] as String? ?? '';
    final isPoints = (m['program_type'] as String? ?? 'stamps') == 'points';
    final count    = isPoints ? (card['points_count'] as int? ?? 0) : (card['stamps_count'] as int? ?? 0);
    final goal     = isPoints ? (m['points_required'] as int? ?? 100) : (m['stamps_required'] as int? ?? 10);
    final style    = _styleFromCard(card, index);
    final selected = _selected.contains(id);

    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _editing ? () => _toggle(id) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(children: [
          if (_editing) ...[
            Icon(
              selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: selected ? kPrimary : _kSub.withValues(alpha: 0.5), size: 24),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 42, height: 42,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(fit: StackFit.expand, children: [
                style.buildBackground(),
                Center(child: Text(_initials(name),
                    style: TextStyle(color: style.textColor, fontSize: 14,
                        fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: _kText)),
            Text(isPoints ? '$count/$goal pts' : '$count/$goal tampons',
                style: const TextStyle(fontSize: 13, color: _kSub)),
          ])),
          if (!_editing)
            Icon(CupertinoIcons.chevron_forward, size: 14,
                color: _kBorder),
        ]),
      ),
    );

    if (_editing) return row;
    return Dismissible(
      key: ValueKey('mc-$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kError.withValues(alpha: 0.7), kError],
          ),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Text('Supprimer',
            style: TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w600)),
      ),
      confirmDismiss: (_) async {
        setState(() { _selected..clear()..add(id); });
        await _deleteSelected();
        return false;
      },
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards  = _sorted;
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: iosReadableWidth(Stack(children: [
        const Positioned.fill(child: _LightBg()),
        ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, bottom + (_editing ? 110 : 30)),
          children: [
            Row(children: [
              _LightBtn(icon: CupertinoIcons.chevron_left,
                  onTap: () => Navigator.maybePop(context)),
              const Spacer(),
              if (_cards.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() { _editing = !_editing; _selected.clear(); }),
                  child: Text(_editing ? 'OK' : 'Modifier',
                      style: const TextStyle(fontSize: 17,
                          fontWeight: FontWeight.w600, color: kPrimary)),
                ),
            ]),
            const SizedBox(height: 14),
            const Text('Mes cartes',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                    letterSpacing: -0.5, color: _kText)),
            Text('${_cards.length} carte${_cards.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 15, color: _kSub)),
            const SizedBox(height: 16),
            _LightSearch(onChanged: (v) => setState(() => _search = v)),
            const SizedBox(height: 10),
            _SortPills(sort: _sort, onChanged: (v) => setState(() => _sort = v)),
            const SizedBox(height: 18),
            if (cards.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Center(child: Text('Aucune carte trouvée',
                    style: TextStyle(fontSize: 15,
                        color: _kSub.withValues(alpha: 0.7)))),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder),
                  boxShadow: [
                    BoxShadow(color: kBlueLight.withValues(alpha: 0.08),
                        blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: EdgeInsets.only(left: _editing ? 102 : 68),
                        child: Container(height: 0.5,
                            color: _kBorder.withValues(alpha: 0.6)),
                      ),
                    _cardRow(cards[i] as Map, i),
                  ],
                ]),
              ),
            if (!_editing && cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text('Glisse une carte vers la gauche pour la supprimer.',
                    style: TextStyle(fontSize: 11,
                        color: _kSub.withValues(alpha: 0.7))),
              ),
          ],
        ),
        if (_editing)
          Positioned(
            left: 16, right: 16, bottom: bottom + 12,
            child: GestureDetector(
              onTap: _selected.isEmpty || _deleting ? null : _deleteSelected,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _selected.isEmpty
                      ? _kCardBg
                      : kError.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selected.isEmpty
                        ? _kBorder
                        : kError.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(color: kBlueLight.withValues(alpha: 0.08),
                        blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: _deleting
                    ? const CupertinoActivityIndicator()
                    : Text(
                        _selected.isEmpty
                            ? 'Choisis des cartes'
                            : 'Supprimer (${_selected.length})',
                        style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600,
                          color: _selected.isEmpty ? _kSub : kError,
                        )),
              ),
            ),
          ),
      ])),
    );
  }
}

// ── Orbes claires ───────────────────────────────────────────────────────────

class _LightBg extends StatelessWidget {
  const _LightBg();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(top: -80, right: -80,
          child: _orb(240, const Color(0xFF93C5FD).withValues(alpha: 0.14))),
      Positioned(bottom: 60, left: -100,
          child: _orb(220, const Color(0xFFA78BFA).withValues(alpha: 0.09))),
      Positioned(top: 320, right: -50,
          child: _orb(170, const Color(0xFF67E8F9).withValues(alpha: 0.10))),
    ]);
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color, blurRadius: size * 0.9,
          spreadRadius: size * 0.3)],
    ),
  );
}

// ── Bouton retour ───────────────────────────────────────────────────────────

class _LightBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _LightBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: 0.10),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: const Icon(CupertinoIcons.chevron_left, color: _kText, size: 18),
      ),
    );
  }
}

// ── Barre de recherche ──────────────────────────────────────────────────────

class _LightSearch extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _LightSearch({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: kBlueLight.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        const Icon(CupertinoIcons.search, color: _kSub, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(color: _kText, fontSize: 15),
            cursorColor: kPrimary,
            decoration: const InputDecoration(
              hintText: 'Rechercher une carte',
              hintStyle: TextStyle(color: _kSub, fontSize: 15),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Pills de tri ────────────────────────────────────────────────────────────

class _SortPills extends StatelessWidget {
  final _SortMode sort;
  final ValueChanged<_SortMode> onChanged;
  const _SortPills({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (_SortMode.recent,     'Récentes'),
      (_SortMode.oldest,     'Anciennes'),
      (_SortMode.mostStamps, 'Tampons'),
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(items[i].$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 36,
              decoration: BoxDecoration(
                color: sort == items[i].$1 ? kPrimary : _kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sort == items[i].$1
                      ? kPrimary
                      : _kBorder,
                ),
                boxShadow: sort == items[i].$1 ? [
                  BoxShadow(color: kPrimary.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ] : [],
              ),
              alignment: Alignment.center,
              child: Text(items[i].$2,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: sort == items[i].$1
                        ? Colors.white
                        : _kSub,
                  )),
            ),
          ),
        ),
      ],
    ]);
  }
}
