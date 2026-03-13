import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'client/client_home.dart';
import 'merchant/merchant_home.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  String userType = 'client';
  bool loading = false;
  String error = '';

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  static const gold = Color(0xFF2C7BE5);

  Future<void> submit() async {
    setState(() { loading = true; error = ''; });
    try {
      Map<String, dynamic> data;
      if (isLogin) {
        data = await AuthService.login(emailCtrl.text.trim(), passCtrl.text);
      } else {
        data = await AuthService.register(emailCtrl.text.trim(), passCtrl.text, nameCtrl.text.trim(), userType);
      }
      await AuthService.saveSession(data['token'], data['user_type'], data['name']);
      if (!mounted) return;
      if (data['user_type'] == 'merchant') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MerchantHome(token: data['token'], merchantName: data['name'])));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientHome(token: data['token'], userName: data['name'])));
      }
    } catch (e) {
      setState(() { error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0E17), Color(0xFF1A1828)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.blue],
                        ),
                      ),
                      child: Column(
                        children: [

                          const SizedBox(height: 8),
                          Text('Qarta', style: GoogleFonts.dmSerifDisplay(fontSize: 100
                              , color: Colors.indigoAccent)),
                          const SizedBox(height: 4),
                          Text(
                            isLogin ? 'Content de te revoir !' : 'Rejoins la plateforme',
                            style: TextStyle(color: Colors.indigoAccent.withOpacity(0.8), fontSize: 20),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Toggle
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                _toggleBtn('Connexion', isLogin, () => setState(() => isLogin = true)),
                                _toggleBtn('Inscription', !isLogin, () => setState(() => isLogin = false)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Type utilisateur
                          if (!isLogin) ...[
                            Row(
                              children: [
                                _typeBtn('👤', 'Client', 'client'),
                                const SizedBox(width: 10),
                                _typeBtn('🏪', 'Commerçant', 'merchant'),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Champs
                          if (!isLogin) ...[
                            _input(nameCtrl, 'Nom complet / Commerce', Icons.person_outline),
                            const SizedBox(height: 12),
                          ],
                          _input(emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _input(passCtrl, 'Mot de passe', Icons.lock_outline, obscure: true),
                          const SizedBox(height: 16),

                          // Erreur
                          if (error.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF0EE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('✗ $error', style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          if (error.isNotEmpty) const SizedBox(height: 12),

                          // Bouton
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gold,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(isLogin ? 'Se connecter' : 'Créer mon compte', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)] : [],
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: active ? gold : Colors.grey)),
        ),
      ),
    );
  }

  Widget _typeBtn(String icon, String label, String value) {
    final selected = userType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => userType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFDF6EE) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? gold : const Color(0xFFEEEEEE), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? gold : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold, width: 1.5)),
      ),
    );
  }
}