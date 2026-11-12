import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';
import '../../../config/demo_mode.dart';
import '../../../services/api_service.dart';
import '../cards_tab.dart' show CardStyle;
import 'client_pass_face_ios.dart';

// Feuilles iOS de l'espace client (style Apple, clair) :
//  • showCardAddedIos       → « Carte ajoutée » après un scan
//  • showRewardUnlockedIos  → « Carte complète ! » quand la carte est pleine
//  • showRewardQrIos        → QR de la récompense + « Récompense utilisée »

/// Met une majuscule au début : « une baguette » → « Une baguette ».
String capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Construit la carte du commerçant (son design) avec un nombre de tampons donné.
Widget merchantCardFace({
  required Map merchant,
  required dynamic design,
  required String userName,
  required int count,
}) {
  final isPoints = (merchant['program_type'] as String? ?? 'stamps') == 'points';
  final card = {
    'stamps_count': isPoints ? 0 : count,
    'points_count': isPoints ? count : 0,
    'card_design': design,
    'merchants': merchant,
  };
  final style = CardStyle.fromDesign(design,
      merchantLogoUrl: merchant['logo_url'] as String?, fallbackColor: kNavyCard);
  return SizedBox(height: 220, child: ClientPassFaceIos(card: card, style: style));
}

// ── Éléments communs ─────────────────────────────────────────────────────────

class _SheetFrame extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showClose;
  const _SheetFrame({required this.child, this.title, this.subtitle, this.showClose = false});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.cBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 36, height: 5,
            decoration: BoxDecoration(color: context.cSub.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(3)),
          ),
        ),
        if (title != null || showClose)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 0, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (title != null)
                    Text(title!, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: context.cText)),
                  if (subtitle != null)
                    Text(subtitle!, style: QText.body.copyWith(fontSize: 17, color: context.cSub)),
                ]),
              ),
              if (showClose) const _CloseCircle(),
            ]),
          ),
        child,
      ]),
    );
  }
}

class _CloseCircle extends StatelessWidget {
  const _CloseCircle();
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF767680).withValues(alpha: 0.12)),
          child: Icon(CupertinoIcons.xmark, color: context.cSub, size: 14),
        ),
      );
}

/// Grand rond vert avec coche et halo (succès).
class SuccessCircle extends StatelessWidget {
  const SuccessCircle({super.key});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: 104, height: 104,
        decoration: BoxDecoration(shape: BoxShape.circle, color: kSuccess.withValues(alpha: 0.18)),
        alignment: Alignment.center,
        child: Container(
          width: 84, height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: kSuccess,
            boxShadow: [BoxShadow(color: kSuccess.withValues(alpha: 0.35), blurRadius: 24)],
          ),
          child: const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 46),
        ),
      ),
    );
  }
}

Widget _bigButton(String label, Color color, VoidCallback onTap) => SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 15),
        borderRadius: BorderRadius.circular(14),
        color: color,
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );

Widget _textButton(String label, VoidCallback onTap) => CupertinoButton(
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: kPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
    );

Widget _centerTitle(BuildContext context, String title, String sub) => Column(children: [
      Text(title, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: context.cText)),
      const SizedBox(height: 6),
      Text(sub, textAlign: TextAlign.center, style: QText.body.copyWith(fontSize: 17, color: context.cSub)),
    ]);

// ── Carte ajoutée ────────────────────────────────────────────────────────────

/// Renvoie true = « Voir ma carte », false = « Scanner une autre carte ».
Future<bool?> showCardAddedIos(
  BuildContext context, {
  required Map merchant,
  required dynamic design,
  required String userName,
  required bool alreadyMember,
}) {
  HapticFeedback.mediumImpact();
  final name = merchant['business_name'] as String? ?? '';
  final isPoints = (merchant['program_type'] as String? ?? 'stamps') == 'points';
  final req = isPoints ? (merchant['points_required'] as int? ?? 100) : (merchant['stamps_required'] as int? ?? 10);
  final reward = merchant['reward_description'] as String? ?? '';
  final rule = isPoints ? '$req points chez $name' : '$req tampons chez $name';
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SheetFrame(
      child: Column(children: [
        const SizedBox(height: 22),
        const SuccessCircle(),
        const SizedBox(height: 18),
        _centerTitle(
          ctx,
          alreadyMember ? 'Déjà dans tes cartes' : 'Carte ajoutée',
          alreadyMember
              ? 'Tu as déjà la carte $name.'
              : reward.isNotEmpty ? '$rule = $reward.' : 'Ta carte $name est prête.',
        ),
        const SizedBox(height: 20),
        merchantCardFace(merchant: merchant, design: design, userName: userName, count: 0),
        const SizedBox(height: 22),
        _bigButton('Voir ma carte', kPrimary, () => Navigator.pop(ctx, true)),
        const SizedBox(height: 4),
        _textButton('Scanner une autre carte', () => Navigator.pop(ctx, false)),
      ]),
    ),
  );
}

