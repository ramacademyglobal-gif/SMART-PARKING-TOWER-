import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/shell_back_button.dart';
import 'package:multiparking_tower/core/widgets/tower_loading.dart';
import 'package:multiparking_tower/features/parking/presentation/widgets/booking_fee_sheet.dart';
import 'package:multiparking_tower/features/qr/presentation/providers/qr_provider.dart';
import 'package:multiparking_tower/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class QrScreen extends ConsumerWidget {
  const QrScreen({super.key});

  Future<void> _bookSlot(BuildContext context, WidgetRef ref) async {
    final hasSub = ref.read(hasActiveSubscriptionProvider);
    if (hasSub) {
      await ref.read(qrControllerProvider.notifier).refreshQr();
      return;
    }
    await showBookingFeeCheckout(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrState = ref.watch(qrControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Entry QR'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(qrControllerProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            if (qrState.status == QrLoadStatus.loading && qrState.qr == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: TowerLoadingPanel(
                  title: 'Preparing your QR',
                  subtitle: 'Fetching your tower access pass…',
                  onDark: false,
                ),
              )
            else if (qrState.status == QrLoadStatus.refreshing &&
                qrState.qr == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: TowerLoadingPanel(
                  title: 'Booking your slot',
                  subtitle: 'Reserving a bay and minting your QR…',
                  onDark: false,
                ),
              )
            else if (qrState.status == QrLoadStatus.error && qrState.qr == null)
              EmptyState.error(
                title: 'QR unavailable',
                subtitle: qrState.errorMessage,
                onAction: () =>
                    ref.read(qrControllerProvider.notifier).load(),
              )
            else if (qrState.qr == null)
              EmptyState(
                icon: Icons.exit_to_app_rounded,
                title: 'You have exited',
                subtitle:
                    'Your visit QR is no longer valid. Book a new slot when you '
                    'return to the tower.',
                actionLabel: 'Book a slot',
                onAction: () => _bookSlot(context, ref),
              )
            else
              _QrPassCard(
                qr: qrState.qr!,
                refreshing: qrState.status == QrLoadStatus.refreshing,
              ),
            if (qrState.errorMessage != null && qrState.qr != null) ...[
              const SizedBox(height: 12),
              Text(
                qrState.errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            PremiumButton(
              label: 'FULL SCREEN',
              icon: Icons.fullscreen_rounded,
              onPressed: qrState.qr == null
                  ? null
                  : () => context.push(AppRoutes.qrFullscreen),
            ),
            if (qrState.qr != null && qrState.qr!.isPermanent) ...[
              const SizedBox(height: 12),
              PremiumCard(
                elevated: false,
                padding: const EdgeInsets.all(14),
                color: AppColors.peachSoft.withValues(alpha: 0.45),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, color: AppColors.tealDeep),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Subscription plans use a permanent QR pass.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QrPassCard extends StatelessWidget {
  const _QrPassCard({
    required this.qr,
    required this.refreshing,
  });

  final QrCodeModel qr;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planLabel = switch (qr.subscriptionType) {
      SubscriptionPlanType.annual => 'Annual Premium',
      SubscriptionPlanType.monthly => 'Monthly',
      SubscriptionPlanType.hourly => 'Pay as you go',
    };
    final expiryLabel = qr.isPermanent
        ? 'Valid for plan duration'
        : qr.isExpired
            ? 'Expired · refresh required'
            : 'Expires ${Formatters.dateTime(qr.expiresAt)} · 2-hour pass';

    return PremiumCard(
      gradient: AppColors.tealGradient,
      border: Border.all(color: Colors.transparent),
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            'TOWER ACCESS PASS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.peach,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                QrImageView(
                  data: qr.token,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: AppColors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: AppColors.tealDark,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: AppColors.tealDeep,
                  ),
                ),
                if (refreshing)
                  Container(
                    width: 210,
                    height: 210,
                    color: AppColors.white.withValues(alpha: 0.72),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.tealDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            qr.userName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            qr.vehicleNumber,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.peachSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          _MetaRow(label: 'Slot', value: qr.slotLabel),
          _MetaRow(label: 'Plan', value: planLabel),
          _MetaRow(label: 'Validity', value: expiryLabel),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textMutedDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
