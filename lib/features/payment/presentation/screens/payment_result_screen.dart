import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/features/payment/presentation/providers/payment_provider.dart';
import 'package:multiparking_tower/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/providers/onboarding_provider.dart';

/// Onboarding step 2 — runs checkout and reports the outcome.
///
/// The screen owns no payment logic of its own: it starts
/// [PaymentController.startPayment] once and renders whatever the controller
/// reports, so a rebuild or hot reload can never trigger a second charge.
class PaymentResultScreen extends ConsumerStatefulWidget {
  const PaymentResultScreen({super.key, this.planType});

  /// Plan passed from the selection screen. Falls back to
  /// [selectedPlanProvider] when the route is opened directly.
  final SubscriptionPlanType? planType;

  @override
  ConsumerState<PaymentResultScreen> createState() =>
      _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(paymentControllerProvider.notifier);
      final status = ref.read(paymentControllerProvider).status;
      // A checkout already in flight must never be started twice.
      if (status.isBusy) return;
      // Clear the outcome of an earlier purchase (renew/upgrade flows reuse
      // this controller) before charging again.
      if (status.isFinished) controller.reset();
      controller.startPayment(
        widget.planType ?? ref.read(selectedPlanProvider),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentControllerProvider);
    final plan = state.planType == null
        ? null
        : ref.watch(planByTypeProvider(state.planType!));