// ── Carte complète (récompense débloquée) ────────────────────────────────────

/// Renvoie true = « Utiliser maintenant », false/null = « Plus tard ».
Future<bool?> showRewardUnlockedIos(
  BuildContext context, {
  required Map merchant,
  required dynamic design,
  required String userName,
}) {
  HapticFeedback.heavyImpact();
  final name = merchant['business_name'] as String? ?? '';
  final isPoints = (merchant['program_type'] as String? ?? 'stamps') == 'points';
  final req = isPoints ? (merchant['points_required'] as int? ?? 100) : (merchant['stamps_required'] as int? ?? 10);
  final reward = merchant['reward_description'] as String? ?? '';
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SheetFrame(
      child: Stack(clipBehavior: Clip.none, children: [
        Column(children: [
          const SizedBox(height: 22),
          const _GiftBadge(),
          const SizedBox(height: 18),
          _centerTitle(ctx, 'Carte complète !',
              reward.isNotEmpty ? 'Ta récompense t\'attend chez $name : $reward.' : 'Ta récompense t\'attend chez $name.'),
          const SizedBox(height: 20),
          merchantCardFace(merchant: merchant, design: design, userName: userName, count: req),
          const SizedBox(height: 22),
          _bigButton('Utiliser maintenant', kGold, () => Navigator.pop(ctx, true)),
          const SizedBox(height: 4),
          _textButton('Plus tard', () => Navigator.pop(ctx, false)),
        ]),
        // Confettis seulement autour du cadeau (jamais sur le texte).
        const Positioned(top: 0, left: 0, right: 0, height: 170, child: IgnorePointer(child: _Confetti())),
      ]),
    ),
  );
}

class _GiftBadge extends StatelessWidget {
  const _GiftBadge();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: 120, height: 120,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(38), color: kGold.withValues(alpha: 0.18)),
        alignment: Alignment.center,
        child: Container(
          width: 98, height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color.lerp(kGold, Colors.white, 0.18)!, kGold],
            ),
            boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.45), blurRadius: 26, offset: const Offset(0, 8))],
          ),
          child: const Icon(CupertinoIcons.gift, color: Colors.white, size: 46),
        ),
      ),
    );
  }
}

/// Petits confettis or et bleu ciel qui tombent une fois.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  final _rnd = Random(7);
  late final List<List<double>> _pieces = List.generate(
      16, (_) => [_rnd.nextDouble(), _rnd.nextDouble() * 0.35, _rnd.nextDouble() * pi, _rnd.nextDouble()]);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<List<double>> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    for (var i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      final x = p[0] * size.width;
      final y = (p[1] + t * 0.6) * size.height;
      final paint = Paint()..color = (i.isEven ? kGold : kBlueLight).withValues(alpha: opacity.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p[2] + t * 4 * (p[3] - 0.5));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -8, 8, 16), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ── QR de la récompense + « Récompense utilisée » ────────────────────────────

Future<void> showRewardQrIos(
  BuildContext context, {
  required Map reward,
  required String merchantName,
  required String userName,
  required VoidCallback onRedeemed,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RewardQrSheetIos(
      reward: reward, merchantName: merchantName, userName: userName, onRedeemed: onRedeemed,
    ),
  );
}

class _RewardQrSheetIos extends StatefulWidget {
  final Map reward;
  final String merchantName;
  final String userName;
  final VoidCallback onRedeemed;
  const _RewardQrSheetIos({required this.reward, required this.merchantName, required this.userName, required this.onRedeemed});

  @override
  State<_RewardQrSheetIos> createState() => _RewardQrSheetIosState();
}

