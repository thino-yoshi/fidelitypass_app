// Carte ouverte iPhone (QR, tampon ajouté, adresse, horaires, Apple Wallet)
// et page qui l'accueille. Fichier iOS — Yassine.
// Copie iOS de QRModal / OpenCardPage (cards_tab.dart reste à Thigrou pour Android).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoActivityIndicator;
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_colors.dart';
import '../../../config/demo_mode.dart';
import '../../../services/api_service.dart';
import '../../../utils/logger.dart';
import '../../merchant/merchant_tokens.dart' show kIsIOS;
import '../cards_tab.dart' show CardStyle, StampEvent, LoyaltyCardFace;
import 'client_pass_face_ios.dart';
import 'client_hours.dart';
import 'client_sheets_ios.dart' show showIosAlert;

class QRModalIos extends StatefulWidget {
  final String token;
  final Map card;
  final CardStyle style;
  final String userName;
  final VoidCallback? onStampAdded;
  final void Function(StampEvent)? onStampEvent;
  /// iOS : si fourni, la carte vole depuis la pile (même Hero) au lieu d'apparaître.
  final String? heroTag;
  /// iOS : part visible de la carte dans la pile (1 = carte entière, sinon la bande
  /// d'une carte rangée). En s'ouvrant, la carte se déplie depuis cette bande.
  final double heroRestFraction;
  const QRModalIos({super.key, required this.token, required this.card, required this.style, this.userName = '', this.onStampAdded, this.onStampEvent, this.heroTag, this.heroRestFraction = 1});

  // Compat : raccourcis pour l'ancien code interne
  Color get color => style.primary;
  String? get logoUrl => style.logoUrl;

  @override
  State<QRModalIos> createState() => _QRModalIosState();
}

