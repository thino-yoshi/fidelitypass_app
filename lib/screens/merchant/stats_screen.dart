import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../utils/platform_route.dart';
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

  /// Top 3 créneaux les plus calmes sur les 7 derniers jours (toutes combinaisons jour × tranche).
  List<Map<String, dynamic>> _top3Creux() {
    const dayNames   = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const monthNames = ['jan', 'fév', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    final slotDefs = [
      {'label': '8h–12h',  'from': 8,  'to': 12},
      {'label': '12h–16h', 'from': 12, 'to': 16},
      {'label': '16h–20h', 'from': 16, 'to': 20},
    ];

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final all   = <Map<String, dynamic>>[];

    for (int d = 0; d < 7; d++) {
      final day = today.subtract(Duration(days: d));
      final label = d == 0 ? "Aujourd'hui"
                  : d == 1 ? 'Hier'
                  : '${dayNames[day.weekday]} ${day.day} ${monthNames[day.month - 1]}';

      final dayScans = _history.where((s) {
        final t = DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal();
        return t != null && DateTime(t.year, t.month, t.day) == day;
      }).toList();

      for (final slot in slotDefs) {
        final count = dayScans.where((s) {
          final t = DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal();
          if (t == null) return false;
          return t.hour >= (slot['from'] as int) && t.hour < (slot['to'] as int);
        }).length;
        all.add({'dayLabel': label, 'slot': slot['label'], 'count': count});
      }
    }

    all.sort((a, b) => (a['count'] as int).compareTo(b['count'] as int));
    return all.take(3).toList();
  }

  // S5 : delta scans vs période précédente (mêmes calculs que l'accueil)
  int _scansDelta() {
    if (_history.isEmpty) return 0;
    final now = DateTime.now();
    final from30 = now.subtract(const Duration(days: 30));
    final from60 = now.subtract(const Duration(days: 60));
    final cur  = _history.where((s) {
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
      return t != null && t.isAfter(from30);
    }).length;
    final prev = _history.where((s) {
      final t = DateTime.tryParse(s['scanned_at'] as String? ?? '');
      return t != null && t.isAfter(from60) && !t.isAfter(from30);
    }).length;
    if (prev == 0) return 0;
    return ((cur - prev) / prev * 100).round();
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
                      _scansParJourCard(),
                      const SizedBox(height: 10),
                      _nouveauxClientsCard(),
                      const SizedBox(height: 10),
                      _heuresCreusesCard(),
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
        Builder(builder: (_) {
          final delta = _scansDelta();
          if (delta == 0) return const SizedBox.shrink();
          final sign   = delta > 0 ? '+' : '';
          final color  = delta > 0 ? _kSuccess : const Color(0xFFE24B4A);
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color, size: 13),
              const SizedBox(width: 4),
              Text('$sign$delta% de visites vs mois précédent',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
            ]),
          );
        }),
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

  // ── S2 : Graphique barres scans par jour (7 derniers jours) ─────────────────
  Widget _scansParJourCard() {
    const dayShort = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final days = List.generate(7, (i) {
      final day  = today.subtract(Duration(days: 6 - i));
      final cnt  = _history.where((s) {
        final t = DateTime.tryParse(s['scanned_at'] as String? ?? '')?.toLocal();
        return t != null && DateTime(t.year, t.month, t.day) == day;
      }).length;
      return {'label': dayShort[day.weekday % 7], 'count': cnt, 'today': i == 6};
    });

    final maxCnt = days.fold<int>(1, (m, d) => ((d['count'] as int) > m ? d['count'] as int : m));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded, color: _kPrimary, size: 15),
          const SizedBox(width: 6),
          Text('Visites par jour – 7 jours', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.cText)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final cnt    = d['count'] as int;
              final ratio  = cnt / maxCnt;
              final isToday = d['today'] as bool;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (cnt > 0)
                      Text('$cnt', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                          color: isToday ? _kPrimary : context.cSub)),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: (56 * ratio).clamp(4.0, 56.0),
                      decoration: BoxDecoration(
                        color: isToday ? _kPrimary : _kPrimary.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(d['label'] as String, style: TextStyle(fontSize: 8.5, color: isToday ? _kPrimary : context.cSub,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── S3 : Nouveaux clients par semaine (4 semaines) ───────────────────────────
  Widget _nouveauxClientsCard() {
    final now = DateTime.now();
    // Semaine courante commence lundi
    final weekStart0 = now.subtract(Duration(days: now.weekday - 1));
    final startOfToday = DateTime(weekStart0.year, weekStart0.month, weekStart0.day);

    final weeks = List.generate(4, (i) {
      final wStart = startOfToday.subtract(Duration(days: 7 * (3 - i)));
      final wEnd   = wStart.add(const Duration(days: 7));
      final cnt    = _clients.where((c) {
        final t = DateTime.tryParse(c['created_at'] as String? ?? '');
        return t != null && !t.isBefore(wStart) && t.isBefore(wEnd);
      }).length;
      final label = i == 3 ? 'Cette sem.' : 'S-${3 - i}';
      return {'label': label, 'count': cnt, 'current': i == 3};
    });

    final maxCnt = weeks.fold<int>(1, (m, w) => ((w['count'] as int) > m ? w['count'] as int : m));
    final totalNewClients = weeks.fold<int>(0, (s, w) => s + (w['count'] as int));
    if (totalNewClients == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_add_rounded, color: _kSuccess, size: 15),
          const SizedBox(width: 6),
          Text('Nouveaux clients – 4 semaines', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.cText)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weeks.map((w) {
              final cnt     = w['count'] as int;
              final ratio   = cnt / maxCnt;
              final isCur   = w['current'] as bool;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (cnt > 0)
                      Text('$cnt', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                          color: isCur ? _kSuccess : context.cSub)),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: (56 * ratio).clamp(4.0, 56.0),
                      decoration: BoxDecoration(
                        color: isCur ? _kSuccess : _kSuccess.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(w['label'] as String, style: TextStyle(fontSize: 8, color: isCur ? _kSuccess : context.cSub,
                        fontWeight: isCur ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Heures creuses – top 3 créneaux les plus calmes ─────────────────────────
  Widget _heuresCreusesCard() {
    final top3 = _top3Creux();
    if (top3.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── En-tête ──────────────────────────────────────────────────────────
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
        const SizedBox(height: 3),
        Text('Les 3 créneaux les moins fréquentés', style: TextStyle(fontSize: 9, color: context.cSub)),
        const SizedBox(height: 12),

        // ── Lignes top 3 ─────────────────────────────────────────────────────
        ...top3.asMap().entries.map((e) {
          final rank  = e.key;
          final item  = e.value;
          final count = item['count'] as int;
          final colors = [_kGold, context.cSub, context.cSub];
          final rankColor = colors[rank];

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            decoration: BoxDecoration(
              color: rank == 0 ? const Color(0xFFFFF3CD) : context.cBg,
              border: Border.all(color: rank == 0 ? _kGold : context.cBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Text('${rank + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: rankColor)),
              const SizedBox(width: 10),
              Icon(Icons.schedule_rounded, size: 13, color: rank == 0 ? _kGold : context.cSub),
              const SizedBox(width: 6),
              Expanded(child: Text('${item['dayLabel']}  ·  ${item['slot']}',
                style: TextStyle(fontSize: 11, fontWeight: rank == 0 ? FontWeight.w700 : FontWeight.w500,
                  color: rank == 0 ? const Color(0xFF92400E) : context.cText))),
              Text('$count visite${count != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: rank == 0 ? _kGold : context.cSub)),
            ]),
          );
        }),
        const SizedBox(height: 8),

        // ── Bouton ────────────────────────────────────────────────────────────
        SizedBox(width: double.infinity, child: GestureDetector(
          onTap: () => Navigator.push(context, platformRoute(
              builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: widget.merchantInfo,
                  initialTemplate: 'promo', initialAudience: 'inactifs'))),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('Relancer les clients', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        )),
      ]),
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
    if (n == 0) return const SizedBox.shrink();
    return _summaryRow(
      icon: Icons.star_rounded, iconColor: _kGold, iconBg: const Color(0xFFFEF3C7),
      countText: '$n client${n > 1 ? "s" : ""}', countColor: _kGold,
      label: n > 1 ? 'sont proches de la récompense' : 'est proche de la récompense',
      sub: '≥ ${(_required - 2).clamp(1, _required)}/$_required tampons · prêts à être relancés',
      btn: 'Notifier', btnBg: _kGold, btnText: Colors.white,
      onTap: () => Navigator.push(context, platformRoute(
          builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: widget.merchantInfo,
              initialTemplate: 'rappel', initialAudience: 'proches'))),
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
      onTap: () => Navigator.push(context, platformRoute(
          builder: (_) => NotificationsScreen(token: widget.token, merchantInfo: widget.merchantInfo,
              initialTemplate: 'promo', initialAudience: 'inactifs'))),
    );
  }
}
