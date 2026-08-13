import 'package:flutter/material.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';

/// Visual variants of [PremiumButton].
enum PremiumButtonVariant { primary, secondary, text }

/// A premium, brand-styled button with a filled peach primary style, an
/// outlined secondary style, and an inline loading state.
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.height = 54,
  });

  /// Convenience constructor for the outlined secondary style.
  const PremiumButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.height = 54,
  }) : variant = PremiumButtonVariant.secondary;

  /// Convenience constructor for the flat text style.
  const PremiumButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.height = 48,
  }) : variant = PremiumButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final PremiumButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _buildChild(context);

    final button = switch (variant) {
      PremiumButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      PremiumButtonVariant.secondary => OutlinedButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      PremiumButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
    };

    final sized = SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: button,
    );

    return sized;
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      final color = variant == PremiumButtonVariant.primary
          ? AppColors.tealDark
          : Theme.of(context).colorScheme.primary;
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    if (icon == null) {
      return Text(label, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// A pill-shaped icon-only variant used for compact actions.
class PremiumIconButton extends StatelessWidget {
  const PremiumIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.filled = false,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: filled ? AppColors.peachDeep : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: 22,
              color: filled ? AppColors.tealDark : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