class _QRModalIosState extends State<QRModalIos> with TickerProviderStateMixin {
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
    AppLogger.client('QRModalIos → ouvert pour $merchantName, état initial: $stamps0/$required0 (${isPoints0 ? "points" : "tampons"})');
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
        AppLogger.client('QRModalIos → scan initial: ${_initialScanAt ?? "aucun"}');
      }
    });
    _startPolling();          // ← démarrer le polling
  }

  @override
  void dispose() {
    AppLogger.client('QRModalIos → fermé, polling arrêté');
    _pollTimer?.cancel();
    _demoTimer?.cancel();
    _confettiCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  // ── Polling : détecte l'ajout d'un tampon en temps réel ──────────────────────
  void _startPolling() {
    AppLogger.client('QRModalIos → polling démarré (toutes les 2s)');
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkForNewStamp());
  }

  Future<void> _checkForNewStamp() async {
    final r = await ApiService.instance.pollCard(widget.card['id'] as String);
    if (!mounted || r.isErr) return;
    final v = r.value;

    final latestScanAt = v['latest_scan_at'] as String?;
    AppLogger.client('QRModalIos → poll: latestScanAt=$latestScanAt, initial=$_initialScanAt');

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

    AppLogger.client('QRModalIos → tampon détecté! +$delta chez $merchantName → $newVal/$total${reward ? " 🎉 RÉCOMPENSE" : ""}');
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
    // Petit iPhone (SE) : QR un peu plus petit pour que la carte garde sa taille.
    final small = MediaQuery.of(context).size.height < 700;
    final qrSize = small ? 110.0 : 150.0;
    final qrBox = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: QrImageView(
        data: widget.card['qr_token'] as String? ?? '',
        version: QrVersions.auto,
        size: qrSize,
        foregroundColor: const Color(0xFF0B1220),
      ),
    );
    // Pas de 2e animation dans la carte quand la carte entière vole déjà.
    final qr = GestureDetector(
      onTap: () => _showQRZoom(context, color),
      child: widget.heroTag != null ? qrBox : Hero(tag: 'qr-${widget.card['id']}', child: qrBox),
    );
    Widget pass = SizedBox(height: small ? 392 : 432, child: ClientPassFaceIos(card: widget.card, style: widget.style, qr: qr));
    // Le vol depuis la pile n'existe qu'à l'ouverture (voir OpenCardPageIos).
    if (capture && widget.heroTag != null && OpenCardHeroScope.enabledOf(context)) {
      final staticQr = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: QrImageView(data: widget.card['qr_token'] as String? ?? '', version: QrVersions.auto, size: qrSize,
            foregroundColor: const Color(0xFF0B1220)),
      );
      pass = Hero(
        tag: widget.heroTag!,
        createRectTween: (b, e) => RectTween(begin: b, end: e),
        // Pendant le vol : la carte entière s'agrandit vers le bas et dévoile le QR.
        flightShuttleBuilder: (_, anim, ___, ____, _____) {
          final full = OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 432, maxHeight: 432,
            child: ClientPassFaceIos(card: widget.card, style: widget.style, qr: staticQr),
          );
          final rest = widget.heroRestFraction;
          if (rest >= 1) {
            return Material(type: MaterialType.transparency,
                child: ClipRRect(borderRadius: BorderRadius.circular(18), child: full));
          }
          // Carte rangée : on part de sa bande (le reste est sous la carte suivante)
          // et on la déplie en douceur, au lieu d'apparaître entière d'un coup.
          final fold = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
          // Passage court entre la carte ouverte et sa bande (sinon le nom apparaît en double).
          final fade = CurvedAnimation(parent: anim, curve: const Interval(0.0, 0.1, curve: Curves.easeOut));
          return Material(
            type: MaterialType.transparency,
            child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) => Align(
                alignment: Alignment.topCenter,
                child: LayoutBuilder(builder: (_, c) {
                  final h = c.maxHeight * (rest + (1 - rest) * fold.value);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: c.maxWidth, height: h,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: c.maxHeight, maxHeight: c.maxHeight,
                        child: Stack(fit: StackFit.expand, children: [
                          if (fade.value < 1)
                            OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: 220, maxHeight: 220,
                              child: ClientPassFaceIos(card: widget.card, style: widget.style, collapsed: true),
                            ),
                          Opacity(opacity: fade.value, child: full),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
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
  /// Zone de la carte dans la fiche. Android : défile si besoin.
  /// iPhone : ne défile jamais ; si l'écran est trop petit, la carte se réduit un peu.
  Widget _cardBody({required EdgeInsets padding, required Widget child}) {
    if (!kIsIOS) return SingleChildScrollView(padding: padding, child: child);
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (_, c) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(width: c.maxWidth, child: child),
        ),
      ),
    );
  }

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
                          behavior: HitTestBehavior.opaque,
                          // Apple : zone de toucher 44 × 44 pt, rond visible 30 pt.
                          child: SizedBox(
                            width: 44, height: 44,
                            child: Center(
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF767680).withValues(alpha: 0.12)),
                                child: Icon(CupertinoIcons.share, color: context.cSub, size: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 0), // les zones 44 pt donnent déjà l'écart
                    ],
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        // iPhone : zone de toucher 44 × 44 pt (règle Apple), rond visible 30 pt.
                        width: kIsIOS ? 44 : 30, height: kIsIOS ? 44 : 30,
                        child: Center(
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kIsIOS ? const Color(0xFF767680).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.1),
                            ),
                            child: Icon(kIsIOS ? CupertinoIcons.xmark : Icons.close, color: kIsIOS ? context.cSub : Colors.white, size: kIsIOS ? 14 : 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Corps scrollable (iOS : se réduit si l'écran est petit)
              Flexible(child: _cardBody(
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
                  child: _AppleWalletButtonIos(loading: _walletLoading, onTap: _addToWallet),
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


/// iOS : carte sortie de la pile, posée au milieu de l'écran.
class CardPopOutIos extends StatelessWidget {
  final String heroTag;
  final Animation<double> animation;
  final Widget face;
  final VoidCallback onOpen;
  const CardPopOutIos({required this.heroTag, required this.animation, required this.face, required this.onOpen});

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
class OpenCardPageIos extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  const OpenCardPageIos({required this.animation, required this.child});

  @override
  State<OpenCardPageIos> createState() => _OpenCardPageIosState();
}

/// iOS : comme une feuille iPhone, la page monte du bas et repart vers le bas
/// (la carte, elle, vole jusqu'à sa place dans la pile). On peut aussi la tirer
/// vers le bas avec le doigt : elle suit le doigt et se ferme si on la lâche assez bas.
/// (Ancienne version : la page apparaissait / disparaissait en fondu.)
class _OpenCardPageIosState extends State<OpenCardPageIos> with SingleTickerProviderStateMixin {
  double _drag = 0; // décalage vers le bas pendant qu'on tire avec le doigt
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  // La carte « vole » depuis la pile seulement à l'ouverture. À la fermeture, on coupe
  // le vol : la carte reste dans la page et redescend avec elle (comme une feuille iPhone).
  bool _closing = false;
  bool _heroOn = true; // vol actif seulement pendant l'ouverture

  void _onStatus(AnimationStatus st) {
    if (!mounted) return;
    final closing = st == AnimationStatus.reverse || st == AnimationStatus.dismissed;
    // Ouverture terminée : on coupe le vol tout de suite, pour qu'au retour la carte
    // reste dans la page (sinon elle volerait vers la pile pendant que la page descend).
    final heroOn = st == AnimationStatus.forward;
    if (closing != _closing || heroOn != _heroOn) setState(() { _closing = closing; _heroOn = heroOn; });
  }

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    _back.dispose();
    super.dispose();
  }

  void _snapBack() {
    final from = _drag;
    final a = CurvedAnimation(parent: _back, curve: Curves.easeOutCubic);
    void tick() => setState(() => _drag = from * (1 - a.value));
    a.addListener(tick);
    _back.forward(from: 0).whenComplete(() => a.removeListener(tick));
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: widget.animation, curve: Curves.easeOut);
    final slide = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final screenH = MediaQuery.of(context).size.height;
    return _page(context, fade, slide, screenH);
  }

  Widget _page(BuildContext context, Animation<double> fade, Animation<double> slide, double screenH) {
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
            onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0, screenH)),
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (_drag > 140 || v > 700) {
                Navigator.maybePop(context);
              } else {
                _snapBack();
              }
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 640, maxHeight: screenH - MediaQuery.of(context).padding.top - 8),
              child: AnimatedBuilder(
                animation: slide,
                // Ouverture : la page apparaît en fondu (la carte, elle, vole depuis la pile).
                // Fermeture : toute la page redescend, carte comprise (+ suit le doigt).
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, (_closing ? (1 - slide.value) * screenH : 0) + _drag),
                  // Toujours le même emballage (sinon la carte serait reconstruite à la fermeture).
                  child: FadeTransition(opacity: _closing ? const AlwaysStoppedAnimation(1.0) : fade, child: child),
                ),
                child: OpenCardHeroScope(enabled: _heroOn && !_closing, child: widget.child),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}


