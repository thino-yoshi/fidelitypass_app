import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../client/cards_tab.dart' show LoyaltyCardFace, CardStyle;
import 'notifications_screen.dart';

const double _kMaxContentWidth = 500;
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Fiche détaillée d'un client (v24) — ouverte depuis une ligne d'historique
/// ou la liste clients. Compose les données depuis l'historique des scans,
/// la liste des cartes et le design de carte du commerçant.
class FicheClientScreen extends StatefulWidget {
  final String token;
  final String clientId;
  final String cardId;
  final String clientName;
  final String? clientEmail;
  final String? clientPic;
  final Map merchantInfo;     // business_name, stamps_required, reward_description, logo_url…

  const FicheClientScreen({
    super.key,
    required this.token,
    required this.clientId,
    required this.cardId,
    required this.clientName,
    required this.merchantInfo,
    this.clientEmail,
    this.clientPic,
  });

  @override
  State<FicheClientScreen> createState() => _FicheClientScreenState();
}

class _FicheClientScreenState extends State<FicheClientScreen> {
  bool _loading = true;
  bool _busy = false;                 // action tampon en cours
  List<Map> _scans = [];              // scans de CE client (récents → anciens)
  int _stamps = 0;
  DateTime? _joinDate;
  Map? _cardDesign;                   // récupéré côté commerçant pour l'aperçu
  final _noteCtrl = TextEditingController();
  bool _noteDirty = false;

  int get _required =>
      widget.merchantInfo['stamps_required'] as int? ??
      (_cardDesign?['stamps_required'] as int?) ??
      10;

