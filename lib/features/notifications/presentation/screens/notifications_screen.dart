import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/loading_shimmer.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/features/notifications/presentation/providers/notification_provider.dart';
import 'package:multiparking_tower/models/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationListProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const ShimmerList(itemCount: 6),
        error: (_, __) => EmptyState.error(
          title: 'Could not load notifications',
          subtitle: 'Check your connection and try again.',
          onAction: () =>
              ref.read(notificationListProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'All caught up',
              subtitle: 'Parking and subscription alerts will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _NotificationTile(
                notification: items[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotificationModel notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final icon = _iconForType(notification.type);
    final accent = _colorForType(notification.type);

    return PremiumCard(
      elevated: !notification.isRead,
      color: notification.isRead
          ? null
          : AppColors.peachSoft.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(14),
      onTap: notification.isRead
          ? null
          : () => ref
              .read(notificationListProvider.notifier)
              .markRead(notification.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.peachDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.timeAgo(notification.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type.toLowerCase()) {
      'parking' || 'entry' || 'exit' => Icons.local_parking_rounded,
      'subscription' || 'payment' || 'billing' => Icons.workspace_premium_rounded,
      'slot' || 'allocation' => Icons.garage_rounded,
      'security' || 'qr' => Icons.qr_code_2_rounded,
      'promo' || 'offer' => Icons.local_offer_outlined,
      _ => Icons.notifications_rounded,
    };
  }

  Color _colorForType(String type) {
    return switch (type.toLowerCase()) {
      'parking' || 'entry' || 'exit' => AppColors.success,
      'subscription' || 'payment' || 'billing' => AppColors.peachDeep,
      'slot' || 'allocation' => AppColors.info,
      'security' || 'qr' => AppColors.tealDeep,
      'promo' || 'offer' => AppColors.warning,
      _ => AppColors.slate,
    };
  }
}
