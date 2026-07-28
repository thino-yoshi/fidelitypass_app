import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/user_avatar.dart';
import '../../utils/logger.dart';

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
  final List<dynamic> initialHistory;
  const ScannerScreen({super.key, required this.token, this.merchantInfo, this.initialHistory = const []});

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
  String _selectedMode = 'stamp'; // 'stamp' | 'reward'

  _Overlay? _overlay;

  int get _required     => widget.merchantInfo?['stamps_required'] as int? ?? 10;
  bool get _isPoints    => (widget.merchantInfo?['program_type'] as String?) == 'points';
  int get _pointsPerEuro => (widget.merchantInfo?['points_per_euro'] as int?) ?? 10;

  @override
  void initState() {
    super.initState();
    AppLogger.merchant('ScannerScreen → ouvert, commerce: ${widget.merchantInfo?['business_name'] ?? '?'}');
    _scanLine = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    if (widget.initialHistory.isNotEmpty) {
      _history = List<dynamic>.from(widget.initialHistory);
      _loadingHistory = false;
    } else {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    _scanLine.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    AppLogger.merchant('ScannerScreen → chargement historique scans...');
    final r = await ApiService.instance.getMerchantScanHistory();
    if (mounted && r.isOk) {
      AppLogger.merchant('ScannerScreen → historique chargé: ${r.value.length} scan(s)');
      setState(() { _history = r.value; _loadingHistory = false; });
    } else if (mounted) {
      AppLogger.error('ScannerScreen → historique erreur: ${r.error}');
      setState(() => _loadingHistory = false);
    }
  }

  // ── Scan caméra → identifie le QR selon l'onglet actif ──────────────────────
  Future<void> _onScan(String qrToken) async {
    if (_processing || _sheetOpen) return;
    AppLogger.merchant('ScannerScreen → QR scanné (mode: $_selectedMode): $qrToken');
    setState(() => _processing = true);
    final r = await ApiService.instance.resolveScan(qrToken);
    if (!mounted) return;
    setState(() => _processing = false);
    if (r.isOk) {
      final v = r.value;
      final kind = v['kind'] as String? ?? 'stamp';
      AppLogger.merchant('ScannerScreen → resolveScan ✓ kind: $kind, client: ${v['client_name']}');
      if (_selectedMode == 'reward') {
        if (kind == 'reward') {
          _openRewardValidation(
            qrToken: qrToken,
            name: (v['client_name'] ?? 'Client') as String,
            description: (v['description'] ?? 'Récompense') as String,
          );
        } else {
          _toast('QR de tampon — allez dans l\'onglet Tampons', isError: true);
        }
      } else {
        if (kind == 'stamp') {
          _openQuantitySheet(
            cardId:  v['card_id'] as String,
            name:    (v['client_name'] ?? 'Client') as String,
            current: (v['stamps_count'] as int?) ?? 0,
            total:   (v['stamps_required'] as int?) ?? _required,
          );
        } else {
          _toast('QR de récompense — allez dans l\'onglet Récompenses', isError: true);
        }
      }
    } else {
      AppLogger.error('ScannerScreen → resolveScan erreur: ${r.error}');
      _toast(r.error ?? 'QR invalide ou expiré', isError: true);
    }
  }

  // ── Validation d'une récompense ──────────────────────────────────────────────
  Future<void> _openRewardValidation({required String qrToken, required String name, required String description}) async {
    if (_sheetOpen) return;
    AppLogger.merchant('ScannerScreen → modale récompense ouverte — client: $name, récompense: $description');
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
        AppLogger.merchant('ScannerScreen → récompense confirmée → redeemReward');
        final r = await ApiService.instance.redeemReward(qrToken);
        if (!mounted) return;
        if (r.isOk) {
          AppLogger.merchant('ScannerScreen → récompense validée ✓ — ${r.value['description'] ?? description}');
          _showSuccess(name: name, count: 0, total: 1, reward: true, rewardLabel: r.value['description'] as String? ?? description);
          _loadHistory();
        } else {
          AppLogger.error('ScannerScreen → redeemReward erreur: ${r.error}');
          _toast(r.error ?? 'Validation impossible', isError: true);
        }
      } else {
        AppLogger.merchant('ScannerScreen → récompense annulée');
      }
    });
  }

  // ── Modale : choisir quantité (tampons) ou montant (points) ─────────────────
  Future<void> _openQuantitySheet({
    required String cardId,
    required String name,
    required int current,
    required int total,
  }) async {
    if (_sheetOpen) return;
    final isPoints = _isPoints;
    final ppe = _pointsPerEuro;
    AppLogger.merchant('ScannerScreen → modale ${isPoints ? "points" : "tampons"} ouverte — client: $name');
    setState(() => _sheetOpen = true);
    int qty = 1;
    final amountCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final parsed      = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
        final pointsToAdd = isPoints ? (parsed * ppe).round() : qty;
        final willReward  = current + pointsToAdd >= total;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
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
              Text('Actuellement $current/$total ${isPoints ? "points" : "tampons"}',
                  style: TextStyle(fontSize: 12, color: context.cSub)),
              const SizedBox(height: 20),

              if (isPoints) ...[
                // ── Mode points : champ montant en euros ──
                Container(
                  decoration: BoxDecoration(
                    color: context.cFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.cBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    Text('€', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.cSub)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: _kPrimary),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: context.cSub),
                        ),
                        onChanged: (_) => setS(() {}),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: pointsToAdd > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.stars_rounded, size: 18, color: _kPrimary),
                      const SizedBox(width: 8),
                      Text('= $pointsToAdd point${pointsToAdd > 1 ? "s" : ""} ($ppe pts/€)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kPrimary)),
                    ]),
                  ),
                ),
              ] else ...[
                // ── Mode tampons : stepper ──
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _stepBtn(Icons.remove_rounded, qty > 1 ? () => setS(() => qty--) : null),
                  SizedBox(width: 64, child: Text('$qty', textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _kPrimary))),
                  _stepBtn(Icons.add_rounded, qty < 20 ? () => setS(() => qty++) : null),
                ]),
                Text('tampon${qty > 1 ? "s" : ""} à ajouter', style: TextStyle(fontSize: 11, color: context.cSub)),
                const SizedBox(height: 14),
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
              ],

              if (willReward && pointsToAdd > 0)
                const Padding(padding: EdgeInsets.only(top: 10), child: Text('🎉 Atteindra la récompense', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGold))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: (isPoints ? pointsToAdd > 0 : true)
                    ? () => Navigator.pop(ctx, pointsToAdd)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isPoints
                      ? (pointsToAdd > 0 ? 'Ajouter $pointsToAdd point${pointsToAdd > 1 ? "s" : ""}' : 'Entrez un montant')
                      : 'Ajouter $qty tampon${qty > 1 ? "s" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              )),
            ]),
          ),
        );
      }),
    ).then((confirmed) async {
      setState(() => _sheetOpen = false);
      if (confirmed is int && confirmed > 0) {
        AppLogger.merchant('ScannerScreen → $confirmed ${_isPoints ? "point(s)" : "tampon(s)"} à ajouter pour $name');
        await _confirmAdd(cardId: cardId, name: name, qty: confirmed, total: total);
      } else {
        AppLogger.merchant('ScannerScreen → modale annulée');
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
    final unit = _isPoints ? 'point(s)' : 'tampon(s)';
    AppLogger.merchant('ScannerScreen → adjustStamp cardId: $cardId, delta: +$qty $unit');
    setState(() => _processing = true);
    final r = await ApiService.instance.adjustStamp(cardId, qty);
    if (!mounted) return;
    setState(() => _processing = false);
    if (r.isOk) {
      final v = r.value;
      final newCount = (v['stamps_count'] as int?) ?? 0;
      final rewardReached = v['reward_reached'] == true;
      AppLogger.merchant('ScannerScreen → adjustStamp ✓ — $name: $newCount/$total $unit${rewardReached ? ' 🎉 RÉCOMPENSE' : ''}');
      _showSuccess(
        name: name,
        count: newCount,
        total: (v['stamps_required'] as int?) ?? total,
        reward: rewardReached,
        isPoints: _isPoints,
      );
      _loadHistory();
    } else {
      AppLogger.error('ScannerScreen → adjustStamp erreur: ${r.error}');
      _toast(r.error ?? 'Erreur', isError: true);
    }
  }

  void _showSuccess({required String name, required int count, required int total, required bool reward, String? rewardLabel, bool isPoints = false}) {
    setState(() => _overlay = _Overlay(name: name, count: count, total: total, reward: reward, rewardLabel: rewardLabel, isPoints: isPoints));
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
      child: Column(children: [
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 10),
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
        ),
        // ── Onglets Tampons / Récompenses ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Stack(children: [
                AnimatedAlign(
                  alignment: _selectedMode == 'stamp' ? Alignment.centerLeft : Alignment.centerRight,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1.0,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _kBlueLight.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _selectedMode = 'stamp'),
                    child: Center(child: Text('Tampons',
                        style: TextStyle(color: Colors.white.withValues(alpha: _selectedMode == 'stamp' ? 1.0 : 0.5), fontSize: 13, fontWeight: FontWeight.w700))),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _selectedMode = 'reward'),
                    child: Center(child: Text('Récompenses',
                        style: TextStyle(color: Colors.white.withValues(alpha: _selectedMode == 'reward' ? 1.0 : 0.5), fontSize: 13, fontWeight: FontWeight.w700))),
                  )),
                ]),
              ]),
            ),
          )),
        ),
      ]),
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
            child: Text(
              _selectedMode == 'reward' ? 'Scanne le QR récompense du client' : 'Scanne le QR du client',
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
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
                  Text(reward ? 'Récompense atteinte' : '$count/$_required ${_isPoints ? "points" : "tampons"}', style: TextStyle(fontSize: 10, color: context.cSub)),
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

  // ── Badge succès compact (en haut de l'écran) ────────────────────────────────
  Widget _successOverlay(_Overlay o) {
    final isRedeem = o.rewardLabel != null;
    final isReward = o.reward || isRedeem;
    final accentColor = isReward ? _kGold : _kPrimary;
    final bgColor = isReward ? const Color(0xFFFFFBEB) : const Color(0xFFF0F6FF);
    final textColor = isReward ? const Color(0xFF92400E) : _kNavy;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(
                  isRedeem ? Icons.redeem_rounded : (isReward ? Icons.emoji_events_rounded : Icons.check_rounded),
                  color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isRedeem ? 'Récompense validée ✓' : (isReward ? 'Récompense atteinte 🎉' : (o.isPoints ? 'Points ajoutés ✓' : 'Tampon ajouté ✓')),
                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(
                  isRedeem ? '${o.rewardLabel} · ${o.name}' : '${o.name} · ${o.count}/${o.total}',
                  style: TextStyle(color: textColor.withValues(alpha: 0.65), fontSize: 11)),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Overlay {
  final String name;
  final int count, total;
  final bool reward;
  final bool isPoints;
  final String? rewardLabel;
  _Overlay({required this.name, required this.count, required this.total, required this.reward, this.rewardLabel, this.isPoints = false});
}
