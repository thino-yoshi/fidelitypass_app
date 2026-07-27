import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../config/api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2C7BE5);
const _kNavy      = Color(0xFF0B1220);
const _kSuccess   = Color(0xFF27AE60);
const _kGold      = Color(0xFFF59E0B);
const _kError     = Color(0xFFE24B4A);
const double _kMaxContentWidth = 500;

class NotificationsScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const NotificationsScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _Tpl {
  final String key, emoji, title, desc, msgTitle, msgBody;
  const _Tpl(this.key, this.emoji, this.title, this.desc, this.msgTitle, this.msgBody);
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _templates = [
    _Tpl('promo', '🏷️', 'Offre spéciale', "Annonce une promo flash pour aujourd'hui",
        'Offre spéciale ce soir !', '-20% sur tout ce soir de 18h à 22h. Venez nous voir !'),
    _Tpl('rappel', '✅', 'Rappel tampon', 'Rappelle aux clients proches de la récompense',
        'Plus que quelques tampons !', 'Vous êtes tout proche de votre récompense. Passez la chercher !'),
    _Tpl('merci', '⭐', 'Merci & fidélité', 'Remercie tes clients fidèles',
        'Merci de votre fidélité 🙏', 'Un grand merci ! Une petite surprise vous attend à votre prochaine visite.'),
    _Tpl('libre', '💬', 'Message libre', 'Écris ton propre message', '', ''),
  ];

  String _tpl = 'promo';
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  String _audience = 'tous';     // 'tous' | 'proches' | 'inactifs'
  String _when = 'now';          // 'now' | 'plan'
  DateTime? _scheduledAt;
  bool _sending = false;

  List<dynamic> _clients = [];
  List<dynamic> _scheduled = [];
  List<dynamic> _history = [];
  int _required = 10;

