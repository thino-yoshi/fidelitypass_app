import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import 'cards_tab.dart' show LoyaltyCardFace, CardStyle;

const _kNavy = Color(0xFF0B1220);
const _kGold = Color(0xFFF59E0B);
const _kGold2 = Color(0xFFFBBF24);
const double _kMaxContentWidth = 500;

/// Portefeuille de récompenses : bannière par magasin → carrousel des cartes
/// complétées (design réel, tampons pleins) → modale QR de la plus ancienne (FIFO).
class RewardsWalletScreen extends StatefulWidget {
  final String token;
  final String userName;
  final List<dynamic> initialRewards;
  final VoidCallback? onChanged;
  const RewardsWalletScreen({
    super.key,
    required this.token,
    this.userName = '',
    this.initialRewards = const [],
    this.onChanged,
  });

  @override
  State<RewardsWalletScreen> createState() => _RewardsWalletScreenState();
}

class _RewardsWalletScreenState extends State<RewardsWalletScreen> {
  List<dynamic> _rewards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialRewards.isNotEmpty) {
      _rewards = List<dynamic>.from(widget.initialRewards);
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final r = await ApiService.instance.getMyRewards();
    if (!mounted) return;
    setState(() {
      _rewards = r.isOk ? r.value : [];
      _loading = false;
    });
  }

  // Regroupe par magasin (déjà trié earned_at asc côté backend)
  Map<String, List<dynamic>> get _byMerchant {
    final map = <String, List<dynamic>>{};
    for (final r in _rewards) {
      map.putIfAbsent(r['merchant_id'] as String, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _byMerchant;
    return Scaffold(
      backgroundColor: context.cBg,
      body: Column(children: [
        _header(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kGold))
              : groups.isEmpty
                  ? _empty()
                  : Center(child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                        children: groups.entries.map((e) => _banner(e.value.first['merchant_name'] as String? ?? 'Commerce', e.value)).toList(),
                      ),
                    )),
        ),
      ]),
    );
  }

  Widget _header() {
    return Container(
      color: _kNavy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 14),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
              child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Mes récompenses', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      )),
    );
  }

  Widget _empty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎁', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 14),
      Text('Aucune récompense pour l\'instant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.cText)),
      const SizedBox(height: 6),
      Text('Complète une carte de fidélité pour\nen débloquer une !', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.cSub, height: 1.5)),
    ]));
  }

  // ── Bannière magasin ──────────────────────────────────────────────────────────
  Widget _banner(String name, List<dynamic> rewards) {
    return GestureDetector(
      onTap: () => _openStack(name, rewards),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _kNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4A9EFF).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFF4A9EFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.star_rounded, color: Color(0xFF4A9EFF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text('${rewards.length} récompense${rewards.length > 1 ? "s" : ""} disponible${rewards.length > 1 ? "s" : ""}',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFF4A9EFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('${rewards.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF4A9EFF))),
          ),
        ]),
      ),
    );
  }

  // ── Carrousel des cartes complétées (design réel, tampons pleins) ────────────
  void _openStack(String name, List<dynamic> rewards) {
    final pageCtrl = PageController(viewportFraction: 0.88);
    int current = 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return Container(
          decoration: BoxDecoration(color: context.cBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(0, 14, 0, 24 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.cText)),
            const SizedBox(height: 2),
            Text('${rewards.length} carte${rewards.length > 1 ? "s" : ""} complétée${rewards.length > 1 ? "s" : ""} · glisse pour voir',
                style: TextStyle(fontSize: 11, color: context.cSub)),
            const SizedBox(height: 18),
            // Carrousel de vraies cartes pleines
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: pageCtrl,
                itemCount: rewards.length,
                onPageChanged: (i) => setS(() => current = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  // SingleChildScrollView → la carte garde sa hauteur naturelle
                  // (pas d'overflow), centrée verticalement dans le slot.
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: _fullCard(rewards[i], name),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Indicateur (points)
            if (rewards.length > 1)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(rewards.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: current == i ? 18 : 7, height: 7,
                decoration: BoxDecoration(
                  color: current == i ? _kGold : context.cBorder,
                  borderRadius: BorderRadius.circular(99)),
              ))),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); _openRewardQR(name, rewards.first); },
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('Utiliser une récompense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('La plus ancienne sera utilisée', style: TextStyle(fontSize: 10, color: context.cSub)),
            ),
          ]),
        );
      }),
    );
  }

  /// Construit la vraie carte du magasin, PLEINE, via LoyaltyCardFace.
  Widget _fullCard(Map reward, String name) {
    final merchant = (reward['merchant'] as Map?) ?? {'business_name': name};
    final isPoints = (merchant['program_type'] as String? ?? 'stamps') == 'points';
    final full = isPoints
        ? (merchant['points_required'] as int? ?? 100)
        : (merchant['stamps_required'] as int? ?? 10);
    final card = {
      'stamps_count': full,                       // toutes les cases pleines
      'card_design': reward['card_design'],
      'merchants': merchant,
    };
    final style = CardStyle.fromDesign(reward['card_design'], fallbackColor: _kGold);
    return LoyaltyCardFace(card: card, style: style, userName: widget.userName);
  }

  // ── Modale QR de la récompense ───────────────────────────────────────────────
  void _openRewardQR(String name, Map reward) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RewardQRModal(
        rewardId: reward['id'] as String,
        merchantName: name,
        description: reward['description'] as String? ?? 'Récompense',
        onRedeemed: () {
          widget.onChanged?.call();
          _load(); // recharge la liste (la récompense utilisée disparaît)
        },
      ),
    );
  }
}

