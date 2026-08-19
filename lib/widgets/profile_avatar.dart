import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// A consistent circular avatar used across profile, feed, chat, and job
/// cards for all three roles. Falls back to a colored initial (derived
/// deterministically from the name, so the same person always gets the
/// same color) instead of a generic person icon when there's no photo.
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;

  const ProfileAvatar({super.key, this.imageUrl, this.name, this.size = 72});

  static const _palette = [
    Color(0xFF17150F),
    Color(0xFFB08A4C),
    Color(0xFFC6273A),
    Color(0xFF3A3A34),
    Color(0xFF5C5C55),
  ];

  Color _colorFor(String seed) {
    if (seed.isEmpty) return AppColors.inkFaint;
    final index = seed.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length;
    return _palette[index];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final trimmedName = (name ?? '').trim();
    final initial = trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '?';

    if (hasImage) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsCircle(initial, trimmedName),
        ),
      );
    }
    return _initialsCircle(initial, trimmedName);
  }

  Widget _initialsCircle(String initial, String seed) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _colorFor(seed), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.paper,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
