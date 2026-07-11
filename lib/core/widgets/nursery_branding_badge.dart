import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Brand icon keys → Material icon data mapping.
const _brandIcons = <String, IconData>{
  'leaf':     Icons.eco_rounded,
  'tree':     Icons.park_rounded,
  'flower':   Icons.local_florist_rounded,
  'seedling': Icons.grass_rounded,
  'pot':      Icons.yard_rounded,
  'cactus':   Icons.spa_rounded,
  'palm':     Icons.filter_vintage_rounded,
  'bonsai':   Icons.nature_rounded,
  'herb':     Icons.energy_savings_leaf_rounded,
  'lotus':    Icons.wb_sunny_rounded,
};

/// Renders nursery branding as a rounded avatar.
///
/// Priority: uploaded logo image → preset icon with brand color → initial letter.
class NurseryBrandingBadge extends StatelessWidget {
  final String? logoUrl;
  final String? brandIconKey;
  final String? brandColor;
  final String nurseryName;
  final double size;

  const NurseryBrandingBadge({
    super.key,
    this.logoUrl,
    this.brandIconKey,
    this.brandColor,
    required this.nurseryName,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.2;

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(radius),
        ),
      );
    }

    if (brandIconKey != null && _brandIcons.containsKey(brandIconKey)) {
      final bg = parseColor(brandColor) ?? AppColors.primaryMain;
      final fgLum = bg.computeLuminance();
      final fg = fgLum > 0.4 ? Colors.black87 : Colors.white;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(_brandIcons[brandIconKey]!, color: fg, size: size * 0.5),
      );
    }

    return _fallback(radius);
  }

  Widget _fallback(double radius) {
    final initial =
        nurseryName.isNotEmpty ? nurseryName[0].toUpperCase() : 'N';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.h3.copyWith(
            color: AppColors.primaryMain,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }

  static Color? parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return null;
    final value = int.tryParse('FF$clean', radix: 16);
    return value == null ? null : Color(value);
  }
}
