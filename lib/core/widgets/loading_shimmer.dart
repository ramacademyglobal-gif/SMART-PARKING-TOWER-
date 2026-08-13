import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';

/// Applies a theme-aware shimmer effect to any [child] placeholder.
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? AppColors.charcoalElevated
          : AppColors.creamWarm,
      highlightColor: isDark
          ? AppColors.charcoalSurface
          : AppColors.creamSurface,
      child: child,
    );
  }
}

/// A single shimmering rounded block of a fixed [height]/[width].
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = 8,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A shimmering card placeholder that mimics a content card layout.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(height: 56, width: 56, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  ShimmerBox(height: 14, width: 160),
                  SizedBox(height: 10),
                  ShimmerBox(height: 12, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical list of [ShimmerCard]s used while a list is loading.
class ShimmerList extends StatelessWidget {
  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 96,
    this.spacing = 14,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final double itemHeight;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, __) => ShimmerCard(height: itemHeight),
    );
  }
}
