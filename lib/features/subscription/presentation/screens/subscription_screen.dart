import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/loading_shimmer.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/section_header.dart';
import 'package:multiparking_tower/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

/// Post-login subscription hub: current plan, renewal, upgrade and receipts.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: RefreshIndicator(
        onRefresh: () async => refreshSubscriptionData(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            subscriptionAsync.when(
              loading: () => const ShimmerCard(height: 200),
              error: (_, __) => EmptyState.error(
                title: 'Could not load your subscription',
                subtitle: 'Pull down to refresh once you are back online.',
                compact: true,
                onAction: () => ref.invalidate(currentSubscriptionProvider),
              ),
              data: (subscription) => subscription == null
                  ? const _NoSubscriptionCard()
                  : _CurrentPlanCard(subscription: subscription),
            ),
            const SizedBox(height: 24),
            const _PaymentHistorySection(),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends ConsumerWidget {
  const _CurrentPlanCard({required this.subscription});

  final SubscriptionModel subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(planByTypeProvider(subscription.planType));
    final daysRemaining = ref.watch(subscriptionDaysRemainingProvider) ?? 0;
    final totalDays = plan?.durationDays ??
        subscription.expiryDate.difference(subscription.startDate).inDays;
    final progress = totalDays <= 0
        ? 0.0
        : (1 - (daysRemaining / totalDays)).clamp(0.0, 1.0).toDouble();
    final isExpiringSoon = subscription.isActive && daysRemaining <= 7;

    return Column(
      children: [
        PremiumCard(
          gradient: AppColors.tealGradient,
          padding: const EdgeInsets.all(22),
          border: Border.all(color: Colors.transparent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan?.name ?? _planLabel(subscription.planType),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(status: subscription.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subscription.planType == SubscriptionPlanType.annual
                    ? 'Preferential premium bay'
                    : 'Preferential bay · monthly',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMutedDark,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _PlanFact(
                      label: 'Started',
                      value: Formatters.date(subscription.startDate),
                    ),
                  ),
                  Expanded(
                    child: _PlanFact(
                      label: subscription.isActive ? 'Renews on' : 'Expired on',
                      value: Formatters.date(subscription.expiryDate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor:
                      AppColors.textOnDark.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isExpiringSoon ? AppColors.warning : AppColors.peachDeep,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subscription.isActive
                    ? '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} '
                        'remaining'
                    : 'This plan has ended. Renew to keep your slot.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isExpiringSoon
                      ? AppColors.peach
                      : AppColors.textMutedDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PremiumButton(
                label: subscription.isActive ? 'RENEW' : 'REACTIVATE',
                onPressed: () {
                  ref
                      .read(selectedPlanProvider.notifier)
                      .select(subscription.planType);
                  context.push('/onboarding/subscription');
                },
              ),
            ),
            if (subscription.planType == SubscriptionPlanType.monthly) ...[
              const SizedBox(width: 14),
              Expanded(
                child: PremiumButton.secondary(
                  label: 'UPGRADE',
                  onPressed: () {
                    ref
                        .read(selectedPlanProvider.notifier)
                        .select(SubscriptionPlanType.annual);
                    context.push('/onboarding/subscription');
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _planLabel(SubscriptionPlanType type) {
    return switch (type) {
      SubscriptionPlanType.monthly => 'Monthly plan',
      SubscriptionPlanType.annual => 'Annual plan',
      SubscriptionPlanType.hourly => 'Hourly pay-as-you-go',
    };
  }
}

class _NoSubscriptionCard extends StatelessWidget {
  const _NoSubscriptionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              gradient: AppColors.peachGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Pay as you go',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Parking works without a plan at ₹50/hour. '
            'Choose monthly or annual only if you want a reserved pass.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          PremiumButton(
            label: 'CHOOSE A PLAN',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.push('/onboarding/subscription'),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistorySection extends ConsumerWidget {
  const _PaymentHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Payment history',
          subtitle: 'Receipts for every subscription charge.',
        ),
        const SizedBox(height: 8),
        paymentsAsync.when(
          // Rendered as a Column rather than ShimmerList: this section is
          // already inside a scroll view.
          loading: () => const Column(
            children: [
              ShimmerCard(height: 78),
              SizedBox(height: 12),
              ShimmerCard(height: 78),
              SizedBox(height: 12),
              ShimmerCard(height: 78),
            ],
          ),
          error: (_, __) => EmptyState.error(
            title: 'Could not load payments',
            subtitle: 'Pull down to try again.',
            compact: true,
            onAction: () => ref.invalidate(paymentHistoryProvider),
          ),
          data: (payments) {
            if (payments.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No payments yet',
                subtitle: 'Your subscription receipts will appear here.',
                compact: true,
              );
            }
            return Column(
              children: [
                for (final payment in payments) ...[
                  _PaymentTile(payment: payment),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = _visuals(payment.status);

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.planType == SubscriptionPlanType.annual
                      ? 'Annual plan'
                      : 'Monthly plan',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  Formatters.dateTime(payment.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(payment.amountInRupees, decimals: false),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                payment.status.name.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, Color) _visuals(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.success => (Icons.check_rounded, AppColors.success),
      PaymentStatus.failed => (Icons.close_rounded, AppColors.error),
      PaymentStatus.cancelled => (Icons.block_rounded, AppColors.warning),
      PaymentStatus.created ||
      PaymentStatus.pending =>
        (Icons.hourglass_bottom_rounded, AppColors.info),
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SubscriptionStatus.active => AppColors.success,
      SubscriptionStatus.pending => AppColors.warning,
      SubscriptionStatus.expired => AppColors.error,
      SubscriptionStatus.cancelled => AppColors.textMutedDark,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _PlanFact extends StatelessWidget {
  const _PlanFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textMutedDark,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