  @override
  void initState() {
    super.initState();
    _noteCtrl.addListener(() {
      if (!_noteDirty) setState(() => _noteDirty = true);
    });
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.instance.getMerchantScanHistory(),
      ApiService.instance.getMerchantClients(limit: 200),
      ApiService.instance.getMerchantCardDesign(),
    ]);
    if (!mounted) return;

    final histR = results[0] as ApiResult;
    final cliR = results[1] as ApiResult;
    final designR = results[2] as ApiResult;
    if (designR.isOk) _cardDesign = designR.value?['card_design'] as Map?;

    // Scans de ce client uniquement.
    final scans = (histR.isOk ? (histR.value as List) : [])
        .where((s) => (s['client_id'] ?? '').toString() == widget.clientId)
        .map<Map>((s) => Map<String, dynamic>.from(s as Map))
        .toList();

    // Carte de ce client → stamps actuels + date d'inscription + note privée.
    int stamps = 0;
    DateTime? join;
    String note = '';
    if (cliR.isOk) {
      final card = (cliR.value as List).cast<Map>().firstWhere(
            (c) => (c['id'] ?? '').toString() == widget.cardId,
            orElse: () => {},
          );
      if (card.isNotEmpty) {
        stamps = (card['stamps_count'] as int?) ?? 0;
        join = DateTime.tryParse(card['created_at'] as String? ?? '');
        note = card['merchant_note'] as String? ?? '';
      }
    }
    // fallback stamps depuis le scan le plus récent
    if (stamps == 0 && scans.isNotEmpty) {
      stamps = (scans.first['stamps_count'] as int?) ?? 0;
    }

    _noteCtrl.text = note;

    setState(() {
      _scans = scans;
      _stamps = stamps;
      _joinDate = join;
      _noteDirty = false;
      _loading = false;
    });
  }

  // ── Métriques dérivées ──────────────────────────────────────────────────
  int get _visits => _scans.length;
  int get _rewardsCount => _scans.where((s) => s['reward_reached'] == true).length;

  List<DateTime> get _scanDates => _scans
      .map((s) => DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal())
      .whereType<DateTime>()
      .toList();

  DateTime? get _lastVisit => _scanDates.isNotEmpty ? _scanDates.first : null;

  /// Fréquence moyenne (jours entre visites). null si < 2 visites.
  double? get _avgGapDays {
    final d = _scanDates;
    if (d.length < 2) return null;
    final sorted = [...d]..sort();
    var total = 0.0;
    for (var i = 1; i < sorted.length; i++) {
      total += sorted[i].difference(sorted[i - 1]).inHours / 24.0;
    }
    return total / (sorted.length - 1);
  }

  bool get _isActive {
    final lv = _lastVisit;
    if (lv == null) return false;
    return DateTime.now().difference(lv).inDays <= 14;
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _adjust(int delta) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await ApiService.instance.adjustStamp(widget.cardId, delta);
    if (!mounted) return;
    if (r.isOk) {
      final reached = r.value['reward_reached'] == true;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: reached ? kGold : kSuccess,
        content: Text(reached
            ? '🎉 Récompense débloquée pour ${widget.clientName} !'
            : (delta > 0 ? '+$delta tampon${delta > 1 ? 's' : ''} ajouté${delta > 1 ? 's' : ''}' : 'Dernier tampon annulé')),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kError, content: Text(r.error ?? 'Erreur')));
    }
    setState(() => _busy = false);
  }

  Future<void> _saveNote() async {
    final r = await ApiService.instance.saveClientNote(widget.cardId, _noteCtrl.text.trim());
    if (!mounted) return;
    if (r.isOk) {
      setState(() => _noteDirty = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kSuccess, content: Text('Note enregistrée')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kError, content: Text(r.error ?? 'Erreur')));
    }
  }

  void _openStampSheet() {
    int qty = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: ctx.cSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ctx.cBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Text('Ajouter des tampons', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ctx.cText)),
            const SizedBox(height: 4),
            Text('${widget.clientName} · $_stamps/$_required actuellement',
                style: TextStyle(fontSize: 12, color: ctx.cSub)),
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _stepBtn(ctx, '−', () { if (qty > 1) setSheet(() => qty--); }),
              SizedBox(width: 70, child: Text('$qty', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: ctx.cText))),
              _stepBtn(ctx, '+', () { if (qty < 20) setSheet(() => qty++); }),
            ]),
            const SizedBox(height: 4),
            Text('tampon(s) à ajouter', style: TextStyle(fontSize: 11, color: ctx.cSub)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [1, 2, 3, 5].map((n) =>
                GestureDetector(
                  onTap: () => setSheet(() => qty = n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: qty == n ? kPrimary : ctx.cFill,
                      borderRadius: BorderRadius.circular(20)),
                    child: Text('+$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: qty == n ? Colors.white : ctx.cSub)),
                  ),
                )).toList()),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () { Navigator.pop(ctx); _adjust(qty); },
              child: const Text("Confirmer l'ajout", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler', style: TextStyle(color: ctx.cSub))),
          ]),
        ),
      ),
    );
  }

  Widget _stepBtn(BuildContext ctx, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52, height: 52, alignment: Alignment.center,
          decoration: BoxDecoration(color: ctx.cFill, borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ctx.cText)),
        ),
      );

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _header(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.of(context).padding.bottom),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _statsStrip(),
                        const SizedBox(height: 12),
                        _freqCard(),
                        const SizedBox(height: 12),
                        _progressCard(),
                        const SizedBox(height: 16),
                        _sectionTitle('Aperçu carte (vue client)'),
                        const SizedBox(height: 8),
                        _cardPreview(),
                        const SizedBox(height: 16),
                        _noteSection(),
                        const SizedBox(height: 16),
                        _sectionTitle('Activité récente'),
                        const SizedBox(height: 8),
                        _activity(),
                        const SizedBox(height: 18),
                        _actions(),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _header() {
    final join = _joinDate != null
        ? 'Client depuis le ${_joinDate!.day} ${_months[_joinDate!.month - 1]} ${_joinDate!.year}'
        : 'Client fidèle';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 22),
      decoration: const BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36, alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new, size: 15, color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          width: 64, height: 64, alignment: Alignment.center,
          decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(20)),
          child: (widget.clientPic != null && widget.clientPic!.isNotEmpty)
              ? ClipRRect(borderRadius: BorderRadius.circular(20),
                  child: Image.network(widget.clientPic!, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(_initials(widget.clientName),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))))
              : Text(_initials(widget.clientName),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        Text(widget.clientName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(join, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5)),
      ]),
    );
  }

  Widget _statsStrip() {
    Widget card(String val, String label, Color valColor) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: context.cSurface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cBorder)),
            child: Column(children: [
              Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: valColor)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10.5, color: context.cSub, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Row(children: [
      card('$_visits', 'Visites', context.cText),
      card('$_stamps', 'Tampons', kBlueLight),
      card('$_rewardsCount', 'Récomp.', kGold),
    ]);
  }

  Widget _freqCard() {
    final gap = _avgGapDays;
    final lv = _lastVisit;
    String sub;
    if (gap != null) {
      sub = 'Revient en moyenne tous les ${gap.round()} jour${gap.round() > 1 ? 's' : ''}';
    } else {
      sub = 'Pas encore assez de visites pour estimer';
    }
    String last = lv != null ? ' · Dernier passage : ${_relDay(lv)}' : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 38, height: 38, alignment: Alignment.center,
          decoration: BoxDecoration(color: kBlueLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.access_time_rounded, size: 19, color: kBlueLight),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Fréquence de visite', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('$sub$last', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5, height: 1.3)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: (_isActive ? kSuccess : context.cSub).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20)),
          child: Text(_isActive ? 'Actif' : 'Inactif',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _isActive ? kSuccess : Colors.white70)),
        ),
      ]),
    );
  }

  Widget _progressCard() {
    final remaining = (_required - _stamps).clamp(0, _required);
    final pct = _required > 0 ? (_stamps / _required).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cSurface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progression carte', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText)),
          Text('$_stamps / $_required', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: kPrimary)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: List.generate(_required, (i) {
          final done = i < _stamps;
          return Container(
            width: 26, height: 26, alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? kPrimary : context.cFill,
              border: Border.all(color: done ? kPrimary : context.cBorder, width: 1.5)),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${i + 1}', style: TextStyle(fontSize: 10, color: context.cSub, fontWeight: FontWeight.w600)),
          );
        })),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(value: pct, minHeight: 6,
              backgroundColor: context.cFill, valueColor: const AlwaysStoppedAnimation(kPrimary)),
        ),
        const SizedBox(height: 6),
        Text(remaining == 0
            ? '🎉 Récompense disponible !'
            : 'Encore $remaining tampon${remaining > 1 ? 's' : ''} pour 1 récompense offerte',
            style: TextStyle(fontSize: 10.5, color: context.cSub)),
      ]),
    );
  }

  Widget _cardPreview() {
    final card = {
      'stamps_count': _stamps,
      'card_design': _cardDesign,
      'merchants': widget.merchantInfo,
    };
    final style = CardStyle.fromDesign(
      _cardDesign,
      merchantLogoUrl: widget.merchantInfo['logo_url'] as String?,
      fallbackColor: kPrimary,
    );
    return LoyaltyCardFace(card: card, style: style, userName: widget.clientName);
  }

  Widget _noteSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionTitle('Note privée'),
        if (_noteDirty)
          GestureDetector(onTap: _saveNote,
              child: const Text('Enregistrer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimary))),
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: context.cSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller: _noteCtrl,
          maxLines: 3,
          style: TextStyle(fontSize: 13, color: context.cText),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Ex : client végane, vient le vendredi midi, allergique aux arachides…',
            hintStyle: TextStyle(fontSize: 12, color: context.cSub, height: 1.4),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text('Visible uniquement par toi · synchronisée',
          style: TextStyle(fontSize: 9.5, color: context.cSub)),
    ]);
  }

  Widget _activity() {
    if (_scans.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: context.cSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder)),
        child: Text('Aucune activité', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.cSub)),
      );
    }
    final items = <Widget>[];
    for (var i = 0; i < _scans.length && i < 12; i++) {
      final s = _scans[i];
      final reward = s['reward_reached'] == true;
      final manual = s['manual'] == true;
      final cnt = s['stamps_count'] as int? ?? 0;
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal();
      final color = reward ? kGold : kPrimary;
      final label = reward
          ? 'Récompense débloquée'
          : '${manual ? 'Tampon (manuel)' : 'Tampon ajouté'} · $cnt/$_required';
      items.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: context.cText))),
          Text(t != null ? '${_relDay(t)} ${_hhmm(t)}' : '',
              style: TextStyle(fontSize: 10.5, color: context.cSub)),
        ]),
      ));
      if (i < _scans.length - 1 && i < 11) {
        items.add(Divider(height: 1, color: context.cBorder));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: context.cSurface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder)),
      child: Column(children: items),
    );
  }

  Widget _actions() {
    return Column(children: [
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: _busy ? null : _openStampSheet,
        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
        label: const Text('Ajouter des tampons manuellement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: kError, side: const BorderSide(color: kError),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: (_busy || _stamps == 0) ? null : () => _adjust(-1),
        icon: const Icon(Icons.undo_rounded, size: 17),
        label: const Text('Annuler le dernier tampon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      )),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: context.cText, side: BorderSide(color: context.cBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: widget.merchantInfo))),
        icon: const Icon(Icons.notifications_active_outlined, size: 17, color: kGold),
        label: const Text('Envoyer une notification ciblée', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      )),
    ]);
  }

  Widget _sectionTitle(String t) =>
      Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cText));

  // ── Helpers date ─────────────────────────────────────────────────────────
  String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _relDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    if (diff == 2) return 'Avant-hier';
    return '${d.day} ${_months[d.month - 1]}';
  }
}
