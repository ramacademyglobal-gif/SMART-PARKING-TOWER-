import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/models/notification_model.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

class NotificationListController
    extends AsyncNotifier<List<AppNotificationModel>> {
  @override
  Future<List<AppNotificationModel>> build() {
    return ref.watch(notificationRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue<List<AppNotificationModel>>.loading()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).list(),
    );
  }

  Future<void> markRead(String notificationId) async {
    await ref.read(notificationRepositoryProvider).markRead(notificationId);
    final current = state.valueOrNull;
    if (current == null) {
      await refresh();
      return;
    }
    state = AsyncValue.data([
      for (final item in current)
        if (item.id == notificationId) item.copyWith(isRead: true) else item,
    ]);
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull ??
        await ref.read(notificationRepositoryProvider).list();
    final unread = current.where((n) => !n.isRead).toList();
    for (final item in unread) {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
    }
    state = AsyncValue.data([
      for (final item in current) item.copyWith(isRead: true),
    ]);
  }
}

final notificationListProvider = AsyncNotifierProvider<
    NotificationListController, List<AppNotificationModel>>(
  NotificationListController.new,
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationListProvider).valueOrNull;
  if (list == null) return 0;
  return list.where((n) => !n.isRead).length;
});
