import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/tower_loading.dart';
import 'package:multiparking_tower/models/staff_models.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/providers/settings_provider.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';
import 'package:multiparking_tower/routes/app_routes.dart';

final staffOverviewProvider =
    FutureProvider.autoDispose<StaffOverviewModel>((ref) {
  return ref.watch(staffRepositoryProvider).getOverview();
});

final staffParkedSessionsProvider =
    FutureProvider.autoDispose<List<StaffSessionModel>>((ref) {
  return ref.watch(staffRepositoryProvider).listSessions(status: 'parked');
});

class StaffHomeScreen extends ConsumerWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final overview = ref.watch(staffOverviewProvider);
    final sessions = ref.watch(staffParkedSessionsProvider);
    final theme = Theme.of(context);
    final isAdmin = auth.user?.role == 'admin';
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(isAdmin ? 'Admin Console' : 'Staff console'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: () {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(staffOverviewProvider);
              ref.invalidate(staffParkedSessionsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton.icon(
            label: const Text('Logout'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Logout staff account?'),
                  content: const Text(
                    'You will return to the staff login screen.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.staffLogin);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffOverviewProvider);
          ref.invalidate(staffParkedSessionsProvider);
          await ref.read(staffOverviewProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hi, ${auth.user?.displayName ?? 'Staff'}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tealDeep,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.tealDeep.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'ADMIN',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isAdmin
                  ? 'Monitor tower activity and management controls.'
                  : 'Scan app QR passes or book a bay for walk-in drivers.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            overview.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: TowerLoadingIndicator(
                  size: 72,
                  color: AppColors.tealDeep,
                  label: 'Loading tower status',
                  compact: true,
                ),
              ),
              error: (error, _) => PremiumCard(
                child: Text(
                  describeError(error),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              data: (data) => _OverviewGrid(data: data),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 22),
              Text(
                'Admin tools',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const _AdminToolsSection(),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: PremiumButton(
                    label: 'SCAN QR',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: () => context.push(AppRoutes.staffScanner),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumButton.secondary(
                    label: 'ADD VEHICLE',
                    icon: Icons.directions_car_filled_rounded,
                    onPressed: () => context.push(AppRoutes.staffWalkIn),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Text(
                  'Parked now',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(AppRoutes.staffSessions),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            sessions.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: TowerLoadingIndicator(
                  size: 64,
                  color: AppColors.tealDeep,
                  label: 'Loading parked cars',
                  compact: true,
                ),
              ),
              error: (error, _) => Text(describeError(error)),
              data: (rows) {
                if (rows.isEmpty) {
                  return PremiumCard(
                    child: Text(
                      'No vehicles parked right now.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final session in rows.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SessionTile(session: session),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminToolsSection extends StatelessWidget {
  const _AdminToolsSection();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: const [
        _AdminToolCard(
          title: 'Reports',
          subtitle: 'Occupancy, collections, and tower trends',
          icon: Icons.analytics_rounded,
        ),
        _AdminToolCard(
          title: 'Staff Management',
          subtitle: 'Review operator access and shift coverage',
          icon: Icons.groups_rounded,
        ),
        _AdminToolCard(
          title: 'Pricing Control',
          subtitle: 'Preview rate and plan configuration changes',
          icon: Icons.tune_rounded,
        ),
        _AdminToolCard(
          title: 'System Settings',
          subtitle: 'Tower alerts, policies, and system controls',
          icon: Icons.settings_suggest_rounded,
        ),
      ],
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.data});

  final StaffOverviewModel data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          label: 'Available',
          value: '${data.availableSlots}',
          hint: 'of ${data.totalSlots} bays',
          color: AppColors.success,
        ),
        _StatCard(
          label: 'Parked now',
          value: '${data.parkedNow}',
          hint: '${data.walkInsParked} walk-ins',
          color: AppColors.tealDeep,
        ),
        _StatCard(
          label: 'Entries today',
          value: '${data.entriesToday}',
          hint: '${data.exitsToday} exits',
          color: AppColors.peachDeep,
        ),
        _StatCard(
          label: 'Collected',
          value: Formatters.currency(data.collectedTodayRupees, decimals: false),
          hint: '${data.pendingPayments} pending',
          color: AppColors.tealDark,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminToolCard extends StatelessWidget {
  const _AdminToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.tealDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.tealDeep,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.tealDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Text(
            'Coming soon',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.tealDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final StaffSessionModel session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: session.isWalkIn
                  ? AppColors.peachSoft
                  : AppColors.tealDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              session.isWalkIn
                  ? Icons.storefront_rounded
                  : Icons.qr_code_2_rounded,
              color: session.isWalkIn ? AppColors.peachDeep : AppColors.tealDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.vehicleNumber,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.slotNumber} · ${Formatters.dateTime(session.entryAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((session.driverName ?? session.userName) != null)
                  Text(
                    session.driverName ?? session.userName!,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final closed = await ref
                    .read(staffRepositoryProvider)
                    .checkout(session.id);
                ref.invalidate(staffOverviewProvider);
                ref.invalidate(staffParkedSessionsProvider);
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Checkout complete'),
                    content: Text(
                      closed.needsPayment
                          ? '${closed.vehicleNumber}\n'
                              '${closed.durationLabel ?? ''}\n'
                              'Amount due: ${Formatters.currency(closed.amountRupees ?? 0, decimals: false)}'
                          : '${closed.vehicleNumber} checked out. No charge.',
                    ),
                    actions: [
                      if (closed.needsPayment)
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(staffRepositoryProvider)
                                .collectPayment(closed.id);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            ref.invalidate(staffOverviewProvider);
                          },
                          child: const Text('Mark paid'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(describeError(error)),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
  }
}
