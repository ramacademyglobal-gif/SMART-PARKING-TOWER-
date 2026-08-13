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
import 'package:multiparking_tower/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

/// Optional subscription plans — users may skip and pay ₹50/hour instead.
class SubscriptionSelectionScreen extends ConsumerWidget {
  const SubscriptionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      body: plansAsync.when(
        loading: () => const SafeArea(child: _LoadingView()),
        error: (_, __) => SafeArea(
          child: EmptyState.error(
            title: 'Could not load plans',
            subtitle: 'Check your connection and try again.',
            onAction: () => ref.invalidate(subscriptionPlansProvider),
          ),
        ),
        data: (plans) => _PlansView(plans: plans),
      ),
    );
  }
}

class _PlansView extends ConsumerWidget {
  const _PlansView({required this.plans});

  final List<SubscriptionPlanModel> plans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plans.isEmpty) {
      return SafeArea(
        child: EmptyState(
          icon: Icons.workspace_premium_outlined,
          title: 'No plans available',
          subtitle: 'Please try again in a moment.',
          actionLabel: 'Reload',
          onAction: () => ref.invalidate(subscriptionPlansProvider),
        ),
      );
    }

    final selectedType = ref.watch(selectedPlanProvider);
    final selectedPlan = plans.firstWhere(
      (plan) => plan.type == selectedType,
      orElse: () => plans.first,
    );
    final canSkip = true; // Plans are optional — hourly pay-as-you-go is default.

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const SafeArea(bottom: false, child: _Header()),
              const SizedBox(height: 24),
              for (final plan in plans) ...[
                _PlanCard(
                  plan: plan,
                  isSelected: plan.type == selectedPlan.type,
                  monthlyReference: _monthlyReference(plans),
                  onTap: () => ref
                      .read(selectedPlanProvider.notifier)
                      .select(plan.type),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              _ComparisonCard(plans: plans),
              const SizedBox(height: 18),
              const _TrustNote(),
            ],
          ),
        ),
        _CheckoutBar(plan: selectedPlan, canSkip: canSkip),
      ],
    );
  }

  /// The monthly plan is the baseline the annual plan's savings are measured
  /// against.
  SubscriptionPlanModel? _monthlyReference(List<SubscriptionPlanModel> plans) {
    for (final plan in plans) {
      if (plan.type == SubscriptionPlanType.monthly) return plan;
    }
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.peachGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: 26,
                width: 26,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.local_parking_rounded,
                  size: 26,
                  color: AppColors.tealDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'MultiParking Tower',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Optional plans',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Subscribe for a reserved slot, or skip and pay ₹50 per hour '
          'based on how long you park.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    this.monthlyReference,
  });

  final SubscriptionPlanModel plan;
  final bool isSelected;
  final VoidCallback onTap;
  final SubscriptionPlanModel? monthlyReference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final savingsPercent = _savingsPercent();

    return PremiumCard(
      onTap: onTap,
      selected: isSelected,
      padding: const EdgeInsets.all(20),
      color: isSelected
          ? AppColors.peachSoft.withValues(alpha: 0.35)
          : scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionDot(isSelected: isSelected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (plan.isPremium) ...[
                          const SizedBox(width: 8),
                          const _Badge(label: 'RECOMMENDED'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _durationLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(plan.priceInRupees, decimals: false),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${Formatters.currency(_effectiveMonthly(), decimals: false)}/mo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (savingsPercent != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.savings_outlined,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Save $savingsPercent% versus paying monthly',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: 16),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.peachDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _durationLabel() {
    if (plan.durationDays % 365 == 0) {
      final years = plan.durationDays ~/ 365;
      return years == 1 ? 'Billed once a year' : 'Billed every $years years';
    }
    if (plan.durationDays % 30 == 0) {
      final months = plan.durationDays ~/ 30;
      return months == 1 ? 'Billed every month' : 'Billed every $months months';
    }
    return 'Valid for ${plan.durationDays} days';
  }

  double _effectiveMonthly() {
    final months = plan.durationDays / 30.0;
    if (months <= 0) return plan.priceInRupees;
    return plan.priceInRupees / months;
  }

  /// Percentage saved against buying the monthly plan for the same period.
  int? _savingsPercent() {
    final monthly = monthlyReference;
    if (monthly == null ||
        monthly.type == plan.type ||
        monthly.priceInPaise <= 0 ||
        monthly.durationDays <= 0) {
      return null;
    }
    final periods = plan.durationDays / monthly.durationDays;
    final baseline = monthly.priceInPaise * periods;
    if (baseline <= plan.priceInPaise) return null;
    return (((baseline - plan.priceInPaise) / baseline) * 100).round();
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.peachDeep : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.peachDeep : scheme.outline,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.tealDark)
          : null,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.peachGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.tealDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

/// Side-by-side feature matrix across every plan.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.plans});

  final List<SubscriptionPlanModel> plans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final features = _allFeatures();

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare plans',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              for (final plan in plans)
                SizedBox(
                  width: 64,
                  child: Text(
                    _shortLabel(plan),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: plan.isPremium
                          ? AppColors.peachDeep
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final feature in features) ...[
            Divider(color: scheme.outlineVariant, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      feature,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  for (final plan in plans)
                    SizedBox(
                      width: 64,
                      child: Center(
                        child: plan.features.contains(feature)
                            ? const Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: AppColors.success,
                              )
                            : Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 20,
                                color: scheme.outline.withValues(alpha: 0.6),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _allFeatures() {
    final features = <String>[];
    for (final plan in plans) {
      for (final feature in plan.features) {
        if (!features.contains(feature)) features.add(feature);
      }
    }
    return features;
  }

  String _shortLabel(SubscriptionPlanModel plan) {
    return switch (plan.type) {
      SubscriptionPlanType.monthly => 'Monthly',
      SubscriptionPlanType.annual => 'Annual',
      SubscriptionPlanType.hourly => 'Hourly',
    };
  }
}

class _TrustNote extends StatelessWidget {
  const _TrustNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Payments are secured by Razorpay. Your slot is reserved as soon '
            'as the payment is verified.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.plan, required this.canSkip});

  final SubscriptionPlanModel plan;
  final bool canSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow,
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(
                            plan.priceInRupees,
                            decimals: false,
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumButton(
                      label: 'PAY NOW',
                      icon: Icons.lock_rounded,
                      onPressed: () => context.push(
                        '/onboarding/payment',
                        extra: plan.type,
                      ),
                    ),
                  ),
                ],
              ),
              if (canSkip)
                PremiumButton.text(
                  label: 'Skip — pay ₹50/hour instead',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: const [
        LoadingShimmer(child: ShimmerBox(height: 28, width: 180, radius: 10)),
        SizedBox(height: 14),
        LoadingShimmer(child: ShimmerBox(height: 14, width: 260)),
        SizedBox(height: 32),
        ShimmerCard(height: 220),
        SizedBox(height: 16),
        ShimmerCard(height: 240),
        SizedBox(height: 16),
        ShimmerCard(height: 180),
      ],
    );
  }
}
