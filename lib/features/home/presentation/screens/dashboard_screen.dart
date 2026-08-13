import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/loading_shimmer.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/tower_loading.dart';
import 'package:multiparking_tower/features/notifications/presentation/providers/notification_provider.dart';
import 'package:multiparking_tower/features/parking/presentation/providers/parking_provider.dart';
import 'package:multiparking_tower/features/parking/presentation/widgets/parking_exit_receipt.dart';
import 'package:multiparking_tower/features/qr/presentation/providers/qr_provider.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isBooking = false;

  Future<void> _openOrBookQr(QrCodeModel? qr) async {
    if (_isBooking) return;
    if (qr != null) {
      if (mounted) context.go(AppRoutes.qr);
      return;
    }
    setState(() => _isBooking = true);
    try {
      await ref.read(qrControllerProvider.notifier).refreshQr();
      if (mounted) context.go(AppRoutes.qr);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(homeParkingPulseProvider);
    final user = ref.watch(authProvider).user;
    final firstName = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName.trim().split(' ').first
        : 'there';
    final slotAsync = ref.watch(currentSlotProvider);
    final parkedAsync = ref.watch(activeParkedSessionProvider);
    final pendingAsync = ref.watch(pendingParkingPaymentProvider);
    final qrState = ref.watch(qrControllerProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: TowerLoadingOverlay(
        visible: _isBooking,
        message: 'Booking your slot',
        detail: 'Reserving a bay and generating your QR pass…',
        child: CustomScrollView(
        slivers: [
          // Compact header — previous template, less empty vertical space.
          SliverAppBar(
            pinned: true,
            expandedHeight: 118,
            toolbarHeight: 56,
            backgroundColor: AppColors.tealDeep,
            foregroundColor: AppColors.white,
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_parking_rounded,
                      color: AppColors.tealDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MultiParking',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => context.push(AppRoutes.notifications),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  smallSize: 7,
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(22, 72, 22, 14),
                decoration: const BoxDecoration(
                  gradient: AppColors.tealGradient,
                ),
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Good day, $firstName',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pendingAsync.when(
                    loading: () => slotAsync.when(
                      loading: () => const ShimmerCard(height: 260),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (slot) => _AllottedSlotCard(
                        slot: slot,
                        isParked: parkedAsync.valueOrNull != null,
                        qr: qrState.qr,
                        qrLoading: qrState.isLoading && qrState.qr == null,
                        onOpenQr: () => _openOrBookQr(qrState.qr),
                      ),
                    ),
                    error: (_, __) => slotAsync.when(
                      loading: () => const ShimmerCard(height: 260),
                      error: (_, __) => PremiumCard(
                        color: AppColors.tealDeep,
                        child: Text(
                          'Could not load your parking slot.',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      data: (slot) => _AllottedSlotCard(
                        slot: slot,
                        isParked: parkedAsync.valueOrNull != null,
                        qr: qrState.qr,
                        qrLoading: qrState.isLoading && qrState.qr == null,
                        onOpenQr: () => _openOrBookQr(qrState.qr),
                      ),
                    ),
                    data: (pending) {
                      if (pending != null) {
                        return _ExitPaymentCard(
                          session: pending,
                          onPay: () async {
                            await showParkingExitReceipt(
                              context,
                              session: pending,
                            );
                            ref.invalidate(pendingParkingPaymentProvider);
                            ref.invalidate(currentSlotProvider);
                            ref.invalidate(activeParkedSessionProvider);
                            await ref
                                .read(qrControllerProvider.notifier)
                                .load();
                          },
                        );
                      }
                      return slotAsync.when(
                        loading: () => const ShimmerCard(height: 260),
                        error: (_, __) => PremiumCard(
                          color: AppColors.tealDeep,
                          child: Text(
                            'Could not load your parking slot.',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        data: (slot) => _AllottedSlotCard(
                          slot: slot,
                          isParked: parkedAsync.valueOrNull != null,
                          qr: qrState.qr,
                          qrLoading: qrState.isLoading && qrState.qr == null,
                          onOpenQr: () => _openOrBookQr(qrState.qr),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ExitPaymentCard extends StatelessWidget {
  const _ExitPaymentCard({
    required this.session,
    required this.onPay,
  });

  final ParkingHistoryModel session;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final amount = session.amountInRupees ?? 0;
    final duration = session.duration == null
        ? '—'
        : Formatters.duration(session.duration!);

    return PremiumCard(
      gradient: AppColors.peachGradient,
      border: Border.all(color: AppColors.peachSoft),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT DUE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.tealDeep,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your vehicle has exited',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.vehicleNumber} · $duration',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.tealDeep,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            Formatters.currency(amount, decimals: false),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            session.slotLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.tealDeep,
                ),
          ),
          const SizedBox(height: 20),
          PremiumButton(
            label: 'PAY NOW',
            icon: Icons.payment_rounded,
            onPressed: onPay,
          ),
        ],
      ),
    );
  }
}

class _AllottedSlotCard extends StatelessWidget {
  const _AllottedSlotCard({
    required this.slot,
    required this.isParked,
    required this.qr,
    required this.qrLoading,
    required this.onOpenQr,
  });

  final ParkingSlotModel? slot;
  final bool isParked;
  final QrCodeModel? qr;
  final bool qrLoading;
  final VoidCallback onOpenQr;

  @override
  Widget build(BuildContext context) {
    final statusLabel = slot == null
        ? 'UNASSIGNED'
        : (isParked ? 'PARKED' : 'ALLOTTED');
    final statusColor = slot == null
        ? AppColors.warning
        : (isParked ? AppColors.slotOccupied : AppColors.success);

    return PremiumCard(
      color: AppColors.tealDeep,
      border: Border.all(color: AppColors.slate),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _Eyebrow(
                  'YOUR PARKING SLOT',
                  color: AppColors.peach,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (slot == null)
            Text(
              'Open QR to get a slot — no plan needed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.peachSoft,
                    fontWeight: FontWeight.w700,
                  ),
            )
          else ...[
            Row(
              children: [
                const Icon(
                  Icons.garage_rounded,
                  color: AppColors.peach,
                  size: 42,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${slot!.tower} · ${slot!.floor} · ${slot!.zone}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  slot!.slotNumber,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.peachSoft,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow(label: 'Tower', value: 'Tower ${slot!.tower}'),
            _DetailRow(label: 'Floor', value: 'Floor ${slot!.floor}'),
            _DetailRow(label: 'Zone', value: 'Zone ${slot!.zone}'),
            _DetailRow(label: 'Slot', value: slot!.slotNumber),
            if (qr != null)
              _DetailRow(label: 'Vehicle', value: qr!.vehicleNumber),
          ],
          const SizedBox(height: 18),
          if (qrLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.peach),
              ),
            )
          else
            _QrValidityTimer(qr: qr),
          const SizedBox(height: 16),
          PremiumButton(
            label: qr == null ? 'BOOK A SLOT' : 'VIEW QR PASS',
            icon: Icons.qr_code_2_rounded,
            onPressed: onOpenQr,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.color = AppColors.tealDeep});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
    );
  }
}

class _QrValidityTimer extends StatefulWidget {
  const _QrValidityTimer({required this.qr});

  final QrCodeModel? qr;

  @override
  State<_QrValidityTimer> createState() => _QrValidityTimerState();
}

class _QrValidityTimerState extends State<_QrValidityTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _QrValidityTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qr?.expiresAt != widget.qr?.expiresAt ||
        oldWidget.qr?.token != widget.qr?.token) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final qr = widget.qr;
    if (qr == null || qr.isPermanent) {
      if (_remaining != Duration.zero) {
        setState(() => _remaining = Duration.zero);
      }
      return;
    }
    final next = qr.expiresAt.difference(DateTime.now());
    setState(() => _remaining = next.isNegative ? Duration.zero : next);
  }

  String _format(Duration value) {
    final total = value.inSeconds.clamp(0, 2 * 3600);
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final qr = widget.qr;
    if (qr == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Text(
          'No active QR. Book a slot to get a 2-hour pass.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.peachSoft,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    if (qr.isPermanent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Text(
          'Subscription pass — permanent QR for your plan.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.peachSoft,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    final expired = _remaining == Duration.zero;
    final shown = _remaining > const Duration(hours: 2)
        ? const Duration(hours: 2)
        : _remaining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: expired
            ? AppColors.error.withValues(alpha: 0.18)
            : AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expired ? 'QR EXPIRED' : 'QR VALID FOR (2 HOURS)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: expired ? AppColors.error : AppColors.peach,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            expired ? '00:00:00' : _format(shown),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            expired
                ? 'Open the QR tab to generate a new 2-hour pass.'
                : 'Pass is valid for 2 hours from issue.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMutedDark,
                ),
          ),
        ],
      ),
    );
  }
}
