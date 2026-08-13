import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/widgets/gradient_background.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/tower_loading.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    // Show spinner while restoring session OR while authenticated and
    // waiting for the router to move to home/onboarding.
    final isRestoring = auth.status == AuthStatus.unknown ||
        auth.status == AuthStatus.loading ||
        auth.isAuthenticated;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = isLandscape
        ? (shortest * 0.28).clamp(72.0, 96.0)
        : (shortest * 0.34).clamp(100.0, 132.0);

    return GradientBackground(
      useScaffold: true,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 36 : 28,
        vertical: isLandscape ? 12 : 24,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    if (!isLandscape) const Spacer(flex: 3) else const SizedBox(height: 8),
                    Container(
                      width: logoSize,
                      height: logoSize,
                      padding: EdgeInsets.all(logoSize * 0.14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(logoSize * 0.27),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 32,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.local_parking_rounded,
                          size: logoSize * 0.5,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                    SizedBox(height: isLandscape ? 16 : 34),
                    Text(
                      isLandscape ? 'MultiParking Tower' : 'MultiParking\nTower',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -1,
                            fontSize: isLandscape ? 28 : null,
                          ),
                    ),
                    SizedBox(height: isLandscape ? 8 : 14),
                    Text(
                      'Smart parking. Seamless journeys.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textMutedDark,
                            letterSpacing: .2,
                            fontSize: isLandscape ? 14 : null,
                          ),
                    ),
                    if (!isLandscape) const Spacer(flex: 4) else const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: isRestoring
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              height: 96,
                              child: Center(
                                child: TowerLoadingIndicator(
                                  size: 72,
                                  compact: true,
                                ),
                              ),
                            )
                          : PremiumButton(
                              key: const ValueKey('start'),
                              label: 'GET STARTED',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () => context.go(AppRoutes.login),
                            ),
                    ),
                    SizedBox(height: isLandscape ? 8 : 12),
                    Text(
                      'SECURE • FAST • CONTACTLESS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMutedDark,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                    ),
                    if (!isLandscape) const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
