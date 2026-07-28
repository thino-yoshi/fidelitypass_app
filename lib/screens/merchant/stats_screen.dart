import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import 'notifications_screen.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2C7BE5);
const _kBlueLight = Color(0xFF4A9EFF);
const _kNavy      = Color(0xFF0B1220);
const _kSuccess   = Color(0xFF27AE60);
const _kGold      = Color(0xFFF59E0B);
const _kError     = Color(0xFFE24B4A);
const double _kMaxContentWidth = 500;

class StatsScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  final Map? initialStats;
  final List<dynamic> initialDaily;
  final List<dynamic> initialHistory;
  final List<dynamic> initialClients;
  const StatsScreen({
    super.key,
    required this.token,
    this.merchantInfo,
    this.initialStats,
    this.initialDaily    = const [],
    this.initialHistory  = const [],
    this.initialClients  = const [],
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map? _stats;
  List<dynamic> _daily = [];
  List<dynamic> _history = [];
  List<dynamic> _clients = [];
  bool _loading = true;
  String _fidPeriod = '7j'; // '7j' | '30j'

  int get _required => widget.merchantInfo?['stamps_required'] as int? ?? 10;

  @override
  void initState() {
    super.initState();
    if (widget.initialStats != null) {
      _stats   = widget.initialStats;
      _daily   = List<dynamic>.from(widget.initialDaily);
      _history = List<dynamic>.from(widget.initialHistory);
      _clients = List<dynamic>.from(widget.initialClients);
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    AppLogger.merchant('StatsScreen → chargement stats...');
    final api = ApiService.instance;
    final s = await api.getMerchantStats();
    final d = await api.getDailyStats();
    final h = await api.getMerchantScanHistory();
    final c = await api.getMerchantClients(limit: 200);
    if (!mounted) return;
    if (s.isOk) {
      AppLogger.merchant('StatsScreen → stats globales: clients=${s.value['total_clients']}, scans=${s.value['total_scans']}, récompenses=${s.value['total_rewards']}');
    } else {
      AppLogger.error('StatsScreen → getMerchantStats erreur: ${s.error}');
    }
    AppLogger.merchant('StatsScreen → daily: ${d.isOk ? d.value.length : 0} jours, historique: ${h.isOk ? h.value.length : 0} scans, clients: ${c.isOk ? c.value.length : 0}');
    setState(() {
      _stats   = s.isOk ? s.value : null;
      _daily   = d.isOk ? d.value : [];
      _history = h.isOk ? h.value : [];
      _clients = c.isOk ? c.value : [];
      _loading = false;
    });
  }

  // ── Calculs ───────────────────────────────────────────────────────────────
  Iterable<dynamic> _histWithin(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _history.where((s) {
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
      return t != null && t.isAfter(cutoff);
    });
  }

  int get _membresActifs {
    final ids = <String>{};
    for (final s in _histWithin(30)) {
      final id = (s['client_id'] ?? '').toString();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.length;
  }

  int get _retentionPct {
    final counts = <String, int>{};
    for (final s in _histWithin(30)) {
      final id = (s['client_id'] ?? '').toString();
      if (id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return 0;
    final returning = counts.values.where((c) => c >= 2).length;
    return (returning / counts.length * 100).round();
  }

  /// Heures creuses : pour chacun des 7 derniers jours, identifie la tranche
  /// horaire (8h-12h / 12h-16h / 16h-20h) avec le moins de visites.
  List<Map<String, dynamic>> _creux7Days() {
    const dayNames   = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const monthNames = ['jan', 'fév', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    final slots = [
      {'label': '8h–12h',  'from': 8,  'to': 12},
      {'label': '12h–16h', 'from': 12, 'to': 16},
      {'label': '16h–20h', 'from': 16, 'to': 20},
    ];

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <Map<String, dynamic>>[];

    for (int d = 0; d < 7; d++) {
      final day = today.subtract(Duration(days: d));
      final label = d == 0 ? "Aujourd'hui"
                  : d == 1 ? 'Hier'
                  : '${dayNames[day.weekday]} ${day.day} ${monthNames[day.month - 1]}';

      // Scans tombant sur ce jour calendaire
      final dayScans = _history.where((s) {
        final t = DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal();
        return t != null && DateTime(t.year, t.month, t.day) == day;
      }).toList();

      // Comptage par tranche
      final counts = <String, int>{'8h–12h': 0, '12h–16h': 0, '16h–20h': 0};
      for (final s in dayScans) {
        final t = DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal();
        if (t == null) continue;
        final h = t.hour;
        for (final slot in slots) {
          if (h >= (slot['from'] as int) && h < (slot['to'] as int)) {
            counts[slot['label'] as String] = (counts[slot['label'] as String] ?? 0) + 1;
            break;
          }
        }
      }

      // Tranche la plus calme (en cas d'égalité, prend la première)
      final quietest = counts.entries.reduce((a, b) => a.value <= b.value ? a : b);

      result.add({
        'dayLabel':  label,
        'slotLabel': quietest.key,
        'count':     quietest.value,
        'total':     dayScans.length,
      });
    }
    return result;
  }

  /// Indice de fidélisation par jour (0-100) = activité normalisée.
  List<int> _fidSeries(int days) {
    final src = _daily.length >= days ? _daily.sublist(_daily.length - days) : _daily;
    return src.map<int>((d) {
      final scans = (d['scans'] as int?) ?? 0;
      final rew   = (d['rewards'] as int?) ?? 0;
      return (scans * 6 + rew * 20).clamp(0, 100);
    }).toList();
  }

  int get _fidScore {
    final s = _fidSeries(int.parse(_fidPeriod.replaceAll('j', '')));
    if (s.isEmpty) return 0;
    // moyenne des 3 derniers points (lissage)
    final tail = s.length >= 3 ? s.sublist(s.length - 3) : s;
    return (tail.reduce((a, b) => a + b) / tail.length).round();
  }

  int get _fidTrend {
    final s = _fidSeries(int.parse(_fidPeriod.replaceAll('j', '')));
    if (s.length < 2) return 0;
    return s.last - s.first;
  }

  int get _prochesRecompense {
    final seuil = (_required - 2).clamp(1, _required);
    return _clients.where((c) {
      final st = (c['stamps_count'] as int?) ?? 0;
      return st >= seuil && st < _required;
    }).length;
  }

  int get _inactifs {
    final activeIds = <String>{};
    for (final s in _histWithin(7)) {
      final id = (s['client_id'] ?? '').toString();
      if (id.isNotEmpty) activeIds.add(id);
    }
    int n = 0;
    for (final c in _clients) {
      final cid = (c['client_id'] ?? c['client']?['id'] ?? '').toString();
      if (cid.isNotEmpty && !activeIds.contains(cid)) n++;
    }
    return n;
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: Column(children: [
        _header(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.of(context).padding.bottom),
                    children: [
                      _overviewCard(),
                      const SizedBox(height: 10),
                      _activityCard(),
                      const SizedBox(height: 10),
                      _heuresCreusesCard(),
                      const SizedBox(height: 10),
                      _fidelityCard(),
                      const SizedBox(height: 10),
                      _prochesCard(),
                      const SizedBox(height: 10),
                      _inactifsCard(),
                    ],
                  ),
                )),
        ),
      ]),
    );
  }

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
          const Text('Statistiques', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      )),
    );
  }

  // ── Vue d'ensemble (carte navy) ─────────────────────────────────────────────
  Widget _overviewCard() {
    final visites = _stats?['total_scans'] as int? ?? 0;
    final clients = _stats?['total_clients'] as int? ?? 0;
    final actifs  = _membresActifs;
    final ret     = _retentionPct;

    Widget kpi(String val, String label, {Border? border}) => Expanded(
      child: Container(
        decoration: BoxDecoration(border: border),
        child: Column(children: [
          Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.5))),
        ]),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A3A6E), Color(0xFF0F2044)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("VUE D'ENSEMBLE · 30 DERNIERS JOURS",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 0.7)),
        const SizedBox(height: 12),
        Row(children: [
          kpi('$visites', 'Total visites'),
          kpi('$clients', 'Clients', border: Border(
            left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
          kpi('$actifs', 'Membres actifs'),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Taux de rétention des membres', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4))),
          Text('$ret% reviennent', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: ret / 100, minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(_kBlueLight)),
        ),
      ]),
    );
  }

  // ── Activité moyenne (vraies métriques, remplace le ROI achats) ─────────────
  Widget _activityCard() {
    final visites = _stats?['total_scans'] as int? ?? 0;
    final clients = _stats?['total_clients'] as int? ?? 1;
    // Tampons réellement distribués sur 30 jours (cumul depuis le daily, pas le
    // total_stamps actuel qui se remet à zéro à chaque carte complétée).
    final tampons30j = _daily.fold<int>(0, (s, d) => s + ((d['scans'] as int?) ?? 0));
    final recompenses = _stats?['total_rewards'] as int? ?? 0;
    final visitesParMembre = clients > 0 ? (visites / clients) : 0;

    Widget m(String val, String label, {Border? border}) => Expanded(
      child: Container(
        decoration: BoxDecoration(border: border),
        child: Column(children: [
          Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kSuccess)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, color: context.cSub, height: 1.3)),
        ]),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.insights_rounded, color: _kSuccess, size: 15),
          const SizedBox(width: 6),
          Text('Activité de votre programme', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.cText)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          m(visitesParMembre.toStringAsFixed(1), 'visites par membre'),
          m('$tampons30j', 'tampons sur 30j', border: Border(
            left: BorderSide(color: context.cBorder), right: BorderSide(color: context.cBorder))),
          m('$recompenses', 'récompenses gagnées'),
        ]),
      ]),
    );
  }

  // ── Heures creuses – liste 7 jours ─────────────────────────────────────────
  Widget _heuresCreusesCard() {
    final days = _creux7Days();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Heures creuses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('7 derniers jours', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Créneau le moins actif chaque jour', style: TextStyle(fontSize: 9, color: context.cSub)),
        const SizedBox(height: 12),
        ...days.map(_creuxRow),
      ]),
    );
  }

  Widget _creuxRow(Map<String, dynamic> d) {
    final count    = d['count'] as int;
    final total    = d['total'] as int;
    final isEmpty  = count == 0;
    final iconColor = isEmpty ? _kGold : _kPrimary;
    final iconBg    = isEmpty ? const Color(0xFFFFF3CD) : const Color(0xFFE8F1FD);
    final sub = isEmpty
        ? '${d['slotLabel']} · aucune visite'
        : '${d['slotLabel']} · $count visite${count > 1 ? 's' : ''} ($total au total)';

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: context.cBg,
        border: Border.all(color: context.cBorder),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(Icons.schedule_rounded, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d['dayLabel'] as String,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.cText)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 10, color: context.cSub)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: widget.merchantInfo))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: context.cBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Relancer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cText)),
          ),
        ),
      ]),
    );
  }

  // ── Indice de fidélisation ──────────────────────────────────────────────────
  Widget _fidelityCard() {
    final n = int.parse(_fidPeriod.replaceAll('j', ''));
    final series = _fidSeries(n);
    final score = _fidScore;
    final trend = _fidTrend;

    Widget pBtn(String key, String label) {
      final active = _fidPeriod == key;
      return GestureDetector(
        onTap: () => setState(() => _fidPeriod = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _kPrimary : context.cBorder)),
          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: active ? Colors.white : context.cSub)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('Évolution de la fidélisation', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText))),
          Row(children: [pBtn('7j', '7j'), const SizedBox(width: 4), pBtn('30j', 'Mois')]),
        ]),
        const SizedBox(height: 4),
        Text('Score combinant tampons, récompenses et activité', style: TextStyle(fontSize: 9, color: context.cSub)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$score', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: context.cText, height: 1)),
          Text('/100', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.cSub)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (trend >= 0 ? _kSuccess : _kError).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('${trend >= 0 ? "↑ +" : "↓ "}$trend sur la période',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: trend >= 0 ? _kSuccess : _kError)),
          ),
        ]),
        const SizedBox(height: 12),
        // Courbe (sparkline)
        SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: _LinePainter(series))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _showExplain,
          icon: const Icon(Icons.help_outline_rounded, size: 14, color: _kPrimary),
          label: const Text('Comprendre ce graphique', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.cBorder), backgroundColor: context.cBg,
            padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        )),
      ]),
    );
  }

  void _showExplain() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: context.cSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(22, 14, 22, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text("L'indice de fidélisation", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.cText)),
          const SizedBox(height: 10),
          Text(
            "C'est un score de 0 à 100 qui résume la santé de votre programme jour par jour. "
            "Il combine le nombre de tampons distribués, les récompenses débloquées et l'activité.\n\n"
            "• Score qui monte → vos clients sont de plus en plus engagés.\n"
            "• Score qui baisse → moins de passages, c'est le moment de relancer (push, offre).\n\n"
            "Utilisez la tendance pour voir si vos actions portent leurs fruits.",
            style: TextStyle(fontSize: 13, color: context.cSub, height: 1.5),
          ),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            child: const Text("J'ai compris", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          )),
        ]),
      ),
    );
  }

  // ── Lignes résumées : proches récompense / inactifs ─────────────────────────
  Widget _summaryRow({required IconData icon, required Color iconColor, required Color iconBg,
      required String countText, required Color countColor, required String label, required String sub,
      required String btn, required Color btnBg, required Color btnText, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText, height: 1.35), children: [
            TextSpan(text: countText, style: TextStyle(color: countColor)),
            TextSpan(text: ' $label'),
          ])),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 10, color: context.cSub)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: btnBg, borderRadius: BorderRadius.circular(9), border: btnBg == context.cBg ? Border.all(color: context.cBorder) : null),
            child: Text(btn, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: btnText)),
          ),
        ),
      ]),
    );
  }

  Widget _prochesCard() {
    final n = _prochesRecompense;
    return _summaryRow(
      icon: Icons.star_rounded, iconColor: _kGold, iconBg: const Color(0xFFFEF3C7),
      countText: '$n client${n > 1 ? "s" : ""}', countColor: _kGold,
      label: n > 1 ? 'sont proches de la récompense' : 'est proche de la récompense',
      sub: '≥ ${(_required - 2).clamp(1, _required)}/$_required tampons · prêts à être relancés',
      btn: 'Notifier', btnBg: _kGold, btnText: Colors.white,
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: widget.merchantInfo))),
    );
  }

  Widget _inactifsCard() {
    final n = _inactifs;
    return _summaryRow(
      icon: Icons.history_toggle_off_rounded, iconColor: _kError, iconBg: const Color(0xFFFDE8E8),
      countText: '$n client${n > 1 ? "s" : ""}', countColor: _kError,
      label: n > 1 ? 'inactifs depuis +7 jours' : 'inactif depuis +7 jours',
      sub: 'aucune visite récente · à reconquérir',
      btn: 'Relancer', btnBg: context.cBg, btnText: context.cText,
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: widget.merchantInfo))),
    );
  }
}

