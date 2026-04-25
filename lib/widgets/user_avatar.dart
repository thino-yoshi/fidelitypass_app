import 'package:flutter/material.dart';

/// Displays a user avatar: profile picture if URL provided, else colored initial circle.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? fallbackColor;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 42,
    this.fallbackColor,
  });

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Color get _color {
    if (fallbackColor != null) return fallbackColor!;
    final colors = [
      const Color(0xFF2C7BE5),
      const Color(0xFFE24B4A),
      const Color(0xFF27AE60),
      const Color(0xFFA78BFA),
      const Color(0xFFF59E0B),
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _fallback();
          },
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          _initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}
