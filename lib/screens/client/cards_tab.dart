import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoActivityIndicator;
import 'package:flutter/physics.dart';
import '../../config/demo_mode.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import 'widgets/client_pass_face_ios.dart';
import 'widgets/client_cards_stack_ios.dart';
import 'widgets/client_hours.dart';
import 'widgets/client_sheets_ios.dart' show showIosAlert;
import '../merchant/merchant_tokens.dart' show kIsIOS;

/// Événement émis quand le commerçant ajoute des tampons/points à une carte
/// pendant que le client a son QR ouvert (détecté par polling).
class StampEvent {
  final String cardId;
  final String merchantName;
  final int delta;       // nb tampons/points ajoutés (0 si inconnu)
  final int newCount;
  final int total;
  final bool reward;     // true si la récompense vient d'être atteinte
  final bool isPoints;
  const StampEvent({
    required this.cardId,
    required this.merchantName,
    required this.delta,
    required this.newCount,
    required this.total,
    required this.reward,
    required this.isPoints,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// Modèle de grille modulaire — grille 2 colonnes fixes
// ════════════════════════════════════════════════════════════════════════════

enum _ModSize {
  small, // 1 cellule carrée (½ largeur)
  wide,  // 1 ligne pleine largeur
  large, // 2 lignes pleine largeur (cards uniquement)
}

class _Mod {
  final String id;
  _ModSize size;
  int row; // position fixe dans la grille (trous possibles)
  _Mod(this.id, {this.size = _ModSize.wide, this.row = 0});
  Map<String, dynamic> toJson() => {'id': id, 'sz': size.name, 'r': row};
  static _Mod fromJson(Map<String, dynamic> j) {
    final sz = switch (j['sz'] as String? ?? '') {
      'small'  => _ModSize.small,
      'large'  => _ModSize.large,
      'square' => _ModSize.small, // migration ancienne sauvegarde
      _        => _ModSize.wide,
    };
    return _Mod(j['id'] as String, size: sz, row: (j['r'] as int?) ?? 0);
  }
}

class CardsTab extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> cards;
  final VoidCallback onRefresh;
  final void Function(StampEvent)? onStampEvent;
  final String? cardIdToAnimate;
  final String? cardIdToSlideIn;
  final VoidCallback? onAnimationDone;
  final VoidCallback? onScanTap;
  final ValueChanged<bool>? onSearchActive;
  final int activeTab;
  final ValueChanged<int>? onNavTap;

  const CardsTab({
    super.key,
    required this.token,
    required this.userName,
    required this.cards,
    required this.onRefresh,
    this.onStampEvent,
    this.cardIdToAnimate,
    this.cardIdToSlideIn,
    this.onAnimationDone,
    this.onScanTap,
    this.onSearchActive,
    this.activeTab = 0,
    this.onNavTap,
  });

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> with TickerProviderStateMixin {
  static final _kDefault = [
    _Mod('greeting', size: _ModSize.wide,  row: 0),
    _Mod('cards',    size: _ModSize.large, row: 1),
    _Mod('navdock',  size: _ModSize.wide,  row: 2),
  ];

  static const List<Color> _palette = [
    Color(0xFF2C7BE5),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFF7B4FBF),
    Color(0xFF0097A7),
    Color(0xFFE67E22),
  ];

  List<_Mod> _mods = _kDefault.map((m) => _Mod(m.id, size: m.size, row: m.row)).toList();
  String _search = '';
  int    _activeCard = 0;

  // ── Drag & drop modulaire ──────────────────────────────────────────────────
  String? _dragId;    // id du module en mode édition/drag actif
  final   _scrollCtrl = ScrollController();
  final   Map<int, GlobalKey> _rowKeys = {};
  late    AnimationController _snapCtrl;
  final   _rootStackKey = GlobalKey();

  CardStyle _styleFromCard(Map card, int i) => CardStyle.fromDesign(
    card['card_design'],
    merchantLogoUrl: (card['merchants']?['logo_url'] as String?),
    fallbackColor: _palette[i % _palette.length],
  );

  static RectTween _straightRect(Rect? b, Rect? e) => RectTween(begin: b, end: e);

  static Widget _passShuttle(Map card, CardStyle style, Animation<double> anim, {required bool collapsedAtRest}) {
    final full = ClientPassFaceIos(card: card, style: style);
    if (!collapsedAtRest) return Material(type: MaterialType.transparency, child: full);
    final t = CurvedAnimation(parent: anim, curve: const Interval(0.0, 0.3, curve: Curves.easeOut));
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: t,
        builder: (_, __) => t.value >= 1
            ? full
            : Stack(fit: StackFit.expand, children: [
                ClientPassFaceIos(card: card, style: style, collapsed: true),
                Opacity(opacity: t.value, child: full),
              ]),
      ),
    );
  }

