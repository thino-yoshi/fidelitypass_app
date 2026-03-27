import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const NotificationsScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const blue = Color(0xFF2C7BE5);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: blue,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Envoyer à tous'),
              Tab(text: 'Push ciblé'),
            ],
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
}

// ── Onglet broadcast (existant) ────────────────────────────────────────────────

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
  static const blue = Color(0xFF2C7BE5);

  List<Map<String, String>> templates = [
    {'title': '🎁 Offre spéciale', 'message': 'Profitez de notre offre du jour ! Venez nous rendre visite.'},
    {'title': '⭐ Double tampons', 'message': 'Aujourd\'hui seulement : chaque achat rapporte 2 tampons !'},
    {'title': '🎉 Nouveau menu', 'message': 'Découvrez nos nouveautés du moment. On vous attend !'},
    {'title': '🏆 Récompense disponible', 'message': 'Vous êtes proche de votre récompense, plus qu\'un peu !'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Templates rapides', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1828))),
              GestureDetector(
                onTap: () => setState(() => editMode = !editMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: editMode ? Colors.red.withOpacity(0.1) : blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(editMode ? '✅ Terminer' : '✏️ Modifier',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: editMode ? Colors.red : blue)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                        color: blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: blue.withOpacity(0.2)),
                      ),
                      child: Center(child: Text(t['title']!, style: TextStyle(color: blue, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                    ),
                  ),
                  if (editMode)
                    Positioned(
                      top: -8, right: -8,
                      child: GestureDetector(
                        onTap: () { setState(() => templates.removeAt(i)); _saveTemplates(); },
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Center(child: Text('✕', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1828))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(
              children: [
                TextField(controller: titleCtrl, decoration: _inputDeco('Titre')),
                const SizedBox(height: 10),
                TextField(controller: messageCtrl, maxLines: 3, decoration: _inputDeco('Message')),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {
                      if (titleCtrl.text.isEmpty || messageCtrl.text.isEmpty) return;
                      setState(() => templates.add({'title': titleCtrl.text, 'message': messageCtrl.text}));
                      _saveTemplates();
                      titleCtrl.clear(); messageCtrl.clear();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter template', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: OutlinedButton.styleFrom(foregroundColor: blue, side: const BorderSide(color: blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                ]),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: sending ? null : _send,
                  style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                  child: sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('🔔 Envoyer à tous mes clients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                )),
              ],
            ),
          ),
          if (feedback != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: feedback!.contains('✅') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(feedback!, style: TextStyle(color: feedback!.contains('✅') ? Colors.green[700] : Colors.red[700], fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  static InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey[500]),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: blue, width: 2)),
  );
}

// ── Onglet push ciblé ─────────────────────────────────────────────────────────

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
  static const blue = Color(0xFF2C7BE5);
  static const purple = Color(0xFF7B4FBF);

  // Filtres
  String _filterType = 'none'; // 'none' | 'stamps' | 'inactive'
  int _stampsRemaining = 3;
  int _inactiveDays = 30;

  bool sending = false;
  String? feedback;

  @override
  void dispose() {
    titleCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendTargeted() async {
    if (titleCtrl.text.isEmpty || messageCtrl.text.isEmpty) {
      setState(() => feedback = '⚠️ Remplis le titre et le message');
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filtres ──
          const Text('Cibler les clients', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1828))),
          const SizedBox(height: 12),
          _filterCard(
            icon: Icons.star_half_rounded,
            color: blue,
            title: 'Proche de la récompense',
            subtitle: 'Clients avec peu de tampons restants',
            selected: _filterType == 'stamps',
            onTap: () => setState(() => _filterType = _filterType == 'stamps' ? 'none' : 'stamps'),
            child: _filterType == 'stamps' ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tampons restants ≤ $_stampsRemaining', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                Slider(
                  value: _stampsRemaining.toDouble(),
                  min: 1, max: stampsRequired.toDouble(),
                  divisions: stampsRequired - 1,
                  activeColor: blue,
                  onChanged: (v) => setState(() => _stampsRemaining = v.round()),
                ),
              ],
            ) : null,
          ),
          const SizedBox(height: 10),
          _filterCard(
            icon: Icons.schedule_rounded,
            color: purple,
            title: 'Clients inactifs',
            subtitle: 'Pas de visite depuis un certain temps',
            selected: _filterType == 'inactive',
            onTap: () => setState(() => _filterType = _filterType == 'inactive' ? 'none' : 'inactive'),
            child: _filterType == 'inactive' ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inactifs depuis $_inactiveDays jours', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                Slider(
                  value: _inactiveDays.toDouble(),
                  min: 7, max: 90,
                  divisions: 11,
                  activeColor: purple,
                  onChanged: (v) => setState(() => _inactiveDays = v.round()),
                ),
              ],
            ) : null,
          ),
          const SizedBox(height: 20),

          // ── Message ──
          const Text('Message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1828))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(
              children: [
                TextField(controller: titleCtrl, decoration: _inputDeco('Titre')),
                const SizedBox(height: 10),
                TextField(controller: messageCtrl, maxLines: 3, decoration: _inputDeco('Message')),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: sending ? null : _sendTargeted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _filterType == 'inactive' ? purple : blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                  ),
                  child: sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    _filterType == 'none' ? '🎯 Envoyer (sans filtre)' :
                    _filterType == 'stamps' ? '🎯 Envoyer aux clients proches' :
                    '🎯 Envoyer aux clients inactifs',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                )),
              ],
            ),
          ),
          if (feedback != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: feedback!.contains('✅') ? Colors.green.withOpacity(0.1) :
                feedback!.contains('⚠️') ? Colors.orange.withOpacity(0.1) :
                Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(feedback!, style: TextStyle(
                color: feedback!.contains('✅') ? Colors.green[700] :
                feedback!.contains('⚠️') ? Colors.orange[700] : Colors.red[700],
                fontWeight: FontWeight.w700,
              ), textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterCard({required IconData icon, required Color color, required String title, required String subtitle, required bool selected, required VoidCallback onTap, Widget? child}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : const Color(0xFFEDE9E3), width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected ? color : const Color(0xFF1A1828))),
                      Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? color : Colors.grey[300], size: 22),
              ],
            ),
            if (child != null) ...[const SizedBox(height: 12), child],
          ],
        ),
      ),
    );
  }

  static InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey[500]),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: blue, width: 2)),
  );
}
