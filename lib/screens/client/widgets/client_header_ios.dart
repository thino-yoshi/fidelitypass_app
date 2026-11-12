import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_text.dart';

/// Largeur maximale du contenu (iPad) : au-delà, le contenu reste centré
/// au lieu de s'étirer, comme les applis Apple sur iPad. Sans effet sur iPhone.
const double kIosMaxContentWidth = 600;

Widget iosReadableWidth(Widget child) => Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: kIosMaxContentWidth), child: child),
    );

/// En-tête iOS de l'espace client : petite ligne (date) + grand titre,
/// alignés sur les boutons ronds en verre (notifications, profil).
class ClientHeaderIos extends StatelessWidget {
  final String caption;      // ex. « Mardi 11 novembre »
  final String title;        // ex. « Bonjour Yassin »
  final int notifCount;
  final VoidCallback onNotifTap;
  final VoidCallback onProfileTap;
  final ImageProvider? avatarImage;
  final String initials;

  const ClientHeaderIos({
    super.key,
    required this.caption,
    required this.title,
    required this.notifCount,
    required this.onNotifTap,
    required this.onProfileTap,
    required this.avatarImage,
    required this.initials,
  });

  static const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  static const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  /// « Mardi 11 novembre »
  static String today() {
    final d = DateTime.now();
    return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(caption.toUpperCase(),
                style: QText.label.copyWith(fontWeight: FontWeight.w600, color: context.cSub)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(title, maxLines: 1,
                  style: QText.largeTitle(context).copyWith(color: context.cText)),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        _GlassCircle(
          onTap: onNotifTap,
          child: Stack(clipBehavior: Clip.none, children: [
            Icon(CupertinoIcons.bell, size: 21, color: context.cText),
            if (notifCount > 0)
              Positioned(
                top: -1, right: -1,
                child: Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(
                    color: kError, shape: BoxShape.circle,
                    border: Border.all(color: context.cSurface, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kPrimary, shape: BoxShape.circle,
              image: avatarImage != null ? DecorationImage(image: avatarImage!, fit: BoxFit.cover) : null,
            ),
            alignment: Alignment.center,
            child: avatarImage == null
                ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))
                : null,
          ),
        ),
      ]),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassCircle({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cSurface.withValues(alpha: context.isDark ? 0.5 : 0.78),
              border: Border.all(color: Colors.white.withValues(alpha: context.isDark ? 0.12 : 0.9)),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