  void _popOutCard(Map card, CardStyle style) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, _) => CardPopOut(
        heroTag: 'card-${card['id']}',
        animation: anim,
        face: ClientPassFaceIos(card: card, style: style),
        onOpen: () => Navigator.of(ctx).pushReplacement(_openCardRoute(card, style)),
      ),
    ));
  }

  Route<void> _openCardRoute(Map card, CardStyle style) => PageRouteBuilder(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (ctx, anim, _) => OpenCardPage(
      animation: anim,
      child: QRModal(
        token: widget.token, card: card, style: style,
        userName: widget.userName, onStampAdded: widget.onRefresh,
        onStampEvent: widget.onStampEvent, heroTag: 'card-${card['id']}',
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _snapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _snapCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('qarta_home_mods_v2');
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((j) => _Mod.fromJson(j as Map<String, dynamic>))
          .toList();
      final validIds = _kDefault.map((m) => m.id).toSet();
      // Filtrer les ids obsolètes (ex: 'progress' retiré) + vérifier tous présents
      final filtered = list.where((m) => validIds.contains(m.id)).toList();
      if (validIds.every((id) => filtered.any((m) => m.id == id)) && mounted) {
        // Migration depuis ancienne sauvegarde sans 'r' : tous row=0 → collision
        // Réassigner les rows selon l'ordre de la liste
        final uniqueRows = filtered.map((m) => m.row).toSet();
        if (uniqueRows.length < filtered.length) {
          for (var i = 0; i < filtered.length; i++) filtered[i].row = i;
        }
        setState(() => _mods = filtered);
      }
    } catch (_) {}
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('qarta_home_mods_v2', jsonEncode(_mods.map((m) => m.toJson()).toList()));
  }

  // Nombre de rows dans la grille : max(row) + 2 (1 zone vide en bas pour drop)
  int get _gridRowCount {
    if (_mods.isEmpty) return 4;
    return _mods.map((m) => m.row).reduce(max) + 2;
  }

  // Modules présents sur une row (peut être vide = trou)
  List<_Mod> _modsAtRow(int r) => _mods.where((m) => m.row == r).toList();

  void _toggleSize(String id) {
    final m = _mods.firstWhere((m) => m.id == id);
    final wasSmall = m.size == _ModSize.small;
    setState(() {
      m.size = wasSmall ? _ModSize.wide : _ModSize.small;
      if (wasSmall) {
        // small → wide : chercher une row entièrement vide, sinon créer une nouvelle
        final occupiedRows = _mods.where((x) => x.id != id).map((x) => x.row).toSet();
        int emptyRow = 0;
        while (occupiedRows.contains(emptyRow)) emptyRow++;
        m.row = emptyRow;
      }
    });
    _saveOrder();
  }

  List<dynamic> get _filteredCards {
    if (_search.isEmpty) return widget.cards;
    final q = _search.toLowerCase();
    return widget.cards.where((c) {
      final name  = (c['merchants']?['business_name'] as String? ?? '').toLowerCase();
      final cName = ((c['card_design'] as Map?)?['cardName'] as String? ?? '').toLowerCase();
      return name.contains(q) || cName.contains(q);
    }).toList();
  }

  // ── Drag helpers ───────────────────────────────────────────────────────────

  // Déplace un module vers une row cible.
  // - Slot vide → move simple
  // - Slot avec 1 small + drag est small → côte à côte sur la même row
  // - Sinon → swap (les cibles vont à l'ancienne row du drag)
  void _moveToRow(String dragId, int targetRow) {
    final drag = _mods.firstWhere((m) => m.id == dragId);
    final originRow = drag.row;
    final at = _modsAtRow(targetRow);

    if (at.isEmpty) {
      drag.row = targetRow;
    } else if (at.length == 1 &&
               at[0].size == _ModSize.small &&
               drag.size == _ModSize.small) {
      // Les deux sont small → on les regroupe côte à côte
      drag.row = targetRow;
    } else {
      // Incompatible (wide, large, ou row déjà pleine) → swap
      for (final m in at) m.row = originRow;
      drag.row = targetRow;
    }
  }

  // Inverse l'ordre de deux smalls sur la même row (swap dans la liste _mods)
  void _swapSiblings(String idA, String idB) {
    final ia = _mods.indexWhere((m) => m.id == idA);
    final ib = _mods.indexWhere((m) => m.id == idB);
    if (ia >= 0 && ib >= 0) {
      final tmp = _mods[ia];
      _mods[ia] = _mods[ib];
      _mods[ib] = tmp;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad   = MediaQuery.of(context).padding.top + 8;
    final dockPad  = MediaQuery.of(context).viewPadding.bottom + 20;
    final filtered = _filteredCards;
    final rowCount = _gridRowCount;

    return Stack(key: _rootStackKey, children: [
      const Positioned.fill(child: _NightBg()),
      SingleChildScrollView(
        controller: _scrollCtrl,
        padding: EdgeInsets.fromLTRB(16, topPad, 16, dockPad),
        child: Column(
          children: [
            for (var r = 0; r < rowCount; r++)
              _buildRow(r, _modsAtRow(r), filtered),
          ],
        ),
      ),
      if (_dragId != null)
        Positioned(
          bottom: dockPad + 16,
          right:  16,
          child: _buildDragButtons(),
        ),
    ]);
  }

  Widget _buildRow(int rowIdx, List<_Mod> mods, List<dynamic> filtered) {
    final rowKey   = _rowKeys.putIfAbsent(rowIdx, () => GlobalKey());
    final isEmpty  = mods.isEmpty;
    final isOrigin = _dragId != null && mods.any((m) => m.id == _dragId);

    return Padding(
      key: ValueKey('row_$rowIdx'),
      padding: const EdgeInsets.only(bottom: 14),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => !isOrigin,
        onAcceptWithDetails: (d) {
          setState(() => _moveToRow(d.data, rowIdx));
          _saveOrder();
        },
        builder: (ctx, candidates, _) {
          final hovered = candidates.isNotEmpty && !isOrigin;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: hovered
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color:  Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  )
                : null,
            child: Container(
              key: rowKey,
              child: isEmpty
                  ? _buildEmptySlot(hovered)
                  : _buildRowContent(rowIdx, mods, filtered),
            ),
          );
        },
      ),
    );
  }

  // Slot vide : visible pendant le drag, invisible sinon
  Widget _buildEmptySlot(bool hovered) {
    if (_dragId == null) return const SizedBox.shrink();
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: hovered ? 0.0 : 0.15),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildDragButtons() {
    if (_dragId == null) return const SizedBox.shrink();
    final mod = _mods.where((m) => m.id == _dragId!).firstOrNull;
    if (mod == null) return const SizedBox.shrink();

    // Sibling small sur la même row (pour le bouton ↔)
    final rowMates = _modsAtRow(mod.row).where((m) => m.id != _dragId).toList();
    final sibling  = (rowMates.length == 1 && rowMates[0].size == _ModSize.small)
        ? rowMates[0] : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton ↔ inverser les deux smalls côte à côte
        if (sibling != null) ...[
          GestureDetector(
            onTap: () {
              setState(() => _swapSiblings(_dragId!, sibling.id));
              _saveOrder();
            },
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: Color(0xFFFF9500), shape: BoxShape.circle),
              child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (mod.id != 'cards') ...[
          GestureDetector(
            onTap: () {
              _toggleSize(mod.id);
              setState(() => _dragId = null);
            },
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
              child: Center(child: Icon(
                mod.size == _ModSize.wide ? Icons.crop_square_rounded : Icons.crop_landscape_rounded,
                color: Colors.white, size: 20,
              )),
            ),
          ),
          const SizedBox(width: 10),
        ],
        GestureDetector(
          onTap: () => setState(() => _dragId = null),
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildRowContent(int rowIdx, List<_Mod> mods, List<dynamic> filtered) {
    return LayoutBuilder(builder: (_, cst) {
      final fullW = cst.maxWidth;
      final halfW = (fullW - 10) / 2;

      if (mods.length >= 2) {
        return Row(children: [
          Expanded(child: _draggableTile(rowIdx, mods[0], halfW, filtered)),
          const SizedBox(width: 10),
          Expanded(child: _draggableTile(rowIdx, mods[1], halfW, filtered)),
        ]);
      }
      final mod = mods[0];
      if (mod.size == _ModSize.small) {
        return Row(children: [
          Expanded(child: _draggableTile(rowIdx, mod, halfW, filtered)),
          const SizedBox(width: 10),
          const Expanded(child: SizedBox()),
        ]);
      }
      return _draggableTile(rowIdx, mod, fullW, filtered);
    });
  }

  Widget _draggableTile(int rowIdx, _Mod mod, double tileW, List<dynamic> filtered) {
    final content = mod.size == _ModSize.small
        ? _GlassCard(child: _squareBody(mod.id, filtered))
        : _GlassCard(child: _rectBody(mod.id, filtered));
    final feedback = mod.size == _ModSize.small
        ? _GlassCard(child: _squareBody(mod.id, _filteredCards))
        : _GlassCard(child: _rectBody(mod.id, _filteredCards));

    return LongPressDraggable<String>(
      data: mod.id,
      delay: const Duration(milliseconds: 400),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: tileW,
          child: Opacity(
            opacity: 0.92,
            child: Transform.scale(
              scale: 1.05,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  )],
                ),
                child: feedback,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: SizedBox(width: tileW),
      onDragStarted: () => setState(() => _dragId = mod.id),
      onDragEnd:     (_) {/* _dragId reste pour les boutons */},
      child: content,
    );
  }

  Widget _rectBody(String id, List<dynamic> filtered) {
    switch (id) {
      case 'greeting':
        return _GreetingModule(userName: widget.userName, cardCount: widget.cards.length);
      case 'cards':
        return _CardsWalletModule(
          cards: filtered,
          scanTap: widget.onScanTap,
          userName: widget.userName,
          onOpen: () => Navigator.of(context).push(_openCardsRoute()),
        );
      case 'navdock':
        return _NavDockRect(activeTab: widget.activeTab, onTap: widget.onNavTap ?? (_) {});
      default:
        return const SizedBox.shrink();
    }
  }

  // Body pour _ModSize.small (½ largeur)
  Widget _squareBody(String id, List<dynamic> filtered) {
    switch (id) {
      case 'greeting':
        return _GreetingSquare(userName: widget.userName);
      case 'navdock':
        return _NavDockSquare(activeTab: widget.activeTab, onTap: widget.onNavTap ?? (_) {});
      default:
        return _rectBody(id, filtered); // fallback : version rect
    }
  }

  Route<void> _openCardsRoute() {
    return PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim, _) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween(begin: 0.88, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: CurvedAnimation(
                parent: anim, curve: const Interval(0.0, 0.5)),
            child: _CardsFullPage(
              token: widget.token,
              userName: widget.userName,
              cards: widget.cards,
              palette: _palette,
              onRefresh: widget.onRefresh,
              onStampEvent: widget.onStampEvent,
              onScanTap: widget.onScanTap,
              onPopOutCard: (card, style) {
                Navigator.of(ctx).pop();
                Future.microtask(() => _popOutCard(card, style));
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Wallet Module — bulle compacte (toutes cartes pliées, tap → plein écran)
// ════════════════════════════════════════════════════════════════════════════

class _CardsWalletModule extends StatelessWidget {
  final List<dynamic> cards;
  final VoidCallback? scanTap;
  final VoidCallback onOpen;
  final String userName;
  const _CardsWalletModule({
    required this.cards,
    required this.onOpen,
    required this.userName,
    this.scanTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return GestureDetector(
        onTap: onOpen,
        child: _EmptyCardsModule(onScanTap: scanTap),
      );
    }
    const cardH    = 90.0;  // hauteur d'une carte en mode compact
    const cardPeek = 14.0;  // pixels visibles de chaque carte en dessous
    const maxCards = 3;
    final shown  = cards.length.clamp(1, maxCards);
    final totalH = cardH + (shown - 1) * cardPeek;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: totalH,
            // Les cartes du dessous sont les premiers enfants du Stack
            // → la carte[0] est en dernier = au premier plan
            child: Stack(children: [
              for (var i = shown - 1; i >= 0; i--)
                Positioned(
                  top: (i * cardPeek),
                  left: 0, right: 0,
                  height: cardH,
                  child: LoyaltyCardFace(
                    card: cards[i] as Map,
                    style: CardStyle.fromDesign(
                      (cards[i] as Map)['card_design'],
                      merchantLogoUrl: ((cards[i] as Map)['merchants']?['logo_url'] as String?),
                      fallbackColor: _CardsTabState._palette[i % _CardsTabState._palette.length],
                    ),
                    userName: userName,
                    compact: true,
                  ),
                ),
            ]),
          ),
          if (cards.length > maxCards)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${cards.length - maxCards} cartes',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Cards Full Page — plein écran avec bouton retour
// ════════════════════════════════════════════════════════════════════════════

class _CardsFullPage extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> cards;
  final List<Color> palette;
  final VoidCallback onRefresh;
  final void Function(StampEvent)? onStampEvent;
  final VoidCallback? onScanTap;
  final void Function(Map, CardStyle) onPopOutCard;

  const _CardsFullPage({
    required this.token, required this.userName, required this.cards,
    required this.palette, required this.onRefresh, required this.onPopOutCard,
    this.onStampEvent, this.onScanTap,
  });

  @override
  State<_CardsFullPage> createState() => _CardsFullPageState();
}

class _CardsFullPageState extends State<_CardsFullPage> {
  @override
  Widget build(BuildContext context) {
    final topPad  = MediaQuery.of(context).padding.top;
    final dockPad = MediaQuery.of(context).viewPadding.bottom + 20;

    return Material(
      color: Colors.transparent,
      child: Stack(children: [
        const Positioned.fill(child: _NightBg()),
        // Cartes Version 1 — LoyaltyCardFace empilées, tap → QR modal
        Positioned(
          top: topPad + 60, left: 0, right: 0, bottom: dockPad,
          child: _WalletStack(
            cards: widget.cards,
            userName: widget.userName,
            onOpenCard: (card, style) => widget.onPopOutCard(card, style),
          ),
        ),
        // Bouton retour
        Positioned(
          top: topPad + 10, left: 16,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Search Sheet — clavier custom sans clavier système
// ════════════════════════════════════════════════════════════════════════════

class _SearchSheet extends StatefulWidget {
  final String initial;
  const _SearchSheet({required this.initial});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late String _q;

  static const _rows = [
    ['A','Z','E','R','T','Y','U','I','O','P'],
    ['Q','S','D','F','G','H','J','K','L','M'],
    ['W','X','C','V','B','N'],
  ];

  @override
  void initState() {
    super.initState();
    _q = widget.initial;
  }

  void _tap(String letter) => setState(() => _q += letter);
  void _del() => setState(() { if (_q.isNotEmpty) _q = _q.substring(0, _q.length - 1); });
  void _clear() => setState(() => _q = '');

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bot + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée
          Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          // Faux input
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A9BB0)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _q.isEmpty ? 'Rechercher une carte...' : _q,
                style: TextStyle(fontSize: 15, color: _q.isEmpty ? const Color(0xFF8A9BB0) : const Color(0xFF0D1B2A)),
              )),
              if (_q.isNotEmpty)
                GestureDetector(
                  onTap: _clear,
                  child: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF8A9BB0))),
                )
              else
                const SizedBox(width: 14),
            ]),
          ),
          const SizedBox(height: 20),
          // Clavier custom
          for (final row in _rows) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final l in row) _Key(label: l, onTap: () => _tap(l)),
                if (row == _rows.last) ...[
                  const SizedBox(width: 6),
                  _DelKey(onTap: _del),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Espace + Valider
          Row(children: [
            Expanded(child: _Key(label: '␣', flex: true, onTap: () => _tap(' '))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context, _q),
              child: Container(
                height: 46,
                width: 90,
                decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool flex;
  const _Key({required this.label, required this.onTap, this.flex = false});

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0D1B2A)))),
      ),
    );
    return flex ? Expanded(child: child) : SizedBox(width: 33, child: child);
  }
}

class _DelKey extends StatelessWidget {
  final VoidCallback onTap;
  const _DelKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        width: 46,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(8)),
        child: const Center(child: Icon(Icons.backspace_outlined, size: 18, color: Color(0xFF0D1B2A))),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Nouveaux widgets glass — design modulaire
// ════════════════════════════════════════════════════════════════════════════

class _NightBg extends StatelessWidget {
  const _NightBg();
  @override
  Widget build(BuildContext context) => Stack(children: [
    Container(color: const Color(0xFF0D1B2A)),
    Positioned(top: -60, left: -40,  child: _Orb(220, const Color(0xFF1A4A8A), 0.22)),
    Positioned(bottom: 120, right: -60, child: _Orb(260, const Color(0xFF2D1B6B), 0.17)),
    Positioned(top: 240, right: 30,  child: _Orb(130, const Color(0xFF0A6670), 0.15)),
  ]);
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Orb(this.size, this.color, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color.withValues(alpha: opacity), blurRadius: size, spreadRadius: size * 0.3)],
    ),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: child,
      ),
    ),
  );
}