class _RewardQrSheetIosState extends State<_RewardQrSheetIos> {
  String? _token;
  int _timeLeft = 120;
  int _validity = 120;
  bool _loading = true;
  bool _redeemed = false;
  Timer? _timer;
  Timer? _poll;

  String get _rewardId => widget.reward['id'] as String? ?? '';
  Map get _merchant => (widget.reward['merchant'] as Map?) ?? {'business_name': widget.merchantName};
  String get _description => capFirst((_merchant['reward_description'] as String?) ??
      (widget.reward['description'] as String?) ?? 'Récompense');

  @override
  void initState() {
    super.initState();
    _fetch();
    if (QartaDemo.enabled) {
      // Aperçu : le commerçant « valide » la récompense au bout de 7 secondes.
      _poll = Timer(const Duration(seconds: 7), _markRedeemed);
    } else {
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _checkRedeemed());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _token = null; });
    if (QartaDemo.enabled) {
      setState(() { _token = 'demo-reward-$_rewardId'; _timeLeft = _validity = 120; _loading = false; });
      _startTimer();
      return;
    }
    final r = await ApiService.instance.getRewardQR(_rewardId);
    if (!mounted) return;
    if (r.isOk) {
      setState(() {
        _token = r.value['dynamic_token'] as String?;
        _timeLeft = _validity = r.value['expires_in'] as int? ?? 120;
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

  // La récompense disparaît de /rewards/me quand le commerçant l'a validée.
  Future<void> _checkRedeemed() async {
    final r = await ApiService.instance.getMyRewards();
    if (!mounted || r.isErr) return;
    if (!r.value.any((x) => x['id'] == _rewardId)) _markRedeemed();
  }

  void _markRedeemed() {
    if (_redeemed || !mounted) return;
    _poll?.cancel();
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _redeemed = true);
    widget.onRedeemed();
  }

  String get _clock => '${_timeLeft ~/ 60}:${(_timeLeft % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: _description,
      subtitle: _redeemed ? null : widget.merchantName,
      showClose: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        child: _redeemed ? _done(context) : _qr(context),
      ),
    );
  }

  Widget _qr(BuildContext context) {
    return Column(key: const ValueKey('qr'), children: [
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kGold.withValues(alpha: 0.55), width: 2),
        ),
        child: Column(children: [
          _loading || _token == null
              ? const SizedBox(width: 220, height: 220, child: Center(child: CupertinoActivityIndicator()))
              : QrImageView(
                  data: _token!, version: QrVersions.auto, size: 220,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: kNavy),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: kNavy),
                ),
          const SizedBox(height: 10),
          Text('Montre ce code au commerçant', style: QText.body.copyWith(fontSize: 17, color: const Color(0xFF9096A4))),
        ]),
      ),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
            value: _validity == 0 ? 0 : _timeLeft / _validity,
            strokeWidth: 3,
            color: kGold,
            backgroundColor: kGold.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(width: 10),
        Text('Code valable encore', style: QText.body.copyWith(fontSize: 17, color: context.cSub)),
        const SizedBox(width: 8),
        Text(_clock, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.cText,
            fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      const SizedBox(height: 10),
      Text("Ta carte repartira à zéro après l'utilisation.",
          textAlign: TextAlign.center, style: QText.label.copyWith(fontSize: 15, color: context.cSub)),
      const SizedBox(height: 12),
    ]);
  }

  Widget _done(BuildContext context) {
    final name = _merchant['business_name'] as String? ?? widget.merchantName;
    return Column(key: const ValueKey('done'), children: [
      const SizedBox(height: 26),
      const SuccessCircle(),
      const SizedBox(height: 18),
      _centerTitle(context, 'Récompense utilisée', 'Profite bien ! Ta carte $name repart à zéro.'),
      const SizedBox(height: 20),
      merchantCardFace(merchant: _merchant, design: widget.reward['card_design'], userName: widget.userName, count: 0),
      const SizedBox(height: 26),
      _bigButton('Terminé', kPrimary, () => Navigator.pop(context)),
    ]);
  }
}


/// Petite alerte iPhone (titre + message + OK), à la place des bandeaux Android.
Future<void> showIosAlert(BuildContext context, String title, String message) {
  return showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}
