import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api.dart';
import '../../config/app_colors.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _blue        = Color(0xFF2C7BE5);
const _errorColor  = Color(0xFFE24B4A);
const _successColor = Color(0xFF27AE60);
const _purple      = Color(0xFF7C3AED);

class NotificationsScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const NotificationsScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Pill tab bar ──
        Container(
          color: context.cBg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.cBorder,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _tabPill(0, 'Diffusion'),
                _tabPill(1, 'Ciblée'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _BroadcastTab(token: widget.token),
              _TargetedTab(token: widget.token, merchantInfo: widget.merchantInfo),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabPill(int index, String label) {
    final active = _tabCtrl.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabCtrl.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? context.cSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: _blue, width: 1.5) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? _blue : context.cSub,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Preview widget ─────────────────────────────────────────────────────────────

class _NotifPreview extends StatelessWidget {
  final String title;
  final String message;
  const _NotifPreview({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final hasContent = title.isNotEmpty || message.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smartphone_outlined, size: 14, color: Colors.white.withOpacity(0.55)),
            const SizedBox(width: 6),
            Text(
              'Aperçu de la notification',
              style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2A4A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Text('Q', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Qarta', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('maintenant', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasContent ? (title.isEmpty ? 'Titre de la notification' : title) : 'Titre de la notification',
                      style: TextStyle(
                        color: hasContent && title.isNotEmpty ? Colors.white : Colors.white.withOpacity(0.3),
                        fontSize: 13, fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasContent ? (message.isEmpty ? 'Votre message s\'affichera ici…' : message) : 'Votre message s\'affichera ici…',
                      style: TextStyle(
                        color: hasContent && message.isNotEmpty ? Colors.white.withOpacity(0.75) : Colors.white.withOpacity(0.25),
                        fontSize: 12, height: 1.4,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Schedule picker ────────────────────────────────────────────────────────────

class _ScheduleSection extends StatefulWidget {
  final bool enabled;
  final DateTime? scheduled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<DateTime> onDateTimeChanged;
  const _ScheduleSection({
    required this.enabled,
    required this.scheduled,
    required this.onToggle,
    required this.onDateTimeChanged,
  });

  @override
  State<_ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<_ScheduleSection> {
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.scheduled ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _blue),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.scheduled ?? now.add(const Duration(hours: 1))),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _blue),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    widget.onDateTimeChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _formatDt(DateTime dt) {
    final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} à $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(18),
        border: widget.enabled ? Border.all(color: _blue, width: 2) : Border.all(color: context.cBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: widget.enabled ? _blue.withOpacity(0.1) : context.cFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule_rounded, color: widget.enabled ? _blue : context.cSub, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Programmer pour plus tard',
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: widget.enabled ? _blue : context.cText,
                      ),
                    ),
                    Text(
                      'Choisir une date et heure d\'envoi',
                      style: TextStyle(color: context.cSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.enabled,
                onChanged: widget.onToggle,
                activeColor: _blue,
              ),
            ],
          ),
          if (widget.enabled) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.cFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: _blue, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      widget.scheduled != null
                          ? _formatDt(widget.scheduled!)
                          : 'Choisir date et heure…',
                      style: TextStyle(
                        color: widget.scheduled != null ? context.cText : context.cSub,
                        fontWeight: FontWeight.w600, fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: context.cSub, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Campagnes planifiées ───────────────────────────────────────────────────────

class _ScheduledList extends StatefulWidget {
  final String token;
  final int refreshKey;
  const _ScheduledList({required this.token, required this.refreshKey});

  @override
  State<_ScheduledList> createState() => _ScheduledListState();
}

class _ScheduledListState extends State<_ScheduledList> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ScheduledList old) {
    super.didUpdateWidget(old);
    if (old.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/notifications/scheduled'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() { _items = jsonDecode(res.body); _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String id) async {
    await http.delete(
      Uri.parse('$apiUrl/notifications/scheduled/$id'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    _load();
  }

  String _formatDt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} à $h:$m';
    } catch (_) {
      return iso;
    }
  }

  String _filterLabel(String type, int? value) {
    switch (type) {
      case 'stamps': return 'Proches récompense (≤$value tampons)';
      case 'inactive': return 'Inactifs depuis $value j.';
      default: return 'Tous les clients';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _blue)));
    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'CAMPAGNES PLANIFIÉES',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.7),
        ),
        const SizedBox(height: 10),
        ..._items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.cBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule_rounded, color: _blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.cText)),
                      const SizedBox(height: 2),
                      Text(item['message'] as String? ?? '', style: TextStyle(color: context.cSub, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: context.cSub),
                          const SizedBox(width: 4),
                          Text(_formatDt(item['scheduled_at'] as String? ?? ''), style: const TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Icon(Icons.people_outline, size: 11, color: context.cSub),
                          const SizedBox(width: 4),
                          Text(
                            _filterLabel(item['filter_type'] as String? ?? 'broadcast', item['filter_value'] as int?),
                            style: TextStyle(fontSize: 11, color: context.cSub),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: ctx.cSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: Text('Annuler la campagne', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ctx.cText)),
                      content: Text('Cette campagne programmée sera supprimée.', style: TextStyle(color: ctx.cSub)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('Garder', style: TextStyle(color: ctx.cSub))),
                        ElevatedButton(
                          onPressed: () { Navigator.pop(context); _cancel(item['id'] as String); },
                          style: ElevatedButton.styleFrom(backgroundColor: _errorColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text('Annuler'),
                        ),
                      ],
                    ),
                  ),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: _errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, color: _errorColor, size: 16),
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

