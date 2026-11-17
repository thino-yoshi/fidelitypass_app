import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/platform_route.dart';
import 'cards_tab.dart' show CardStyle;
import '../../config/app_text.dart';
import 'widgets/client_notifications_ios.dart' show GlassBackButton;
import 'widgets/client_header_ios.dart' show iosReadableWidth;
import '../merchant/merchant_tokens.dart' show kPrimary, kError;

enum _SortModeIos { recent, oldest, mostStamps, leastStamps }

class ManageCardsScreenIos extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> cards;
  final List<dynamic> rewards;
  final VoidCallback onRefresh;

  const ManageCardsScreenIos({
    super.key,
    required this.token,
    required this.userName,
    required this.cards,
    this.rewards = const [],
    required this.onRefresh,
  });

  @override
  State<ManageCardsScreenIos> createState() => _ManageCardsScreenIosState();
}

class _ManageCardsScreenIosState extends State<ManageCardsScreenIos> {
  _SortModeIos _sort = _SortModeIos.recent;
  String _search = '';
  final Set<String> _selected = {};
  bool _deleting = false;
  bool _editing  = false;
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
      case _SortModeIos.recent:
        list.sort((a, b) {
          final da = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
          return db.compareTo(da);
        });
      case _SortModeIos.oldest:
        list.sort((a, b) {
          final da = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
          return da.compareTo(db);
        });
      case _SortModeIos.mostStamps:
        list.sort((a, b) =>
            (b['stamps_count'] as int? ?? 0).compareTo(a['stamps_count'] as int? ?? 0));
      case _SortModeIos.leastStamps:
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

  Widget _buildDeleteDialog({
    required BuildContext ctx,
    required int n,
    required int lostRewards,
    required int countdown,
    required VoidCallback onCancel,
    required VoidCallback? onConfirm,
  }) {
    final title = 'Supprimer $n carte${n > 1 ? 's' : ''} ?';
    const body = 'Tes tampons et ton historique seront perdus. Tu ne pourras pas revenir en arrière.';
    const confirmLabel = 'Supprimer';

    return CupertinoAlertDialog(
      title: Text(title),
      // Apple : une alerte ne contient que du texte (pas d'encadré coloré).
      content: Text(lostRewards > 0
          ? '$body Tu perdras aussi $lostRewards récompense${lostRewards > 1 ? 's' : ''} pas encore utilisée${lostRewards > 1 ? 's' : ''}.'
          : body),
      actions: [
        CupertinoDialogAction(isDefaultAction: true, onPressed: onCancel, child: const Text('Annuler')),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: onConfirm,
          child: const Text(confirmLabel),
        ),
      ],
    );
  }

  Future<void> _deleteSelected() async {
    final n = _selected.length;

    final selectedMerchantIds = _cards
        .where((c) => _selected.contains(c['id'] as String?))
        .map((c) => c['merchant_id'] as String?)
        .toSet();
    final lostRewards = widget.rewards
        .where((r) => selectedMerchantIds.contains(r['merchant_id'] as String?))
        .length;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int countdown = 0; // Apple : pas d'attente avant de pouvoir confirmer
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
              child: _buildDeleteDialog(
                ctx: ctx,
                n: n,
                lostRewards: lostRewards,
                countdown: countdown,
                onCancel: () { t?.cancel(); Navigator.pop(ctx, false); },
                onConfirm: countdown == 0 ? () { t?.cancel(); Navigator.pop(ctx, true); } : null,
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

  String _initials(String name) {
    final w = name.trim().split(RegExp(r'\s+')).where((e) => RegExp(r'^[A-Za-zÀ-ÿ0-9]').hasMatch(e)).toList();
    if (w.isEmpty) return '';
    return (w.length >= 2 ? '${w[0][0]}${w[1][0]}' : w[0].substring(0, w[0].length < 2 ? w[0].length : 2)).toUpperCase();
  }

  Widget _seg(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.cText)),
      );

  Widget _iosRow(Map card, int index) {
    final id = card['id'] as String? ?? '';
    final m = (card['merchants'] as Map?) ?? const {};
    final name = m['business_name'] as String? ?? '';
    final isPoints = (m['program_type'] as String? ?? 'stamps') == 'points';
    final count = isPoints ? (card['points_count'] as int? ?? 0) : (card['stamps_count'] as int? ?? 0);
    final goal = isPoints ? (m['points_required'] as int? ?? 100) : (m['stamps_required'] as int? ?? 10);
    final style = _styleFromCard(card, index);
    final selected = _selected.contains(id);
    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _editing ? () => _toggle(id) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          if (_editing) ...[
            Icon(selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                color: selected ? kPrimary : context.cSub.withValues(alpha: 0.6), size: 24),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 42, height: 42,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(fit: StackFit.expand, children: [
                style.buildBackground(),
                Center(child: Text(_initials(name), style: TextStyle(color: style.textColor, fontSize: 14, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: QText.body.copyWith(fontSize: 17, color: context.cText)),
              Text(isPoints ? '$count/$goal pts' : '$count/$goal tampons', style: QText.caption.copyWith(fontSize: 14, color: context.cSub)),
            ]),
          ),
        ]),
      ),
    );
    if (_editing) return row;
    return _IosSwipeRow(
      key: ValueKey('mc-$id'),
      surface: context.cSurface,
      onDelete: () async {
        setState(() { _selected..clear()..add(id); });
        await _deleteSelected();
      },
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _sorted;
    return _buildIos(cards);
  }

  Widget _buildIos(List<dynamic> cards) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: context.cBg,
      body: iosReadableWidth(Stack(children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, bottom + (_editing ? 100 : 30)),
          children: [
            Row(children: [
              GlassBackButton(onTap: () => Navigator.maybePop(context)),
              const Spacer(),
              if (_cards.isNotEmpty)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: () => setState(() { _editing = !_editing; _selected.clear(); }),
                  child: Text(_editing ? 'OK' : 'Modifier',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kPrimary)),
                ),
            ]),
            const SizedBox(height: 14),
            Text('Mes cartes', style: QText.largeTitle(context).copyWith(color: context.cText)),
            Text('${_cards.length} carte${_cards.length > 1 ? 's' : ''}', style: QText.body.copyWith(fontSize: 17, color: context.cSub)),
            const SizedBox(height: 14),
            CupertinoSearchTextField(
              placeholder: 'Rechercher une carte',
              onChanged: (v) => setState(() => _search = v),
              style: QText.body.copyWith(fontSize: 17, color: context.cText),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<_SortModeIos>(
                groupValue: _sort == _SortModeIos.leastStamps ? _SortModeIos.mostStamps : _sort,
                padding: const EdgeInsets.all(2),
                children: {
                  _SortModeIos.recent:  _seg('Récentes'),
                  _SortModeIos.oldest:  _seg('Anciennes'),
                  _SortModeIos.mostStamps: _seg('Tampons'),
                },
                onValueChanged: (v) { if (v != null) setState(() => _sort = v); },
              ),
            ),
            const SizedBox(height: 18),
            if (cards.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Center(child: Text('Aucune carte trouvée', style: QText.body.copyWith(color: context.cSub))),
              )
            else
              Container(
                decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) Padding(padding: EdgeInsets.only(left: _editing ? 102 : 70), child: Container(height: 0.5, color: context.cBorder)),
                    _iosRow(cards[i] as Map, i),
                  ],
                ]),
              ),
            if (!_editing && cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Glisse une carte vers la gauche pour la supprimer.', style: QText.label.copyWith(color: context.cSub)),
              ),
          ],
        ),
        if (_editing)
          Positioned(
            left: 16, right: 16, bottom: bottom + 12,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 15),
              borderRadius: BorderRadius.circular(14),
              color: kError,
              disabledColor: context.cSub.withValues(alpha: 0.25),
              onPressed: _selected.isEmpty || _deleting ? null : _deleteSelected,
              child: _deleting
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(_selected.isEmpty ? 'Choisis des cartes' : 'Supprimer (${_selected.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
      ])),
    );
  }
}