class _GreetingModule extends StatelessWidget {
  final String userName;
  final int cardCount;
  const _GreetingModule({required this.userName, required this.cardCount});
  static const _jours = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
  static const _mois  = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
  @override
  Widget build(BuildContext context) {
    final first = userName.split(' ').first;
    final n     = DateTime.now();
    final date  = '${_jours[n.weekday - 1]} ${n.day} ${_mois[n.month - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bonjour, $first 👋',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(date, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$cardCount',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(cardCount == 1 ? 'carte' : 'cartes',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

class _CardsModule extends StatefulWidget {
  final List<dynamic> cards;
  final int activeIndex;
  final ValueChanged<int> onActiveChanged;
  final ValueChanged<String> onSearch;
  final String search;
  final ValueChanged<int> onOpen;
  final Widget Function(int) cardBuilder;
  final VoidCallback? scanTap;

  const _CardsModule({
    required this.cards, required this.activeIndex, required this.onActiveChanged,
    required this.onSearch, required this.search, required this.onOpen,
    required this.cardBuilder, this.scanTap,
  });

  @override
  State<_CardsModule> createState() => _CardsModuleState();
}

class _CardsModuleState extends State<_CardsModule> {
  static const double _cardH = 220.0;
  static const double _peek  = 54.0;

  Future<void> _openSearch() async {
    final result = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(initial: widget.search),
    );
    if (result != null) widget.onSearch(result);
  }

  Widget _stackedCard(int i, bool isActive, bool isLast) {
    const cardH = _cardH;
    const peek  = _peek;
    final framed = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => isActive ? widget.onOpen(i) : widget.onActiveChanged(i),
      child: SizedBox(height: cardH, child: widget.cardBuilder(i)),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(end: isActive ? 1.0 : peek / cardH),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, f, child) {
        if (isLast && !isActive) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Align(alignment: Alignment.topCenter,
                heightFactor: (peek + 14) / cardH, child: child),
          );
        }
        if (!isActive && f < 0.99) {
          const keep = peek + 18;
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: (f * cardH) / keep,
            child: ClipRect(child: Align(
                alignment: Alignment.topCenter,
                heightFactor: keep / cardH, child: child)),
          );
        }
        return Align(alignment: Alignment.topCenter, heightFactor: f, child: child);
      },
      child: framed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards  = widget.cards;
    final active = widget.activeIndex;

    if (cards.isEmpty) return _EmptyCardsModule(onScanTap: widget.scanTap);

    final visible = cards.length.clamp(1, 5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Barre de recherche
        GestureDetector(
          onTap: _openSearch,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, size: 18,
                  color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                widget.search.isEmpty ? 'Rechercher...' : widget.search,
                style: TextStyle(fontSize: 14,
                    color: widget.search.isEmpty
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.white),
              )),
              if (widget.search.isNotEmpty)
                GestureDetector(
                  onTap: () => widget.onSearch(''),
                  child: Padding(padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.close_rounded, size: 16,
                          color: Colors.white.withValues(alpha: 0.5))),
                )
              else
                const SizedBox(width: 12),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // Pile de cartes
        for (var i = 0; i < visible; i++)
          _stackedCard(i, i == active, i == visible - 1),
        // Indicateur pagination
        if (visible > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(visible, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == active ? 20 : 6, height: 6,
                decoration: BoxDecoration(
                  color: i == active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
      ]),
    );
  }
}

class _EmptyCardsModule extends StatelessWidget {
  final VoidCallback? onScanTap;
  const _EmptyCardsModule({this.onScanTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.credit_card_rounded, size: 48,
          color: Colors.white.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      Text('Aucune carte pour le moment',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Scanne ton premier QR code pour commencer',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: onScanTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2C7BE5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.qr_code_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Scanner une carte',
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]),
  );
}

class _ProgressModule extends StatelessWidget {
  final List<dynamic> cards;
  const _ProgressModule({required this.cards});
  @override
  Widget build(BuildContext context) {
    Map? best;
    int bCurr = 0, bTotal = 1;
    double bRatio = 0;
    for (final raw in cards) {
      final c      = raw as Map;
      final design = c['card_design'] as Map?;
      if (design == null) continue;
      final type    = design['rewardType'] as String? ?? 'stamps';
      final total   = (design['stampsRequired'] as num?)?.toInt()
          ?? (design['pointsRequired'] as num?)?.toInt() ?? 10;
      final current = type == 'points'
          ? (c['points_count'] as num?)?.toInt() ?? 0
          : (c['stamps_count'] as num?)?.toInt() ?? 0;
      if (total <= 0) continue;
      final ratio = current / total;
      if (ratio > bRatio && ratio < 1.0) {
        bRatio = ratio; best = c; bCurr = current; bTotal = total;
      }
    }
    if (best == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 20),
          const SizedBox(width: 10),
          Text('Aucune récompense en cours',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14)),
        ]),
      );
    }
    final name    = (best['merchants']?['business_name'] as String?) ?? '';
    final design  = best['card_design'] as Map?;
    final type    = design?['rewardType'] as String? ?? 'stamps';
    final label   = type == 'points' ? 'pts' : 'tampons';
    final left    = bTotal - bCurr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 8),
          Text('Prochaine récompense',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text('$bCurr / $bTotal $label',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: bRatio, minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF5BB8FF)),
          ),
        ),
        const SizedBox(height: 8),
        Text('Plus que $left $label pour votre récompense !',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Modules carrés (versions compactes)
// ════════════════════════════════════════════════════════════════════════════

class _GreetingSquare extends StatelessWidget {
  final String userName;
  const _GreetingSquare({required this.userName});
  static const _mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
  @override
  Widget build(BuildContext context) {
    final first = userName.split(' ').first;
    final n = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('👋 $first',
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${n.day} ${_mois[n.month - 1]} ${n.year}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _greet(n.hour),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
  static String _greet(int h) {
    if (h < 12) return '☀️ Bonne matinée';
    if (h < 18) return '🌤 Bon après-midi';
    return '🌙 Bonne soirée';
  }
}

class _ProgressSquare extends StatelessWidget {
  final List<dynamic> cards;
  const _ProgressSquare({required this.cards});
  @override
  Widget build(BuildContext context) {
    Map? best;
    int bCurr = 0, bTotal = 1;
    double bRatio = 0;
    for (final raw in cards) {
      final c = raw as Map;
      final design = c['card_design'] as Map?;
      if (design == null) continue;
      final type    = design['rewardType'] as String? ?? 'stamps';
      final total   = (design['stampsRequired'] as num?)?.toInt()
          ?? (design['pointsRequired'] as num?)?.toInt() ?? 10;
      final current = type == 'points'
          ? (c['points_count'] as num?)?.toInt() ?? 0
          : (c['stamps_count'] as num?)?.toInt() ?? 0;
      if (total <= 0) continue;
      final ratio = current / total;
      if (ratio > bRatio && ratio < 1.0) {
        bRatio = ratio; best = c; bCurr = current; bTotal = total;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 15),
            const SizedBox(width: 5),
            Text('Prochain', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65), fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 10),
          if (best != null) ...[
            Text('$bCurr / $bTotal',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: bRatio, minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF5BB8FF)),
              ),
            ),
            const SizedBox(height: 6),
            Text('encore ${bTotal - bCurr} pour ta récompense',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ] else
            Text('Aucune\nrécompense',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// NavDock — module de navigation (rect et carré)
// ════════════════════════════════════════════════════════════════════════════

class _NavDockRect extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTap;
  const _NavDockRect({required this.activeTab, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _NavBtn(icon: Icons.credit_card_rounded,     label: 'Cartes',      active: activeTab == 0, onTap: () => onTap(0)),
        _NavBtn(icon: Icons.qr_code_scanner_rounded, label: 'Scanner',     active: activeTab == 1, onTap: () => onTap(1), accent: true),
        _NavBtn(icon: Icons.history_rounded,         label: 'Historique',  active: activeTab == 2, onTap: () => onTap(2)),
        _NavBtn(icon: Icons.person_rounded,          label: 'Profil',      active: activeTab == 3, onTap: () => onTap(3)),
      ]),
    );
  }
}

class _NavDockSquare extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTap;
  const _NavDockSquare({required this.activeTab, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _NavBtnCompact(icon: Icons.credit_card_rounded,     active: activeTab == 0, onTap: () => onTap(0)),
          _NavBtnCompact(icon: Icons.qr_code_scanner_rounded, active: activeTab == 1, onTap: () => onTap(1), accent: true),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _NavBtnCompact(icon: Icons.history_rounded, active: activeTab == 2, onTap: () => onTap(2)),
          _NavBtnCompact(icon: Icons.person_rounded,  active: activeTab == 3, onTap: () => onTap(3)),
        ]),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool accent;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label, required this.active, required this.onTap, this.accent = false});
  @override
  Widget build(BuildContext context) {
    final color = accent
        ? const Color(0xFF5BB8FF)
        : (active ? Colors.white : Colors.white.withValues(alpha: 0.4));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (accent)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2C7BE5).withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            )
          else
            Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
              color: color, fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

