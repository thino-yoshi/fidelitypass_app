import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'cards_tab.dart' show QRModal, CardStyle;

class RewardsPage extends StatelessWidget {
  final String token;
  final List<dynamic> cards;
  final VoidCallback? onStampAdded; // appelé après détection d'un tampon

  const RewardsPage({super.key, required this.token, required this.cards, this.onStampAdded});

  static const List<Color> _palette = [
    Color(0xFF2C7BE5),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFF7B4FBF),
    Color(0xFF0097A7),
    Color(0xFFE67E22),
  ];

  List<dynamic> get _rewardCards => cards.where((c) {
        final val = c['stamps_count'] as int? ?? 0;
        final type = c['merchants']?['program_type'] as String? ?? 'stamps';
        final req = type == 'points'
            ? (c['merchants']?['points_required'] as int? ?? 100)
            : (c['merchants']?['stamps_required'] as int? ?? 10);
        return val >= req;
      }).toList();

  Color _cardColor(dynamic card) {
    final i = cards.indexOf(card);
    return _palette[i % _palette.length];
  }

  CardStyle _styleForCard(Map card) {
    return CardStyle.fromDesign(
      card['card_design'],
      merchantLogoUrl: card['merchants']?['logo_url'] as String?,
      fallbackColor: _cardColor(card),
    );
  }

  void _showQRModal(BuildContext context, Map card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRModal(
        token: token,
        card: card,
        style: _styleForCard(card),
        onStampAdded: () {
          // ferme le modal récompenses, puis rafraîchit + retour tab cartes
          Navigator.pop(context);
          onStampAdded?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final rewards = _rewardCards;

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée + titre
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Mes récompenses',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.qText,
                      ),
                    ),
                    if (rewards.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${rewards.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Contenu
          Expanded(
            child: rewards.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded, size: 64, color: Color(0xFFFBBF24)),
                        SizedBox(height: 16),
                        Text(
                          'Aucune récompense pour l\'instant',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Continue à cumuler des points !',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    itemCount: rewards.length,
                    itemBuilder: (context, index) {
                      final card = rewards[index];
                      final name = card['merchants']?['business_name'] as String? ?? '';
                      final reward = card['merchants']?['reward_description'] as String? ?? '';

                      return GestureDetector(
                        onTap: () => _showQRModal(context, card as Map),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.qSurface,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: const Color(0xFFFBBF24),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFBBF24).withOpacity(0.12),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Center(
                                  child: Icon(Icons.star_rounded, size: 20, color: Color(0xFFF59E0B)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Récompense chez $name',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: context.qText,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      reward,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.qSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Text(
                                  'Voir',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
