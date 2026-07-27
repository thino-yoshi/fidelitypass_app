import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../client/cards_tab.dart' show LoyaltyCardFace, CardStyle;

// ── Thèmes (identiques aux 12 du site qarta.be) ────────────────────────────

class _Theme {
  final String name;
  final String bgType;
  final List<Color> bgColors;
  final List<Color> accentColors;
  final Color textColor;
  final double angle;
  const _Theme(this.name, this.bgType, this.bgColors, this.accentColors, this.textColor, this.angle);
}

const _kThemes = [
  _Theme('Rose Nuit',  'gradient', [Color(0xFFFF2D78), Color(0xFF985986)], [Color(0xFFFF2D78)], Color(0xFFFFFFFF), 135),
  _Theme('Nuit Dorée', 'gradient', [Color(0xFF141626), Color(0xFF2c1f50)], [Color(0xFFF5C842)], Color(0xFFF5C842), 135),
  _Theme('Émeraude',   'gradient', [Color(0xFF1B4332), Color(0xFF2d6a4f)], [Color(0xFF95D5B2)], Color(0xFFd8f3dc), 135),
  _Theme('Cobalt',     'gradient', [Color(0xFF03045E), Color(0xFF0096C7)], [Color(0xFF90E0EF)], Color(0xFFCAF0F8), 135),
  _Theme('Craie',      'color',    [Color(0xFFF5F0E8)],                    [Color(0xFF2c1f50)], Color(0xFF2c1f50), 135),
  _Theme('Braise',     'gradient', [Color(0xFFF94144), Color(0xFFF8961E)], [Color(0xFFF8961E)], Color(0xFFFFFFFF), 135),
  _Theme('Lavande',    'gradient', [Color(0xFF4A1D96), Color(0xFF7C3AED)], [Color(0xFFDDD6FE)], Color(0xFFEDE9FE), 135),
  _Theme('Bordeaux',   'gradient', [Color(0xFF4C0519), Color(0xFF881337)], [Color(0xFFFCA5A5)], Color(0xFFFEE2E2), 135),
  _Theme('Teal Glacé', 'gradient', [Color(0xFF134E4A), Color(0xFF0F766E)], [Color(0xFF2DD4BF)], Color(0xFFCCFBF1), 135),
  _Theme('Café',       'gradient', [Color(0xFF292524), Color(0xFF44403C)], [Color(0xFFD6B896)], Color(0xFFF5EFE8), 135),
  _Theme('Sakura',     'color',    [Color(0xFFFFF0F5)],                    [Color(0xFFDB2777)], Color(0xFF831843), 135),
  _Theme('Soleil',     'gradient', [Color(0xFF92400E), Color(0xFFB45309)], [Color(0xFFFDE68A)], Color(0xFFFEF3C7), 135),
];

