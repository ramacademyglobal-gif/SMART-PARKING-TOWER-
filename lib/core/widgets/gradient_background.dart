import 'package:flutter/material.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';

/// A full-bleed teal-to-slate gradient background, optionally wrapped in a
/// [Scaffold]. Use as a premium backdrop for auth, splash and hero screens.
class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.gradient,
    this.useScaffold = false,
    this.safeArea = true,
    this.appBar,
    this.padding,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final Gradient? gradient;
  final bool useScaffold;
  final bool safeArea;
  final PreferredSizeWidget? appBar;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedGradient = gradient ??
        (isDark ? AppColors.tealDarkGradient : AppColors.tealGradient);

    Widget wrap(Widget content) {
      if (padding != null) {
        content = Padding(padding: padding!, child: content);
      }
      if (safeArea) {
        content = SafeArea(child: content);
      }
      return content;
    }

    if (!useScaffold) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: resolvedGradient),
        child: wrap(child),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: resolvedGradient),
        child: wrap(child),
      ),
    );
  }
}