// ── Template selector ──────────────────────────────────────────────────────────

class _TemplateSelector extends StatelessWidget {
  final Function(String title, String body) onSelect;
  const _TemplateSelector({required this.onSelect});

  static const _templates = [
    {'emoji': '', 'label': 'Offre spéciale', 'title': 'Offre spéciale ce soir !', 'body': '-20% sur tout le menu ce soir. On t\'attend !'},
    {'emoji': '', 'label': 'Rappel tampon', 'title': 'Tu es proche d\'une récompense !', 'body': 'Plus que quelques tampons pour décrocher ta récompense !'},
    {'emoji': '', 'label': 'Merci & fidélité', 'title': 'Merci pour ta fidélité !', 'body': 'Tu fais partie de nos meilleurs clients. Merci !'},
    {'emoji': '', 'label': 'Message libre', 'title': '', 'body': ''},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'MODÈLES RAPIDES',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.7),
      ),
      const SizedBox(height: 10),
      ..._templates.map((t) => GestureDetector(
        onTap: () => onSelect(t['title']!, t['body']!),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(t['emoji']!, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['label']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.cText)),
                if (t['body']!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(t['body']!, style: TextStyle(fontSize: 12, color: context.cSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: context.cSub, size: 18),
          ]),
        ),
      )),
      const SizedBox(height: 8),
    ]);
  }
}

// ── Onglet broadcast ───────────────────────────────────────────────────────────

class _BroadcastTab extends StatefulWidget {
  final String token;
  const _BroadcastTab({required this.token});

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final titleCtrl = TextEditingController();
  final messageCtrl = TextEditingController();
  bool sending = false;
  String? feedback;
  bool editMode = false;
  bool _scheduleEnabled = false;
  DateTime? _scheduledAt;
  int _refreshKey = 0;

