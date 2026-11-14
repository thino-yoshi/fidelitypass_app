import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';

const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

const _categories = [
  'Restauration', 'Café / Bar', 'Boulangerie', 'Épicerie', 'Coiffure / Beauté',
  'Sport / Bien-être', 'Mode / Vêtements', 'Librairie', 'Pharmacie', 'Autre',
];

// Horaires par jour : Ouvre - Pause début - Pause fin - Ferme
class _DaySchedule {
  TimeOfDay? open, pauseStart, pauseEnd, close;
  _DaySchedule({this.open, this.pauseStart, this.pauseEnd, this.close});

  String toJson() {
    String fmt(TimeOfDay? t) => t != null
        ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
        : '';
    final o = fmt(open); final ps = fmt(pauseStart); final pe = fmt(pauseEnd); final c = fmt(close);
    if (o.isEmpty && c.isEmpty) return '';
    if (ps.isEmpty) return '$o-$c';
    return '$o-$ps/$pe-$c';
  }

  static _DaySchedule fromJson(String s) {
    if (s.isEmpty) return _DaySchedule();
    // Format : "09:00-12:00/14:00-18:00" (avec pause) ou "09:00-18:00" (sans pause)
    final slashIdx = s.indexOf('/');
    if (slashIdx > 0) {
      final parts1 = s.substring(0, slashIdx).split('-');
      final parts2 = s.substring(slashIdx + 1).split('-');
      return _DaySchedule(
        open: _pt(parts1.isNotEmpty ? parts1[0] : ''),
        pauseStart: _pt(parts1.length > 1 ? parts1[1] : ''),
        pauseEnd: _pt(parts2.isNotEmpty ? parts2[0] : ''),
        close: _pt(parts2.length > 1 ? parts2[1] : ''),
      );
    } else {
      final parts = s.split('-');
      return _DaySchedule(
        open: _pt(parts.isNotEmpty ? parts[0] : ''),
        close: _pt(parts.length > 1 ? parts[1] : ''),
      );
    }
  }

  static TimeOfDay? _pt(String s) {
    final p = s.trim().split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]); final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool get isEmpty => open == null && close == null;
}

/// Écran "Info commerce" (v24) — édite les infos publiques de la boutique.
/// Préremplit depuis le profil marchand et sauvegarde via /merchants/me/info.
class InfoCommerceScreen extends StatefulWidget {
  final String token;
  final Map merchantInfo;
  const InfoCommerceScreen({super.key, required this.token, required this.merchantInfo});

  @override
  State<InfoCommerceScreen> createState() => _InfoCommerceScreenState();
}

