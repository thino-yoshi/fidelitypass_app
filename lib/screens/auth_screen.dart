import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../config/api.dart';
import '../config/app_colors.dart';
import 'client/client_home.dart';
import 'merchant/merchant_home.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF2C7BE5);
const _kError   = Color(0xFFE24B4A);
const _kSuccess = Color(0xFF27AE60);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  Color get _kBg    => context.cBg;
  Color get _kWhite => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText  => context.cText;
  Color get _kSub   => context.cSub;
  Color get _kFill  => context.cFill;

  String screen = 'landing'; // landing | login | register
  String? regType;           // 'client' | 'merchant'

  final prenomCtrl     = TextEditingController();
  final emailCtrl      = TextEditingController();
  final passCtrl       = TextEditingController();
  final codeCtrl       = TextEditingController();
  final loginEmailCtrl = TextEditingController();
  final loginPassCtrl  = TextEditingController();

  bool loading = false;
  bool googleLoading = false;
  String error = '';
  int passScore = 0;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());

  int _checkStrength(String val) {
    int s = 0;
    if (val.length >= 6) s++;
    if (val.length >= 10) s++;
    if (RegExp(r'[A-Z]').hasMatch(val) && RegExp(r'[0-9]').hasMatch(val)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(val)) s++;
    return s;
  }

  Color _strengthColor(int s) {
    switch (s) {
      case 1: return _kError;
      case 2: return const Color(0xFFF59E0B);
      case 3: return _kPrimary;
      case 4: return _kSuccess;
      default: return _kBorder;
    }
  }

  @override
  void dispose() {
    prenomCtrl.dispose(); emailCtrl.dispose(); passCtrl.dispose();
    codeCtrl.dispose(); loginEmailCtrl.dispose(); loginPassCtrl.dispose();
    super.dispose();
  }

  void _navigate(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data['user_type'] == 'merchant') {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => MerchantHome(token: data['token'], merchantName: data['name'])));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ClientHome(token: data['token'], userName: data['name'])));
    }
  }

  Future<void> _doLogin() async {
    if (loginEmailCtrl.text.trim().isEmpty || loginPassCtrl.text.isEmpty) {
      setState(() => error = 'Remplis tous les champs.');
      return;
    }
    setState(() { loading = true; error = ''; });
    try {
      final data = await AuthService.login(loginEmailCtrl.text.trim(), loginPassCtrl.text);
      await AuthService.saveSession(data['token'], data['user_type'], data['name']);
      _navigate(data);
    } catch (e) {
      setState(() => error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _doRegister() async {
    if (prenomCtrl.text.trim().isEmpty || !_isValidEmail(emailCtrl.text) || passCtrl.text.length < 6) {
      setState(() => error = 'Remplis tous les champs correctement.');
      return;
    }
    setState(() { loading = true; error = ''; });
    try {
      final data = await AuthService.register(
        emailCtrl.text.trim(), passCtrl.text,
        prenomCtrl.text.trim(),
        regType == 'merchant' ? 'merchant' : 'client',
        merchantCode: regType == 'merchant' ? codeCtrl.text.trim() : null,
      );
      await AuthService.saveSession(data['token'], data['user_type'], data['name']);
      _navigate(data);
    } catch (e) {
      setState(() => error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _doGoogle() async {
    setState(() { googleLoading = true; error = ''; });
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { setState(() => googleLoading = false); return; }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) { setState(() { error = 'Token introuvable'; googleLoading = false; }); return; }
      final res = await http.post(Uri.parse('$apiUrl/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': idToken}));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await AuthService.saveSession(data['token'], data['user_type'], data['name']);
        await AuthService.saveFCMToken(data['token']);
        _navigate(data);
      } else {
        setState(() => error = jsonDecode(res.body)['detail'] ?? 'Erreur Google');
      }
    } catch (e) {
      setState(() => error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => googleLoading = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: switch (screen) {
          'login'    => _buildLogin(),
          'register' => regType == null ? _buildTypeChoice() : _buildRegisterForm(),
          _          => _buildLanding(),
        },
      ),
    );
  }

  // ─── Landing ───────────────────────────────────────────────────────────────

  Widget _buildLanding() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('Q', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              ),
            ),
            const SizedBox(height: 16),
                    Text('Qarta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _kText)),
            const SizedBox(height: 6),
            Text('Votre programme de fidélité', style: TextStyle(fontSize: 14, color: _kSub)),
            const SizedBox(height: 48),

            // Boutons
            _primaryBtn('Créer un compte', () => setState(() { screen = 'register'; regType = null; error = ''; })),
            const SizedBox(height: 12),
            _outlineBtn('Se connecter', () => setState(() { screen = 'login'; error = ''; })),
            const SizedBox(height: 20),
            _orDivider(),
            const SizedBox(height: 20),
            _googleBtn(),
          ],
        ),
      ),
    );
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  Widget _buildLogin() {
    return Column(
      children: [
        _simpleHeader('Connexion', () => setState(() { screen = 'landing'; error = ''; })),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Email'),
                _field(loginEmailCtrl, 'toi@email.com', type: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _label('Mot de passe'),
                _field(loginPassCtrl, '••••••••', obscure: true),
                if (error.isNotEmpty) ...[const SizedBox(height: 12), _errorBox(error)],
                const SizedBox(height: 24),
                _primaryBtn(loading ? 'Connexion…' : 'Se connecter', loading ? null : _doLogin),
                const SizedBox(height: 16),
                _orDivider(),
                const SizedBox(height: 16),
                _googleBtn(),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() { screen = 'register'; regType = null; error = ''; }),
                    child: Text.rich(TextSpan(
                      text: 'Pas de compte ? ',
                      style: TextStyle(color: _kSub, fontSize: 13),
                      children: const [TextSpan(text: "S'inscrire", style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w600))],
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Register — choix du type ───────────────────────────────────────────────

  Widget _buildTypeChoice() {
    return Column(
      children: [
        _simpleHeader('Créer un compte', () => setState(() { screen = 'landing'; error = ''; })),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu es…', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kText)),
                const SizedBox(height: 8),
                Text('Choisis ton type de compte.', style: TextStyle(fontSize: 14, color: _kSub)),
                const SizedBox(height: 32),
                _typeCard(
                  icon: Icons.person_outline,
                  title: 'Client',
                  subtitle: 'Collectionne des tampons et débloque des récompenses',
                  selected: regType == 'client',
                  onTap: () => setState(() => regType = 'client'),
                ),
                const SizedBox(height: 12),
                _typeCard(
                  icon: Icons.store_outlined,
                  title: 'Commerçant',
                  subtitle: 'Crée et gérez votre programme de fidélité',
                  selected: regType == 'merchant',
                  onTap: () => setState(() => regType = 'merchant'),
                ),
                const Spacer(),
                _primaryBtn('Continuer', regType == null ? null : () => setState(() {})),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Register — formulaire ─────────────────────────────────────────────────

  Widget _buildRegisterForm() {
    return Column(
      children: [
        _simpleHeader(
          regType == 'merchant' ? 'Inscription Commerçant' : 'Inscription Client',
          () => setState(() { regType = null; error = ''; }),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Prénom / Nom'),
                _field(prenomCtrl, 'Sophie Martin'),
                const SizedBox(height: 16),
                _label('Email'),
                _field(emailCtrl, 'toi@email.com', type: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _label('Mot de passe'),
                StatefulBuilder(builder: (_, ss) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(passCtrl, '••••••••', obscure: true, onChanged: (v) => ss(() => passScore = _checkStrength(v))),
                    if (passScore > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: passScore / 4,
                          minHeight: 4,
                          backgroundColor: _kBorder,
                          color: _strengthColor(passScore),
                        ),
                      ),
                    ],
                  ],
                )),
                if (regType == 'merchant') ...[
                  const SizedBox(height: 16),
                  _label('Code partenaire (optionnel)'),
                  _field(codeCtrl, 'CODE123'),
                ],
                if (error.isNotEmpty) ...[const SizedBox(height: 12), _errorBox(error)],
                const SizedBox(height: 24),
                _primaryBtn(loading ? 'Inscription…' : 'Créer mon compte', loading ? null : _doRegister),
                const SizedBox(height: 16),
                _orDivider(),
                const SizedBox(height: 16),
                _googleBtn(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shared widgets ────────────────────────────────────────────────────────

  Widget _simpleHeader(String title, VoidCallback onBack) {
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: _kText), onPressed: onBack),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: _kText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _kSub),
        filled: true,
        fillColor: _kFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _kPrimary, width: 1.5)),
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kPrimary.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kPrimary,
          side: const BorderSide(color: _kPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _googleBtn() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: googleLoading ? null : _doGoogle,
        icon: googleLoading
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _kSub))
            : Icon(Icons.g_mobiledata, size: 22, color: _kSub),
        label: Text('Continuer avec Google', style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _kBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(children: [
      Expanded(child: Divider(color: _kBorder)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('ou', style: TextStyle(color: _kSub.withOpacity(0.7), fontSize: 12)),
      ),
      Expanded(child: Divider(color: _kBorder)),
    ]);
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kError.withOpacity(0.08),
        border: Border.all(color: _kError.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg, style: const TextStyle(color: _kError, fontSize: 13)),
    );
  }

  Widget _typeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _kPrimary : _kBorder, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: selected ? _kPrimary.withOpacity(0.1) : _kFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: selected ? _kPrimary : _kSub, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: selected ? _kPrimary : _kText)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: _kSub)),
              ]),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: _kPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}
