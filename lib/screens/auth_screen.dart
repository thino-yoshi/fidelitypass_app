import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../config/api.dart';
import 'client/client_home.dart';
import 'merchant/merchant_home.dart';
import 'merchant_redirect_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class CardData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  CardData({required this.title, required this.description, required this.icon, required this.color});
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {

  static const kBg   = Color(0xFF0D1526);
  static const kBlue = Color(0xFF4A9EFF);
  static const kDark = Color(0xFF0D1526);

  String screen = 'landing';
  int regStep = 1;
  String? regType;
  bool _isValidEmail(String email) =>
      RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());

  final prenomCtrl     = TextEditingController();
  final emailCtrl      = TextEditingController();
  final passCtrl       = TextEditingController();
  final codeCtrl       = TextEditingController();
  final loginEmailCtrl = TextEditingController();
  final loginPassCtrl  = TextEditingController();
  final nomCtrl        = TextEditingController();

  bool loading = false;
  bool googleLoading = false;
  String error = '';
  int passScore = 0;

  late AnimationController _orbCtrl;
  late Animation<double> _orbOpacity;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool _isTablet(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 600;
  double _maxW(BuildContext ctx) => _isTablet(ctx) ? 480.0 : double.infinity;
  double _fs(BuildContext ctx, double phone, {double? tablet}) =>
      _isTablet(ctx) ? (tablet ?? phone * 1.2) : phone;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true);
    _orbOpacity = Tween(begin: 0.15, end: 0.26).animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    prenomCtrl.dispose(); emailCtrl.dispose(); passCtrl.dispose(); codeCtrl.dispose();
    loginEmailCtrl.dispose(); loginPassCtrl.dispose(); nomCtrl.dispose();
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

  int _checkStrength(String val) {
    int score = 0;
    if (val.length >= 6) score++;
    if (val.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(val) && RegExp(r'[0-9]').hasMatch(val)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(val)) score++;
    return score;
  }

  Color _strengthColor(int score) {
    switch (score) {
      case 1: return const Color(0xFFE24B4A);
      case 2: return const Color(0xFFF59E0B);
      case 3: return kBlue;
      case 4: return const Color(0xFF22C55E);
      default: return Colors.white12;
    }
  }

  String _strengthLabel(int score) {
    switch (score) {
      case 1: return 'Trop court';
      case 2: return 'Moyen';
      case 3: return 'Bon';
      case 4: return 'Excellent';
      default: return 'Force du mot de passe';
    }
  }

  Future<void> _doLogin() async {
    setState(() { loading = true; error = ''; });
    try {
      final data = await AuthService.login(loginEmailCtrl.text.trim(), loginPassCtrl.text);
      await AuthService.saveSession(data['token'], data['user_type'], data['name'],
          email: loginEmailCtrl.text.trim());
      _navigate(data);
    } catch (e) {
      setState(() { error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _doRegister() async {
    setState(() { loading = true; error = ''; });
    try {
      final data = await AuthService.register(
        emailCtrl.text.trim(), passCtrl.text,
        prenomCtrl.text.trim(),
        regType == 'merchant' ? 'merchant' : 'client',
        merchantCode: regType == 'merchant' ? codeCtrl.text.trim() : null,
      );
      await AuthService.saveSession(data['token'], data['user_type'], data['name'],
          email: emailCtrl.text.trim());
      _navigate(data);
    } catch (e) {
      setState(() { error = e.toString().replaceAll('Exception: ', ''); });
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
        await AuthService.saveSession(data['token'], data['user_type'], data['name'],
            email: data['email'] ?? googleUser.email, isGoogle: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
        child: screen == 'landing' ? _buildLanding()
            : screen == 'login'   ? _buildLogin()
            : _buildRegister(),
      ),
    );
  }

  // ═══════════════════════════════════════
  // LANDING
  // ═══════════════════════════════════════
  Widget _buildLanding() {
    final tablet = _isTablet(context);
    final size = MediaQuery.of(context).size;

    return Stack(
      key: const ValueKey('landing'),
      children: [
        ..._corners(),

        // Orb
        AnimatedBuilder(
          animation: _orbOpacity,
          builder: (_, __) => Positioned(
            top: size.height * 0.3 - 130,
            left: size.width / 2 - 130,
            child: Opacity(
              opacity: _orbOpacity.value,
              child: Container(
                width: 260, height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x2E4A9EFF), Colors.transparent],
                    stops: [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Logo
        Positioned(
          top: MediaQuery.of(context).padding.top + 24,
          left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _logoWidget(),
            const SizedBox(width: 8),
            Text('QARTA', style: TextStyle(
              color: Colors.white,
              fontSize: _fs(context, 18, tablet: 22),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            )),
          ]),
        ),

        // Carousel
        Positioned(
          top: MediaQuery.of(context).padding.top + (tablet ? 110 : 90),
          left: 0, right: 0,
          height: tablet
              ? size.height * 0.55
              : 330,
          child: tablet
              ? Column(children: [
            SizedBox(
              height: (size.height * 0.55 - 20) / 2,
              child: FloatingCards(reverse: false, isTablet: true),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: (size.height * 0.55 - 20) / 2,
              child: FloatingCards(reverse: true, isTablet: true),
            ),
          ])
              : const FloatingCards(reverse: false, isTablet: false),
        ),

        // Bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: tablet ? 600.0 : double.infinity),
              padding: EdgeInsets.only(
                left: tablet ? 40 : 22,
                right: tablet ? 40 : 22,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                top: 26,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF0D1526)],
                  stops: [0, 0.35],
                ),
              ),
              child: Column(children: [
                Text('La fidélité,', style: TextStyle(
                  color: Colors.white,
                  fontSize: _fs(context, 21, tablet: 26),
                  fontWeight: FontWeight.w700,
                )),
                Text('en un scan', style: TextStyle(
                  color: Colors.white,
                  fontSize: _fs(context, 21, tablet: 26),
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 7),
                Text('Rejoins des milliers de clients\net commerçants sur Qarta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: _fs(context, 12, tablet: 14),
                    )),
                const SizedBox(height: 22),

                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() { screen = 'register'; regStep = 1; regType = null; error = ''; }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue, foregroundColor: kDark,
                      padding: EdgeInsets.symmetric(vertical: tablet ? 18 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Créer un compte', style: TextStyle(
                      fontSize: _fs(context, 15, tablet: 17),
                      fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
                const SizedBox(height: 9),

                SizedBox(width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() { screen = 'login'; error = ''; }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: tablet ? 18 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Text('Se connecter', style: TextStyle(
                      fontSize: _fs(context, 15, tablet: 17),
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
                const SizedBox(height: 13),

                Row(children: [
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ou', style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 11))),
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                ]),
                const SizedBox(height: 13),

                SizedBox(width: double.infinity,
                  child: OutlinedButton(
                    onPressed: googleLoading ? null : _doGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.07),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: tablet ? 17 : 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: googleLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _googleIcon(),
                      const SizedBox(width: 9),
                      Text('Continuer avec Google', style: TextStyle(
                        fontSize: _fs(context, 13, tablet: 15),
                        fontWeight: FontWeight.w500,
                      )),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════
  Widget _buildLogin() {
    final tablet = _isTablet(context);
    bool _showPass = false;
    String _loginTab = 'client'; // 'client' | 'merchant'

    return StatefulBuilder(
      builder: (context, setS) => Stack(
        key: const ValueKey('login'),
        children: [
          ..._corners(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _maxW(context)),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(tablet ? 40 : 24, 0, tablet ? 40 : 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _backBtn(() => setState(() { screen = 'landing'; error = ''; })),
                      const SizedBox(height: 24),

                      // Logo centré
                      Center(
                        child: Column(children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A2E50)),
                            child: Center(child: Text('Q', style: TextStyle(
                                color: kBlue, fontSize: 32, fontWeight: FontWeight.w700))),
                          ),
                          const SizedBox(height: 12),
                          Text('Bon retour !', style: TextStyle(
                              color: Colors.white, fontSize: _fs(context, 20, tablet: 24), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Connecte-toi à ton compte Qarta',
                              style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: _fs(context, 12, tablet: 14))),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      // Toggle Client / Commerçant
                     /* Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1E35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          _loginTabBtn('client', 'Client', _loginTab, (v) => setS(() => _loginTab = v)),
                          _loginTabBtn('merchant', 'Commerçant', _loginTab, (v) => setS(() => _loginTab = v)),
                        ]),
                      ),*/
                      const SizedBox(height: 20),

                      _label('ADRESSE EMAIL'),
                      const SizedBox(height: 8),
                      _darkField(loginEmailCtrl, 'toi@email.com', Icons.email_outlined, type: TextInputType.emailAddress),
                      const SizedBox(height: 12),

                      _label('MOT DE PASSE'),
                      const SizedBox(height: 8),

                      // Champ mot de passe avec bouton Voir
                      TextField(
                        controller: loginPassCtrl,
                        obscureText: !_showPass,
                        style: TextStyle(color: Colors.white, fontSize: _fs(context, 14, tablet: 16)),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.white38, size: 18),
                          suffixIcon: GestureDetector(
                            onTap: () => setS(() => _showPass = !_showPass),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Text(_showPass ? 'Cacher' : 'Voir',
                                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(),
                          filled: true,
                          fillColor: const Color(0xFF0E1E35),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: _isTablet(context) ? 18 : 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: kBlue, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Align(alignment: Alignment.centerRight,
                          child: Text('Mot de passe oublié ?',
                              style: TextStyle(color: kBlue, fontSize: _fs(context, 12, tablet: 14), fontWeight: FontWeight.w600))),

                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _errorBox(error),
                      ],

                      const SizedBox(height: 22),

                      SizedBox(width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : _doLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBlue, foregroundColor: kDark,
                            padding: EdgeInsets.symmetric(vertical: tablet ? 18 : 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Se connecter', style: TextStyle(fontSize: _fs(context, 15, tablet: 17), fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('ou', style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 11))),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                      ]),
                      const SizedBox(height: 14),

                      SizedBox(width: double.infinity,
                        child: OutlinedButton(
                          onPressed: googleLoading ? null : _doGoogle,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.07),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: tablet ? 17 : 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: googleLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _googleIcon(),
                            const SizedBox(width: 9),
                            Text('Continuer avec Google', style: TextStyle(fontSize: _fs(context, 13, tablet: 15), fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: GestureDetector(
                          onTap: () => setState(() { screen = 'register'; regStep = 1; regType = null; error = ''; }),
                          child: RichText(
                            text: TextSpan(
                              text: 'Pas encore de compte ? ',
                              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: _fs(context, 12, tablet: 14)),
                              children: const [
                                TextSpan(text: 'S\'inscrire',
                                    style: TextStyle(color: kBlue, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // REGISTER
  // ═══════════════════════════════════════
  Widget _buildRegister() {
    final tablet = _isTablet(context);

    return Stack(
      key: const ValueKey('register'),
      children: [
        ..._corners(),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxW(context)),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(tablet ? 40 : 24, 0, tablet ? 40 : 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _backBtn(() {
                      if (regStep > 1) {
                        setState(() { regStep--; error = ''; });
                      } else {
                        setState(() { screen = 'landing'; error = ''; });
                      }
                    }),
                    const SizedBox(height: 20),

                    Row(children: List.generate(3, (i) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        height: 3,
                        decoration: BoxDecoration(
                          color: i < regStep ? kBlue : Colors.white12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ))),
                    const SizedBox(height: 24),

                    if (regStep == 1) _buildStep1(),
                    if (regStep == 2) _buildStep2(),
                    if (regStep == 3) _buildStep3(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    final tablet = _isTablet(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tu es ici pour…', style: TextStyle(
          color: Colors.white, fontSize: _fs(context, 20, tablet: 24), fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Choisis ton profil pour commencer', style: TextStyle(
          color: Colors.white.withOpacity(0.38), fontSize: _fs(context, 12, tablet: 14))),
      const SizedBox(height: 22),

      tablet
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _typeCard('client', Icons.person_outline, 'Je suis client', 'Scanne et cumule des tampons', tags: ['Gratuit', 'Apple Wallet', 'Notifs'])),
        const SizedBox(width: 12),
        Expanded(child: _typeCard('merchant', Icons.storefront_outlined, 'Je suis commerçant', 'Crée ta carte, fidélise tes clients', tags: ['30j offerts', 'Dashboard', 'Scanner'])),
      ])
          : Column(children: [
        _typeCard('client', Icons.person_outline, 'Je suis client', 'Scanne et cumule des tampons', tags: ['Gratuit', 'Apple Wallet', 'Notifs']),
        const SizedBox(height: 12),
        _typeCard('merchant', Icons.storefront_outlined, 'Je suis commerçant', 'Crée ta carte, fidélise tes clients', tags: ['30j offerts', 'Dashboard', 'Scanner']),
      ]),

      const SizedBox(height: 16),

      SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: regType == null
              ? null
              : () {
            if (regType == 'merchant') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MerchantRedirectScreen(),
                ),
              );
              return; // 🔥 SUPER IMPORTANT
            }

            setState(() {
              regStep = 2;
              error = '';
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: regType != null ? kBlue : const Color(0xFF1A2E50),
            foregroundColor: regType != null ? kDark : Colors.white30,
            padding: EdgeInsets.symmetric(vertical: tablet ? 18 : 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text('Continuer', style: TextStyle(fontSize: _fs(context, 15, tablet: 17), fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _buildStep2() {
    final tablet = _isTablet(context);
    return StatefulBuilder(
      builder: (context, setS) {
        bool _isValidEmail(String email) =>
            RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());

        final allFilled = prenomCtrl.text.trim().isNotEmpty
            && nomCtrl.text.trim().isNotEmpty
            && _isValidEmail(emailCtrl.text)
            && passCtrl.text.isNotEmpty
            && (regType != 'merchant' || codeCtrl.text.trim().isNotEmpty);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tes informations', style: TextStyle(
              color: Colors.white, fontSize: _fs(context, 20, tablet: 24), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Gratuit · 30 secondes · zéro CB',
              style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: _fs(context, 12, tablet: 14))),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(child: _darkField(prenomCtrl, 'Prénom', Icons.person_outline,
                onChanged: (_) => setS(() {}))),
            const SizedBox(width: 10),
            Expanded(child: _darkField(nomCtrl, 'Nom', Icons.person_outline,
                onChanged: (_) => setS(() {}))),
          ]),
          const SizedBox(height: 12),


          // Email avec validation
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setS(() {}),
            style: TextStyle(color: Colors.white, fontSize: _fs(context, 14, tablet: 16)),
            decoration: InputDecoration(
              hintText: 'Adresse email',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38, size: 18),
              suffixIcon: emailCtrl.text.isNotEmpty
                  ? Icon(
                _isValidEmail(emailCtrl.text)
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: _isValidEmail(emailCtrl.text)
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFE24B4A),
                size: 18,
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0E1E35),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: _isTablet(context) ? 18 : 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(
                    color: emailCtrl.text.isNotEmpty
                        ? _isValidEmail(emailCtrl.text)
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFE24B4A)
                        : Colors.white.withOpacity(0.12),
                  )),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: kBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          _darkField(passCtrl, 'Mot de passe', Icons.lock_outline, obscure: true, onChanged: (v) {
            setS(() => passScore = _checkStrength(v));
          }),
          const SizedBox(height: 8),

          Row(children: List.generate(4, (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: i < passScore ? _strengthColor(passScore) : Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ))),
          const SizedBox(height: 4),
          Text(_strengthLabel(passScore),
              style: TextStyle(fontSize: 11, color: passScore > 0 ? _strengthColor(passScore) : Colors.white30)),




          if (error.isNotEmpty) ...[
            const SizedBox(height: 12),
            _errorBox(error),
          ],

          const SizedBox(height: 24),

          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: (loading || !allFilled) ? null : () async {
                if (regType == 'merchant') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MerchantRedirectScreen(),
                      )
                  );
                } else {
                  setState(() { regStep = 3; error = ''; });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: allFilled ? kBlue : const Color(0xFF1A2E50),
                foregroundColor: allFilled ? kDark : Colors.white30,
                padding: EdgeInsets.symmetric(vertical: tablet ? 18 : 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Créer mon compte',
                  style: TextStyle(fontSize: _fs(context, 15, tablet: 17), fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() { regStep = 1; error = ''; }),
              child: Text('Retour',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildStep3() {
    final tablet = _isTablet(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),

        // Cercle avec check animé
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: const Cubic(0.34, 1.56, 0.64, 1),
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: tablet ? 90 : 72, height: tablet ? 90 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBlue.withOpacity(0.15),
              border: Border.all(color: kBlue, width: 2),
            ),
            child: Center(
              child: Icon(Icons.check_rounded, color: kBlue, size: tablet ? 44 : 32),
            ),
          ),
        ),

        const SizedBox(height: 18),
        Text(prenomCtrl.text.isNotEmpty ? 'Bienvenue ${prenomCtrl.text} !' : 'Bienvenue !',
            style: TextStyle(color: Colors.white, fontSize: _fs(context, 21, tablet: 26), fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Ton compte Qarta est prêt.\nCommence à scanner dès maintenant.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: _fs(context, 13, tablet: 15), height: 1.6)),
        const SizedBox(height: 26),

        if (error.isNotEmpty) ...[
          _errorBox(error),
          const SizedBox(height: 16),
        ],

        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : _doRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue, foregroundColor: kDark,
              padding: EdgeInsets.symmetric(vertical: tablet ? 18 : 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('C\'est parti ! 🚀', style: TextStyle(fontSize: _fs(context, 15, tablet: 17), fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _typeCard(String type, IconData icon, String title, String subtitle, {List<String>? tags}) {
    final selected = regType == type;
    final tablet = _isTablet(context);
    return GestureDetector(
      onTap: () => setState(() => regType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? kBlue : const Color(0xFF0E1E35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? kBlue : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.2) : const Color(0xFF1A2E50),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: Icon(icon,
                  color: selected ? const Color(0xFF0D1526) : kBlue,
                  size: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(
                    color: selected ? const Color(0xFF0D1526) : Colors.white,
                    fontSize: _fs(context, 15, tablet: 17), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(
                    color: selected ? const Color(0xFF0D1526).withOpacity(0.65) : Colors.white.withOpacity(0.38),
                    fontSize: _fs(context, 11, tablet: 12))),
              ]),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF0D1526) : Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: selected ? const Color(0xFF0D1526) : Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Center(child: Icon(Icons.check,
                  size: 13,
                  color: selected ? kBlue : Colors.white.withOpacity(0.2))),
            ),
          ]),
          if (tags != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: kBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(tag, style: const TextStyle(
                  fontSize: 10, color: kBlue, fontWeight: FontWeight.w500)),
            )).toList()),
          ],
        ]),
      ),
    );
  }

  Widget _darkField(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, TextInputType type = TextInputType.text, Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      onChanged: onChanged,
      style: TextStyle(color: Colors.white, fontSize: _fs(context, 14, tablet: 16)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: _fs(context, 14, tablet: 16)),
        prefixIcon: Icon(icon, color: Colors.white38, size: _isTablet(context) ? 22 : 18),
        filled: true,
        fillColor: const Color(0xFF0E1E35),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: _isTablet(context) ? 18 : 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: kBlue, width: 1.5)),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: _fs(context, 11, tablet: 13), fontWeight: FontWeight.w600,
          color: const Color(0x66FFFFFF), letterSpacing: 0.8));

  Widget _errorBox(String msg) => Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0x22E24B4A), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x44E24B4A))),
      child: Text('✗ $msg', style: TextStyle(color: const Color(0xFFE24B4A),
          fontSize: _fs(context, 13, tablet: 15), fontWeight: FontWeight.w600)));

  Widget _backBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.chevron_left, color: kBlue, size: 22),
      Text('Retour', style: TextStyle(color: kBlue, fontSize: _fs(context, 13, tablet: 15))),
    ]),
  );
  Widget _loginTabBtn(String val, String label, String current, Function(String) onTap) {
    final active = val == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? kDark : Colors.white.withOpacity(0.4),
                  fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _logoWidget() {
    final s = _isTablet(context) ? 36.0 : 28.0;
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A2E50)),
      child: Center(child: Text('Q', style: TextStyle(
          color: kBlue, fontSize: _isTablet(context) ? 20 : 16, fontWeight: FontWeight.w700))),
    );
  }

  Widget _googleIcon() => SizedBox(
    width: 16, height: 16,
    child: CustomPaint(painter: _GoogleSvgPainter()),
  );

  List<Widget> _corners() {
    const c = Color(0x4D4A9EFF);
    const s = 18.0;
    const t = 20.0;
    const w = 1.5;
    return [
      Positioned(top: t, left: t, child: _Corner(size: s, color: c, top: true, left: true, width: w)),
      Positioned(top: t, right: t, child: _Corner(size: s, color: c, top: true, left: false, width: w)),
      Positioned(bottom: t, left: t, child: _Corner(size: s, color: c, top: false, left: true, width: w)),
      Positioned(bottom: t, right: t, child: _Corner(size: s, color: c, top: false, left: false, width: w)),
    ];
  }



  Widget _redirectFeature(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4A9EFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4A9EFF), size: 14),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Corner ──
class _Corner extends StatelessWidget {
  final double size, width;
  final Color color;
  final bool top, left;
  const _Corner({required this.size, required this.color, required this.top, required this.left, required this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: CustomPaint(painter: _CornerPainter(color: color, top: top, left: left, width: width)),
  );
}

class _CornerPainter extends CustomPainter {
  final Color color; final bool top, left; final double width;
  const _CornerPainter({required this.color, required this.top, required this.left, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke;
    const r = 3.0;
    final path = Path();
    if (top && left) { path.moveTo(0, size.height); path.lineTo(0, r); path.arcToPoint(Offset(r, 0), radius: const Radius.circular(r)); path.lineTo(size.width, 0); }
    else if (top) { path.moveTo(0, 0); path.lineTo(size.width - r, 0); path.arcToPoint(Offset(size.width, r), radius: const Radius.circular(r)); path.lineTo(size.width, size.height); }
    else if (left) { path.moveTo(0, 0); path.lineTo(0, size.height - r); path.arcToPoint(Offset(r, size.height), radius: const Radius.circular(r)); path.lineTo(size.width, size.height); }
    else { path.moveTo(size.width, 0); path.lineTo(size.width, size.height - r); path.arcToPoint(Offset(size.width - r, size.height), radius: const Radius.circular(r)); path.lineTo(0, size.height); }
    canvas.drawPath(path, p);
  }
  @override bool shouldRepaint(_) => false;
}

// ── Google SVG ──
class _GoogleSvgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFF4285F4);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(9*s, 0, 9*s, 9*s), const Radius.circular(1)), paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(9*s, 9*s, 9*s, 9*s), const Radius.circular(1)), paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 9*s, 9*s, 9*s), const Radius.circular(1)), paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 9*s, 9*s), const Radius.circular(1)), paint);
  }
  @override bool shouldRepaint(_) => false;
}