class _NavBtnCompact extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool accent;
  final VoidCallback onTap;
  const _NavBtnCompact({required this.icon, required this.active, required this.onTap, this.accent = false});
  @override
  Widget build(BuildContext context) {
    final color = accent
        ? const Color(0xFF5BB8FF)
        : (active ? Colors.white : Colors.white.withValues(alpha: 0.4));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Icon(icon, color: color, size: 24)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _WalletCarousel — gardé pour compatibilité (non utilisé dans le nouveau design)
// ════════════════════════════════════════════════════════════════════════════

class _WalletCarousel extends StatefulWidget {
  final List<dynamic> cards;
  final String userName;
  const _WalletCarousel({required this.cards, required this.userName});

  @override
  State<_WalletCarousel> createState() => _WalletCarouselState();
}

class _WalletCarouselState extends State<_WalletCarousel> with SingleTickerProviderStateMixin {
  static const List<Color> _fallbackColors = [
    Color(0xFF2C7BE5), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFFF97316),
  ];

  late final FixedExtentScrollController _scroll;
  late final AnimationController _flyCtrl;
  late final Animation<Offset> _flyAnim;
  int _prevCount = 0;
  bool _flying = false;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.cards.length;
    _scroll = FixedExtentScrollController();
    _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _flyAnim = Tween<Offset>(begin: const Offset(0, -4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(_WalletCarousel old) {
    super.didUpdateWidget(old);
    if (widget.cards.length > _prevCount) {
      _prevCount = widget.cards.length;
      setState(() => _flying = true);
      _flyCtrl.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateToItem(0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
        _flyCtrl.forward().whenComplete(() {
          if (mounted) setState(() => _flying = false);
        });
      });
    } else {
      _prevCount = widget.cards.length;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _flyCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _parsed {
    return widget.cards.asMap().entries.map((e) {
      final i    = e.key;
      final card = e.value as Map;
      final style = CardStyle.fromDesign(
        card['card_design'],
        merchantLogoUrl: card['merchants']?['logo_url'] as String?,
        fallbackColor: _fallbackColors[i % _fallbackColors.length],
      );
      return <String, dynamic>{'card': card, 'style': style};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _parsed;
    if (data.isEmpty) return const SizedBox.shrink();

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Carousel principal
          Positioned.fill(
            child: ListWheelScrollView.useDelegate(
              controller: _scroll,
              itemExtent: 248,
              perspective: 0.002,
              diameterRatio: 2.8,
              squeeze: 1.0,
              physics: const FixedExtentScrollPhysics(),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: data.length,
                builder: (context, index) {
                  // Masquer la première carte pendant l'animation (remplacée par la carte en vol)
                  if (_flying && index == 0) {
                    return const SizedBox(height: 220);
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: SizedBox(
                      height: 220,
                      child: LoyaltyCardFace(
                        card:         data[index]['card']  as Map,
                        style:        data[index]['style'] as CardStyle,
                        userName:     widget.userName,
                        decorPattern: index % 6,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Carte en vol — arrive par le haut et atterrit en position 0
          if (_flying && data.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              top: 24, // position centrale du premier item dans le carousel
              child: SlideTransition(
                position: _flyAnim,
                child: SizedBox(
                  height: 220,
                  child: LoyaltyCardFace(
                    card:         data[0]['card']  as Map,
                    style:        data[0]['style'] as CardStyle,
                    userName:     widget.userName,
                    decorPattern: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Wallet Stack — effet portefeuille interactif (Android design)
// ════════════════════════════════════════════════════════════════════════════

class _WalletStack extends StatefulWidget {
  final List<dynamic> cards;
  final String userName;
  final void Function(Map, CardStyle)? onOpenCard;
  const _WalletStack({required this.cards, required this.userName, this.onOpenCard});
  @override
  State<_WalletStack> createState() => _WalletStackState();
}

class _WalletStackState extends State<_WalletStack> with TickerProviderStateMixin {
  int _selectedIdx = 0;
  late final ScrollController _scrollCtrl;

  // ── Dimensions portefeuille ──────────────────────────────────────────────────
  static const double _cardFull = 220.0; // hauteur de chaque carte (toujours pleine)
  static const double _peek     = 64.0;  // offset vertical entre chaque carte dans le Stack
  static const _dur   = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;

  static const _fallbackColors = [
    Color(0xFF2C7BE5), Color(0xFF10B981),
    Color(0xFF8B5CF6), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFFF97316),
  ];

  OverlayEntry? _overlayEntry;
  AnimationController? _overlayCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _closeCard(animate: false);
    _overlayCtrl?.dispose();
    super.dispose();
  }

  // ── Sélectionne une carte (animation via AnimatedPositioned) ──────────────
  void _selectCard(int i) => setState(() => _selectedIdx = i);

  // ── Hauteur totale du Stack portefeuille ──────────────────────────────────
  double _stackH(int n) => n > 0 ? _peek * (n - 1) + _cardFull : _cardFull;

  // ── Position top de la carte i quand sel est active ──────────────────────
  double _topFor(int i, int sel) {
    if (i <= sel) return i.toDouble() * _peek;
    return sel.toDouble() * _peek + _cardFull + (i - sel - 1).toDouble() * _peek;
  }

  // ── Parsing des cartes depuis widget.cards ────────────────────────────────
  List<Map<String, dynamic>> get _parsed {
    return widget.cards.asMap().entries.map((e) {
      final i     = e.key;
      final card  = e.value as Map;
      final m     = card['merchants'] as Map? ?? {};
      final pts   = (m['program_type'] as String?) == 'points';
      final cnt   = pts ? (card['points_count'] as int? ?? 0) : (card['stamps_count'] as int? ?? 0);
      final mx    = pts ? (m['points_required'] as int? ?? 10) : (m['stamps_required'] as int? ?? 10);
      final style = CardStyle.fromDesign(
        card['card_design'],
        merchantLogoUrl: card['merchants']?['logo_url'] as String?,
        fallbackColor: _fallbackColors[i % _fallbackColors.length],
      );
      return <String, dynamic>{
        'card':  card,
        'style': style,
        'name':  m['business_name'] as String? ?? 'Carte',
        'count': cnt,
        'max':   mx,
        'label': pts ? 'points' : 'tampons',
        'color': style.bgColors.first,
      };
    }).toList();
  }

  // ── Overlay animé (grand format + QR) ────────────────────────────────────
  void _openCard(Map card, CardStyle style, Rect fromRect) {
    if (widget.onOpenCard != null) { widget.onOpenCard!(card, style); return; }
    if (_overlayEntry != null) return;

    final screen  = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final targetW = screen.width - 48;
    const targetH = 220.0;
    final targetRect = Rect.fromLTWH(
      24,
      padding.top + (screen.height - padding.top - padding.bottom - targetH) / 2,
      targetW,
      targetH,
    );

    _overlayCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    final anim = CurvedAnimation(parent: _overlayCtrl!, curve: Curves.easeOutCubic);

    _overlayEntry = OverlayEntry(builder: (ctx) {
      return AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          final t    = anim.value;
          final rect = Rect.lerp(fromRect, targetRect, t)!;
          final bg   = (t * 0.65).clamp(0.0, 0.65);
          return Stack(children: [
            GestureDetector(
              onTap: _closeCard,
              child: Container(color: Colors.black.withValues(alpha: bg)),
            ),
            Positioned(
              left: rect.left, top: rect.top,
              width: rect.width, height: rect.height,
              child: GestureDetector(
                onTap: () {},
                child: Transform.scale(
                  scale: 1.0 + t * 0.04,
                  child: LoyaltyCardFace(card: card, style: style, userName: widget.userName),
                ),
              ),
            ),
          ]);
        },
      );
    });

    Overlay.of(context).insert(_overlayEntry!);
    _overlayCtrl!.forward();
  }

  void _closeCard({bool animate = true}) {
    if (_overlayEntry == null) return;
    if (!animate) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }
    _overlayCtrl!.reverse().whenComplete(() {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data = _parsed;
    if (data.isEmpty) return const SizedBox.shrink();

    final sel    = _selectedIdx.clamp(0, data.length - 1);
    final stackH = _stackH(data.length);

    Widget buildCard(int i) {
      final c         = data[i];
      final isFocused = i == sel;

      return AnimatedPositioned(
        key: ValueKey(i),
        duration: _dur,
        curve: _curve,
        top:    _topFor(i, sel),
        left:   0,
        right:  0,
        height: _cardFull, // toujours pleine hauteur — le chevauchement fait l'effet portefeuille
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isFocused) {
              final box    = context.findRenderObject() as RenderBox?;
              final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
              final w      = MediaQuery.of(context).size.width - 32;
              _openCard(
                c['card']  as Map,
                c['style'] as CardStyle,
                Rect.fromLTWH(16, _topFor(i, sel) + origin.dy, w, _cardFull),
              );
            } else {
              _selectCard(i);
            }
          },
          child: LoyaltyCardFace(
            card:         c['card']  as Map,
            style:        c['style'] as CardStyle,
            userName:     widget.userName,
            decorPattern: i % 6,
          ),
        ),
      );
    }

    final stackWidget = SizedBox(
      height: stackH,
      child: Stack(
        children: [
          // Cartes non-actives en premier (dessous)
          for (int i = 0; i < data.length; i++) if (i != sel) buildCard(i),
          // Carte active en dernier (au-dessus de tout)
          buildCard(sel),
        ],
      ),
    );

    return LayoutBuilder(builder: (_, constraints) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: stackH > constraints.maxHeight
            ? SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(),
                child: stackWidget,
              )
            : stackWidget,
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Helpers partagés (liste + modale QR)
// ════════════════════════════════════════════════════════════════════════════

double lcTitleFontSize(String name) {
  if (name.length >= 22) return 14;
  if (name.length >= 16) return 16;
  return 18;
}

String lcFirstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  final first = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : fullName;
  if (first.isEmpty) return first;
  return first[0].toUpperCase() + first.substring(1);
}

/// Noir ou blanc — le meilleur contraste WCAG sur [bg].
Color lcContrastOn(Color bg) {
  final lum = bg.computeLuminance();
  const dark = Color(0xFF0B1220);
  final cBlack = (lum + 0.05) / 0.05;
  final cWhite = 1.05 / (lum + 0.05);
  return cBlack >= cWhite ? dark : Colors.white;
}

Widget lcProgressBar(double pct, Color accent) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: pct,
      minHeight: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      valueColor: AlwaysStoppedAnimation(accent),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// LoyaltyCardFace : le visuel de carte (tampons OU points), réplique du site.
// Réutilisé par la liste des cartes ET la face avant de la modale QR.
// ════════════════════════════════════════════════════════════════════════════

class LoyaltyCardFace extends StatelessWidget {
  final Map card;
  final CardStyle style;
  final String userName;
  final int? decorPattern; // 0-5 : motif géométrique décoratif, null = aucun
  final bool compact;      // true = affiche uniquement le header (mode peek portefeuille)
  const LoyaltyCardFace({
    super.key,
    required this.card,
    required this.style,
    required this.userName,
    this.decorPattern,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPoints = (card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    final businessName = card['merchants']?['business_name'] as String? ?? '';
    final reward = (style.rewardDescription ??
            card['merchants']?['reward_description'] as String? ??
            '')
        .trim();
    final rawTitle = (style.cardName ?? '').trim().isNotEmpty
        ? style.cardName!.trim()
        : businessName;
    final title = rawTitle.toUpperCase();
    final textColor = style.textColor;
    final accent = style.accentColor ?? const Color(0xFFFF2D78);

    // Mode compact (peek portefeuille) : une seule ligne titre + prénom.
    // Aucun Column multi-ligne → zéro risque d'overflow ou de NaN.
    if (compact) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: style.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              style.buildBackground(),
              if (decorPattern != null)
                Positioned.fill(child: CustomPaint(painter: _CardPatternPainter(decorPattern!))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: style.fontFamily, fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lcFirstName(userName),
                        style: TextStyle(fontFamily: style.fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      final fill = constraints.hasBoundedHeight;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: style.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: fill ? StackFit.expand : StackFit.loose,
            children: [
              Positioned.fill(child: style.buildBackground()),
              if (decorPattern != null)
                Positioned.fill(child: CustomPaint(painter: _CardPatternPainter(decorPattern!))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 13, 18, 11),
                child: Column(
                  mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(title, textColor),
                    const SizedBox(height: 8),
                    if (isPoints) ..._points(textColor, accent, reward, fill) else ..._stamps(textColor, accent, reward),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _header(String title, Color textColor) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CARTE DE FIDÉLITÉ',
                    style: TextStyle(fontFamily: style.fontFamily, fontSize: 8, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 1.3)),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: style.fontFamily, fontSize: lcTitleFontSize(title), fontWeight: FontWeight.w900, color: textColor, height: 1.05)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TITULAIRE',
                  style: TextStyle(fontFamily: style.fontFamily, fontSize: 8, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 1.3)),
              const SizedBox(height: 2),
              Text(lcFirstName(userName),
                  style: TextStyle(fontFamily: style.fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
            ],
          ),
        ],
      );

  List<Widget> _stamps(Color textColor, Color accent, String reward) {
    final stamps = card['stamps_count'] as int? ?? 0;
    final required = style.stampsRequired ?? card['merchants']?['stamps_required'] as int? ?? 10;
    final pct = (stamps / required).clamp(0.0, 1.0);
    final full = stamps >= required;
    final stampLabel = style.stampLabel ?? 'POINTS COLLECTÉS';
    final perRow = (required / 2).ceil();

    return [
      Text(stampLabel,
          style: TextStyle(fontFamily: style.fontFamily, fontSize: 8, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 1.1)),
      const SizedBox(height: 6),
      LayoutBuilder(builder: (ctx, c) {
        const vSpacing = 5.0;
        final size = (c.maxWidth / perRow * 0.68).clamp(22.0, 42.0);
        Widget cell(int idx) {
          if (idx >= required) return SizedBox(width: size, height: size);
          final filled = idx < stamps;
          return Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? accent : Colors.transparent,
              border: Border.all(color: accent.withValues(alpha: 0.27), width: 1.5),
            ),
            child: filled ? Center(child: Icon(Icons.check, size: size * 0.5, color: lcContrastOn(accent))) : null,
          );
        }
        Widget row(int r) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(perRow, (col) => cell(r * perRow + col)),
            );
        return Column(children: [row(0), const SizedBox(height: vSpacing), row(1)]);
      }),
      const SizedBox(height: 8),
      lcProgressBar(pct, accent),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _footer(required - stamps, reward, full, textColor)),
          const SizedBox(width: 8),
          Text('$stamps / $required',
              style: TextStyle(fontFamily: style.fontFamily, color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    ];
  }

  List<Widget> _points(Color textColor, Color accent, String reward, [bool fill = false]) {
    final required = style.pointsGoal ?? card['merchants']?['points_required'] as int? ?? card['merchants']?['stamps_required'] as int? ?? 100;
    final points = (card['points_count'] as int? ?? 0).clamp(0, required);
    final pct = (points / required).clamp(0.0, 1.0);
    final full = points >= required;
    final remaining = required - points;
    final pointsLabel = style.pointsLabel ?? style.stampLabel ?? 'POINTS COLLECTÉS';

    return [
      Text(pointsLabel,
          style: TextStyle(fontFamily: style.fontFamily, fontSize: 8, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 1.1)),
      const SizedBox(height: 10),
      // ── Grand chiffre : "{points} PTS" (le /goal va dans le compteur footer, comme le site)
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$points',
              style: TextStyle(fontFamily: style.fontFamily, color: accent, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text('PTS',
                style: TextStyle(fontFamily: style.fontFamily, color: accent.withValues(alpha: 0.75), fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      if (fill) const Spacer() else const SizedBox(height: 10),
      lcProgressBar(pct, accent),
      const SizedBox(height: 7),
      // ── Footer : "Encore X pts pour votre Y"  |  "{points} / {goal}"
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _pointsFooter(remaining, reward, full, textColor)),
          const SizedBox(width: 8),
          Text('$points / $required',
              style: TextStyle(fontFamily: style.fontFamily, color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    ];
  }

  /// Footer points : "Encore X pts pour votre Y" avec le "X pts" en bold (comme le site).
  Widget _pointsFooter(int remaining, String reward, bool full, Color textColor) {
    final base = TextStyle(fontFamily: style.fontFamily, color: textColor, fontSize: 10, fontWeight: full ? FontWeight.w700 : FontWeight.w400);
    if (full) {
      return Text(reward.isEmpty ? 'Récompense disponible 🎉' : '$reward disponible !',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: base);
    }
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: [
        const TextSpan(text: 'Plus que '),
        TextSpan(text: '$remaining pts', style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: ' avant : ${reward.isEmpty ? "récompense" : reward}'),
      ]),
    );
  }

  Widget _footer(int remaining, String reward, bool full, Color textColor) {
    final base = TextStyle(fontFamily: style.fontFamily, color: textColor, fontSize: 10, fontWeight: full ? FontWeight.w700 : FontWeight.w400);
    if (full) {
      return Text(reward.isEmpty ? 'récompense disponible !' : '$reward disponible !',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: base);
    }
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: [
        const TextSpan(text: 'Plus que '),
        TextSpan(text: '$remaining tampon${remaining > 1 ? "s" : ""}', style: const TextStyle(fontWeight: FontWeight.w800)),
        TextSpan(text: ' avant : ${reward.isEmpty ? "récompense" : reward}'),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CardStyle : parse le card_design (qarta.be) en un style Flutter directement utilisable
// ════════════════════════════════════════════════════════════════════════════

class CardStyle {
  final String bgType;           // 'color' | 'gradient' | 'image'
  final List<Color> bgColors;    // 1 si color, 2+ si gradient
  final double bgGradientAngle;  // degrés
  final String? bgImageUrl;
  final double bgImageOpacity;
  final Color textColor;
  final List<Color> accentColors;
  final double accentAngle;
  final String? fontFamily;
  final String? cardName;
  final String? stampLabel;
  final String? pointsLabel;
  final String? rewardDescription;  // depuis card_design (prioritaire sur merchants.reward_description)
  final int? stampsRequired;        // depuis card_design (prioritaire sur merchants.stamps_required)
  final int? pointsGoal;            // depuis card_design (prioritaire sur merchants.points_required)
  final String? logoUrl;
  final Color fallback;

  CardStyle({
    required this.bgType,
    required this.bgColors,
    required this.bgGradientAngle,
    required this.bgImageUrl,
    required this.bgImageOpacity,
    required this.textColor,
    required this.accentColors,
    required this.accentAngle,
    required this.fontFamily,
    required this.cardName,
    required this.stampLabel,
    required this.pointsLabel,
    required this.rewardDescription,
    required this.stampsRequired,
    required this.pointsGoal,
    required this.logoUrl,
    required this.fallback,
  });

  /// Couleur "principale" — sert d'ombrage et de fallback.
  Color get primary => bgColors.isNotEmpty ? bgColors.first : fallback;

  /// Couleur d'accent (utilisée pour tampons cochés, compteur points).
  Color? get accentColor => accentColors.isNotEmpty ? accentColors.first : null;

  /// Couleur de texte effective : si textColor a un mauvais contraste sur le fond,
  /// on bascule sur blanc/noir auto. Le site qarta.be a un bouton "Auto" qui fait
  /// pareil — on émule ce comportement quand textColor=#000000 sur fond sombre.
  Color get effectiveTextColor {
    final bg = primary;
    final txt = textColor;
    final bgLum = bg.computeLuminance();
    final txtLum = txt.computeLuminance();
    // contraste approximatif WCAG : (L1+0.05)/(L2+0.05)
    final lighter = txtLum > bgLum ? txtLum : bgLum;
    final darker  = txtLum > bgLum ? bgLum  : txtLum;
    final ratio   = (lighter + 0.05) / (darker + 0.05);
    if (ratio >= 3.5) return txt; // contraste suffisant → respecter textColor
    // Sinon : noir si fond clair, blanc si fond sombre
    return bgLum > 0.5 ? const Color(0xFF0B1220) : Colors.white;
  }

  /// Couleur de remplissage des tampons cochés (basée sur textColor pour bon contraste).
  Color get stampFillColor => effectiveTextColor.withValues(alpha: 0.9);

  factory CardStyle.fromDesign(
    dynamic design, {
    String? merchantLogoUrl,
    required Color fallbackColor,
  }) {
    if (design is! Map) {
      return CardStyle(
        bgType: 'color',
        bgColors: [fallbackColor],
        bgGradientAngle: 135,
        bgImageUrl: null,
        bgImageOpacity: 0.3,
        textColor: Colors.white,
        accentColors: const [],
        accentAngle: 135,
        fontFamily: null,
        cardName: null,
        stampLabel: null,
        pointsLabel: null,
        rewardDescription: null,
        stampsRequired: null,
        pointsGoal: null,
        logoUrl: merchantLogoUrl,
        fallback: fallbackColor,
      );
    }
    return CardStyle(
      bgType:             (design['bgType']           as String?) ?? 'color',
      bgColors:           _parseColors(design['bgColors'])       ?? [fallbackColor],
      bgGradientAngle:    _toDouble(design['bgGradientAngle'])   ?? 135,
      bgImageUrl:         _str(design['bgImageUrl']),
      bgImageOpacity:     _toDouble(design['bgImageOpacity'])    ?? 0.3,
      textColor:          _parseColor(design['textColor'])       ?? Colors.white,
      accentColors:       _parseColors(design['accentColors'])   ?? const [],
      accentAngle:        _toDouble(design['accentAngle'])       ?? 135,
      fontFamily:         _str(design['fontFamily']),
      cardName:           _str(design['cardName']),
      stampLabel:         _str(design['stampLabel']),
      pointsLabel:        _str(design['pointsLabel']),
      rewardDescription:  _str(design['rewardDescription']),
      stampsRequired:     _toInt(design['stampsRequired']),
      pointsGoal:         _toInt(design['pointsGoal']),
      logoUrl:            _str(design['logoUrl']) ?? _str(design['logo_url']) ?? merchantLogoUrl,
      fallback:           fallbackColor,
    );
  }

  /// Construit le widget de fond (couleur, gradient, ou image).
  Widget buildBackground() {
    switch (bgType) {
      case 'image':
        if (bgImageUrl != null && bgImageUrl!.isNotEmpty) {
          return Stack(fit: StackFit.expand, children: [
            Container(color: primary),
            Opacity(
              opacity: bgImageOpacity.clamp(0.0, 1.0),
              child: Image.network(bgImageUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ]);
        }
        return Container(color: primary);
      case 'gradient':
        if (bgColors.length >= 2) {
          // Convention CSS linear-gradient(Ndeg, …) :
          //   0° = bas→haut, 90° = gauche→droite, 180° = haut→bas, 270° = droite→gauche.
          //   L'angle est mesuré dans le sens horaire depuis le haut.
          // En coords écran (y vers le bas) : direction = (sin θ, -cos θ).
          //   begin = -direction (1ère couleur), end = +direction (dernière couleur).
          final rad = bgGradientAngle * pi / 180;
          final dx = sin(rad);
          final dy = -cos(rad);
          // On étire le vecteur pour que la composante dominante atteigne ±1
          // (le dégradé couvre bien toute la carte, y compris en diagonale).
          final m = (dx.abs() > dy.abs() ? dx.abs() : dy.abs());
          final scale = m == 0 ? 1.0 : 1 / m;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-dx * scale, -dy * scale),
                end:   Alignment( dx * scale,  dy * scale),
                colors: bgColors,
              ),
            ),
          );
        }
        return Container(color: primary);
      case 'color':
      default:
        return Container(color: primary);
    }
  }

  // ── Helpers de parsing ──────────────────────────────────────────────────────

  static String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static Color? _parseColor(dynamic raw) {
    if (raw is! String) return null;
    final hex = raw.replaceAll('#', '').trim();
    try {
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex,     radix: 16));
    } catch (_) {}
    return null;
  }

  static List<Color>? _parseColors(dynamic raw) {
    if (raw is List) {
      final out = <Color>[];
      for (final c in raw) {
        final col = _parseColor(c);
        if (col != null) out.add(col);
      }
      return out.isEmpty ? null : out;
    }
    final single = _parseColor(raw);
    return single == null ? null : [single];
  }
}

// ── Motifs géométriques décoratifs sur les cartes ────────────────────────────

class _CardPatternPainter extends CustomPainter {
  final int pattern; // 0-5

  const _CardPatternPainter(this.pattern);

  static final _paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.08)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  static final _paintFill = Paint()
    ..color = Colors.white.withValues(alpha: 0.05)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern % 6) {
      case 0: _circles(canvas, size);    break;
      case 1: _diagonals(canvas, size);  break;
      case 2: _dots(canvas, size);       break;
      case 3: _waves(canvas, size);      break;
      case 4: _hexagons(canvas, size);   break;
      case 5: _triangles(canvas, size);  break;
    }
  }

  // 0 : Cercles concentriques dans le coin bas-droit
  void _circles(Canvas canvas, Size s) {
    final center = Offset(s.width * 1.1, s.height * 1.2);
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, s.height * 0.35 * i, _paint);
    }
    canvas.drawCircle(Offset(-s.width * 0.1, -s.height * 0.2), s.height * 0.5, _paint);
  }

  // 1 : Lignes diagonales parallèles
  void _diagonals(Canvas canvas, Size s) {
    const step = 28.0;
    for (double x = -s.height; x < s.width + s.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + s.height, s.height), _paint);
    }
  }

  // 2 : Grille de petits cercles (dots)
  void _dots(Canvas canvas, Size s) {
    const spacing = 20.0;
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    for (double x = spacing; x < s.width; x += spacing) {
      for (double y = spacing; y < s.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  // 3 : Vagues horizontales (arcs)
  void _waves(Canvas canvas, Size s) {
    const waveH = 10.0;
    const waveL = 40.0;
    for (double y = 20; y < s.height + 20; y += 22) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < s.width; x += waveL) {
        path.quadraticBezierTo(x + waveL / 4, y - waveH, x + waveL / 2, y);
        path.quadraticBezierTo(x + 3 * waveL / 4, y + waveH, x + waveL, y);
      }
      canvas.drawPath(path, _paint);
    }
  }

  // 4 : Hexagones (nid d'abeille)
  void _hexagons(Canvas canvas, Size s) {
    const r = 18.0;
    final dx = r * 1.732;
    final dy = r * 1.5;
    int row = 0;
    for (double y = -r; y < s.height + r; y += dy) {
      final offset = (row % 2 == 0) ? 0.0 : dx / 2;
      for (double x = -r + offset; x < s.width + r; x += dx) {
        _drawHex(canvas, Offset(x, y), r);
      }
      row++;
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, _paint);
  }

  // 5 : Triangles en coin
  void _triangles(Canvas canvas, Size s) {
    final corners = [
      [Offset(0, 0), Offset(s.width * 0.5, 0), Offset(0, s.height * 0.5)],
      [Offset(s.width, s.height), Offset(s.width * 0.5, s.height), Offset(s.width, s.height * 0.5)],
    ];
    for (final tri in corners) {
      final path = Path()
        ..moveTo(tri[0].dx, tri[0].dy)
        ..lineTo(tri[1].dx, tri[1].dy)
        ..lineTo(tri[2].dx, tri[2].dy)
        ..close();
      canvas.drawPath(path, _paintFill);
      canvas.drawPath(path, _paint);
    }
    // petits triangles répétés
    const step = 30.0;
    for (double x = step; x < s.width - step; x += step) {
      final triPath = Path()
        ..moveTo(x, s.height * 0.1)
        ..lineTo(x + 12, s.height * 0.1 + 20)
        ..lineTo(x - 12, s.height * 0.1 + 20)
        ..close();
      canvas.drawPath(triPath, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardPatternPainter old) => old.pattern != pattern;
}

// ── Widget badge récompense ───────────────────────────────────────────────────

class _RewardBadge extends StatelessWidget {
  final List<dynamic> rewardCards;
  final List<dynamic> allCards;
  final List<Color> palette;
  final void Function(Map, Color) onTap;

  const _RewardBadge({required this.rewardCards, required this.allCards, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = rewardCards.first;
    final i = allCards.indexOf(card);
    final color = palette[i % palette.length];
    final name = card['merchants']?['business_name'] as String? ?? '';
    final reward = card['merchants']?['reward_description'] as String? ?? '';

    return GestureDetector(
      onTap: () => onTap(card, color),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.qSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFFFBBF24).withValues(alpha: 0.12), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(11)),
              child: const Center(child: Icon(Icons.star_rounded, size: 20, color: Color(0xFFF59E0B))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Récompense chez $name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.qText)),
                  const SizedBox(height: 1),
                  Text(reward, style: TextStyle(fontSize: 11, color: context.qSub)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(9)),
              child: const Text('Voir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.qText)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 12, color: Color(0xFF2C7BE5), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Modal QR fixe ────────────────────────────────────────────────────────────

class QRModal extends StatefulWidget {
  final String token;
  final Map card;
  final CardStyle style;
  final String userName;
  final VoidCallback? onStampAdded;
  final void Function(StampEvent)? onStampEvent;
  /// iOS : si fourni, la carte vole depuis la pile (même Hero) au lieu d'apparaître.
  final String? heroTag;
  const QRModal({super.key, required this.token, required this.card, required this.style, this.userName = '', this.onStampAdded, this.onStampEvent, this.heroTag});

  // Compat : raccourcis pour l'ancien code interne
  Color get color => style.primary;
  String? get logoUrl => style.logoUrl;

  @override
  State<QRModal> createState() => _QRModalState();
}

class _QRModalState extends State<QRModal> with TickerProviderStateMixin {
  Timer? _pollTimer;           // ← polling détection tampon
  int    _initialStamps = 0;   // ← valeur de référence (utilisée pour le delta affiché)
  String? _initialScanAt;      // ← horodatage du dernier scan à l'ouverture (base de comparaison)
  late AnimationController _confettiCtrl;
  final bool _showConfetti = false;
  DateTime? _stampedAt;        // iOS : « Tampon ajouté · à l'instant » sous la carte
  Timer? _demoTimer;           // aperçu design uniquement (QartaDemo)

  // ── Wallet ────────────────────────────────────────────────────────────────
  final GlobalKey _cardKey = GlobalKey();
  bool _walletLoading = false;

  Future<void> _addToWallet() async {
    final cardId = widget.card['id'] as String? ?? '';
    if (cardId.isEmpty || _walletLoading) return;

    setState(() => _walletLoading = true);
    try {
      if (Platform.isAndroid) {
        final result = await ApiService.instance.getGoogleWalletJwt(cardId);
        if (!mounted) return;
        if (result.isErr) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Erreur Google Wallet')),
          );
          return;
        }
        final saveUrl = result.value['save_url'] as String;
        await launchUrl(Uri.parse(saveUrl), mode: LaunchMode.externalApplication);

      } else if (kIsIOS) {
        final result = await ApiService.instance.getAppleWalletUrl(cardId);
        if (!mounted) return;
        if (result.isErr) {
          showIosAlert(context, 'Apple Wallet', result.error ?? 'La carte n\'a pas pu être ajoutée à Wallet. Réessaie dans un instant.');
          return;
        }
        final passUrl = result.value['url'] as String;
        // iOS Safari télécharge automatiquement le .pkpass et propose "Ajouter au Wallet"
        await launchUrl(Uri.parse(passUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error('Wallet erreur: $e');
    } finally {
      if (mounted) setState(() => _walletLoading = false);
    }
  }

  // ── Flip 3D ──────────────────────────────────────────────────────────────────
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  bool _isFlipped = false;

  void _toggleFlip() {
    if (_isFlipped) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  void initState() {
    super.initState();
    final merchantName = widget.card['merchants']?['business_name'] as String? ?? '?';
    final isPoints0 = (widget.card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    final stamps0   = isPoints0 ? (widget.card['points_count'] as int? ?? 0) : (widget.card['stamps_count'] as int? ?? 0);
    final required0 = isPoints0 ? (widget.card['merchants']?['points_required'] as int? ?? 100) : (widget.card['merchants']?['stamps_required'] as int? ?? 10);
    AppLogger.client('QRModal → ouvert pour $merchantName, état initial: $stamps0/$required0 (${isPoints0 ? "points" : "tampons"})');
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
    _initialStamps = stamps0; // ← mémoriser pour le calcul du delta
    if (QartaDemo.enabled) {
      // Aperçu : le commerçant « ajoute un tampon » 4 s après l'ouverture.
      _demoTimer = Timer(const Duration(seconds: 4), () {
        final total = required0;
        final next = isPoints0 ? stamps0 + 10 : stamps0 + 1;
        _onNewStamp(newVal: next >= total ? next - total : next, total: total, reward: next >= total,
            isPoints: isPoints0, merchantName: merchantName);
      });
      return;
    }
    // Récupérer le dernier scan_at pour détecter un nouveau scan (comparaison timestamp)
    ApiService.instance.pollCard(widget.card['id'] as String).then((r) {
      if (r.isOk && mounted) {
        _initialScanAt = r.value['latest_scan_at'] as String?;
        AppLogger.client('QRModal → scan initial: ${_initialScanAt ?? "aucun"}');
      }
    });
    _startPolling();          // ← démarrer le polling
  }

  @override
  void dispose() {
    AppLogger.client('QRModal → fermé, polling arrêté');
    _pollTimer?.cancel();
    _demoTimer?.cancel();
    _confettiCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  // ── Polling : détecte l'ajout d'un tampon en temps réel ──────────────────────
  void _startPolling() {
    AppLogger.client('QRModal → polling démarré (toutes les 2s)');
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkForNewStamp());
  }

  Future<void> _checkForNewStamp() async {
    final r = await ApiService.instance.pollCard(widget.card['id'] as String);
    if (!mounted || r.isErr) return;
    final v = r.value;

    final latestScanAt = v['latest_scan_at'] as String?;
    AppLogger.client('QRModal → poll: latestScanAt=$latestScanAt, initial=$_initialScanAt');

    // Aucun nouveau scan : même horodatage (ou les deux sont null)
    if (latestScanAt == _initialScanAt) return;

    // Nouveau scan détecté via la scan_history (fiable même si points_count boucle)
    final isPoints = (widget.card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    final total = isPoints
        ? (widget.card['merchants']?['points_required'] as int? ?? 100)
        : (widget.card['merchants']?['stamps_required'] as int? ?? 10);
    final newVal = isPoints
        ? (v['points_count'] as int? ?? 0)
        : (v['stamps_count'] as int? ?? 0);
    final reward    = v['latest_reward_reached'] == true;
    final increased = newVal > _initialStamps;
    final delta     = reward
        ? (total - _initialStamps).clamp(0, total) // approx, non affiché pour les récompenses
        : (increased ? newVal - _initialStamps : (total - _initialStamps + newVal).clamp(0, total));
    final merchantName = (widget.card['merchants']?['business_name'] as String?) ?? 'Le magasin';

    AppLogger.client('QRModal → tampon détecté! +$delta chez $merchantName → $newVal/$total${reward ? " 🎉 RÉCOMPENSE" : ""}');
    if (kIsIOS) {
      _initialScanAt = latestScanAt; // base pour détecter le tampon suivant
      _onNewStamp(newVal: newVal, total: total, reward: reward, isPoints: isPoints, merchantName: merchantName, delta: delta);
      return;
    }
    _pollTimer?.cancel();
    if (!mounted) return;

    final event = StampEvent(
      cardId: widget.card['id'] as String,
      merchantName: merchantName,
      delta: delta,
      newCount: newVal,
      total: total,
      reward: reward,
      isPoints: isPoints,
    );

    final cbEvent = widget.onStampEvent;
    final cbOld   = widget.onStampAdded;
    Navigator.pop(context);
    if (cbEvent != null) {
      Future.microtask(() => cbEvent(event));
    } else if (cbOld != null) {
      Future.microtask(cbOld);
    }
  }

  // iOS : tampon ajouté → la carte se met à jour dans la fenêtre ouverte,
  // petite ligne verte + vibration. Carte pleine → on ferme et client_home
  // affiche « Carte complète ! ».
  void _onNewStamp({required int newVal, required int total, required bool reward,
      required bool isPoints, required String merchantName, int? delta}) {
    if (!mounted) return;
    final event = StampEvent(
      cardId: widget.card['id'] as String,
      merchantName: merchantName,
      delta: delta ?? (newVal - _initialStamps).clamp(1, total),
      newCount: newVal,
      total: total,
      reward: reward,
      isPoints: isPoints,
    );
    final cb = widget.onStampEvent;
    if (reward) {
      _pollTimer?.cancel();
      Navigator.pop(context);
      if (cb != null) Future.microtask(() => cb(event));
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      widget.card[isPoints ? 'points_count' : 'stamps_count'] = newVal;
      _initialStamps = newVal;
      _stampedAt = DateTime.now();
    });
    if (cb != null) cb(event);
  }

  // ── ZOOM QR ──────────────────────────────────────────────────────────────────
  void _showQRZoom(BuildContext context, Color color) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'qr-${widget.card['id']}',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: QrImageView(
                    data: widget.card['qr_token'] as String? ?? '',
                    version: QrVersions.auto,
                    size: 240,
                    foregroundColor: const Color(0xFF0B1220),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Appuie n\'importe où pour fermer',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FACE AVANT : carte fidélité (réplique du site) + panneau QR ──────────────
  Widget _buildCardFront(Color color, String businessName, int stamps, int required, String reward, bool full, double pct, [bool isPoints = false, bool capture = false]) {
    final merchantId = widget.card['merchant_id'] as String? ?? '';
    if (kIsIOS) return _buildPassIos(color, capture);
    final cardFace = kIsIOS
        ? SizedBox(height: 220, child: ClientPassFaceIos(card: widget.card, style: widget.style))
        : LoyaltyCardFace(
            card: widget.card,
            style: widget.style,
            userName: widget.userName,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Le visuel de carte — identique à la liste / au site (tap → flip infos)
        GestureDetector(
          onTap: _toggleFlip,
          child: capture
              ? RepaintBoundary(key: _cardKey, child: cardFace)
              : cardFace,
        ),
        // iOS : confirmation intégrée juste sous la carte après un tampon.
        if (kIsIOS && _stampedAt != null)
          TweenAnimationBuilder<double>(
            key: ValueKey(_stampedAt),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 0.85 + 0.15 * v, child: child)),
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(color: Color(0xFF27AE60), shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(isPoints ? 'Points ajoutés · à l\'instant' : 'Tampon ajouté · à l\'instant',
                    style: const TextStyle(color: Color(0xFF27AE60), fontSize: 17, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        // 2. Panneau QR : sur iOS il reprend le fond de la carte (couleur du
        //    commerçant) ; sur Android, fond sombre comme avant.
        ClipRRect(
          borderRadius: BorderRadius.circular(kIsIOS ? 18 : 16),
          child: Stack(children: [
          if (kIsIOS) Positioned.fill(child: widget.style.buildBackground()),
          Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kIsIOS ? null : const Color(0xFF111726),
            borderRadius: BorderRadius.circular(16),
            border: kIsIOS ? null : Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              // Bouton partager
              Align(
                alignment: Alignment.centerRight,
                child: Builder(
                  builder: (ctx) => GestureDetector(
                    onTap: () {
                      final box = ctx.findRenderObject() as RenderBox?;
                      final origin = box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      final url = merchantId.isNotEmpty
                          ? '\nhttps://qarta.be/join/$merchantId'
                          : '';
                      Share.share(
                        "Rejoins le programme de fidélité de $businessName sur l'app Qarta !$url",
                        subject: 'Carte fidélité $businessName',
                        sharePositionOrigin: origin,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.share_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 5),
                        Text('Partager', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // QR code (fond blanc = scan optimal)
              GestureDetector(
                onTap: () => _showQRZoom(context, color),
                child: Hero(
                  tag: 'qr-${widget.card['id']}',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16)]),
                    child: QrImageView(
                      data: widget.card['qr_token'] as String? ?? '',
                      version: QrVersions.auto,
                      size: kIsIOS ? 176 : 150,
                      foregroundColor: const Color(0xFF0B1220),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(kIsIOS ? 'Montre ce code en caisse' : 'Touche la carte pour voir les infos',
                  style: kIsIOS
                      ? TextStyle(fontSize: 15, color: widget.style.textColor, fontWeight: FontWeight.w600, letterSpacing: -0.2)
                      : TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600)),
              if (kIsIOS) ...[
                const SizedBox(height: 2),
                Text('Touche la carte pour voir les infos',
                    style: TextStyle(fontSize: 13, color: widget.style.textColor.withValues(alpha: 0.7))),
              ],
            ],
          ),
        ),
          ]),
        ),
      ],
    );
  }

  // iOS : dos de la carte, même style que l'avant : adresse, téléphone, et
  // les horaires de toute la semaine (aujourd'hui en gras).
  Widget _buildBackIos(String businessName) {
    final m = (widget.card['merchants'] as Map?) ?? const {};
    final fg = widget.style.textColor;
    final address = (m['address'] as String? ?? '').trim();
    final phone = (m['phone'] as String? ?? '').trim();
    final h = MerchantHours.fromMerchant(m);
    final today = DateTime.now().weekday;
    Widget info(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: fg.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label.toUpperCase(), style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                Text(value, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
        );
    // Même hauteur que l'avant de la carte (456), arrondie en bas aussi.
    return Align(alignment: Alignment.topCenter, child: SizedBox(height: 432, child: GestureDetector(
      onTap: _toggleFlip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(fit: StackFit.expand, children: [
          widget.style.buildBackground(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('INFOS', style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              Text(businessName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 14),
              if (address.isNotEmpty) info(CupertinoIcons.location_solid, 'Adresse', address),
              if (phone.isNotEmpty) info(CupertinoIcons.phone_fill, 'Téléphone', phone),
              Row(children: [
                Icon(CupertinoIcons.clock_fill, size: 18, color: fg.withValues(alpha: 0.8)),
                const SizedBox(width: 10),
                Text('HORAIRES', style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
              ]),
              const SizedBox(height: 6),
              if (h.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text('Le commerçant ne les a pas encore indiqués.', style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 15)),
                )
              else
                for (var d = 1; d <= 7; d++)
                  Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 3),
                    child: Row(children: [
                      Expanded(
                        child: Text(MerchantHours.names[d - 1],
                            style: TextStyle(color: fg, fontSize: 15, fontWeight: d == today ? FontWeight.w700 : FontWeight.w400)),
                      ),
                      Text(h.openOn(d) ? h.range : 'Fermé',
                          style: TextStyle(color: h.openOn(d) ? fg : fg.withValues(alpha: 0.6), fontSize: 15,
                              fontWeight: d == today ? FontWeight.w700 : FontWeight.w400,
                              fontFeatures: const [ui.FontFeature.tabularFigures()])),
                    ]),
                  ),
              const Spacer(),
              Center(child: Text('Touche pour revenir à la carte', style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 13))),
            ]),
          ),
        ]),
      ),
    )));
  }

  // iOS : une seule carte d'une seule couleur, QR code à l'intérieur (comme Apple Wallet).
  // Toucher le QR → agrandi ; toucher la carte → infos du commerce (au dos).
  Widget _buildPassIos(Color color, bool capture) {
    final qrBox = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: QrImageView(
        data: widget.card['qr_token'] as String? ?? '',
        version: QrVersions.auto,
        size: 150,
        foregroundColor: const Color(0xFF0B1220),
      ),
    );
    // Pas de 2e animation dans la carte quand la carte entière vole déjà.
    final qr = GestureDetector(
      onTap: () => _showQRZoom(context, color),
      child: widget.heroTag != null ? qrBox : Hero(tag: 'qr-${widget.card['id']}', child: qrBox),
    );
    Widget pass = SizedBox(height: 432, child: ClientPassFaceIos(card: widget.card, style: widget.style, qr: qr));
    if (capture && widget.heroTag != null) {
      final staticQr = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: QrImageView(data: widget.card['qr_token'] as String? ?? '', version: QrVersions.auto, size: 150,
            foregroundColor: const Color(0xFF0B1220)),
      );
      pass = Hero(
        tag: widget.heroTag!,
        createRectTween: (b, e) => RectTween(begin: b, end: e),
        // Pendant le vol : la carte entière s'agrandit vers le bas et dévoile le QR.
        flightShuttleBuilder: (_, __, ___, ____, _____) => Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 432, maxHeight: 432,
              child: ClientPassFaceIos(card: widget.card, style: widget.style, qr: staticQr),
            ),
          ),
        ),
        child: Material(type: MaterialType.transparency, child: pass),
      );
    }
    final isPoints = (widget.card['merchants']?['program_type'] as String? ?? 'stamps') == 'points';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(onTap: _toggleFlip, child: capture ? RepaintBoundary(key: _cardKey, child: pass) : pass),
      const SizedBox(height: 14),
    ]);
  }

  // ── FACE ARRIÈRE : infos du commerce ─────────────────────────────────────────
  Widget _buildCardBack(Color color, String businessName) {
    if (kIsIOS) return _buildBackIos(businessName);
    final address  = widget.card['merchants']?['address']       as String? ?? '';
    final phone    = widget.card['merchants']?['phone']         as String? ?? '';
    final rawHours = widget.card['merchants']?['opening_hours'] as String? ?? '';
    final rawDays  = widget.card['merchants']?['opening_days']  as String? ?? '';
    final hours    = rawDays.isNotEmpty && rawHours.isNotEmpty
        ? '$rawDays · $rawHours'
        : rawHours.isNotEmpty ? rawHours : rawDays.isNotEmpty ? rawDays : '';
    final rawLogo  = widget.logoUrl;
    final logoUrl  = (rawLogo != null && rawLogo.isNotEmpty) ? rawLogo : null;
    final initials = businessName.length >= 2 ? businessName.substring(0, 2).toUpperCase() : businessName.toUpperCase();
    final txt      = widget.style.textColor;

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(child: widget.style.buildBackground()),
              Positioned(top: -30, right: -20, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: txt.withValues(alpha: 0.07)))),
              Positioned(bottom: -40, left: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: txt.withValues(alpha: 0.05)))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (logoUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              logoUrl,
                              width: 36, height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          _backInfoRow(Icons.location_on_outlined, 'Adresse',   address.isEmpty   ? '—' : address),
                          const SizedBox(height: 14),
                          _backInfoRow(Icons.phone_outlined,       'Téléphone', phone.isEmpty     ? '—' : phone),
                          const SizedBox(height: 14),
                          _backInfoRow(Icons.access_time_rounded,  'Horaires',  hours.isEmpty     ? '—' : hours),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: Text('Tapez pour voir la carte', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final programType = widget.card['merchants']?['program_type'] as String? ?? 'stamps';
    final isPoints = programType == 'points';
    final stamps   = isPoints
        ? (widget.card['points_count'] as int? ?? 0)
        : (widget.card['stamps_count'] as int? ?? 0);
    final required = isPoints
        ? (widget.card['merchants']?['points_required'] as int? ?? 100)
        : (widget.card['merchants']?['stamps_required'] as int? ?? 10);
    final reward = widget.card['merchants']?['reward_description'] as String? ?? '';
    final businessName = widget.card['merchants']?['business_name'] as String? ?? '';
    final color = widget.color;
    final pct = (stamps / required).clamp(0.0, 1.0);
    final full = stamps >= required;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Fond sombre (style design) ────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: kIsIOS ? context.cBg : const Color(0xFF0B1220),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 0),
                child: Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: kIsIOS ? context.cSub.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (kIsIOS)
                      // Titre + confirmation du tampon juste dessous (toujours visible).
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(businessName,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: context.cText)),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: _stampedAt == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  key: ValueKey(_stampedAt),
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      width: 20, height: 20,
                                      decoration: const BoxDecoration(color: Color(0xFF27AE60), shape: BoxShape.circle),
                                      child: const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      (widget.card['merchants']?['program_type'] as String? ?? 'stamps') == 'points'
                                          ? 'Points ajoutés · à l\'instant'
                                          : 'Tampon ajouté · à l\'instant',
                                      style: const TextStyle(color: Color(0xFF27AE60), fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                  ]),
                                ),
                        ),
                      ])
                    else
                    Text(
                      businessName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    if (kIsIOS) ...[
                      const Spacer(),
                      // Partager (déplacé ici : le QR est maintenant dans la carte)
                      Builder(
                        builder: (ctx) => GestureDetector(
                          onTap: () {
                            final box = ctx.findRenderObject() as RenderBox?;
                            final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
                            final mId = widget.card['merchant_id'] as String? ?? '';
                            final url = mId.isNotEmpty ? '\nhttps://qarta.be/join/$mId' : '';
                            Share.share(
                              "Rejoins le programme de fidélité de $businessName sur l'app Qarta !$url",
                              subject: 'Carte fidélité $businessName',
                              sharePositionOrigin: origin,
                            );
                          },
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF767680).withValues(alpha: 0.12)),
                            child: Icon(CupertinoIcons.share, color: context.cSub, size: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kIsIOS ? const Color(0xFF767680).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.1),
                        ),
                        child: Icon(Icons.close, color: kIsIOS ? context.cSub : Colors.white, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
              // Corps scrollable (iOS : se réduit si l'écran est petit)
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    // ── Carte avec flip 3D ───────────────────────────
                    Stack(
                      children: [
                        // Face avant invisible — maintient la hauteur
                        Opacity(
                          opacity: 0,
                          child: _buildCardFront(color, businessName, stamps, required, reward, full, pct, isPoints),
                        ),
                        // Animation flip par-dessus (même taille grâce à Positioned.fill)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _flipAnim,
                            builder: (_, __) {
                              final angle = _flipAnim.value;
                              final showFront = angle < pi / 2;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(angle),
                                child: showFront
                                    ? _buildCardFront(color, businessName, stamps, required, reward, full, pct, isPoints, true)
                                    : Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()..rotateY(pi),
                                        child: _buildCardBack(color, businessName),
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
              // iOS : adresse du commerce (touche → Plans), comme sur la maquette.
              if (kIsIOS && (widget.card['merchants']?['address'] as String? ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(widget.card['merchants']['address'] as String)}'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(color: const Color(0xFF2C7BE5), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(CupertinoIcons.location_solid, color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(widget.card['merchants']['address'] as String,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 17, color: context.cText, letterSpacing: -0.3)),
                        ),
                        Icon(CupertinoIcons.chevron_forward, size: 16, color: context.cSub.withValues(alpha: 0.7)),
                      ]),
                    ),
                  ),
                ),
              // iOS : aujourd'hui (date + ouvert/fermé maintenant). Tous les horaires sont au dos.
              if (kIsIOS && !MerchantHours.fromMerchant(widget.card['merchants'] as Map?).isEmpty)
                Builder(builder: (_) {
                  final h = MerchantHours.fromMerchant(widget.card['merchants'] as Map?);
                  final (isOpen, txt) = h.statusNow();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: GestureDetector(
                      onTap: _toggleFlip,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                        decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: isOpen ? const Color(0xFF27AE60) : const Color(0xFF9096A4),
                              borderRadius: BorderRadius.circular(8)),
                            child: const Icon(CupertinoIcons.clock_fill, color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(txt, style: TextStyle(fontSize: 17, letterSpacing: -0.3,
                                  color: isOpen ? const Color(0xFF27AE60) : context.cText)),
                              Text('${MerchantHours.todayLabel()} · ${h.range}',
                                  style: TextStyle(fontSize: 14, color: context.cSub)),
                            ]),
                          ),
                          Icon(CupertinoIcons.chevron_forward, size: 16, color: context.cSub.withValues(alpha: 0.7)),
                        ]),
                      ),
                    ),
                  );
                }),
              // ── Bouton Ajouter au Wallet ─────────────────────────────────────
              if (kIsIOS)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
                  child: _AppleWalletButton(loading: _walletLoading, onTap: _addToWallet),
                )
              else
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _walletLoading ? null : _addToWallet,
                    icon: _walletLoading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : const Icon(Icons.account_balance_wallet_rounded, size: 18),
                    label: Text(
                      kIsIOS ? 'Ajouter à Apple Wallet' : 'Ajouter à Google Wallet',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kIsIOS
                          ? const Color(0xFF000000)
                          : const Color(0xFF2C7BE5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  static final _rng = Random(42);
  static final _particles = List.generate(60, (_) => _Particle(_rng));

  _ConfettiPainter(this.progress, this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;
    for (final p in _particles) {
      final t = (progress * 1.3 - p.delay).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = p.x * size.width;
      final y = p.startY * size.height - t * size.height * p.speed;
      final opacity = (1.0 - t * 0.8).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin * pi * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  final double x, startY, speed, delay, spin, w, h;
  final Color color;

  _Particle(Random rng)
      : x = rng.nextDouble(),
        startY = rng.nextDouble() * 0.3 + 0.8,
        speed = rng.nextDouble() * 0.8 + 0.5,
        delay = rng.nextDouble() * 0.4,
        spin = (rng.nextBool() ? 1 : -1) * (rng.nextDouble() + 0.5),
        w = rng.nextDouble() * 8 + 4,
        h = rng.nextDouble() * 6 + 3,
        color = [
          const Color(0xFFFBBF24),
          const Color(0xFF2C7BE5),
          const Color(0xFF27AE60),
          const Color(0xFFE24B4A),
          const Color(0xFF7B4FBF),
          Colors.white,
        ][rng.nextInt(6)];
}

// ── Animation : carte qui rétrécit et s'envole vers le pill Récompenses ───────
class _FlyingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDone;
  const _FlyingCard({super.key, required this.child, required this.onDone});
  @override
  State<_FlyingCard> createState() => _FlyingCardState();
}

class _FlyingCardState extends State<_FlyingCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>  _scale;
  late final Animation<Offset>  _slide;
  late final Animation<double>  _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale   = Tween<double>(begin: 1.0, end: 0.05)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInCubic));
    _slide   = Tween<Offset>(begin: Offset.zero, end: const Offset(0.35, -6.0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInCubic));
    _opacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 1.0)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(
      position: _slide,
      child: ScaleTransition(scale: _scale, child: widget.child),
    ),
  );
}

