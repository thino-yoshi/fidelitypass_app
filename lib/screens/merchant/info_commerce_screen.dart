import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

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

  @override
  void initState() {
    super.initState();
    final m = widget.merchantInfo;
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
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _website.dispose();
    _desc.dispose();
    super.dispose();
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
    final r = await ApiService.instance.saveMerchantInfo({
      'business_name': _name.text.trim(),
      'address': _address.text.trim(),
      'phone': _phone.text.trim(),
      'website': _website.text.trim(),
      'opening_days': _openDays.toList().join(','),
      'opening_hours': hours,
      'description': _desc.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kSuccess, content: Text('Informations mises à jour ✓')));
      Navigator.pop(context, r.value);
    } else {
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
              _label('Nom du commerce'),
              _input(_name, hint: 'Ex : Black & White'),
              _label('Adresse'),
              _input(_address, hint: '14 rue de la Paix, Charleroi'),
              _label('Téléphone'),
              _input(_phone, hint: '+32 71 00 00 00', keyboard: TextInputType.phone),
              _label('Site web'),
              _input(_website, hint: 'https://moncommerce.be', keyboard: TextInputType.url),
              _label("Jours d'ouverture"),
              _daysRow(),
              _label('Horaires'),
              _hoursRow(),
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

  Widget _hoursRow() => Row(children: [
        Expanded(child: _timeField(_open, 'Ouverture', (t) => setState(() => _open = t))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('–', style: TextStyle(color: context.cSub))),
        Expanded(child: _timeField(_close, 'Fermeture', (t) => setState(() => _close = t))),
      ]);

  Widget _timeField(TimeOfDay? value, String hint, ValueChanged<TimeOfDay> onPick) => GestureDetector(
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
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: context.cSurface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cBorder)),
          child: Row(children: [
            Icon(Icons.access_time_rounded, size: 16, color: context.cSub),
            const SizedBox(width: 8),
            Text(value != null ? _fmt(value) : hint,
                style: TextStyle(fontSize: 14, color: value != null ? context.cText : context.cSub)),
          ]),
        ),
      );
}
