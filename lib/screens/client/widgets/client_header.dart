import 'dart:io';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class ClientHeader extends StatelessWidget {
  final int tab;
  final String firstName;
  final String initials;
  final String? profileImageUrl;
  final String? profileImagePath;
  final int cardCount;
  final int rewardCount;
  final int notifCount;
  final bool rewardPillActive;
  final String notifFilter;
  final VoidCallback onProfileTap;
  final VoidCallback onNotifTap;
  final VoidCallback onBackFromProfil;
  final VoidCallback onCloseNotifs;
  final VoidCallback onGoToCards;
  final VoidCallback onGoToRewards;
  final void Function(String) onFilterChanged;
  final VoidCallback onPhotoTap;

  const ClientHeader({
    super.key,
    required this.tab,
    required this.firstName,
    required this.initials,
    this.profileImageUrl,
    this.profileImagePath,
    required this.cardCount,
    required this.rewardCount,
    required this.notifCount,
    required this.rewardPillActive,
    required this.notifFilter,
    required this.onProfileTap,
    required this.onNotifTap,
    required this.onBackFromProfil,
    required this.onCloseNotifs,
    required this.onGoToCards,
    required this.onGoToRewards,
    required this.onFilterChanged,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.qNavy,
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -10,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF2C7BE5).withValues(alpha: 0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 14,
              left: 20, right: 20, bottom: 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (tab == 3) _buildProfilRow(context)
                  else if (tab == 4) _buildNotifsRow(context)
                  else _buildNormalRow(context),
                  if (tab != 3 && tab != 4) const Spacer(),
                  if (tab != 3 && tab != 4) _buildNotifBell(context),
                ]),
                if (tab == 4) _buildNotifFilters(context)
                else if (tab != 3) _buildPills(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Ligne normale : avatar + nom + cloche ───────────────────────────────────
  Widget _buildNormalRow(BuildContext context) {
    return GestureDetector(
      onTap: onProfileTap,
      child: Row(children: [
        _avatar(context, size: 38, fontSize: 13),
        const SizedBox(width: 9),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bonjour', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, height: 1)),
          const SizedBox(height: 2),
          Text(firstName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
        ]),
      ]),
    );
  }

  // ── Ligne Profil : flèche + avatar centré ───────────────────────────────────
  Widget _buildProfilRow(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (_, constraints) => Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onBackFromProfil,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Profil', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
            Center(
              child: GestureDetector(
                onTap: onPhotoTap,
                child: Stack(children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2C7BE5).withValues(alpha: 0.30),
                      border: Border.all(color: const Color(0xFF4A9EFF).withValues(alpha: 0.45), width: 2),
                      image: profileImageUrl != null
                          ? DecorationImage(image: NetworkImage(profileImageUrl!), fit: BoxFit.cover)
                          : profileImagePath != null
                              ? DecorationImage(image: FileImage(File(profileImagePath!)), fit: BoxFit.cover)
                              : null,
                    ),
                    child: (profileImageUrl == null && profileImagePath == null)
                        ? Center(child: Text(initials, style: const TextStyle(color: Color(0xFF4A9EFF), fontSize: 28, fontWeight: FontWeight.w700)))
                        : null,
                  ),
                  Positioned(
                    bottom: 2, right: 2,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2C7BE5),
                        border: Border.all(color: context.qNavy, width: 1.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ligne Notifications : flèche + titre centré ─────────────────────────────
  Widget _buildNotifsRow(BuildContext context) {
    return Expanded(
      child: Row(children: [
        GestureDetector(
          onTap: onCloseNotifs,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
          ),
        ),
        const Expanded(
          child: Text('Notifications',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 34),
      ]),
    );
  }

  // ── Cloche notifications ────────────────────────────────────────────────────
  Widget _buildNotifBell(BuildContext context) {
    return GestureDetector(
      onTap: onNotifTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(Icons.notifications_outlined, color: Colors.white.withValues(alpha: 0.8), size: 18),
          ),
          if (notifCount > 0)
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
                  child: Text('$notifCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Filtres notifs ──────────────────────────────────────────────────────────
  Widget _buildNotifFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 42,
        child: Row(children: [
          for (final f in [
            {'key': 'tout',       'label': 'Tout'},
            {'key': 'tampon',     'label': 'Tampons'},
            {'key': 'recompense', 'label': 'Récompenses'},
            {'key': 'promo',      'label': 'Promos'},
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => onFilterChanged(f['key']!),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: notifFilter == f['key'] ? const Color(0xFF2C7BE5) : const Color(0xFF0F1E3A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: notifFilter == f['key']
                          ? Colors.transparent
                          : const Color(0xFF4A9EFF).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(f['label']!,
                        style: TextStyle(
                          color: notifFilter == f['key'] ? Colors.white : const Color(0xFF4A9EFF),
                          fontSize: 11, fontWeight: FontWeight.w600,
                        )),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Pills Cartes / Récompenses ──────────────────────────────────────────────
  Widget _buildPills(BuildContext context) {
    const blue = Color(0xFF2C7BE5);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 42,
        child: Stack(children: [
          Positioned.fill(child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
          )),
          AnimatedAlign(
            alignment: rewardPillActive ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: blue.withValues(alpha: 0.55)),
                ),
              ),
            ),
          ),
          Row(children: [
            Expanded(child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onGoToCards,
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('$cardCount', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1)),
                const SizedBox(width: 5),
                Text(cardCount > 1 ? 'Cartes' : 'Carte',
                  maxLines: 1,
                  style: TextStyle(color: Colors.white.withValues(alpha: !rewardPillActive ? 0.9 : 0.55), fontSize: 13, fontWeight: FontWeight.w600)),
              ])),
            )),
            Expanded(child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onGoToRewards,
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('$rewardCount', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1)),
                const SizedBox(width: 5),
                Text(rewardCount > 1 ? 'Récompenses' : 'Récompense',
                  maxLines: 1,
                  style: TextStyle(color: Colors.white.withValues(alpha: rewardPillActive ? 0.9 : 0.55), fontSize: 13, fontWeight: FontWeight.w600)),
              ])),
            )),
          ]),
        ]),
      ),
    );
  }

  // ── Avatar helper ───────────────────────────────────────────────────────────
  Widget _avatar(BuildContext context, {required double size, required double fontSize}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2C7BE5).withValues(alpha: 0.30),
        border: Border.all(color: const Color(0xFF4A9EFF).withValues(alpha: 0.45), width: 2),
        image: profileImageUrl != null
            ? DecorationImage(image: NetworkImage(profileImageUrl!), fit: BoxFit.cover)
            : profileImagePath != null
                ? DecorationImage(image: FileImage(File(profileImagePath!)), fit: BoxFit.cover)
                : null,
      ),
      child: (profileImageUrl == null && profileImagePath == null)
          ? Center(child: Text(initials, style: TextStyle(color: const Color(0xFF4A9EFF), fontSize: fontSize, fontWeight: FontWeight.w700)))
          : null,
    );
  }
}