  @override
  void initState() {
    super.initState();
    _required = widget.merchantInfo?['stamps_required'] as int? ?? 10;
    _applyTemplate('promo');
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    AppLogger.merchant('NotificationsScreen → chargement clients + planifiées...');
    final c = await ApiService.instance.getMerchantClients(limit: 200);
    if (mounted && c.isOk) {
      AppLogger.merchant('NotificationsScreen → ${c.value.length} client(s) chargé(s)');
      setState(() => _clients = c.value);
    }
    await _loadScheduled();
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/notifications/history'),
          headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? widget.token}'});
      if (res.statusCode == 200 && mounted) {
        setState(() => _history = jsonDecode(res.body) as List);
      }
    } catch (_) {}
  }

  Future<void> _loadScheduled() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/notifications/scheduled'),
          headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? widget.token}'});
      if (res.statusCode == 200 && mounted) {
        setState(() => _scheduled = jsonDecode(res.body) as List);
      }
    } catch (_) {}
  }

  void _applyTemplate(String key) {
    final t = _templates.firstWhere((e) => e.key == key);
    setState(() {
      _tpl = key;
      if (key != 'libre') {
        _titleCtrl.text = t.msgTitle;
        _bodyCtrl.text = t.msgBody;
      }
    });
  }

  // ── Compteurs d'audience ────────────────────────────────────────────────────
  int get _countTous => _clients.length;
  int get _countProches => _clients.where((c) {
    final s = (c['stamps_count'] as int?) ?? 0;
    return (_required - s) <= 2 && s < _required;
  }).length;

  // ── Envoi ───────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _toast('Titre et message requis', err: true); return;
    }
    if (_when == 'plan' && _scheduledAt == null) {
      _toast("Choisis une date d'envoi", err: true); return;
    }
    AppLogger.merchant('NotificationsScreen → envoi notif: template=$_tpl, audience=$_audience, when=$_when, titre="$title"');
    setState(() => _sending = true);
    final headers = {
      'Authorization': 'Bearer ${AuthService.currentToken ?? widget.token}',
      'Content-Type': 'application/json',
    };
    try {
      http.Response res;
      if (_when == 'plan') {
        final filterType = _audience == 'proches' ? 'stamps' : _audience == 'inactifs' ? 'inactive' : 'broadcast';
        final filterVal  = _audience == 'proches' ? 2 : _audience == 'inactifs' ? 7 : null;
        res = await http.post(Uri.parse('$apiUrl/notifications/schedule'), headers: headers,
            body: jsonEncode({
              'title': title, 'message': body,
              'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
              'filter_type': filterType, 'filter_value': filterVal,
            }));
      } else if (_audience == 'tous') {
        res = await http.post(Uri.parse('$apiUrl/notifications/send'), headers: headers,
            body: jsonEncode({'title': title, 'message': body}));
      } else {
        final Map<String, dynamic> payload = {'title': title, 'message': body};
        if (_audience == 'proches') payload['max_stamps_remaining'] = 2;
        if (_audience == 'inactifs') payload['inactive_days'] = 7;
        res = await http.post(Uri.parse('$apiUrl/notifications/send-targeted'), headers: headers,
            body: jsonEncode(payload));
      }
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = _when == 'plan' ? 'Notification planifiée ✓' : (data['message'] ?? 'Envoyée ✓').toString();
        AppLogger.merchant('NotificationsScreen → envoi ✓ : $msg');
        _toast(msg);
        setState(() { _when = 'now'; _scheduledAt = null; });
        _loadScheduled();
      } else {
        AppLogger.error('NotificationsScreen → envoi erreur HTTP ${res.statusCode}: ${res.body}');
        _toast(_errOf(res), err: true);
      }
    } catch (e) {
      AppLogger.error('NotificationsScreen → envoi exception: $e');
      _toast('Erreur réseau', err: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _cancelScheduled(String id) async {
    await http.delete(Uri.parse('$apiUrl/notifications/scheduled/$id'),
        headers: {'Authorization': 'Bearer ${AuthService.currentToken ?? widget.token}'});
    _loadScheduled();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(hours: 1)),
        firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (t == null || !mounted) return;
    setState(() {
      _when = 'plan';
      _scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  String _errOf(http.Response res) {
    try { return (jsonDecode(res.body)['detail'] ?? 'Erreur ${res.statusCode}').toString(); }
    catch (_) { return 'Erreur ${res.statusCode}'; }
  }

  void _toast(String m, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m), behavior: SnackBarBehavior.floating,
      backgroundColor: err ? _kError : _kSuccess, duration: const Duration(seconds: 2)));
  }

  String get _initials {
    final n = (widget.merchantInfo?['business_name'] as String? ?? 'Q').trim();
    return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n.toUpperCase();
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: Column(children: [
        _headerBar(),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              _preview(),
              const SizedBox(height: 16),
              _sectionTitle('Choisir un modèle'),
              const SizedBox(height: 8),
              ..._templates.map(_templateCard),
              const SizedBox(height: 14),
              _sectionTitle('Message'),
              const SizedBox(height: 8),
              _field(_titleCtrl, 'Titre', 60),
              const SizedBox(height: 8),
              _field(_bodyCtrl, 'Message', 160, lines: 3),
              const SizedBox(height: 16),
              _sectionTitle('Envoyer à'),
              const SizedBox(height: 8),
              _audienceRow(),
              const SizedBox(height: 16),
              _sectionTitle('Quand envoyer ?'),
              const SizedBox(height: 8),
              _whenRow(),
              const SizedBox(height: 16),
              _sendButton(),
              if (_scheduled.isNotEmpty) ...[
                const SizedBox(height: 22),
                _sectionTitle('Notifications planifiées'),
                const SizedBox(height: 8),
                ..._scheduled.map(_scheduledItem),
              ],
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 22),
                _sectionTitle('Historique des envois'),
                const SizedBox(height: 8),
                ..._history.map(_historyItem),
              ],
            ],
          ),
        ))),
      ]),
    );
  }

  Widget _headerBar() => Container(
    color: _kNavy,
    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 12),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
              child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 22)),
        ),
        const SizedBox(width: 12),
        const Text('Notification push', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    )),
  );

  Widget _sectionTitle(String t) => Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.cText));

  // Aperçu live
  Widget _preview() {
    final title = _titleCtrl.text.trim().isEmpty ? 'Titre de la notification' : _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim().isEmpty ? 'Votre message apparaîtra ici…' : _bodyCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('APERÇU SUR MOBILE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(9)),
                child: Center(child: Text(_initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 2),
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), height: 1.4)),
              const SizedBox(height: 3),
              Text("À l'instant · ${widget.merchantInfo?['business_name'] ?? ''}", style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3))),
            ])),
          ]),
        ),
      ]),
    );
  }

  Widget _templateCard(_Tpl t) {
    final sel = _tpl == t.key;
    return GestureDetector(
      onTap: () => _applyTemplate(t.key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: sel ? _kPrimary.withValues(alpha: 0.08) : context.cSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? _kPrimary : context.cBorder, width: sel ? 1.5 : 1),
        ),
        child: Row(children: [
          Text(t.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
            const SizedBox(height: 1),
            Text(t.desc, style: TextStyle(fontSize: 11, color: context.cSub)),
          ])),
          if (sel) const Icon(Icons.check_circle_rounded, color: _kPrimary, size: 18),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, int max, {int lines = 1}) {
    return Container(
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.cBorder)),
      child: TextField(
        controller: c, maxLength: max, maxLines: lines, minLines: lines,
        onChanged: (_) => setState(() {}), // refresh preview
        style: TextStyle(fontSize: 13, color: context.cText),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(fontSize: 13, color: context.cSub),
          counterText: '', border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _audienceRow() {
    Widget pill(String key, String label) {
      final sel = _audience == key;
      return Expanded(child: GestureDetector(
        onTap: () => setState(() => _audience = key),
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? _kPrimary : context.cSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? _kPrimary : context.cBorder),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.2, color: sel ? Colors.white : context.cSub)),
        ),
      ));
    }
    return Row(children: [
      pill('tous', 'Tous\n($_countTous)'),
      pill('proches', 'Proches\nrécompense ($_countProches)'),
      pill('inactifs', 'Inactifs\n+7j'),
    ]);
  }

  Widget _whenRow() {
    Widget btn({required bool active, required String label, IconData? icon, required VoidCallback onTap}) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _kPrimary : context.cSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _kPrimary : context.cBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 14, color: active ? Colors.white : context.cSub), const SizedBox(width: 6)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : context.cText))),
          ]),
        ),
      ),
    );
    return Row(children: [
      btn(active: _when == 'now', label: 'Maintenant', onTap: () => setState(() { _when = 'now'; _scheduledAt = null; })),
      btn(active: _when == 'plan', icon: Icons.calendar_today_rounded,
          label: _scheduledAt == null ? 'Planifier' : _fmt(_scheduledAt!), onTap: _pickDateTime),
    ]);
  }

  Widget _sendButton() {
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _sending ? null : _send,
      icon: _sending
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.send_rounded, size: 16),
      label: Text(_sending ? 'Envoi…' : (_when == 'plan' ? 'Planifier la notification' : 'Envoyer la notification'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _when == 'plan' ? _kGold : _kSuccess, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ));
  }

  Widget _scheduledItem(dynamic item) {
    final id = item['id'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.cBorder)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.schedule_rounded, color: _kGold, size: 18)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
          const SizedBox(height: 1),
          Text(_fmt(DateTime.tryParse(item['scheduled_at'] as String? ?? '')?.toLocal() ?? DateTime.now()),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kGold)),
        ])),
        GestureDetector(
          onTap: () => _cancelScheduled(id),
          child: Container(padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 18, color: context.cSub)),
        ),
      ]),
    );
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} à ${two(d.hour)}h${two(d.minute)}';
  }

  Widget _historyItem(dynamic item) {
    final sentAt  = DateTime.tryParse(item['sent_at'] as String? ?? '')?.toLocal();
    final sent    = (item['sent_count']   as int?) ?? 0;
    final opened  = (item['opened_count'] as int?) ?? 0;
    final openPct = sent > 0 ? (opened / sent * 100).round() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.cBorder)),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_outline_rounded, color: _kPrimary, size: 18)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
          const SizedBox(height: 2),
          Text(sentAt != null ? _fmt(sentAt) : '',
              style: TextStyle(fontSize: 10, color: context.cSub)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _kSuccess.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$openPct% ouverts',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSuccess)),
        ),
      ]),
    );
  }
}