/// Bouton officiel « Ajouter à Apple Wallet » : c'est le bouton système d'Apple
/// (PKAddPassButton, voir ios/Runner/AppDelegate.swift), pas un dessin.
/// Règle Apple : ne jamais le redessiner, l'animer ni l'ombrer.
class _AppleWalletButtonIos extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AppleWalletButtonIos({required this.loading, required this.onTap});

  @override
  State<_AppleWalletButtonIos> createState() => _AppleWalletButtonIosState();
}

class _AppleWalletButtonIosState extends State<_AppleWalletButtonIos> {
  MethodChannel? _channel;

  void _created(int id) {
    _channel = MethodChannel('qarta/add_pass_button_$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'pressed' && !widget.loading) widget.onTap();
      });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: UiKitView(
            viewType: 'qarta/add_pass_button',
            onPlatformViewCreated: _created,
          ),
        ),
        if (widget.loading) const CupertinoActivityIndicator(),
      ]),
    );
  }
}


/// Dit à la carte ouverte si elle peut encore « voler » depuis la pile.
/// Coupé dès que l'ouverture est finie : à la fermeture, la carte redescend avec la page.
class OpenCardHeroScope extends InheritedWidget {
  final bool enabled;
  const OpenCardHeroScope({super.key, required this.enabled, required super.child});

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OpenCardHeroScope>()?.enabled ?? true;

  @override
  bool updateShouldNotify(OpenCardHeroScope old) => old.enabled != enabled;
}