class _InfoCommerceScreenState extends State<InfoCommerceScreen> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _desc;
  final Set<String> _openDays = {};
  TimeOfDay? _open;
  TimeOfDay? _close;
  bool _saving = false;

  // I1 : catégorie
  String? _category;

  // I3 : horaires par jour
  final Map<String, _DaySchedule> _schedules = {};

  // I4 : logo
  File? _logoFile;
  String? _currentLogoUrl;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final m = widget.merchantInfo;
    AppLogger.merchant('InfoCommerceScreen → ouvert pour: ${m['business_name'] ?? '?'}');
    _name = TextEditingController(text: (m['business_name'] ?? '').toString());
    _address = TextEditingController(text: (m['address'] ?? '').toString());
    _phone = TextEditingController(text: (m['phone'] ?? '').toString());
    _website = TextEditingController(text: (m['website'] ?? '').toString());
    _desc = TextEditingController(text: (m['description'] ?? '').toString());
    final od = (m['opening_days'] ?? '').toString();
    if (od.isNotEmpty) _openDays.addAll(od.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    final oh = (m['opening_hours'] ?? '').toString();
    if (oh.isNotEmpty) {
      // Format "HH:MM-HH:MM" (ouverture + fermeture) ou "HH:MM" (ouverture seule)
      final dashIdx = oh.indexOf('-', 1); // ignore un éventuel '-' en position 0
      if (dashIdx > 0) {
        _open  = _parseTime(oh.substring(0, dashIdx));
        _close = _parseTime(oh.substring(dashIdx + 1));
      } else if (!oh.startsWith('-')) {
        _open = _parseTime(oh);
      } else {
        _close = _parseTime(oh.substring(1));
      }
    }
    // I1 : catégorie
    final cat = (m['category'] as String?) ?? '';
    _category = _categories.contains(cat) ? cat : null;
    // I3 : horaires par jour
    final dayHoursRaw = m['day_hours'] as Map?;
    if (dayHoursRaw != null) {
      for (final d in _days) {
        final val = (dayHoursRaw[d] as String?) ?? '';
        if (val.isNotEmpty) _schedules[d] = _DaySchedule.fromJson(val);
      }
    }
    // I4 : logo
    _currentLogoUrl = m['logo_url'] as String?;
  }

  @override
  void dispose() {
    _name.dispose(); _address.dispose(); _phone.dispose();
    _website.dispose(); _desc.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (img == null) return;
    setState(() => _logoFile = File(img.path));
  }

  TimeOfDay? _parseTime(String s) {
    final p = s.trim().split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kError, content: Text('Le nom du commerce est requis')));
      return;
    }
    AppLogger.merchant('InfoCommerceScreen → sauvegarde: nom="${_name.text.trim()}", adresse="${_address.text.trim()}", tél="${_phone.text.trim()}"');
    setState(() => _saving = true);
    final String hours;
    if (_open != null && _close != null) {
      hours = '${_fmt(_open!)}-${_fmt(_close!)}';
    } else if (_open != null) {
      hours = _fmt(_open!);
    } else if (_close != null) {
      hours = '-${_fmt(_close!)}';
    } else {
      hours = '';
    }
    // I4 : upload logo si nouveau fichier
    if (_logoFile != null) {
      setState(() => _uploadingLogo = true);
      final upRes = await ApiService.instance.uploadMerchantLogo(_logoFile!);
      setState(() => _uploadingLogo = false);
      if (mounted && upRes.isOk) _currentLogoUrl = upRes.value;
    }

    // I3 : sérialiser les horaires par jour
    final dayHours = <String, String>{};
    for (final d in _days) {
      final s = _schedules[d];
      if (s != null && !s.isEmpty) dayHours[d] = s.toJson();
    }

    final r = await ApiService.instance.saveMerchantInfo({
      'business_name': _name.text.trim(),
      'address': _address.text.trim(),
      'phone': _phone.text.trim(),
      'website': _website.text.trim(),
      'opening_days': _openDays.toList().join(','),
      'opening_hours': hours,
      'description': _desc.text.trim(),
      if (_category != null) 'category': _category,
      if (dayHours.isNotEmpty) 'day_hours': dayHours,
      if (_currentLogoUrl != null) 'logo_url': _currentLogoUrl,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isOk) {
      AppLogger.merchant('InfoCommerceScreen → sauvegarde ✓');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kSuccess, content: Text('Informations mises à jour ✓')));
      Navigator.pop(context, r.value);
    } else {
      AppLogger.error('InfoCommerceScreen → sauvegarde erreur: ${r.error}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kError, content: Text(r.error ?? 'Erreur')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: Column(children: [
        // Header navy
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 16),
          decoration: const BoxDecoration(color: kNavy),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 17, color: Colors.white),
            ),
            const Text('Informations', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              // I4 : logo en haut
              _logoSection(),
              _label('Nom du commerce'),
              _input(_name, hint: 'Ex : Black & White'),
              // I1 : catégorie
              _label('Catégorie'),
              _categorySelector(),
              _label('Adresse'),
              // I2 : champ adresse avec hint géoloc (sans API externe)
              _addressField(),
              _label('Téléphone'),
              _input(_phone, hint: '+32 71 00 00 00', keyboard: TextInputType.phone),
              _label('Site web'),
              _input(_website, hint: 'https://moncommerce.be', keyboard: TextInputType.url),
              _label("Jours d'ouverture"),
              _daysRow(),
              // I3 : horaires par jour avec pause
              _label('Horaires par jour'),
              _dayScheduleSection(),
              _label('Description courte'),
              _input(_desc, hint: 'Quelques mots sur ton commerce…', lines: 3),
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              )),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 7),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
      );

  Widget _input(TextEditingController c, {String? hint, TextInputType? keyboard, int lines = 1}) => Container(
        decoration: BoxDecoration(
          color: context.cSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cBorder)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: lines,
          style: TextStyle(fontSize: 14, color: context.cText),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13.5, color: context.cSub),
          ),
        ),
      );

  Widget _daysRow() => Wrap(spacing: 7, runSpacing: 7, children: _days.map((d) {
        final on = _openDays.contains(d);
        return GestureDetector(
          onTap: () => setState(() => on ? _openDays.remove(d) : _openDays.add(d)),
          child: Container(
            width: 42, height: 36, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? kPrimary : context.cSurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: on ? kPrimary : context.cBorder)),
            child: Text(d, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                color: on ? Colors.white : context.cSub)),
          ),
        );
      }).toList());

  // ── I4 : Logo ────────────────────────────────────────────────────────────────
  Widget _logoSection() {
    Widget avatar;
    if (_logoFile != null) {
      avatar = ClipRRect(borderRadius: BorderRadius.circular(14),
          child: Image.file(_logoFile!, width: 72, height: 72, fit: BoxFit.cover));
    } else if (_currentLogoUrl != null && _currentLogoUrl!.isNotEmpty) {
      avatar = ClipRRect(borderRadius: BorderRadius.circular(14),
          child: Image.network(_currentLogoUrl!, width: 72, height: 72, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _logoFallback()));
    } else {
      avatar = _logoFallback();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(children: [
        avatar,
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: _uploadingLogo ? null : _pickLogo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _uploadingLogo
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                    : const Icon(Icons.upload_rounded, size: 14, color: kPrimary),
                const SizedBox(width: 6),
                Text(_logoFile != null ? 'Changer' : 'Choisir un logo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text('PNG/JPG · max 512×512px', style: TextStyle(fontSize: 10, color: context.cSub)),
        ]),
      ]),
    );
  }

  Widget _logoFallback() {
    final initials = (_name.text.trim().isNotEmpty ? _name.text.trim() : 'Q').substring(0, 1).toUpperCase();
    return Container(width: 72, height: 72, alignment: Alignment.center,
        decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kPrimary.withValues(alpha: 0.2))),
        child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kPrimary)));
  }

  // ── I1 : Catégorie ────────────────────────────────────────────────────────────
  Widget _categorySelector() => Wrap(
    spacing: 7, runSpacing: 7,
    children: _categories.map((cat) {
      final sel = _category == cat;
      return GestureDetector(
        onTap: () => setState(() => _category = sel ? null : cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? kPrimary : context.cSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? kPrimary : context.cBorder),
          ),
          child: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : context.cSub)),
        ),
      );
    }).toList(),
  );

  // ── I2 : Adresse (champ amélioré) ─────────────────────────────────────────────
  Widget _addressField() => Container(
    decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: TextField(
          controller: _address,
          keyboardType: TextInputType.streetAddress,
          style: TextStyle(fontSize: 14, color: context.cText),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: '14 rue de la Paix, Charleroi',
            hintStyle: TextStyle(fontSize: 13.5, color: context.cSub),
            suffixIcon: Icon(Icons.location_on_outlined, size: 18, color: context.cSub),
          ),
        ),
      ),
    ]),
  );

  // ── I3 : Horaires par jour ──────────────────────────────────────────────────────
  Widget _dayScheduleSection() {
    final activeDays = _openDays.isEmpty ? _days : _days.where((d) => _openDays.contains(d)).toList();
    if (activeDays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text("Sélectionne d'abord tes jours d'ouverture ci-dessus",
            style: TextStyle(fontSize: 11, color: context.cSub)),
      );
    }
    return Column(
      children: activeDays.map((day) {
        final sch = _schedules[day] ?? _DaySchedule();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.cBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(day, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText)),
              const Spacer(),
              if (!sch.isEmpty)
                GestureDetector(
                  onTap: () => setState(() => _schedules.remove(day)),
                  child: Text('Effacer', style: TextStyle(fontSize: 10, color: context.cSub)),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _miniTime(sch.open, 'Ouverture', (t) => setState(() { (_schedules[day] ??= _DaySchedule()).open = t; }))),
              const SizedBox(width: 6),
              Expanded(child: _miniTime(sch.pauseStart, 'Pause début', (t) => setState(() { (_schedules[day] ??= _DaySchedule()).pauseStart = t; }))),
              const SizedBox(width: 6),
              Expanded(child: _miniTime(sch.pauseEnd, 'Pause fin', (t) => setState(() { (_schedules[day] ??= _DaySchedule()).pauseEnd = t; }))),
              const SizedBox(width: 6),
              Expanded(child: _miniTime(sch.close, 'Fermeture', (t) => setState(() { (_schedules[day] ??= _DaySchedule()).close = t; }))),
            ]),
          ]),
        );
      }).toList(),
    );
  }

  Widget _miniTime(TimeOfDay? value, String hint, ValueChanged<TimeOfDay> onPick) => GestureDetector(
    onTap: () async {
      final t = await showTimePicker(
        context: context,
        initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
        builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
      );
      if (t != null) onPick(t);
    },
    child: Container(
      height: 42, alignment: Alignment.center,
      decoration: BoxDecoration(color: context.cBg, borderRadius: BorderRadius.circular(9),
          border: Border.all(color: value != null ? kPrimary.withValues(alpha: 0.5) : context.cBorder)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (value != null)
          Text(_fmt(value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary))
        else
          Icon(Icons.access_time_rounded, size: 14, color: context.cSub),
        Text(hint, style: TextStyle(fontSize: 7.5, color: context.cSub), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

}
