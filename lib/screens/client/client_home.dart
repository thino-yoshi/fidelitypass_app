import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../auth_screen.dart';
import 'stores_tab.dart';
import 'cards_tab.dart';

class ClientHome extends StatefulWidget {
  final String token;
  final String userName;
  const ClientHome({super.key, required this.token, required this.userName});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int currentTab = 0;
  static const gold = Color(0xFF2C7BE5);

  void logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F0E17), Color(0xFF1A1828)],
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24, right: 24, bottom: 24,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bonjour,', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${widget.userName} 👋', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: logout,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text('Sortir', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _tab('🏪', 'Commerces', 0),
                _tab('💳', 'Mes cartes', 1),
              ],
            ),
          ),

          // Content
          Expanded(
            child: currentTab == 0
                ? StoresTab(token: widget.token)
                : CardsTab(token: widget.token),
          ),
        ],
      ),
    );
  }

  Widget _tab(String icon, String label, int index) {
    final active = currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? gold : Colors.transparent, width: 3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: active ? gold : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}