// ── Screen ──────────────────────────────────────────────────────────────────

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

  int          _stampsRequired = 8;
  int          _selectedTheme  = 1; // Nuit Dorée par défaut
  String       _bgType         = _kThemes[1].bgType;
  List<Color>  _bgColors       = _kThemes[1].bgColors;
  List<Color>  _accentColors   = _kThemes[1].accentColors;
  Color        _textColor      = _kThemes[1].textColor;
  double       _bgAngle        = 135;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    final info = widget.merchantInfo;
    _rewardCtrl = TextEditingController(text: (info['reward_description'] ?? '').toString());
    _nameCtrl   = TextEditingController(text: (info['business_name'] ?? '').toString());
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

  // ── Chargement ─────────────────────────────────────────────────────────────

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
    final bgType  = (d['bgType']  as String?) ?? 'gradient';
    final colors  = _parseColors(d['bgColors']);
    final accents = _parseColors(d['accentColors']);
    final angle   = (d['bgGradientAngle'] as num?)?.toDouble() ?? 135.0;
    final txtHex  = d['textColor'] as String?;
    final txt     = txtHex != null ? (_hexColor(txtHex) ?? Colors.white) : Colors.white;

    // Retrouver le thème correspondant
    int tidx = -1;
    for (int i = 0; i < _kThemes.length; i++) {
      final t = _kThemes[i];
      if (t.bgType == bgType && _colorsMatch(t.bgColors, colors)) { tidx = i; break; }
    }

    setState(() {
      _bgType       = bgType;
      _bgColors     = colors.isEmpty ? _kThemes[1].bgColors : colors;
      _accentColors = accents.isEmpty ? _kThemes[1].accentColors : accents;
      _textColor    = txt;
      _bgAngle      = angle;
      _selectedTheme = tidx;

      final rd = d['rewardDescription'] as String?;
      if (rd != null && rd.isNotEmpty) _rewardCtrl.text = rd;
      final cn = d['cardName'] as String?;
      if (cn != null && cn.isNotEmpty) _nameCtrl.text = cn;
      final sr = d['stampsRequired'];
      if (sr != null) _stampsRequired = sr is int ? sr : int.tryParse(sr.toString()) ?? _stampsRequired;
    });
  }

  // ── Helpers couleur ────────────────────────────────────────────────────────

  List<Color> _parseColors(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((c) => _hexColor(c?.toString())).whereType<Color>().toList();
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

  // ── Design courant ─────────────────────────────────────────────────────────

  Map<String, dynamic> get _design => {
    'bgType':            _bgType,
    'bgColors':          _bgColors.map(_toHex).toList(),
    'bgGradientAngle':   _bgAngle,
    'textColor':         _toHex(_textColor),
    'accentColors':      _accentColors.map(_toHex).toList(),
    'accentAngle':       _bgAngle,
    'cardName':          _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
    'rewardDescription': _rewardCtrl.text.trim().isEmpty ? null : _rewardCtrl.text.trim(),
    'stampsRequired':    _stampsRequired,
  };

  Map get _previewCard => {
    'stamps_count': 3,
    'card_design':  _design,
    'merchants': {
      'business_name':      _nameCtrl.text.trim().isEmpty
          ? (widget.merchantInfo['business_name'] ?? '')
          : _nameCtrl.text.trim(),
      'stamps_required':    _stampsRequired,
      'reward_description': _rewardCtrl.text.trim(),
    },
  };

  // ── Sauvegarde ─────────────────────────────────────────────────────────────

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

  // ── Build ──────────────────────────────────────────────────────────────────

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
                const SizedBox(height: 24),

                // ── Thèmes rapides ──────────────────────────────────────────
                _label('Thème'),
                _buildThemeGrid(),
                const SizedBox(height: 8),

                // ── Récompense ──────────────────────────────────────────────
                _label('Nom de la récompense'),
                _inputField(_rewardCtrl, hint: 'Ex : 1 café offert'),

                // ── Nom sur la carte ────────────────────────────────────────
                _label('Nom affiché sur la carte'),
                _inputField(_nameCtrl,
                    hint: widget.merchantInfo['business_name']?.toString() ?? 'Nom de la boutique'),

                const SizedBox(height: 8),
                _buildWebsiteHint(),
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

  Widget _buildThemeGrid() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: _kThemes.asMap().entries
          .map((e) => _themeSwatch(e.key, e.value))
          .toList(),
    ),
  );

  Widget _themeSwatch(int idx, _Theme t) {
    final selected = _selectedTheme == idx;
    return Tooltip(
      message: t.name,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTheme = idx;
          _bgType        = t.bgType;
          _bgColors      = t.bgColors;
          _accentColors  = t.accentColors;
          _textColor     = t.textColor;
          _bgAngle       = t.angle;
        }),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: t.bgType == 'gradient' && t.bgColors.length >= 2
                ? LinearGradient(colors: t.bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: t.bgType == 'color' ? t.bgColors.first : null,
            border: selected
                ? Border.all(color: Colors.white, width: 2.5)
                : Border.all(color: Colors.transparent),
            boxShadow: selected
                ? [BoxShadow(color: t.bgColors.first.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                : null,
          ),
          child: Stack(children: [
            if (selected)
              const Center(child: Icon(Icons.check, color: Colors.white, size: 17)),
            Positioned(
              bottom: 4, right: 4,
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: t.accentColors.first,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildWebsiteHint() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: context.cSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.cBorder),
    ),
    child: Row(children: [
      Icon(Icons.open_in_browser_rounded, size: 16, color: context.cSub),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Pour modifier les tampons, la police ou les couleurs avancées, rendez-vous sur qarta.be',
          style: TextStyle(fontSize: 11.5, color: context.cSub, height: 1.4),
        ),
      ),
    ]),
  );

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
