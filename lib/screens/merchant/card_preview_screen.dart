import 'package:flutter/material.dart';

class CardPreviewScreen extends StatelessWidget {
  final Map merchantInfo;
  final Color accentColor;
  final String emoji;
  final String businessName;
  final String initials;

  const CardPreviewScreen({
    super.key,
    required this.merchantInfo,
    required this.accentColor,
    required this.emoji,
    required this.businessName,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final int total = merchantInfo['stamps_required'] as int? ?? 10;
    final String reward = merchantInfo['reward_description'] as String? ?? 'Récompense';
    final String category = merchantInfo['category'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Aperçu carte client', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Voici comment tes clients voient leur carte fidélité. L\'exemple affiche 3 tampons.',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CARTE FIDÉLITÉ',
                              style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5, color: Colors.white.withOpacity(0.55))),
                          const SizedBox(height: 4),
                          Text(businessName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                          if (category.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(category,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Stamp grid
                  _StampGrid(total: total, filled: 3, accentColor: accentColor),

                  const SizedBox(height: 16),

                  // Progress row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Encore ${total - 3} tampons pour $reward',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('3/$total',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: 3 / total,
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Programme details
            _detailCard(
              icon: Icons.card_giftcard_outlined,
              label: 'Récompense',
              value: reward,
              accentColor: accentColor,
            ),
            const SizedBox(height: 10),
            _detailCard(
              icon: Icons.auto_awesome_outlined,
              label: 'Tampons requis',
              value: '$total tampons pour débloquer la récompense',
              accentColor: accentColor,
            ),
            if ((merchantInfo['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailCard(
                icon: Icons.info_outline,
                label: 'Description',
                value: merchantInfo['description'] as String,
                accentColor: accentColor,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StampGrid extends StatelessWidget {
  final int total;
  final int filled;
  final Color accentColor;

  const _StampGrid({required this.total, required this.filled, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = total <= 10 ? total : (total <= 15 ? 8 : 10);
      const spacing = 5.0;
      final stampSize = ((constraints.maxWidth - spacing * (cols - 1)) / cols).clamp(18.0, 32.0);
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(total, (i) => Container(
          width: stampSize, height: stampSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(stampSize * 0.3),
            color: i < filled ? Colors.white.withOpacity(0.9) : Colors.transparent,
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
          ),
          child: i < filled
              ? Center(child: Icon(Icons.check, size: stampSize * 0.5, color: accentColor))
              : null,
        )),
      );
    });
  }
}
