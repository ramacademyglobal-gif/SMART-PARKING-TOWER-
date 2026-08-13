import 'package:flutter/material.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';

/// A rounded, softly-shadowed card used for premium content surfaces.
///
/// Supports an optional [onTap], custom [padding], a [gradient] fill, and a
/// selected state that highlights the border with the accent colour.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color,
    this.gradient,
    this.borderRadius = AppTheme.radiusLarge,
    this.selected = false,
    this.elevated = true,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final bool selected;
  final bool elevated;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final resolvedBorder = border ??
        (selected
            ? Border.all(color: AppColors.peachDeep, width: 1.8)
            : Border.all(color: scheme.outlineVariant, width: 1));

    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? scheme.surface) : null,
      gradient: gradient,
      borderRadius: radius,
      border: resolvedBorder,
      boxShadow: elevated
          ? [
              BoxShadow(
                color: isDark
                    ? AppColors.shadowDark
                    : AppColors.shadowLight,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: decoration,
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}