// ── Animation : nouvelle carte qui entre depuis la gauche (post-récompense) ──
class _SlideInCard extends StatefulWidget {
  final Widget child;
  const _SlideInCard({super.key, required this.child});
  @override
  State<_SlideInCard> createState() => _SlideInCardState();
}

class _SlideInCardState extends State<_SlideInCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _slide = Tween<Offset>(begin: const Offset(-1.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.45)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}


/// iOS : carte sortie de la pile, posée au milieu de l'écran.
class CardPopOut extends StatelessWidget {
  final String heroTag;
  final Animation<double> animation;
  final Widget face;
  final VoidCallback onOpen;
  const CardPopOut({required this.heroTag, required this.animation, required this.face, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final w = min(MediaQuery.of(context).size.width - 32, 568.0); // iPad : pas plus large que la pile
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    void close() => Navigator.pop(context);
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: close,
        onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) > 150) close(); },
        child: Stack(children: [
          // Fond flouté fixe, qui apparaît/disparaît en fondu (léger pour rester fluide).
          Positioned.fill(
            child: FadeTransition(
              opacity: fade,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ColoredBox(color: const Color(0xFF0B1220).withValues(alpha: 0.30)),
              ),
            ),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: onOpen,
                child: Hero(
                  tag: heroTag,
                  createRectTween: (b, e) => RectTween(begin: b, end: e),
                  child: SizedBox(width: w, height: 220, child: face),
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: fade,
                child: const Text('Touche la carte pour l\'ouvrir',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


/// iOS : page « carte ouverte ». La carte arrive en volant depuis la pile ;
/// le reste (titre, adresse, Wallet) apparaît en fondu. Toucher le fond
/// ou glisser vers le bas ferme : la carte redescend à sa place.
class OpenCardPage extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const OpenCardPage({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: FadeTransition(opacity: fade, child: const ColoredBox(color: Color(0x660B1220))),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) > 250) Navigator.maybePop(context); },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 8),
              child: FadeTransition(opacity: fade, alwaysIncludeSemantics: true, child: child),
            ),
          ),
        ),
      ]),
    );
  }
}


/// Bouton « Ajouter à Apple Wallet » dans le style du badge Apple :
/// fond noir, icône Wallet en couleurs, « Ajouter à » en petit au-dessus.
class _AppleWalletButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AppleWalletButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA6A6A6), width: 0.5),
        ),
        alignment: Alignment.center,
        child: loading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const _WalletGlyph(),
                const SizedBox(width: 10),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Ajouter à', style: TextStyle(color: Colors.white, fontSize: 11, height: 1.1, fontWeight: FontWeight.w400)),
                  Text('Apple Wallet', style: TextStyle(color: Colors.white, fontSize: 20, height: 1.1, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                ]),
              ]),
      ),
    );
  }
}

class _WalletGlyph extends StatelessWidget {
  const _WalletGlyph();
  @override
  Widget build(BuildContext context) {
    const stripes = [Color(0xFF3D9BE9), Color(0xFFF9B92D), Color(0xFF4CB848), Color(0xFFEE4136)];
    return Container(
      width: 32, height: 24,
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 0),
      decoration: BoxDecoration(color: const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(5)),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        child: Column(children: [
          for (final c in stripes) Expanded(child: Container(color: c, margin: const EdgeInsets.only(bottom: 1))),
        ]),
      ),
    );
  }
}
