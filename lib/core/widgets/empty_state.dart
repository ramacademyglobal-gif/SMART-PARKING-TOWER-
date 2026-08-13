import 'package:flutter/material.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';

/// A centred illustration-style placeholder used for empty lists and errors.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.compact = false,
  });

  /// Preset for a generic error state with a "Try again" action.
  const EmptyState.error({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle = 'Please try again in a moment.',
    this.actionLabel = 'Try again',
    this.onAction,
    this.compact = false,
  })  : icon = Icons.error_outline_rounded,
        iconColor = AppColors.error;

  /// Preset for an offline state.
  const EmptyState.offline({
    super.key,
    this.title = 'You are offline',
    this.subtitle = 'Check your connection and try again.',
    this.actionLabel = 'Retry',
    this.onAction,
    this.compact = false,
  })  : icon = Icons.wifi_off_rounded,
        iconColor = AppColors.warning;

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resolvedIconColor = iconColor ?? scheme.primary;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 16 : 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 72 : 96,
              height: compact ? 72 : 96,
              decoration: BoxDecoration(
                color: resolvedIconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 34 : 44,
                color: resolvedIconColor,
              ),
            ),
            SizedBox(height: compact ? 16 : 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              PremiumButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
