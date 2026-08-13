import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/app_text_field.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/loading_shimmer.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/shell_back_button.dart';
import 'package:multiparking_tower/features/history/presentation/providers/history_provider.dart';
import 'package:multiparking_tower/features/parking/presentation/widgets/parking_exit_receipt.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

class ParkingHistoryScreen extends ConsumerStatefulWidget {
  const ParkingHistoryScreen({super.key});

  @override
  ConsumerState<ParkingHistoryScreen> createState() =>
      _ParkingHistoryScreenState();
}

class _ParkingHistoryScreenState extends ConsumerState<ParkingHistoryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(historyQueryProvider).search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(historyQueryProvider);
    final historyAsync = ref.watch(parkingHistoryListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Parking history'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: AppTextField(
              controller: _searchController,
              hint: 'Search vehicle, tower or slot',
              prefixIcon: Icons.search_rounded,
              suffixIcon: query.search.isEmpty ? null : Icons.clear_rounded,
              onSuffixTap: () {
                _searchController.clear();
                ref.read(historyQueryProvider.notifier).setSearch('');
              },
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  ref.read(historyQueryProvider.notifier).setSearch(value),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: HistoryFilterKind.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = HistoryFilterKind.values[index];
                final selected = query.filter == filter;
                return FilterChip(
                  selected: selected,
                  label: Text(filter.label),
                  onSelected: (_) =>
                      ref.read(historyQueryProvider.notifier).setFilter(filter),
                  selectedColor: AppColors.peachSoft,
                  checkmarkColor: AppColors.tealDeep,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.tealDeep
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.peachDeep
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: historyAsync.when(
              loading: () => const ShimmerList(itemCount: 5),
              error: (_, __) => EmptyState.error(
                title: 'Could not load history',
                subtitle: 'Pull to refresh or try again shortly.',
                onAction: () => ref.invalidate(parkingHistoryListProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No parking sessions',
                    subtitle: query.search.isNotEmpty ||
                            query.filter != HistoryFilterKind.all
                        ? 'Try a different search or filter.'
                        : 'Your tower entries and exits will appear here.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(parkingHistoryListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) =>
                        _HistoryCard(item: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final ParkingHistoryModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isParked = item.status == ParkingHistoryStatus.parked;
    final duration = item.duration ??
        (item.exitAt != null
            ? item.exitAt!.difference(item.entryAt)
            : DateTime.now().difference(item.entryAt));
    final planLabel = switch (item.subscriptionType) {
      SubscriptionPlanType.annual => 'Annual',
      SubscriptionPlanType.monthly => 'Monthly',
      SubscriptionPlanType.hourly => 'Hourly',
    };

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isParked
                      ? AppColors.success.withValues(alpha: 0.14)
                      : AppColors.peachSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  isParked
                      ? Icons.local_parking_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isParked ? AppColors.success : AppColors.tealDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.vehicleNumber,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.slotLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.tealDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  planLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.tealDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Fact(
            icon: Icons.login_rounded,
            label: 'Entry',
            value: Formatters.dateTime(item.entryAt),
          ),
          const SizedBox(height: 6),
          _Fact(
            icon: Icons.logout_rounded,
            label: 'Exit',
            value: item.exitAt == null
                ? (isParked ? 'Still parked' : '—')
                : Formatters.dateTime(item.exitAt!),
          ),
          const SizedBox(height: 6),
          _Fact(
            icon: Icons.schedule_rounded,
            label: 'Duration',
            value: Formatters.duration(duration),
          ),
          if (item.amountInPaise != null) ...[
            const SizedBox(height: 6),
            _Fact(
              icon: Icons.payments_outlined,
              label: 'Charge',
              value: item.amountInPaise == 0
                  ? 'Included in plan'
                  : Formatters.currency(item.amountInRupees ?? 0),
            ),
          ],
          if (item.needsPayment) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await showParkingExitReceipt(context, session: item);
                  ref.invalidate(parkingHistoryListProvider);
                },
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  'PAY ${Formatters.currency(item.amountInRupees ?? 0, decimals: false)}',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tealDeep,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else if (item.isPaid && (item.amountInPaise ?? 0) > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Paid',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.tealDeep),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