// ── Modale QR + polling de validation ──────────────────────────────────────────
class _RewardQRModal extends StatefulWidget {
  final String rewardId;
  final String merchantName;
  final String description;
  final VoidCallback onRedeemed;
  const _RewardQRModal({required this.rewardId, required this.merchantName, required this.description, required this.onRedeemed});

  @override
  State<_RewardQRModal> createState() => _RewardQRModalState();
}

class _RewardQRModalState extends State<_RewardQRModal> {
  String? _token;
  int _timeLeft = 120;
  bool _loading = true;
  bool _redeemed = false;
  Timer? _timer;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _fetch();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _checkRedeemed());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _token = null; });
    final r = await ApiService.instance.getRewardQR(widget.rewardId);
    if (!mounted) return;
    if (r.isOk) {
      setState(() {
        _token = r.value['dynamic_token'] as String?;
        _timeLeft = r.value['expires_in'] as int? ?? 120;
        _loading = false;
      });
      _startTimer();
    } else {
      setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) { t.cancel(); _fetch(); }
    });
  }

  // Détecte la validation : la récompense disparaît de /rewards/me
  Future<void> _checkRedeemed() async {
    final r = await ApiService.instance.getMyRewards();
    if (!mounted || r.isErr) return;
    final stillThere = r.value.any((x) => x['id'] == widget.rewardId);
    if (!stillThere && !_redeemed) {
      _redeemed = true;
      _poll?.cancel();
      _timer?.cancel();
      if (mounted) {
        setState(() {}); // affiche l'écran "utilisée"
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) {
            Navigator.pop(context);
            widget.onRedeemed();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + MediaQuery.of(context).padding.bottom),
      child: Container(
      decoration: const BoxDecoration(color: _kNavy, borderRadius: BorderRadius.all(Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 18),
        if (_redeemed) ...[
          Container(width: 76, height: 76, decoration: BoxDecoration(color: const Color(0xFF27AE60).withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Color(0xFF27AE60), size: 40)),
          const SizedBox(height: 18),
          const Text('Récompense utilisée ✓', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(widget.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
        ] else ...[
          const Text('RÉCOMPENSE', style: TextStyle(color: _kGold2, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text(widget.description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('chez ${widget.merchantName}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: _loading
                ? const SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)))
                : QrImageView(data: _token ?? '', version: QrVersions.auto, size: 180, foregroundColor: _kNavy),
          ),
          const SizedBox(height: 16),
          Text('Montre ce QR au commerce pour\nutiliser ta récompense', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.5)),
          const SizedBox(height: 8),
          Text('🔒 Renouvellement dans ${_timeLeft}s', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        ],
      ]),
    ));
  }
}