  List<Map<String, String>> templates = [
    {'title': 'Offre spéciale', 'message': 'Profitez de notre offre du jour ! Venez nous rendre visite.'},
    {'title': 'Double tampons', 'message': 'Aujourd\'hui seulement : chaque achat rapporte 2 tampons !'},
    {'title': 'Nouveau menu', 'message': 'Découvrez nos nouveautés du moment. On vous attend !'},
    {'title': 'Récompense disponible', 'message': 'Vous êtes proche de votre récompense, plus qu\'un peu !'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    titleCtrl.addListener(() => setState(() {}));
    messageCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('notif_templates');
    if (saved != null) {
      setState(() => templates = (jsonDecode(saved) as List).map((e) => Map<String, String>.from(e)).toList());
    }
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_templates', jsonEncode(templates));
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (titleCtrl.text.isEmpty || messageCtrl.text.isEmpty) return;

    // Mode planifié
    if (_scheduleEnabled) {
      if (_scheduledAt == null) {
        setState(() => feedback = '⚠️ Choisis une date et heure d\'envoi');
        return;
      }
      setState(() { sending = true; feedback = null; });
      try {
        final res = await http.post(
          Uri.parse('$apiUrl/notifications/schedule'),
          headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': titleCtrl.text,
            'message': messageCtrl.text,
            'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
            'filter_type': 'broadcast',
          }),
        );
        if (res.statusCode == 200) {
          setState(() { feedback = '📅 Campagne planifiée !'; _refreshKey++; });
          titleCtrl.clear(); messageCtrl.clear();
          setState(() { _scheduleEnabled = false; _scheduledAt = null; });
        } else {
          setState(() => feedback = '❌ ${jsonDecode(res.body)['detail'] ?? 'Erreur'}');
        }
      } catch (_) {
        setState(() => feedback = '❌ Erreur réseau');
      } finally {
        setState(() => sending = false);
      }
      return;
    }

