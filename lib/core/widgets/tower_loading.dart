import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';

/// Brand loading indicator — animated tower rings + parking glyph.
///
/// Use for short waits (auth, QR mint, slot booking) instead of a plain spinner.
class TowerLoadingIndicator extends StatefulWidget {
  const TowerLoadingIndicator({
    super.key,
    this.size = 88,
    this.color = AppColors.peach,
    this.label,
    this.compact = false,
  });

  final double size;
  final Color color;
  final String? label;
  final bool compact;

  @override
  State<TowerLoadingIndicator> createState() => _TowerLoadingIndicatorState();
}

class _TowerLoadingIndicatorState extends State<TowerLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? widget.size * 0.72 : widget.size;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_spin, _pulse]),
            builder: (context, _) {
              final pulse = 0.72 + (_pulse.value * 0.28);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Soft glow
                  Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: size * 0.78,
                      height: size * 0.78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                  // Outer dashed ring
                  Transform.rotate(
                    angle: _spin.value * 2 * math.pi,
                    child: CustomPaint(
                      size: Size.square(size),
                      painter: _RingPainter(
                        color: widget.color.withValues(alpha: 0.55),
                        strokeWidth: 2.2,
                        dashCount: 18,
                      ),
                    ),
                  ),
                  // Inner solid arc
                  Transform.rotate(
                    angle: -_spin.value * 2 * math.pi * 1.35,
                    child: SizedBox(
                      width: size * 0.68,
                      height: size * 0.68,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.2,
                        strokeCap: StrokeCap.round,
                        value: 0.28,
                        color: widget.color,
                        backgroundColor: widget.color.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  // Core badge
                  Container(
                    width: size * 0.42,
                    height: size * 0.42,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(size * 0.14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.local_parking_rounded,
                      color: AppColors.tealDeep,
                      size: size * 0.22,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.label != null) ...[
          SizedBox(height: widget.compact ? 12 : 18),
          Text(
            widget.label!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: widget.color == AppColors.peach
                  ? AppColors.textOnDark
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          _LoadingDots(color: widget.color),
        ],
      ],
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.color});

  final Color color;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value + i * 0.22) % 1.0;
            final opacity = 0.25 + (math.sin(t * math.pi) * 0.75);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  final Color color;
  final double strokeWidth;
  final int dashCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth;
    final sweep = (2 * math.pi) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      final start = i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * 0.45,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashCount != dashCount;
}

/// Full-screen branded loading panel (auth / booking waits).
class TowerLoadingPanel extends StatelessWidget {
  const TowerLoadingPanel({
    super.key,
    this.title = 'Please wait',
    this.subtitle,
    this.onDark = true,
  });

  final String title;
  final String? subtitle;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TowerLoadingIndicator(
              label: title,
              color: onDark ? AppColors.peach : AppColors.tealDeep,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onDark
                      ? AppColors.textMutedDark
                      : theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal barrier overlay while a booking / network action runs.
class TowerLoadingOverlay extends StatelessWidget {
  const TowerLoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message = 'Booking your slot',
    this.detail = 'Reserving a bay and generating your QR pass…',
  });

  final bool visible;
  final Widget child;
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: ColoredBox(
                  color: AppColors.tealDark.withValues(alpha: 0.72),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: AppColors.charcoalElevated,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(
                            color: AppColors.peach.withValues(alpha: 0.28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TowerLoadingIndicator(
                              size: 96,
                              label: null,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              detail,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textMutedDark,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
