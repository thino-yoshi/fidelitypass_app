import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpSheet extends StatelessWidget {
  const HelpSheet({super.key});

  static const _faqs = [
    (
      q: 'Comment gagner des tampons ?',
      a: 'À chaque passage en caisse, le commerçant scanne ton QR code ou tu scannes le sien depuis l\'onglet Scan. Un tampon est ajouté automatiquement à la carte concernée.',
    ),
    (
      q: 'Comment utiliser une récompense ?',
      a: 'Quand ta carte est complète, une bannière « Récompense disponible » apparaît en haut de l\'onglet Cartes. Appuie sur « Utiliser » puis montre l\'écran au commerçant.',
    ),
    (
      q: 'Mes tampons peuvent-ils expirer ?',
      a: 'Les tampons restent valables tant que la carte est active. Certains commerces fixent une durée de validité, indiquée sur le détail de la carte.',
    ),
    (
      q: 'J\'ai changé de téléphone, comment récupérer mes cartes ?',
      a: 'Connecte-toi avec le même compte (email et mot de passe). Toutes tes cartes, tampons et récompenses sont synchronisés automatiquement.',
    ),
    (
      q: 'Comment ajouter une nouvelle carte ?',
      a: 'Va dans l\'onglet Scan et scanne le QR code affiché en caisse du commerce. Sa carte de fidélité est ajoutée automatiquement à tes cartes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E35) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              Text('Aide et Support',
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
          const SizedBox(height: 16),
          Text('QUESTIONS FRÉQUENTES',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                color: isDark ? const Color(0xFF4A9EFF) : const Color(0xFF0F2044),
              )),
          const SizedBox(height: 8),
          ...(_faqs.map((faq) => _FaqTile(q: faq.q, a: faq.a, isDark: isDark))),
          const SizedBox(height: 12),
          Text('NOUS CONTACTER',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                color: isDark ? const Color(0xFF4A9EFF) : const Color(0xFF0F2044),
              )),
          const SizedBox(height: 8),
          Text('Pour toute autre question, écris-nous par email. On te répond sous 24h.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF666666))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162032) : const Color(0xFFF4F2EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('qarta.contact@gmail.com',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1A1828),
                      )),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: 'qarta.contact@gmail.com'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email copié !'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C7BE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Copier',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Réponse sous 24h',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2C7BE5))),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  final bool isDark;
  const _FaqTile({required this.q, required this.a, required this.isDark});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF162032) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? Colors.white12 : const Color(0xFFE8E8E8),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF2C7BE5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.q,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : const Color(0xFF1A1828),
                        )),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(widget.a,
                  style: TextStyle(
                    fontSize: 11, height: 1.55,
                    color: widget.isDark ? Colors.white60 : const Color(0xFF666666),
                  )),
            ),
            crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
