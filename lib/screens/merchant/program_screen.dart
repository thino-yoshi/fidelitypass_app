import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../config/app_colors.dart';
import 'package:flutter/services.dart';

class ProgramScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  final VoidCallback? onSaved;
  const ProgramScreen({super.key, required this.token, this.merchantInfo, this.onSaved});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  late TextEditingController rewardCtrl;
  late TextEditingController nameCtrl;
  late TextEditingController categoryCtrl;
  late int stampsRequired;
  bool saving = false;

  static const _blue          = Color(0xFF2C7BE5);
  static const _errorColor    = Color(0xFFE24B4A);
  static const _successColor  = Color(0xFF27AE60);

  Color get _kBg     => context.cBg;
  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;
  Color get _kFill   => context.cFill;

  // Multi-récompenses
  List<Map<String, dynamic>> _bonusRewards = [];
  bool _rewardsLoaded = false;

  @override
  void initState() {
    super.initState();
    rewardCtrl = TextEditingController(text: widget.merchantInfo?['reward_description'] ?? '');
    nameCtrl = TextEditingController(text: widget.merchantInfo?['business_name'] ?? '');
    categoryCtrl = TextEditingController(text: widget.merchantInfo?['category'] ?? '');
    stampsRequired = widget.merchantInfo?['stamps_required'] ?? 10;
    _loadBonusRewards();
  }

  Future<void> _loadBonusRewards() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/merchants/me/rewards'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _bonusRewards = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          _rewardsLoaded = true;
        });
      }
    } catch (_) {
      setState(() => _rewardsLoaded = true);
    }
  }

  Future<void> _addBonusReward() async {
    int newStamps = 5;
    final descCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: ctx.cSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Ajouter une récompense bonus',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ctx.cText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TAMPONS REQUIS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ctx.cSub, letterSpacing: 0.7),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () { if (newStamps > 1) setD(() => newStamps--); },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.remove_rounded, color: _blue, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 60, padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: ctx.cFill, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '$newStamps',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.cText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () { setD(() => newStamps++); },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.add_rounded, color: _blue, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                style: TextStyle(color: ctx.cText),
                decoration: InputDecoration(
                  hintText: 'Ex: Croissant offert',
                  hintStyle: TextStyle(color: ctx.cSub, fontSize: 14),
                  filled: true,
                  fillColor: ctx.cFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: TextStyle(color: ctx.cSub)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || descCtrl.text.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/merchants/me/rewards'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'stamps_required': newStamps, 'description': descCtrl.text}),
      );
      if (res.statusCode == 200 && mounted) _loadBonusRewards();
    } catch (_) {}
  }

  Future<void> _deleteBonusReward(String id) async {
    try {
      await http.delete(
        Uri.parse('$apiUrl/merchants/me/rewards/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (mounted) _loadBonusRewards();
    } catch (_) {}
  }

  Future<void> saveProgram() async {
    setState(() => saving = true);
    try {
      final body = jsonEncode({
        'business_name': nameCtrl.text,
        'category': categoryCtrl.text,
        'stamps_required': stampsRequired,
        'reward_description': rewardCtrl.text,
      });

      final res = await http.post(
        Uri.parse('$apiUrl/merchants/setup'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: body,
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Programme mis à jour ! ✓'),
          backgroundColor: _successColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ));
        widget.onSaved?.call();
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['detail'] ?? 'Erreur');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : ${e.toString().replaceAll("Exception: ", "")}'),
        backgroundColor: _errorColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section: Configuration ──────────────────────────────────────
          _sectionLabel('CONFIGURATION'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Nom du commerce'),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: _inputDeco('Ex: Café Lumière'), style: TextStyle(color: _kText)),
                const SizedBox(height: 16),

                _fieldLabel('Catégorie'),
                const SizedBox(height: 8),
                TextField(controller: categoryCtrl, decoration: _inputDeco('Ex: Café, Restaurant, Boulangerie...'), style: TextStyle(color: _kText)),
                const SizedBox(height: 16),

                Divider(color: _kBorder, thickness: 1),
                const SizedBox(height: 16),

                _fieldLabel('Nombre de tampons requis'),
                const SizedBox(height: 4),
                Text('Nombre de visites pour obtenir la récompense',
                    style: TextStyle(fontSize: 12, color: _kSub)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () { if (stampsRequired > 2) setState(() => stampsRequired--); },
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.remove_rounded, color: _blue, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _kFill, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '$stampsRequired',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _blue),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () { if (stampsRequired < 50) setState(() => stampsRequired++); },
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add_rounded, color: _blue, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Divider(color: _kBorder, thickness: 1),
                const SizedBox(height: 16),

                _fieldLabel('Description de la récompense'),
                const SizedBox(height: 8),
                TextField(controller: rewardCtrl, decoration: _inputDeco('Ex: 1 café offert'), style: TextStyle(color: _kText)),
                const SizedBox(height: 20),

                // Aperçu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Après $stampsRequired visites',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _kText)),
                            const SizedBox(height: 2),
                            Text(
                              '🎁 ${rewardCtrl.text.isEmpty ? "Votre récompense" : rewardCtrl.text}',
                              style: const TextStyle(fontSize: 13, color: _blue, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Text('🏪', style: TextStyle(fontSize: 32)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Section: Récompenses bonus ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('RÉCOMPENSES BONUS'),
              GestureDetector(
                onTap: _addBonusReward,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    Icon(Icons.add, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Récompenses débloquées en cours de cycle (sans réinitialiser les tampons)',
            style: TextStyle(fontSize: 11, color: _kSub),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBorder),
            ),
            child: !_rewardsLoaded
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _blue)),
                  ))
                : _bonusRewards.isEmpty
                    ? Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: _kFill, borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.card_giftcard_outlined, color: _kSub, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('Aucune récompense bonus', style: TextStyle(color: _kSub, fontSize: 13)),
                      ])
                    : Column(
                        children: _bonusRewards.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _kFill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Text(
                                    '${r['stamps_required']}',
                                    style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 14),
                                  )),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('🎁 ${r['description']}',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kText)),
                                    Text('À ${r['stamps_required']} tampons',
                                        style: TextStyle(fontSize: 11, color: _kSub)),
                                  ]),
                                ),
                                GestureDetector(
                                  onTap: () => _deleteBonusReward(r['id'].toString()),
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: _errorColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close_rounded, color: _errorColor, size: 15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
          ),

          const SizedBox(height: 24),

          // ── Save button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: saving ? null : saveProgram,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer les modifications',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.7));
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kText));
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _kSub, fontSize: 14),
      filled: true,
      fillColor: _kFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 2)),
    );
  }
}