    // Envoi immédiat
    setState(() { sending = true; feedback = null; });
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/notifications/send'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'title': titleCtrl.text, 'message': messageCtrl.text}),
      );
      setState(() => feedback = res.statusCode == 200 ? '✅ Notification envoyée !' : '❌ Erreur lors de l\'envoi');
      if (res.statusCode == 200) { titleCtrl.clear(); messageCtrl.clear(); }
    } catch (_) {
      setState(() => feedback = '❌ Erreur réseau');
    } finally {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Templates rapides
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TEMPLATES RAPIDES',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.7),
              ),
              GestureDetector(
                onTap: () => setState(() => editMode = !editMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: editMode ? _errorColor.withOpacity(0.1) : _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    editMode ? '✅ Terminer' : '✏️ Modifier',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: editMode ? _errorColor : _blue),
                  ),
                ),
              ),
            ],
          ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
              children: templates.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: editMode ? null : () { titleCtrl.text = t['title']!; messageCtrl.text = t['message']!; },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.cSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _blue.withOpacity(0.25), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            t['title']!,
                            style: const TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    if (editMode)
                      Positioned(
                        top: -8, right: -8,
                        child: GestureDetector(
                          onTap: () { setState(() => templates.removeAt(i)); _saveTemplates(); },
                          child: Container(
                            width: 22, height: 22,
                            decoration: const BoxDecoration(color: _errorColor, shape: BoxShape.circle),
                            child: const Center(child: Text('✕', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                          ),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Preview
            _NotifPreview(title: titleCtrl.text, message: messageCtrl.text),
            const SizedBox(height: 20),

            // Template selector
            _TemplateSelector(
              onSelect: (title, body) {
                if (title.isNotEmpty) titleCtrl.text = title;
                if (body.isNotEmpty) messageCtrl.text = body;
                setState(() {});
              },
            ),
            const SizedBox(height: 4),

            // Message section
            Text(
              'MESSAGE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.7),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.cBorder),
              ),
              child: Column(
                children: [
                  TextField(controller: titleCtrl, decoration: _inputDeco(context, 'Titre'), style: TextStyle(color: context.cText)),
                  const SizedBox(height: 10),
                  TextField(controller: messageCtrl, maxLines: 3, decoration: _inputDeco(context, 'Message'), style: TextStyle(color: context.cText)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (titleCtrl.text.isEmpty || messageCtrl.text.isEmpty) return;
                        setState(() => templates.add({'title': titleCtrl.text, 'message': messageCtrl.text}));
                        _saveTemplates();
                        titleCtrl.clear(); messageCtrl.clear();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter template', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: const BorderSide(color: _blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Planification
            _ScheduleSection(
              enabled: _scheduleEnabled,
              scheduled: _scheduledAt,
              onToggle: (v) => setState(() => _scheduleEnabled = v),
              onDateTimeChanged: (dt) => setState(() => _scheduledAt = dt),
            ),
            const SizedBox(height: 14),

            // Bouton envoi
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _scheduleEnabled ? '📅 Programmer la campagne' : '🔔 Envoyer à tous mes clients',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),

            if (feedback != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: feedback!.contains('✅') || feedback!.contains('📅')
                      ? const Color(0xFFE4F5EB)
                      : feedback!.contains('⚠️')
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFFDE8E7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  feedback!,
                  style: TextStyle(
                    color: feedback!.contains('✅') || feedback!.contains('📅')
                        ? _successColor
                        : feedback!.contains('⚠️')
                            ? const Color(0xFFF59E0B)
                            : _errorColor,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Liste campagnes planifiées
            _ScheduledList(token: widget.token, refreshKey: _refreshKey),
            const SizedBox(height: 16),
          ],
        ),
      );
  }
}

// ── Onglet push ciblé ──────────────────────────────────────────────────────────

class _TargetedTab extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const _TargetedTab({required this.token, this.merchantInfo});

  @override
  State<_TargetedTab> createState() => _TargetedTabState();
}

class _TargetedTabState extends State<_TargetedTab> {
  final titleCtrl = TextEditingController();
  final messageCtrl = TextEditingController();

  String _filterType = 'none';
  int _stampsRemaining = 3;
  int _inactiveDays = 30;
  bool _scheduleEnabled = false;
  DateTime? _scheduledAt;
  int _refreshKey = 0;

  bool sending = false;
  String? feedback;

  @override
  void initState() {
    super.initState();
    titleCtrl.addListener(() => setState(() {}));
    messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  String get _apiFilterType {
    if (_filterType == 'stamps') return 'stamps';
    if (_filterType == 'inactive') return 'inactive';
    return 'broadcast';
  }

  Future<void> _send() async {
    if (titleCtrl.text.isEmpty || messageCtrl.text.isEmpty) {
      setState(() => feedback = '⚠️ Remplis le titre et le message');
      return;
    }

    if (_scheduleEnabled) {
      if (_scheduledAt == null) {
        setState(() => feedback = '⚠️ Choisis une date et heure d\'envoi');
        return;
      }
      setState(() { sending = true; feedback = null; });
      try {
        final res = await http.post(
          Uri.parse('$apiUrl/notifications/schedule'),
          headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': titleCtrl.text,
            'message': messageCtrl.text,
            'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
            'filter_type': _apiFilterType,
            if (_filterType == 'stamps') 'filter_value': _stampsRemaining,
            if (_filterType == 'inactive') 'filter_value': _inactiveDays,
          }),
        );
        if (res.statusCode == 200) {
          setState(() { feedback = '📅 Campagne planifiée !'; _refreshKey++; });
          titleCtrl.clear(); messageCtrl.clear();
          setState(() { _scheduleEnabled = false; _scheduledAt = null; });
        } else {
          setState(() => feedback = '❌ ${jsonDecode(res.body)['detail'] ?? 'Erreur'}');
        }
      } catch (_) {
        setState(() => feedback = '❌ Erreur réseau');
      } finally {
        setState(() => sending = false);
      }
      return;
    }

    setState(() { sending = true; feedback = null; });
    try {
      final body = {
        'title': titleCtrl.text,
        'message': messageCtrl.text,
        if (_filterType == 'stamps') 'max_stamps_remaining': _stampsRemaining,
        if (_filterType == 'inactive') 'inactive_days': _inactiveDays,
      };
      final res = await http.post(
        Uri.parse('$apiUrl/notifications/send-targeted'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => feedback = '✅ ${data['message']}');
        titleCtrl.clear(); messageCtrl.clear();
      } else {
        setState(() => feedback = '❌ Erreur lors de l\'envoi');
      }
    } catch (_) {
      setState(() => feedback = '❌ Erreur réseau');
    } finally {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stampsRequired = widget.merchantInfo?['stamps_required'] as int? ?? 10;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres
          Text(
            'CIBLER LES CLIENTS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.7),
          ),
            const SizedBox(height: 10),
            _filterCard(
              icon: Icons.star_half_rounded, color: _blue,
              title: 'Proche de la récompense',
              subtitle: 'Clients avec peu de tampons restants',
              selected: _filterType == 'stamps',
              onTap: () => setState(() => _filterType = _filterType == 'stamps' ? 'none' : 'stamps'),
              child: _filterType == 'stamps' ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tampons restants ≤ $_stampsRemaining', style: TextStyle(color: context.cSub, fontSize: 13)),
                  Slider(
                    value: _stampsRemaining.toDouble(),
                    min: 1, max: stampsRequired.toDouble(),
                    divisions: stampsRequired - 1,
                    activeColor: _blue,
                    onChanged: (v) => setState(() => _stampsRemaining = v.round()),
                  ),
                ],
              ) : null,
            ),
            const SizedBox(height: 10),
            _filterCard(
              icon: Icons.schedule_rounded, color: _purple,
              title: 'Clients inactifs',
              subtitle: 'Pas de visite depuis un certain temps',
              selected: _filterType == 'inactive',
              onTap: () => setState(() => _filterType = _filterType == 'inactive' ? 'none' : 'inactive'),
              child: _filterType == 'inactive' ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inactifs depuis $_inactiveDays jours', style: TextStyle(color: context.cSub, fontSize: 13)),
                  Slider(
                    value: _inactiveDays.toDouble(),
                    min: 7, max: 90, divisions: 11,
                    activeColor: _purple,
                    onChanged: (v) => setState(() => _inactiveDays = v.round()),
                  ),
                ],
              ) : null,
            ),
            const SizedBox(height: 20),

            // Preview
            _NotifPreview(title: titleCtrl.text, message: messageCtrl.text),
            const SizedBox(height: 20),

            // Template selector
            _TemplateSelector(
              onSelect: (title, body) {
                if (title.isNotEmpty) titleCtrl.text = title;
                if (body.isNotEmpty) messageCtrl.text = body;
                setState(() {});
              },
            ),
            const SizedBox(height: 4),

            // Message
            Text(
              'MESSAGE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.cSub, letterSpacing: 0.7),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.cBorder),
              ),
              child: Column(
                children: [
                  TextField(controller: titleCtrl, decoration: _inputDeco(context, 'Titre'), style: TextStyle(color: context.cText)),
                  const SizedBox(height: 10),
                  TextField(controller: messageCtrl, maxLines: 3, decoration: _inputDeco(context, 'Message'), style: TextStyle(color: context.cText)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Planification
            _ScheduleSection(
              enabled: _scheduleEnabled,
              scheduled: _scheduledAt,
              onToggle: (v) => setState(() => _scheduleEnabled = v),
              onDateTimeChanged: (dt) => setState(() => _scheduledAt = dt),
            ),
            const SizedBox(height: 14),

            // Bouton envoi
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _scheduleEnabled ? _blue : (_filterType == 'inactive' ? _purple : _blue),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _scheduleEnabled ? 'Programmer la campagne' :
                        _filterType == 'none' ? 'Envoyer (sans filtre)' :
                        _filterType == 'stamps' ? 'Envoyer aux clients proches' :
                        'Envoyer aux clients inactifs',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),

            if (feedback != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: feedback!.contains('✅') || feedback!.contains('📅')
                      ? const Color(0xFFE4F5EB)
                      : feedback!.contains('⚠️')
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFFDE8E7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  feedback!,
                  style: TextStyle(
                    color: feedback!.contains('✅') || feedback!.contains('📅')
                        ? _successColor
                        : feedback!.contains('⚠️')
                            ? const Color(0xFFF59E0B)
                            : _errorColor,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Liste campagnes planifiées
            _ScheduledList(token: widget.token, refreshKey: _refreshKey),
            const SizedBox(height: 16),
          ],
        ),
    );
  }

  Widget _filterCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(18),
          border: selected ? Border.all(color: color, width: 2) : Border.all(color: context.cBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.12) : context.cFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: selected ? color : context.cSub, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected ? color : context.cText)),
                      Text(subtitle, style: TextStyle(color: context.cSub, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? color : context.cSub,
                  size: 22,
                ),
              ],
            ),
            if (child != null) ...[const SizedBox(height: 12), child],
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDeco(BuildContext ctx, String label) => InputDecoration(
  labelText: label,
  labelStyle: TextStyle(color: ctx.cSub),
  filled: true,
  fillColor: ctx.cFill,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: _blue, width: 2),
  ),
);
