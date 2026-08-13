import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/features/authentication/presentation/screens/otp_verification_screen.dart';
import 'package:multiparking_tower/features/authentication/presentation/screens/phone_login_screen.dart';
import 'package:multiparking_tower/features/authentication/presentation/screens/splash_screen.dart';
import 'package:multiparking_tower/features/authentication/presentation/screens/staff_login_screen.dart';
import 'package:multiparking_tower/features/history/presentation/screens/parking_history_screen.dart';
import 'package:multiparking_tower/features/home/presentation/screens/dashboard_screen.dart';
import 'package:multiparking_tower/features/home/presentation/screens/main_shell_screen.dart';
import 'package:multiparking_tower/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:multiparking_tower/features/parking/presentation/screens/slot_allocation_screen.dart';
import 'package:multiparking_tower/features/payment/presentation/screens/payment_result_screen.dart';
import 'package:multiparking_tower/features/profile/presentation/screens/profile_screen.dart';
import 'package:multiparking_tower/features/qr/presentation/screens/qr_fullscreen_screen.dart';
import 'package:multiparking_tower/features/qr/presentation/screens/qr_screen.dart';
import 'package:multiparking_tower/features/qr/presentation/screens/scanner_screen.dart';
import 'package:multiparking_tower/features/settings/presentation/screens/settings_screen.dart';
import 'package:multiparking_tower/features/staff/presentation/screens/staff_home_screen.dart';
import 'package:multiparking_tower/features/staff/presentation/screens/staff_scanner_screen.dart';
import 'package:multiparking_tower/features/staff/presentation/screens/staff_sessions_screen.dart';
import 'package:multiparking_tower/features/staff/presentation/screens/staff_walk_in_screen.dart';
import 'package:multiparking_tower/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:multiparking_tower/features/subscription/presentation/screens/subscription_selection_screen.dart';
import 'package:multiparking_tower/features/support/presentation/screens/support_screen.dart';
import 'package:multiparking_tower/features/vehicle/presentation/screens/vehicle_onboarding_screen.dart';
import 'package:multiparking_tower/features/vehicle/presentation/screens/vehicles_screen.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/providers/onboarding_provider.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<AsyncValue<OnboardingStep>>(
      onboardingProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.peachSoft,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.wrong_location_outlined,
                  size: 44,
                  color: AppColors.tealDeep,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                state.error?.message ?? 'This destination is unavailable.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffLogin,
        builder: (_, __) => const StaffLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, state) => OtpVerificationScreen(
          phone: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingSubscription,
        builder: (_, __) => const SubscriptionSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPayment,
        builder: (_, state) => PaymentResultScreen(
          planType: state.extra is SubscriptionPlanType
              ? state.extra! as SubscriptionPlanType
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingVehicle,
        builder: (_, __) => const VehicleOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingAllocation,
        builder: (_, __) => const SlotAllocationScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => MainShellScreen(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'dashboard',
                    builder: (_, __) => const DashboardScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (_, __) => const ParkingHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.vehicles,
                builder: (_, __) => const VehiclesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.qr,
                builder: (_, __) => const QrScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.support,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.qrFullscreen,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const QrFullscreenScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanner,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const ScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffHome,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const StaffHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffScanner,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const StaffScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffWalkIn,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const StaffWalkInScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffSessions,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const StaffSessionsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String? _redirect(Ref ref, GoRouterState routerState) {
  final auth = ref.read(authProvider);
  final path = routerState.matchedLocation;
  final isSplash = path == AppRoutes.splash;
  final isAuthRoute = path == AppRoutes.login ||
      path == AppRoutes.otp ||
      path == AppRoutes.staffLogin;
  final isStaffRoute = path == AppRoutes.staffHome ||
      path == AppRoutes.staffScanner ||
      path == AppRoutes.staffWalkIn ||
      path == AppRoutes.staffSessions;
  final isOnboardingRoute = path.startsWith('/onboarding/');

  // Only gate on the initial session restore — never bounce OTP/login
  // back to splash while send/verify is in progress (AuthStatus.loading).
  if (auth.status == AuthStatus.unknown) {
    return isSplash ? null : AppRoutes.splash;
  }

  if (!auth.isAuthenticated) {
    if (isSplash || isAuthRoute) return null;
    return AppRoutes.login;
  }

  // Staff / admin accounts skip member onboarding and stay in the console.
  if (auth.user?.isStaff == true) {
    if (isSplash || isAuthRoute || path.startsWith('/home') || isOnboardingRoute) {
      return AppRoutes.staffHome;
    }
    if (isStaffRoute) return null;
    return AppRoutes.staffHome;
  }

  // Members should not linger on staff routes.
  if (isStaffRoute || path == AppRoutes.staffLogin) {
    return AppRoutes.home;
  }

  final onboarding = ref.read(onboardingProvider);
  // Stay put while onboarding resolves after login (do not force splash).
  if (onboarding.isLoading || !onboarding.hasValue) {
    return null;
  }
  if (onboarding.hasError) {
    if (isSplash || isAuthRoute) return AppRoutes.onboardingVehicle;
    return null;
  }

  final step = onboarding.valueOrNull ?? OnboardingStep.none;
  final requiredRoute = switch (step) {
    OnboardingStep.vehicle => AppRoutes.onboardingVehicle,
    OnboardingStep.allocation => AppRoutes.onboardingAllocation,
    OnboardingStep.complete => AppRoutes.home,
    OnboardingStep.none => AppRoutes.home,
  };

  if (step == OnboardingStep.complete) {
    if (isSplash || isAuthRoute) return AppRoutes.home;
    // Optional subscription purchase remains reachable.
    if (path == AppRoutes.onboardingSubscription ||
        path == AppRoutes.onboardingPayment) {
      return null;
    }
    if (path == AppRoutes.onboardingVehicle ||
        path == AppRoutes.onboardingAllocation) {
      return null;
    }
    if (isOnboardingRoute) return AppRoutes.home;
    return null;
  }

  return path == requiredRoute ? null : requiredRoute;
}