    return PopScope(
      canPop: !state.status.isBusy,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: switch (state.status) {
                PaymentFlowStatus.idle ||
                PaymentFlowStatus.creatingOrder ||
                PaymentFlowStatus.awaitingCheckout ||
                PaymentFlowStatus.verifying =>
                  _InProgressView(state: state),
                PaymentFlowStatus.success => _SuccessView(
                    state: state,
                    planName: plan?.name,
                  ),
                PaymentFlowStatus.cancelled => _CancelledView(state: state),
                PaymentFlowStatus.failed => _FailedView(state: state),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InProgressView extends StatelessWidget {
  const _InProgressView({required this.state});

  final PaymentState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      key: const ValueKey('payment-in-progress'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatusIcon(
          key: const ValueKey('payment-icon-busy'),
          icon: Icons.lock_rounded,
          color: AppColors.peachDeep,
          pulse: true,
          showProgressRing: true,
        ),
        const SizedBox(height: 32),
        Text(
          _title(),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          state.notice ?? 'Keep this screen open until we confirm your payment.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),
        _FlowSteps(status: state.status),
        if (state.amountInRupees != null) ...[
          const SizedBox(height: 32),
          Text(
            Formatters.currency(state.amountInRupees!),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }

  String _title() {
    return switch (state.status) {
      PaymentFlowStatus.creatingOrder => 'Creating your order',
      PaymentFlowStatus.awaitingCheckout => 'Completing payment',
      PaymentFlowStatus.verifying => 'Verifying payment',
      _ => 'Preparing checkout',
    };
  }
}

/// Three-dot progress rail mirroring the controller's stages.
class _FlowSteps extends StatelessWidget {
  const _FlowSteps({required this.status});

  final PaymentFlowStatus status;

  static const List<String> _labels = ['Order', 'Payment', 'Verification'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeIndex = switch (status) {
      PaymentFlowStatus.creatingOrder => 0,
      PaymentFlowStatus.awaitingCheckout => 1,
      PaymentFlowStatus.verifying => 2,
      _ => 0,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Container(
              width: 28,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: i <= activeIndex
                  ? AppColors.peachDeep
                  : scheme.outlineVariant,
            ),
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: i == activeIndex ? 12 : 9,
                width: i == activeIndex ? 12 : 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= activeIndex
                      ? AppColors.peachDeep
                      : scheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _labels[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: i <= activeIndex
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                  fontWeight:
                      i == activeIndex ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SuccessView extends ConsumerWidget {
  const _SuccessView({required this.state, this.planName});

  final PaymentState state;
  final String? planName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subscription = state.subscription;

    return Column(
      key: const ValueKey('payment-success'),
      children: [
        const Spacer(),
        const _StatusIcon(
          key: ValueKey('payment-icon-success'),
          icon: Icons.check_rounded,
          color: AppColors.success,
        ),
        const SizedBox(height: 32),
        Text(
          'Payment successful',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your subscription is active. Next, tell us which vehicle will use '
          'the slot.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _ReceiptRow(
                label: 'Plan',
                value: planName ?? _planFallback(),
              ),
              if (state.amountInRupees != null)
                _ReceiptRow(
                  label: 'Amount paid',
                  value: Formatters.currency(state.amountInRupees!),
                ),
              if (subscription != null)
                _ReceiptRow(
                  label: 'Valid till',
                  value: Formatters.date(subscription.expiryDate),
                ),
              if (state.paymentId != null)
                _ReceiptRow(
                  label: 'Reference',
                  value: state.paymentId!,
                  isLast: true,
                ),
            ],
          ),
        ),
        const Spacer(),
        PremiumButton(
          label: 'CONTINUE',
          icon: Icons.arrow_forward_rounded,
          onPressed: () async {
            ref.read(paymentControllerProvider.notifier).reset();
            await ref.read(onboardingProvider.notifier).refresh();
            if (!context.mounted) return;
            // The route can be replaced while refresh is in flight. Checking
            // the widget before reading ref prevents a disposed-ref crash.
            final step = ref.read(onboardingProvider).valueOrNull;
            switch (step) {
              case OnboardingStep.allocation:
                context.go('/onboarding/allocation');
              case OnboardingStep.complete:
                context.go('/home');
              case OnboardingStep.vehicle:
              case OnboardingStep.none:
              case null:
                context.go('/onboarding/vehicle');
            }
          },
        ),
      ],
    );
  }

  String _planFallback() {
    return switch (state.planType) {
      SubscriptionPlanType.monthly => 'Monthly plan',
      SubscriptionPlanType.annual => 'Annual plan',
      SubscriptionPlanType.hourly => 'Hourly parking',
      null => 'Subscription',
    };
  }
}

class _FailedView extends ConsumerWidget {
  const _FailedView({required this.state});

  final PaymentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OutcomeView(
      viewKey: const ValueKey('payment-failed'),
      icon: Icons.priority_high_rounded,
      iconKey: const ValueKey('payment-icon-failed'),
      color: AppColors.error,
      title: 'Payment failed',
      message: state.errorMessage ??
          'The payment did not go through. You have not been charged.',
      primaryLabel: 'TRY AGAIN',
      onPrimary: state.canRetry
          ? () => ref.read(paymentControllerProvider.notifier).retry()
          : null,
      secondaryLabel: 'CHANGE PLAN',
      onSecondary: () {
        ref.read(paymentControllerProvider.notifier).reset();
        context.go('/onboarding/subscription');
      },
    );
  }
}

class _CancelledView extends ConsumerWidget {
  const _CancelledView({required this.state});

  final PaymentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OutcomeView(
      viewKey: const ValueKey('payment-cancelled'),
      icon: Icons.close_rounded,
      iconKey: const ValueKey('payment-icon-cancelled'),
      color: AppColors.warning,
      title: 'Payment cancelled',
      message: state.errorMessage ??
          'You closed the checkout before the payment completed.',
      primaryLabel: 'RESUME PAYMENT',
      onPrimary: state.canRetry
          ? () => ref.read(paymentControllerProvider.notifier).retry()
          : null,
      secondaryLabel: 'CHANGE PLAN',
      onSecondary: () {
        ref.read(paymentControllerProvider.notifier).reset();
        context.go('/onboarding/subscription');
      },
    );
  }
}

class _OutcomeView extends StatelessWidget {
  const _OutcomeView({
    required this.viewKey,
    required this.iconKey,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final Key viewKey;
  final Key iconKey;
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      key: viewKey,
      children: [
        const Spacer(),
        _StatusIcon(key: iconKey, icon: icon, color: color),
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const Spacer(),
        PremiumButton(
          label: primaryLabel,
          icon: Icons.refresh_rounded,
          onPressed: onPrimary,
        ),
        const SizedBox(height: 12),
        PremiumButton.secondary(
          label: secondaryLabel,
          onPressed: onSecondary,
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon badge that springs in for terminal states and breathes while busy.
class _StatusIcon extends StatefulWidget {
  const _StatusIcon({
    super.key,
    required this.icon,
    required this.color,
    this.pulse = false,
    this.showProgressRing = false,
  });

  final IconData icon;
  final Color color;
  final bool pulse;
  final bool showProgressRing;

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.pulse ? 1200 : 700),
    );
    if (widget.pulse) {
      _scale = Tween<double>(begin: 0.92, end: 1.06).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller.repeat(reverse: true);
    } else {
      _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: SizedBox(
        height: 132,
        width: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.showProgressRing)
              SizedBox(
                height: 132,
                width: 132,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.color.withValues(alpha: 0.7),
                  ),
                ),
              ),
            Container(
              height: 108,
              width: 108,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Icon(widget.icon, size: 52, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}
