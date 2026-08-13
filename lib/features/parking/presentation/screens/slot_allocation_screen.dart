import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/gradient_background.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/tower_loading.dart';
import 'package:multiparking_tower/features/parking/presentation/providers/parking_provider.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/providers/onboarding_provider.dart';

/// Onboarding step 4 — allocate a slot and mint the QR pass.
class SlotAllocationScreen extends ConsumerStatefulWidget {
  const SlotAllocationScreen({super.key});

  @override
  ConsumerState<SlotAllocationScreen> createState() =>
      _SlotAllocationScreenState();
}

class _SlotAllocationScreenState extends ConsumerState<SlotAllocationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(slotAllocationControllerProvider).status;
      // Only kick off automatically from a blank slate. Failures retry via the
      // button so a rebuild never re-charges the allocation endpoint.
      if (status == SlotAllocationStatus.idle) {
        ref.read(slotAllocationControllerProvider.notifier).allocate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(slotAllocationControllerProvider);

    return PopScope(
      canPop: state.status != SlotAllocationStatus.inProgress,
      child: GradientBackground(
        useScaffold: true,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: switch (state.status) {
            SlotAllocationStatus.idle ||
            SlotAllocationStatus.inProgress =>
              _ProgressView(state: state),
            SlotAllocationStatus.success => _ResultView(state: state),
            SlotAllocationStatus.failed => _FailureView(state: state),
          },
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.state});

  final SlotAllocationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                key: const ValueKey('allocation-progress'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const TowerLoadingIndicator(
                    size: 96,
                    label: null,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Reserving your slot',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We are matching you with the closest available slot in the tower.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMutedDark,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  for (var i = 0; i < SlotAllocationStep.values.length; i++)
                    _StepRow(
                      step: SlotAllocationStep.values[i],
                      isDone: i < state.completedSteps,
                      isActive: i == state.completedSteps,
                    ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: state.progress),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor:
                            AppColors.textOnDark.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.peachDeep,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'This usually takes a few seconds.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMutedDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isDone,
    required this.isActive,
  });

  final SlotAllocationStep step;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDone
        ? AppColors.success
        : (isActive ? AppColors.peach : AppColors.textMutedDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          SizedBox(
            height: 28,
            width: 28,
            child: isActive
                ? const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.peach),
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppColors.success.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: Border.all(
                        color: isDone
                            ? AppColors.success
                            : AppColors.textMutedDark.withValues(alpha: 0.5),
                        width: 1.6,
                      ),
                    ),
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.success,
                          )
                        : null,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              style: theme.textTheme.titleSmall!.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(step.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends ConsumerWidget {
  const _ResultView({required this.state});

  final SlotAllocationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slot = state.slot;

    return Column(
      key: const ValueKey('allocation-result'),
      children: [
        const Spacer(),
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.verified_rounded,
            size: 34,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Your slot is reserved',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textOnDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan your QR pass at the tower gate to enter.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMutedDark,
          ),
        ),
        const SizedBox(height: 28),
        if (slot != null) _SlotCard(slot: slot, qrCode: state.qrCode),
        const Spacer(),
        PremiumButton(
          label: 'CONTINUE TO DASHBOARD',
          icon: Icons.arrow_forward_rounded,
          onPressed: () async {
            ref.read(slotAllocationControllerProvider.notifier).reset();
            await ref.read(onboardingProvider.notifier).refresh();
            if (!context.mounted) return;
            context.go('/home');
          },
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, this.qrCode});

  final ParkingSlotModel slot;
  final QrCodeModel? qrCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      color: AppColors.creamSurface,
      padding: const EdgeInsets.all(20),
      border: Border.all(
        color: AppColors.peachDeep.withValues(alpha: 0.5),
        width: 1.4,
      ),
      child: Column(
        children: [
          if (slot.isPremium)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.peachGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PREMIUM SLOT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(child: _SlotFact(label: 'Tower', value: slot.tower)),
              Expanded(
                child: _SlotFact(label: 'Floor', value: '${slot.floor}'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _SlotFact(label: 'Zone', value: slot.zone)),
              Expanded(
                child: _SlotFact(label: 'Slot', value: slot.slotNumber),
              ),
            ],
          ),
          if (qrCode != null) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 18,
                  color: AppColors.tealDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    qrCode!.isPermanent
                        ? 'Permanent QR pass issued'
                        : 'QR pass valid till '
                            '${Formatters.dateTime(qrCode!.expiresAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotFact extends StatelessWidget {
  const _SlotFact({required this.label, required this.value});

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
            color: AppColors.textMuted,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.tealDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FailureView extends ConsumerWidget {
  const _FailureView({required this.state});

  final SlotAllocationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('allocation-failed'),
      children: [
        const Spacer(),
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 34,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Slot allocation failed',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textOnDark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          state.errorMessage ??
              'We could not reserve a slot right now. Please try again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMutedDark,
            height: 1.5,
          ),
        ),
        const Spacer(),
        PremiumButton(
          label: 'TRY AGAIN',
          icon: Icons.refresh_rounded,
          onPressed: () =>
              ref.read(slotAllocationControllerProvider.notifier).allocate(),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go('/home'),
          style: TextButton.styleFrom(foregroundColor: AppColors.peach),
          child: const Text('Continue to dashboard'),
        ),
      ],
    );
  }
}