// ─── Sparkline (courbe lissée de l'indice) ──────────────────────────────────
class _LinePainter extends CustomPainter {
  final List<int> data;
  _LinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    const maxV = 100.0;
    final dx = size.width / (data.length - 1);
    Offset pt(int i) => Offset(i * dx, size.height - (data[i] / maxV) * size.height);

    // Aire sous la courbe
    final fill = Path()..moveTo(0, size.height);
    for (int i = 0; i < data.length; i++) { fill.lineTo(pt(i).dx, pt(i).dy); }
    fill..lineTo(size.width, size.height)..close();
    canvas.drawPath(fill, Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x332C7BE5), Color(0x002C7BE5)]).createShader(Offset.zero & size));

    // Ligne
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < data.length; i++) {
      final p0 = pt(i - 1), p1 = pt(i);
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      line.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      line.quadraticBezierTo(p1.dx, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(line, Paint()
      ..color = _kPrimary ..style = PaintingStyle.stroke ..strokeWidth = 2.5 ..strokeCap = StrokeCap.round);

    // Point final
    canvas.drawCircle(pt(data.length - 1), 3.5, Paint()..color = _kPrimary);
    canvas.drawCircle(pt(data.length - 1), 3.5, Paint()..color = Colors.white ..style = PaintingStyle.stroke ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.data != data;
}