/// Ligne qu'on glisse vers la gauche, comme dans les listes iPhone :
/// la ligne se décale et laisse voir un bouton rouge « Supprimer » collé à droite.
/// Glisser jusqu'au bout = supprimer directement (avec l'alerte de confirmation).
class _IosSwipeRow extends StatefulWidget {
  final Widget child;
  final Color surface;
  final Future<void> Function() onDelete;
  const _IosSwipeRow({super.key, required this.child, required this.surface, required this.onDelete});

  @override
  State<_IosSwipeRow> createState() => _IosSwipeRowState();
}

class _IosSwipeRowState extends State<_IosSwipeRow> with SingleTickerProviderStateMixin {
  static const double _btn = 96; // largeur du bouton rouge
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  double _dx = 0;       // décalage actuel (négatif = vers la gauche)
  double _width = 1;

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  void _animateTo(double target) {
    final from = _dx;
    final anim = Tween<double>(begin: from, end: target).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    void tick() => setState(() => _dx = anim.value);
    anim.addListener(tick);
    _c.forward(from: 0).whenComplete(() => anim.removeListener(tick));
  }

  Future<void> _delete() async {
    _animateTo(0);
    await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _width = c.maxWidth;
      final open = -_dx; // largeur visible du rouge
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dx != 0 ? () => _animateTo(0) : null,
        onHorizontalDragUpdate: (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(-_width, 0)),
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (-_dx > _width * 0.6) { _delete(); return; }          // glissé jusqu'au bout
          if (v < -300 || -_dx > _btn / 2) { _animateTo(-_btn); }   // reste ouvert
          else { _animateTo(0); }                                   // se referme
        },
        child: Stack(children: [
          if (open > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _delete,
                  child: Container(
                    width: open,
                    color: kError,
                    alignment: Alignment.center,
                    child: open > 60
                        ? const Text('Supprimer', maxLines: 1, overflow: TextOverflow.clip, softWrap: false,
                            style: TextStyle(color: Colors.white, fontSize: 17))
                        : null,
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: ColoredBox(color: widget.surface, child: widget.child),
          ),
        ]),
      );
    });
  }
}
