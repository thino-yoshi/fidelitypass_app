import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../client/cards_tab.dart' show LoyaltyCardFace, CardStyle;

// ── Presets couleurs (v24) ─────────────────────────────────────────────────────

class _Preset {
  final String bgType;
  final List<Color> colors;
  final double angle;
  const _Preset(this.bgType, this.colors, this.angle);
}

const _kPresets = [
  _Preset('color',    [Color(0xFF2C7BE5)], 135),
  _Preset('color',    [Color(0xFF1E2D45)], 135),
  _Preset('gradient', [Color(0xFF0f2f1a), Color(0xFF1a4a2e)], 135),
  _Preset('gradient', [Color(0xFF1a0a2e), Color(0xFF3d1f6e)], 135),
  _Preset('gradient', [Color(0xFF7c2d12), Color(0xFFc2410c)], 135),
  _Preset('gradient', [Color(0xFF0c4a6e), Color(0xFF0369a1)], 135),
  _Preset('gradient', [Color(0xFF064e3b), Color(0xFF047857)], 135),
  _Preset('gradient', [Color(0xFF831843), Color(0xFFbe185d)], 135),
  _Preset('gradient', [Color(0xFF111827), Color(0xFF374151)], 135),
  _Preset('gradient', [Color(0xFF78350f), Color(0xFFb45309)], 135),
  _Preset('gradient', [Color(0xFF312e81), Color(0xFF4f46e5)], 135),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class CarteEditorScreen extends StatefulWidget {
  final String token;
  final Map merchantInfo;
  const CarteEditorScreen({super.key, required this.token, required this.merchantInfo});

  @override
  State<CarteEditorScreen> createState() => _CarteEditorScreenState();
}

class _CarteEditorScreenState extends State<CarteEditorScreen> {
  late final TextEditingController _rewardCtrl;
  late final TextEditingController _nameCtrl;

  int  _stampsRequired = 8;
  int  _selectedPreset = 0;
  String       _bgType  = 'color';
  List<Color>  _bgColors = [const Color(0xFF2C7BE5)];
  double       _bgAngle  = 135;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    final info = widget.merchantInfo;
    _rewardCtrl = TextEditingController(
        text: (info['reward_description'] ?? '').toString());
    _nameCtrl = TextEditingController(
        text: (info['business_name'] ?? '').toString());
    final mr = info['stamps_required'];
    if (mr != null) _stampsRequired = mr is int ? mr : int.tryParse(mr.toString()) ?? 8;
    _load();
  }

  @override
  void dispose() {
    _rewardCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Chargement ──────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final r = await ApiService.instance.getMerchantCardDesign();
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.isOk && r.value != null) {
      final d = r.value!['card_design'];
      if (d is Map) _applyDesign(d);
    }
  }

  void _applyDesign(Map d) {
    final bgType  = (d['bgType'] as String?) ?? 'color';
    final colors  = _parseColors(d['bgColors']);
    final angle   = (d['bgGradientAngle'] as num?)?.toDouble() ?? 135.0;

    int pidx = -1;
    for (int i = 0; i < _kPresets.length; i++) {
      final p = _kPresets[i];
      if (p.bgType == bgType && _colorsMatch(p.colors, colors)) { pidx = i; break; }
    }

    setState(() {
      _bgType  = bgType;
      _bgColors = colors.isEmpty ? [const Color(0xFF2C7BE5)] : colors;
      _bgAngle  = angle;
      _selectedPreset = pidx;

      final rd = d['rewardDescription'] as String?;
      if (rd != null && rd.isNotEmpty) _rewardCtrl.text = rd;
      final cn = d['cardName'] as String?;
      if (cn != null && cn.isNotEmpty) _nameCtrl.text = cn;
      final sr = d['stampsRequired'];
      if (sr != null) _stampsRequired = sr is int ? sr : int.tryParse(sr.toString()) ?? _stampsRequired;
    });
  }

  // ── Helpers couleur ─────────────────────────────────────────────────────────

  List<Color> _parseColors(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((c) => _hexColor(c?.toString()))
        .whereType<Color>()
        .toList();
  }

  Color? _hexColor(String? s) {
    if (s == null) return null;
    final c = s.replaceAll('#', '').trim();
    if (c.length == 6) return Color(0xFF000000 | int.parse(c, radix: 16));
    if (c.length == 8) return Color(int.parse(c, radix: 16));
    return null;
  }

  bool _colorsMatch(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i].toARGB32() & 0xFFFFFF) != (b[i].toARGB32() & 0xFFFFFF)) return false;
    }
    return true;
  }

  String _toHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  // ── Design courant ──────────────────────────────────────────────────────────

  Map<String, dynamic> get _design => {
    'bgType':          _bgType,
    'bgColors':        _bgColors.map(_toHex).toList(),
    'bgGradientAngle': _bgAngle,
    'textColor':       '#ffffff',
    'accentColors':    <String>[],
    'accentAngle':     135.0,
    'cardName':        _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
    'rewardDescription': _rewardCtrl.text.trim().isEmpty ? null : _rewardCtrl.text.trim(),
    'stampsRequired':  _stampsRequired,
  };

  Map get _previewCard => {
    'stamps_count': 3,
    'card_design':  _design,
    'merchants': {
      'business_name':     _nameCtrl.text.trim().isEmpty
          ? (widget.merchantInfo['business_name'] ?? '')
          : _nameCtrl.text.trim(),
      'stamps_required':   _stampsRequired,
      'reward_description': _rewardCtrl.text.trim(),
    },
  };

  // ── Sauvegarde ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = await ApiService.instance.saveCardDesign(_design);
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: kSuccess, content: Text('Carte mise à jour ✓')));
      Navigator.pop(context, _design);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kError, content: Text(r.error ?? 'Erreur')));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
          decoration: const BoxDecoration(color: kNavy),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 17, color: Colors.white),
            ),
            const Text('Ma carte fidélité',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary)))
        else
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                _buildPreview(),
                const SizedBox(height: 20),
                _label('Nom de la récompense'),
                _inputField(_rewardCtrl, hint: 'Ex : 1 café offert'),
                _label('Nombre de tampons'),
                _buildStepper(),
                _label('Couleur de fond'),
                _buildColorGrid(),
                _label('Nom affiché sur la carte'),
                _inputField(_nameCtrl,
                    hint: widget.merchantInfo['business_name']?.toString() ?? 'Nom de la boutique'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Enregistrer la carte',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _buildPreview() {
    final style = CardStyle.fromDesign(_design, fallbackColor: const Color(0xFF2C7BE5));
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: style.primary.withValues(alpha: 0.4),
            blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: LoyaltyCardFace(card: _previewCard, style: style, userName: ''),
    );
  }

  Widget _buildStepper() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      _stepBtn(Icons.remove, () => setState(() => _stampsRequired = (_stampsRequired - 1).clamp(3, 30))),
      const SizedBox(width: 16),
      Text('$_stampsRequired',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.cText)),
      const SizedBox(width: 16),
      _stepBtn(Icons.add, () => setState(() => _stampsRequired = (_stampsRequired + 1).clamp(3, 30))),
      const SizedBox(width: 10),
      Text('tampons pour débloquer',
          style: TextStyle(fontSize: 12, color: context.cSub)),
    ]),
  );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cBorder)),
      child: Icon(icon, size: 18, color: context.cText),
    ),
  );

  Widget _buildColorGrid() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: _kPresets.asMap().entries
          .map((e) => _colorSwatch(e.key, e.value))
          .toList(),
    ),
  );

  Widget _colorSwatch(int idx, _Preset p) {
    final selected = _selectedPreset == idx;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedPreset = idx;
        _bgType   = p.bgType;
        _bgColors = p.colors;
        _bgAngle  = p.angle;
      }),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: p.bgType == 'gradient' && p.colors.length >= 2
              ? LinearGradient(colors: p.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: p.bgType == 'color' ? p.colors.first : null,
          border: selected
              ? Border.all(color: Colors.white, width: 2.5)
              : Border.all(color: Colors.transparent),
          boxShadow: selected
              ? [BoxShadow(color: p.colors.first.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 16, 0, 7),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
  );

  Widget _inputField(TextEditingController c, {String? hint}) => Container(
    decoration: BoxDecoration(
      color: context.cSurface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.cBorder)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: 14, color: context.cText),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.5, color: context.cSub),
      ),
    ),
  );
}
