import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _push = true;
  bool _offres = true;
  bool _visites = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _push    = p.getBool('notif_push')    ?? true;
      _offres  = p.getBool('notif_offres')  ?? true;
      _visites = p.getBool('notif_visites') ?? false;
    });
  }

  Future<void> _save() async {
    // 1. Sauvegarde locale
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_push',    _push);
    await p.setBool('notif_offres',  _offres);
    await p.setBool('notif_visites', _visites);

    // 2. Sync via API (contourne les RLS Supabase côté client)
    try {
      await AuthService.authPut('/notifications/preferences', '', {
        'notif_push':    _push,
        'notif_offres':  _offres,
        'notif_visites': _visites,
      });
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Préférences enregistrées ✓'),
        backgroundColor: Color(0xFF2C7BE5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E35) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notifications',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F2044),
                  )),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded,
                    size: 20, color: isDark ? Colors.white54 : Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choisis comment tu veux être prévenu de ton activité fidélité.',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF4A9EFF) : const Color(0xFF0F2044)),
          ),
          const SizedBox(height: 16),
          _notifTile(
            iconBg: const Color(0xFFE8F1FD),
            icon: Icons.notifications_outlined,
            iconColor: const Color(0xFF2C7BE5),
            label: 'Push',
            sub: 'Alertes sur ton téléphone',
            value: _push,
            onChanged: (v) => setState(() => _push = v),
          ),
          _notifTile(
            iconBg: const Color(0xFFE4F5EB),
            icon: Icons.local_offer_outlined,
            iconColor: const Color(0xFF27AE60),
            label: 'Offres',
            sub: 'Promos et offres des commerces',
            value: _offres,
            onChanged: (v) => setState(() => _offres = v),
          ),
          _notifTile(
            iconBg: const Color(0xFFF5E8FD),
            icon: Icons.place_outlined,
            iconColor: const Color(0xFF7C3AED),
            label: 'Visites',
            sub: 'Rappel après un passage en caisse',
            value: _visites,
            onChanged: (v) => setState(() => _visites = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C7BE5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifTile({
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1828))),
                Text(sub, style: TextStyle(fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF888888))),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2C7BE5),
          ),
        ],
      ),
    );
  }
}