// ── FloatingCards ──
class FloatingCards extends StatefulWidget {
  final bool reverse;
  final bool isTablet;
  const FloatingCards({super.key, this.reverse = false, this.isTablet = false});

  @override
  State<FloatingCards> createState() => _FloatingCardsState();
}

class _FloatingCardsState extends State<FloatingCards> {
  late final PageController _controller;
  late final List<CardData> cards;
  Timer? _autoScrollTimer;
  bool isUserTouching = false;

  @override
  void initState() {
    super.initState();

    _controller = PageController(
      initialPage: widget.reverse ? 1005 : 1000,
      viewportFraction: widget.isTablet ? 0.70 : 0.82,
    );

    cards = [
      CardData(title: "Offres", description: "Tes promos du moment", icon: Icons.local_offer, color: Colors.blue),
      CardData(title: "Fidélité", description: "Tes points cumulés", icon: Icons.star, color: Colors.purple),
      CardData(title: "Récompenses", description: "Ce que tu peux gagner", icon: Icons.card_giftcard, color: Colors.orange),
      CardData(title: "Cashback", description: "Récupère de l'argent", icon: Icons.savings, color: Colors.teal),
      CardData(title: "VIP", description: "Accès exclusifs", icon: Icons.star_border, color: Colors.pink),
    ];

    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (isUserTouching || !_controller.hasClients) return;
      if (widget.reverse) {
        _controller.previousPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      } else {
        _controller.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) { isUserTouching = true; _autoScrollTimer?.cancel(); },
      onPointerUp: (_) { isUserTouching = false; _startAutoScroll(); },
      onPointerCancel: (_) { isUserTouching = false; _startAutoScroll(); },
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final card = cards[index % cards.length];
          return Center(
            child: Transform.scale(
              scale: 0.95,
              child: _card(card),
            ),
          );
        },
      ),
    );
  }

  Widget _card(CardData card) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = widget.isTablet
        ? screenWidth * 0.85
        : screenWidth * 0.82;
    final cardHeight = widget.isTablet ? 350.0 : 200.0;

    return Container(
      width: cardWidth,
      height: cardHeight,
      padding: EdgeInsets.all(widget.isTablet ? 24 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [card.color.withOpacity(0.9), card.color.withOpacity(0.5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(
          color: card.color.withOpacity(0.35),
          blurRadius: 30,
          offset: const Offset(0, 15),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(card.icon, color: Colors.white, size: widget.isTablet ? 32 : 26),
        const Spacer(),
        Text(card.title, style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold,
            fontSize: widget.isTablet ? 22 : 18)),
        const SizedBox(height: 6),
        Text(card.description, style: TextStyle(
            color: Colors.white70,
            fontSize: widget.isTablet ? 15 : 13)),
      ]),
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}