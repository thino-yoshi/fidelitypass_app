import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/user_avatar.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2C7BE5);
const _kBlueLight = Color(0xFF4A9EF5);
const _kNavy      = Color(0xFF0B1220);
const _kSuccess   = Color(0xFF27AE60);
const _kGold      = Color(0xFFF59E0B);
const double _kMaxContentWidth = 500;

class ScannerScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const ScannerScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _camera = MobileScannerController();
  late final AnimationController _scanLine;

  bool _processing = false;
  bool _sheetOpen = false;
  List<dynamic> _history = [];
  bool _loadingHistory = true;

  _Overlay? _overlay;

  int get _required => widget.merchantInfo?['stamps_required'] as int? ?? 10;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _loadHistory();
  }

  @override
  void dispose() {
    _camera.dispose();
    _scanLine.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final r = await ApiService.instance.getMerchantScanHistory();
    if (mounted && r.isOk) {
      setState(() { _history = r.value; _loadingHistory = false; });
    } else if (mounted) {
      setState(() => _loadingHistory = false);
    }
  }

  // ── Scan caméra → identifie le QR (tampon OU récompense) ─────────────────────
  Future<void> _onScan(String qrToken) async {
    if (_processing || _sheetOpen) return;
    setState(() => _processing = true);
    final r = await ApiService.instance.resolveScan(qrToken);
    if (!mounted) return;
    setState(() => _processing = false);
    if (r.isOk) {
      final v = r.value;
      if (v['kind'] == 'reward') {
        _openRewardValidation(
          qrToken: qrToken,
          name: (v['client_name'] ?? 'Client') as String,
          description: (v['description'] ?? 'Récompense') as String,
        );
      } else {
        _openQuantitySheet(
          cardId:  v['card_id'] as String,
          name:    (v['client_name'] ?? 'Client') as String,
          current: (v['stamps_count'] as int?) ?? 0,
          total:   (v['stamps_required'] as int?) ?? _required,
        );
      }
    } else {
      _toast(r.error ?? 'QR invalide ou expiré', isError: true);
    }
  }

  // ── Validation d'une récompense ──────────────────────────────────────────────
  Future<void> _openRewardValidation({required String qrToken, required String name, required String description}) async {
    if (_sheetOpen) return;
    setState(() => _sheetOpen = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: context.cSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Container(width: 64, height: 64, decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Center(child: Text('🎁', style: TextStyle(fontSize: 30)))),
          const SizedBox(height: 14),
          Text('Récompense de $name', style: TextStyle(fontSize: 13, color: context.cSub)),
          const SizedBox(height: 4),
          Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: context.cText)),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGold, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Valider la récompense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: context.cSub))),
        ]),
      ),
    ).then((confirmed) async {
      setState(() => _sheetOpen = false);
      if (confirmed == true) {
        final r = await ApiService.instance.redeemReward(qrToken);
        if (!mounted) return;
        if (r.isOk) {
          _showSuccess(name: name, count: 0, total: 1, reward: true, rewardLabel: r.value['description'] as String? ?? description);
          _loadHistory();
        } else {
          _toast(r.error ?? 'Validation impossible', isError: true);
        }
      }
    });
  }

  // ── Modale : choisir le nombre de tampons à ajouter ──────────────────────────
  Future<void> _openQuantitySheet({
    required String cardId,
    required String name,
    required int current,
    required int total,
  }) async {
    if (_sheetOpen) return;
    setState(() => _sheetOpen = true);
    int qty = 1;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final willReward = current + qty >= total;
        return Container(
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.cText)),
            const SizedBox(height: 2),
            Text('Actuellement $current/$total tampons', style: TextStyle(fontSize: 12, color: context.cSub)),
            const SizedBox(height: 20),
            // Stepper
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _stepBtn(Icons.remove_rounded, qty > 1 ? () => setS(() => qty--) : null),
              SizedBox(width: 64, child: Text('$qty', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _kPrimary))),
              _stepBtn(Icons.add_rounded, qty < 20 ? () => setS(() => qty++) : null),
            ]),
            Text('tampon${qty > 1 ? "s" : ""} à ajouter', style: TextStyle(fontSize: 11, color: context.cSub)),
            const SizedBox(height: 14),
            // Boutons rapides
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [1, 2, 3, 5].map((n) {
              final sel = qty == n;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setS(() => qty = n),
                  child: Container(
                    width: 48, height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? _kPrimary : _kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text('+$n', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: sel ? Colors.white : _kPrimary)),
                  ),
                ),
              );
            }).toList()),
            if (willReward)
              const Padding(padding: EdgeInsets.only(top: 10), child: Text('🎉 Atteindra la récompense', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGold))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, qty),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Ajouter $qty tampon${qty > 1 ? "s" : ""}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            )),
          ]),
        );
      }),
    ).then((confirmed) async {
      setState(() => _sheetOpen = false);
      if (confirmed is int && confirmed > 0) {
        await _confirmAdd(cardId: cardId, name: name, qty: confirmed, total: total);
      }
    });
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: enabled ? context.cBg : context.cBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        child: Icon(icon, color: enabled ? context.cText : context.cSub, size: 24),
      ),
    );
  }

  Future<void> _confirmAdd({required String cardId, required String name, required int qty, required int total}) async {
    if (_processing) return;
    setState(() => _processing = true);
    final r = await ApiService.instance.adjustStamp(cardId, qty);
    if (!mounted) return;
    setState(() => _processing = false);
    if (r.isOk) {
      final v = r.value;
      _showSuccess(
        name: name,
        count: (v['stamps_count'] as int?) ?? 0,
        total: (v['stamps_required'] as int?) ?? total,
        reward: v['reward_reached'] == true,
      );
      _loadHistory();
    } else {
      _toast(r.error ?? 'Erreur', isError: true);
    }
  }

  void _showSuccess({required String name, required int count, required int total, required bool reward, String? rewardLabel}) {
    setState(() => _overlay = _Overlay(name: name, count: count, total: total, reward: reward, rewardLabel: rewardLabel));
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _overlay = null);
    });
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFE24B4A) : _kSuccess,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ──────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: Stack(children: [
        Column(children: [
          _header(),
          // Caméra — moitié haute
          Expanded(child: _cameraSection()),
          // Historique — moitié basse
          Expanded(child: _historySection()),
        ]),
        if (_overlay != null) _successOverlay(_overlay!),
      ]),
    );
  }

  // ── Header navy ───────────────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      color: _kNavy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 12),
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
          const Text('Scanner un client', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      )),
    );
  }

  // ── Caméra plein cadre (moitié haute) ─────────────────────────────────────────
  Widget _cameraSection() {
    return Container(
      color: const Color(0xFF0A0F1A),
      width: double.infinity,
      child: Stack(children: [
        Positioned.fill(child: MobileScanner(
          controller: _camera,
          onDetect: (capture) {
            final b = capture.barcodes.firstOrNull;
            if (b?.rawValue != null) _onScan(b!.rawValue!);
          },
        )),
        // Cadre cible centré
        Center(child: LayoutBuilder(builder: (ctx, c) {
          final size = (c.maxHeight * 0.72).clamp(140.0, 280.0);
          return SizedBox(width: size, height: size, child: Stack(children: [
            ..._corners(),
            AnimatedBuilder(
              animation: _scanLine,
              builder: (_, __) => Positioned(
                left: 10, right: 10,
                top: 10 + _scanLine.value * (size - 20),
                child: Container(height: 2, decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.transparent, _kBlueLight, Colors.transparent])),
                ),
              ),
            ),
          ]));
        })),
        // Hint bas
        Positioned(
          left: 0, right: 0, bottom: 12,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
            child: const Text('Scanne le QR du client', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          )),
        ),
      ]),
    );
  }

  List<Widget> _corners() {
    BorderSide s() => const BorderSide(color: _kPrimary, width: 3);
    Widget corner({bool top = false, bool left = false}) => Positioned(
      top: top ? 6 : null, bottom: top ? null : 6,
      left: left ? 6 : null, right: left ? null : 6,
      child: Container(width: 26, height: 26, decoration: BoxDecoration(
        border: Border(
          top: top ? s() : BorderSide.none,
          bottom: top ? BorderSide.none : s(),
          left: left ? s() : BorderSide.none,
          right: left ? BorderSide.none : s(),
        ),
      )),
    );
    return [
      corner(top: true, left: true), corner(top: true, left: false),
      corner(top: false, left: true), corner(top: false, left: false),
    ];
  }

  // ── Historique des scans récents (moitié basse, cliquable) ───────────────────
  Widget _historySection() {
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Historique des scans', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.cText)),
            Text('Appui = ajouter', style: TextStyle(fontSize: 10, color: context.cSub)),
          ]),
        ),
        Expanded(child: _loadingHistory
            ? const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2))
            : _history.isEmpty
                ? Center(child: Text("Aucun scan pour l'instant", style: TextStyle(fontSize: 12, color: context.cSub)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
                    itemCount: _history.length,
                    itemBuilder: (_, i) => _historyRow(_history[i] as Map),
                  )),
      ]),
    ));
  }

  Widget _historyRow(Map scan) {
    final client  = scan['client'] as Map? ?? {};
    final name    = (client['name'] ?? client['email'] ?? 'Client') as String;
    final count   = (scan['stamps_count'] as int?) ?? 0;
    final reward  = scan['reward_reached'] == true;
    final cardId  = scan['card_id'] as String?;
    final time    = _fmtTime(scan['scanned_at'] as String?);
    final c = reward ? _kGold : _kSuccess;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.cBorder)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (cardId == null || _processing || _sheetOpen) ? null : () => _openQuantitySheet(
            cardId: cardId, name: name, current: count, total: _required,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              UserAvatar(imageUrl: client['profile_picture_url'] as String?, name: name, size: 34),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(reward ? 'Récompense atteinte' : '$count/$_required tampons', style: TextStyle(fontSize: 10, color: context.cSub)),
                ]),
              ])),
              if (time.isNotEmpty) Text(time, style: TextStyle(fontSize: 10, color: context.cSub)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.add_rounded, size: 16, color: _kPrimary),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Overlay succès plein écran ──────────────────────────────────────────────
  Widget _successOverlay(_Overlay o) {
    final isRedeem = o.rewardLabel != null;
    final c = (o.reward || isRedeem) ? _kGold : _kSuccess;
    final pct = o.total > 0 ? (o.count / o.total).clamp(0.0, 1.0) : 0.0;
    return Positioned.fill(child: Container(
      color: c.withValues(alpha: 0.96),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(isRedeem ? Icons.redeem_rounded : (o.reward ? Icons.emoji_events_rounded : Icons.check_rounded), color: Colors.white, size: 42),
        ),
        const SizedBox(height: 18),
        Text(isRedeem ? 'Récompense validée ✓' : (o.reward ? 'Récompense atteinte 🎉' : 'Tampon ajouté ✓'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (isRedeem)
          Text('${o.rewardLabel} · ${o.name}', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600))
        else ...[
          Text('${o.name} · ${o.count}/${o.total}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(width: 180, child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: Colors.white.withValues(alpha: 0.25), valueColor: const AlwaysStoppedAnimation(Colors.white)),
          )),
        ],
      ])),
    ));
  }
}

class _Overlay {
  final String name;
  final int count, total;
  final bool reward;
  final String? rewardLabel; // si défini → écran "Récompense validée"
  _Overlay({required this.name, required this.count, required this.total, required this.reward, this.rewardLabel});
}
