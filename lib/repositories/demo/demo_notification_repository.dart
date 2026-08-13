import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/models/notification_model.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/notification_repository.dart';

class DemoNotificationRepository implements NotificationRepository {
  DemoNotificationRepository({DemoDataStore? store})
      : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;

  @override
  Future<List<AppNotificationModel>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final sorted = List<AppNotificationModel>.from(_store.notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotificationModel>.unmodifiable(sorted);
  }

  @override
  Future<void> markRead(String notificationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final index =
        _store.notifications.indexWhere((n) => n.id == notificationId);
    if (index < 0) {
      throw const ServerException(message: 'Notification not found');
    }
    _store.notifications[index] =
        _store.notifications[index].copyWith(isRead: true);
  }

  @override
  Future<void> registerFcmToken(String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _store.fcmToken = token;
  }
}
