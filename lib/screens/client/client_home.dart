import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/widget_service.dart';
import '../../config/api.dart';
import '../../main.dart';
import '../auth_screen.dart';
import 'cards_tab.dart';
import 'history_tab.dart';
import 'rewards_tab.dart';
import 'client_scanner_screen.dart';
import '../../config/app_colors.dart';
import '../../services/program_config_service.dart';

class ClientHome extends StatefulWidget {
  final String token;
  final String userName;
  const ClientHome({super.key, required this.token, required this.userName});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> with TickerProviderStateMixin {
  int _tab = 0; // 0=cartes, 1=scan, 2=historique, 3=profil
  int _cardCount = 0;
  int _totalStamps = 0;
  int _rewardCount = 0;
  int _notifCount = 3;
  List<dynamic> _cards = [];
  bool _statsLoaded = false;
  bool _notifOpen = false;
  late AnimationController _notifAnim;

  List<Map> _notifs = [];
  bool _notifsLoaded = false;
  String _notifFilter = 'tout';

  String? _profileImagePath;  // fichier local (avant upload / fallback)
  String? _profileImageUrl;   // URL serveur (Supabase Storage)
  String  _userEmail = '';
  String  _phone = '';
  bool    _isGoogle = false; // 'tout' | 'tampon' | 'recompense' | 'promo'

  static const Map<String, Map<String, dynamic>> _notifStyle = {
    'recompense': {'icon': '⭐', 'color': 0xFFFBBF24},
    'tampon':     {'icon': '✓',  'color': 0xFF2C7BE5},
    'promo':      {'icon': '→',  'color': 0xFF27AE60},
    'targeted':   {'icon': '→',  'color': 0xFF27AE60},
    'scheduled':  {'icon': '→',  'color': 0xFF27AE60},
  };

  @override
  void initState() {
    super.initState();
    _notifAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadStats();
    _loadNotifs();
    _loadProfileImage();
    _loadPhone();
    _loadSessionInfo();
  }

  Future<void> _loadProfileImage() async {
    // 1. Charger l'image locale en cache (affichage immédiat)
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (path != null && File(path).existsSync() && mounted) {
      setState(() => _profileImagePath = path);
    }
    // 2. Charger l'URL distante + email depuis /users/me
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/users/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final url      = body['profile_picture_url'] as String?;
        final email    = body['email'] as String? ?? '';
        final isGoogle = body['is_google'] as bool? ?? false;
        setState(() {
          if (url != null && url.isNotEmpty) _profileImageUrl = url;
          _userEmail = email;
          _isGoogle  = isGoogle;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? '';
    if (mounted) setState(() => _phone = phone);
  }

  Future<void> _loadSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email    = prefs.getString('email') ?? '';
    final isGoogle = prefs.getBool('is_google') ?? false;
    if (mounted) setState(() {
      if (email.isNotEmpty) _userEmail = email;
      _isGoogle = isGoogle;
    });
  }

  void _showPersonalInfo() {
    const blue = Color(0xFF2C7BE5);

    // Champs éditables
    final nameCtrl  = TextEditingController(text: widget.userName);
    final emailCtrl = TextEditingController(text: _userEmail);
    final phoneCtrl = TextEditingController(text: _phone);

    // Quel champ est en cours d'édition ? null = aucun
    String? editingField; // 'name' | 'email' | 'phone'
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bg  = isDark ? const Color(0xFF1E1D2A) : Colors.white;
          final sub = isDark ? Colors.white54 : Colors.black45;

          // ── champ éditable ─────────────────────────────────────────────
          Widget editableRow({
            required IconData icon,
            required String fieldKey,
            required String label,
            required TextEditingController ctrl,
            TextInputType keyboard = TextInputType.text,
            bool readOnly = false,
          }) {
            final isEditing = editingField == fieldKey;
            return Container(
              decoration: BoxDecoration(
                color: blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: blue.withOpacity(isEditing ? 0.45 : 0.12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: blue.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: blue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isEditing
                        ? TextField(
                            controller: ctrl,
                            autofocus: true,
                            keyboardType: keyboard,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: label,
                              hintStyle: TextStyle(color: sub),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: TextStyle(fontSize: 11, color: sub)),
                              Text(
                                ctrl.text.isEmpty ? 'Non renseigné' : ctrl.text,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15,
                                  color: ctrl.text.isEmpty ? sub : null,
                                ),
                              ),
                            ],
                          ),
                  ),
                  // Icône d'édition — masquée pour Google (sauf téléphone)
                  if (!readOnly)
                    isEditing
                        ? IconButton(
                            icon: const Icon(Icons.check_rounded, color: blue, size: 20),
                            onPressed: () => setS(() => editingField = null),
                          )
                        : IconButton(
                            icon: const Icon(Icons.edit_rounded, color: blue, size: 18),
                            onPressed: () => setS(() => editingField = fieldKey),
                          )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock_outline_rounded, color: sub, size: 16),
                    ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Flexible(
                        child: Text('Informations personnelles', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                      ),
                      if (_isGoogle) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Compte Google', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  if (_isGoogle)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text('Nom et email gérés par Google', style: TextStyle(fontSize: 12, color: sub)),
                    ),
                  const SizedBox(height: 16),

                  // Nom
                  editableRow(
                    icon: Icons.person_rounded,
                    fieldKey: 'name',
                    label: 'Nom & Prénom',
                    ctrl: nameCtrl,
                    readOnly: _isGoogle,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  editableRow(
                    icon: Icons.email_outlined,
                    fieldKey: 'email',
                    label: 'Email',
                    ctrl: emailCtrl,
                    keyboard: TextInputType.emailAddress,
                    readOnly: _isGoogle,
                  ),
                  const SizedBox(height: 12),

                  // Téléphone (toujours éditable, local)
                  editableRow(
                    icon: Icons.phone_outlined,
                    fieldKey: 'phone',
                    label: 'Téléphone',
                    ctrl: phoneCtrl,
                    keyboard: TextInputType.phone,
                    readOnly: false,
                  ),
                  const SizedBox(height: 24),

                  // Bouton Enregistrer
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        setS(() => saving = true);
                        // Sauvegarder téléphone localement
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('user_phone', phoneCtrl.text.trim());

                        // Mettre à jour nom/email sur le serveur (sauf Google)
                        if (!_isGoogle) {
                          try {
                            final res = await http.patch(
                              Uri.parse('$apiUrl/users/me'),
                              headers: {
                                'Authorization': 'Bearer ${widget.token}',
                                'Content-Type': 'application/json',
                              },
                              body: jsonEncode({
                                'name':  nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                              }),
                            );
                            if (res.statusCode == 200 && mounted) {
                              final updated = jsonDecode(res.body);
                              setState(() {
                                _userEmail = updated['email'] ?? _userEmail;
                                // Met à jour aussi le nom dans la session
                                SharedPreferences.getInstance().then((p) => p.setString('name', updated['name'] ?? widget.userName));
                              });
                            }
                          } catch (_) {}
                        }

                        if (mounted) setState(() => _phone = phoneCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value, required Color sub}) {
    const blue = Color(0xFF2C7BE5);
    return Container(
      decoration: BoxDecoration(
        color: blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blue.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: blue.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: blue, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: sub)),
              Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    // Affichage local immédiat
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', picked.path);
    if (mounted) setState(() => _profileImagePath = picked.path);

    // Upload vers le serveur
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/users/profile-picture'),
      )
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..files.add(await http.MultipartFile.fromPath('file', picked.path));
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200 && mounted) {
        final url = jsonDecode(res.body)['profile_picture_url'] as String?;
        if (url != null) setState(() => _profileImageUrl = url);
      }
    } catch (_) {}
  }

  Future<void> _loadNotifs() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/notifications/client'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as List;
        final mapped = data.map((n) {
          final type = n['type'] as String? ?? 'promo';
          final style = _notifStyle[type] ?? _notifStyle['promo']!;
          final dt = DateTime.tryParse(n['created_at'] as String? ?? '')?.toLocal();
          final time = dt != null
              ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
              : '';
          return {
            'id': n['id'],
            'icon': style['icon'],
            'commerce': n['merchant_name'] ?? '',
            'title': n['title'] ?? '',
            'body': n['body'] ?? '',
            'time': time,
            'color': style['color'],
            'read': n['read'] ?? false,
            'type': type,
          };
        }).toList();
        setState(() { _notifs = mapped; _notifsLoaded = true; });
        _updateNotifCount();
      }
    } catch (_) {}
  }

  void _updateNotifCount() {
    setState(() => _notifCount = _notifs.where((n) => !(n['read'] as bool)).length);
  }

  @override
  void dispose() {
    _notifAnim.dispose();
    super.dispose();
  }

  void _openProfil() {
    setState(() => _tab = 3);
  }

  Future<void> _loadStats() async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final raw = jsonDecode(res.body) as List;

        // Enrichir chaque carte avec la config locale (program_type, points, etc.)
        final data = await Future.wait(raw.map((card) async {
          final c = Map<String, dynamic>.from(card as Map);
          final merchant = c['merchants'];
          if (merchant != null) {
            final merchantId = merchant['id']?.toString() ?? '';
            if (merchantId.isNotEmpty) {
              c['merchants'] = await ProgramConfigService.overlay(merchant as Map);
              // DEBUG — à supprimer après vérification
              final enriched = c['merchants'] as Map?;
              debugPrint('[DEBUG] merchant=$merchantId type=${enriched?['program_type']}');
            }
          }
          return c;
        }));

        int stamps = 0;
        int rewards = 0;
        for (final c in data) {
          final val = c['stamps_count'] as int? ?? 0;
          stamps += val;
          final type = c['merchants']?['program_type'] as String? ?? 'stamps';
          final req = type == 'points'
              ? (c['merchants']?['points_required'] as int? ?? 100)
              : (c['merchants']?['stamps_required'] as int? ?? 10);
          if (val >= req) rewards++;
        }

        if (!mounted) return;
        setState(() {
          _cards = data;
          _cardCount = data.length;
          _totalStamps = stamps;
          _rewardCount = rewards;
          _statsLoaded = true;
        });
        WidgetService.updateFromCards(data);
      }
    } catch (_) {}
  }

  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool loading = false;
    const blue = Color(0xFF2C7BE5);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Changer le mot de passe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe actuel')),
              const SizedBox(height: 12),
              TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                try {
                  final res = await http.put(
                    Uri.parse('$apiUrl/users/change-password'),
                    headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
                    body: jsonEncode({'current_password': currentCtrl.text, 'new_password': newCtrl.text}),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res.statusCode == 200 ? 'Mot de passe mis à jour !' : jsonDecode(res.body)['detail'] ?? 'Erreur'),
                    backgroundColor: res.statusCode == 200 ? blue : Colors.red,
                  ));
                } catch (_) { setDialogState(() => loading = false); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white),
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccount() {
    final passCtrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Supprimer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFE24B4A))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cette action est irréversible. Toutes tes cartes et données seront supprimées.', style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirme ton mot de passe')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                try {
                  final res = await http.delete(
                    Uri.parse('$apiUrl/users/account'),
                    headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
                    body: jsonEncode({'password': passCtrl.text}),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (res.statusCode == 200) _logout();
                  else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(res.body)['detail'] ?? 'Erreur'), backgroundColor: Colors.red));
                  }
                } catch (_) { setDialogState(() => loading = false); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE24B4A), foregroundColor: Colors.white),
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _openNotifs() {
    setState(() => _notifOpen = true);
    _notifAnim.forward();
  }

  void _closeNotifs() {
    _notifAnim.reverse().then((_) {
      if (mounted) setState(() => _notifOpen = false);
    });
  }

  void _markAllRead() {
    setState(() {
      for (var n in _notifs) n['read'] = true;
      _notifCount = 0;
    });
    http.put(
      Uri.parse('$apiUrl/notifications/client/read-all'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
  }

  String get _firstName {
    final parts = widget.userName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : widget.userName;
  }

  String get _initials {
    final parts = widget.userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.qBg,
        extendBody: true,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildTabContent()),
              ],
            ),
            _buildBottomNav(),
            if (_notifOpen) _buildNotifOverlay(),
          ],
        ),
      ),
    );
  }

  // ── HEADER (inclut les pills) ──────────────────────────────────────────────

  Widget _buildHeader() {
    final cartesActive = _tab == 0;
    final histoActive = _tab == 2;
    return Container(
      color: context.qNavy,
      child: Stack(
        children: [
          // Logo Q en filigrane (comme sur Figma : hgrid background-image)
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: Image.asset(
                'assets/images/89.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Orbe lumineux
          Positioned(
            top: -20, right: -10,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF2C7BE5).withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          // Contenu
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 14,
              left: 20, right: 20, bottom: 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ligne avatar + notifs
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openProfil(),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2C7BE5).withOpacity(0.30),
                              border: Border.all(color: const Color(0xFF4A9EFF).withOpacity(0.45), width: 2),
                              image: _profileImageUrl != null
                                  ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                                  : _profileImagePath != null
                                      ? DecorationImage(image: FileImage(File(_profileImagePath!)), fit: BoxFit.cover)
                                      : null,
                            ),
                            child: (_profileImageUrl == null && _profileImagePath == null)
                                ? Center(child: Text(_initials, style: const TextStyle(color: Color(0xFF4A9EFF), fontSize: 13, fontWeight: FontWeight.w700)))
                                : null,
                          ),
                          const SizedBox(width: 9),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bonjour 👋', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, height: 1)),
                              const SizedBox(height: 2),
                              Text(_firstName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Bouton notifs
                    GestureDetector(
                      onTap: _openNotifs,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Icon(Icons.notifications_outlined, color: Colors.white.withOpacity(0.8), size: 18),
                          ),
                          if (_notifCount > 0)
                            Positioned(
                              top: -2, right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE24B4A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.qNavy, width: 2),
                                ),
                                child: Center(
                                  child: Text('$_notifCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Sous-titre
                Text(
                  _statsLoaded
                      ? '$_cardCount carte${_cardCount > 1 ? 's' : ''} active${_cardCount > 1 ? 's' : ''} · $_rewardCount récompense${_rewardCount > 1 ? 's' : ''} disponible${_rewardCount > 1 ? 's' : ''}'
                      : '···',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
                const SizedBox(height: 16),
                // ── Pills (dans le même header, même grille)
                Row(
                  children: [
                    _sumPill(
                      val: '$_cardCount',
                      label: _cardCount > 1 ? 'Cartes' : 'Carte',
                      isActive: cartesActive,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    const SizedBox(width: 8),
                    _sumPill(
                      val: '$_rewardCount',
                      label: _rewardCount > 1 ? 'Récompenses' : 'Récompense',
                      isActive: histoActive,
                      onTap: () {
                        final headerH = MediaQuery.of(context).padding.top + 14 + 38 + 10 + 28 + 10 + 44 + 18; // hauteur approx du header
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SizedBox(
                            height: MediaQuery.of(context).size.height - headerH,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: RewardsPage(
                                token: widget.token,
                                cards: _cards,
                                onStampAdded: () {
                                  _loadStats();
                                  setState(() => _tab = 0);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumPill({
    required String val,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2C7BE5).withOpacity(0.18) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF4A9EFF).withOpacity(0.55) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                val,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(isActive ? 0.9 : 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB CONTENT ────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return CardsTab(token: widget.token, cards: _cards, onRefresh: _loadStats);
      case 1:
        return ClientScannerScreen(token: widget.token, embedded: true);
      case 2:
        return HistoryTab(token: widget.token);
      case 3:
        return _buildProfilTab();
      default:
        return CardsTab(token: widget.token, cards: _cards, onRefresh: _loadStats);
    }
  }

  // ── PROFIL TAB ─────────────────────────────────────────────────────────────

  Widget _buildProfilTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          // ── Avatar profil ──────────────────────────────────────────────────
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              children: [
                Container(
                  width: 86, height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2C7BE5).withOpacity(0.15),
                    border: Border.all(color: const Color(0xFF2C7BE5).withOpacity(0.35), width: 2.5),
                    image: _profileImageUrl != null
                        ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                        : _profileImagePath != null
                            ? DecorationImage(image: FileImage(File(_profileImagePath!)), fit: BoxFit.cover)
                            : null,
                  ),
                  child: (_profileImageUrl == null && _profileImagePath == null)
                      ? Center(child: Text(_initials, style: const TextStyle(color: Color(0xFF2C7BE5), fontSize: 28, fontWeight: FontWeight.w800)))
                      : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2C7BE5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 18),
          // Section 1: compte
          _profSec([
            _profRow(
              iconBg: const Color(0xFFE8F1FD),
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF2C7BE5),
              label: 'Informations personnelles',
              sub: 'Nom, email, téléphone',
              onTap: _showPersonalInfo,
            ),
            if (!_isGoogle)
              _profRow(
                iconBg: const Color(0xFFFEF3C7),
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Changer le mot de passe',
                sub: 'Sécurité du compte',
                onTap: _showChangePassword,
              ),
            _profRow(
              iconBg: const Color(0xFFE4F5EB),
              icon: Icons.credit_card_outlined,
              iconColor: const Color(0xFF27AE60),
              label: 'Mes cartes',
              sub: 'Gérer et supprimer',
              onTap: () => setState(() => _tab = 0),
            ),
          ]),
          const SizedBox(height: 10),
          // Section 2: préférences
          _profSec([
            _profRowDarkMode(),
            _profRow(
              iconBg: const Color(0xFFF4F2EE),
              icon: Icons.help_outline_rounded,
              iconColor: const Color(0xFF888888),
              label: 'Aide & Support',
              sub: 'FAQ, nous contacter',
            ),
          ]),
          const SizedBox(height: 14),
          // Bouton déconnexion
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(
                color: context.qSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE8E7), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFE24B4A), size: 16),
                  SizedBox(width: 8),
                  Text('Se déconnecter', style: TextStyle(color: Color(0xFFE24B4A), fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Bouton suppression
          GestureDetector(
            onTap: _showDeleteAccount,
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.qBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, color: context.qSub, size: 15),
                  const SizedBox(width: 6),
                  Text('Supprimer mon compte', style: TextStyle(color: context.qSub, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profSec(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: context.qSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.qBorder),
      ),
      child: Column(children: rows),
    );
  }

  Widget _profRow({
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sub,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.qDivider)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
                  Text(sub, style: TextStyle(fontSize: 11, color: context.qSub)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: context.qMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _profRowDarkMode() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.qDivider))),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1828),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dark_mode_outlined, color: Color(0xFF4A9EFF), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mode sombre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
                  Text("Thème de l'interface", style: TextStyle(fontSize: 11, color: context.qSub)),
                ],
              ),
            ),
            Switch(
              value: mode == ThemeMode.dark,
              onChanged: (val) async {
                themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                final p = await SharedPreferences.getInstance();
                await p.setBool('dark_mode', val);
              },
              activeColor: const Color(0xFF2C7BE5),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // Couleurs exactes Figma : --nav-bg #ffffffb3 (blanc 70%), --nav-border #ede9e380 (50%)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark
        ? const Color(0xFF1E1D2A).withOpacity(0.70)
        : Colors.white.withOpacity(0.70);
    final navBorder = isDark
        ? const Color(0xFF2A2840).withOpacity(0.50)
        : const Color(0xFFEDE9E3).withOpacity(0.50);

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 76 + bottomPad,
            decoration: BoxDecoration(
              color: navBg,
              border: Border(top: BorderSide(color: navBorder, width: 1)),
            ),
            padding: EdgeInsets.only(bottom: bottomPad + 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _navItem(Icons.credit_card_outlined, 'Cartes', 0),
                _navFab(),
                _navItem(Icons.history_rounded, 'Historique', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? const Color(0xFF2C7BE5) : context.qNavInactive, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF2C7BE5) : context.qNavInactive,
            )),
          ],
        ),
      ),
    );
  }

  Widget _navFab() {
    final active = _tab == 1;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: active ? const Color(0xFF1A5FBF) : const Color(0xFF2C7BE5),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: const Color(0xFF2C7BE5).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: Colors.black, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  // ── NOTIF OVERLAY ──────────────────────────────────────────────────────────

  Widget _buildNotifOverlay() {
    return AnimatedBuilder(
      animation: _notifAnim,
      builder: (_, __) => Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: _closeNotifs,
            child: Container(color: Colors.black.withOpacity(0.4 * _notifAnim.value)),
          ),
          // Sheet
          Positioned(
            top: 0, left: 0, right: 0,
            child: FractionalTranslation(
              translation: Offset(0, -1 + _notifAnim.value),
              child: Container(
                decoration: BoxDecoration(
                  color: context.qSurface,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      color: const Color(0xFF0B1220),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 20, right: 20, bottom: 16,
                      ),
                      child: Row(
                        children: [
                          const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          TextButton(
                            onPressed: _markAllRead,
                            child: const Text('Tout lu', style: TextStyle(color: Color(0xFF4A9EFF), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          GestureDetector(
                            onTap: _closeNotifs,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Filtres
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in [
                              {'key': 'tout', 'label': 'Tout'},
                              {'key': 'tampon', 'label': '✓ Tampons'},
                              {'key': 'recompense', 'label': '⭐ Récompenses'},
                              {'key': 'promo', 'label': '→ Promos'},
                            ]) ...[
                              GestureDetector(
                                onTap: () => setState(() => _notifFilter = f['key']!),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _notifFilter == f['key'] ? const Color(0xFF2C7BE5) : context.qBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    f['label']!,
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: _notifFilter == f['key'] ? Colors.white : context.qChipText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: Text("Aujourd'hui", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.06)),
                            ),
                            ...(_notifFilter == 'tout' ? _notifs : _notifs.where((n) => n['type'] == _notifFilter).toList()).map((n) => _notifItem(n)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifItem(Map n) {
    final color = Color(n['color'] as int);
    final unread = !(n['read'] as bool);
    return GestureDetector(
      onTap: () {
        setState(() {
          n['read'] = true;
          _notifCount = _notifs.where((x) => !(x['read'] as bool)).length;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.qDivider),
            left: unread ? BorderSide(color: color, width: 3) : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(20, 20),
                  painter: _NotifIconPainter(type: n['type'] as String, color: color),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(n['commerce'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.qText)),
                      Text(n['time'], style: TextStyle(fontSize: 10, color: context.qSub)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n['title'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.qText)),
                  const SizedBox(height: 2),
                  Text(n['body'], style: TextStyle(fontSize: 11, color: context.qSub, height: 1.4)),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

/// Reproduit exactement les icônes SVG du Figma pour chaque type de notification
class _NotifIconPainter extends CustomPainter {
  final String type;
  final Color color;
  const _NotifIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18; // facteur d'échelle (viewport Figma = 18×18)
    switch (type) {
      case 'tampon':
      case 'stamp':
        _drawStamp(canvas, s);
        break;
      case 'recompense':
      case 'reward':
        _drawReward(canvas, s);
        break;
      case 'promo':
      case 'targeted':
      case 'scheduled':
        _drawPromo(canvas, s);
        break;
      default:
        _drawReview(canvas, s);
    }
  }

  // ── stamp: carré arrondi + coche ─────────────────────────────────────────
  void _drawStamp(Canvas canvas, double s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Rounded rect (rx=4)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2 * s, 2 * s, 14 * s, 14 * s),
        Radius.circular(4 * s),
      ),
      p,
    );
    // Coche : M6 9 l2.5 2.5 l4 -4
    final check = Path()
      ..moveTo(6 * s, 9 * s)
      ..lineTo(8.5 * s, 11.5 * s)
      ..lineTo(12.5 * s, 7.5 * s);
    canvas.drawPath(check, p);
  }

  // ── reward: cercle plein + étoile blanche ────────────────────────────────
  void _drawReward(Canvas canvas, double s) {
    // Cercle plein
    canvas.drawCircle(
      Offset(9 * s, 9 * s),
      8.5 * s,
      Paint()..color = color,
    );
    // Étoile 5 branches blanche centrée
    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    const points = 5;
    const outerR = 4.5;
    const innerR = 2.0;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = -pi / 2 + (pi * i / points);
      final x = 9 * s + r * s * cos(angle);
      final y = 9 * s + r * s * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, starPaint);
  }

  // ── promo: % (2 petits cercles + diagonale) ──────────────────────────────
  void _drawPromo(Canvas canvas, double s) {
    final p = Paint()..color = color;
    canvas.drawCircle(Offset(5 * s, 5 * s), 1.5 * s, p);
    canvas.drawCircle(Offset(13 * s, 13 * s), 1.5 * s, p);
    canvas.drawLine(
      Offset(4 * s, 14 * s),
      Offset(14 * s, 4 * s),
      Paint()
        ..color = color
        ..strokeWidth = 1.8 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── review: bulle de commentaire avec étoile ─────────────────────────────
  void _drawReview(Canvas canvas, double s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Bulle arrondie simplifiée
    final bubble = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(1 * s, 1 * s, 14 * s, 11 * s),
        Radius.circular(3 * s),
      ));
    canvas.drawPath(bubble, p);
    // Pointe de bulle
    canvas.drawLine(Offset(5 * s, 12 * s), Offset(3 * s, 16 * s), p);
    // Petite étoile au centre
    final starPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final star = Path();
    const points = 5;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? 3.0 : 1.3;
      final angle = -pi / 2 + (pi * i / points);
      final x = 9 * s + r * s * cos(angle);
      final y = 6.5 * s + r * s * sin(angle);
      if (i == 0) star.moveTo(x, y); else star.lineTo(x, y);
    }
    star.close();
    canvas.drawPath(star, starPaint);
  }

  @override
  bool shouldRepaint(_NotifIconPainter old) => old.type != type || old.color != color;
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A82F6).withOpacity(0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;
  const _CornerPainter({required this.isLeft, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2C7BE5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? size.width : -size.width;
    final dy = isTop ? size.height : -size.height;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}