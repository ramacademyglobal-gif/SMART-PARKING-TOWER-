import 'package:multiparking_tower/models/notification_model.dart';

abstract class NotificationRepository {
  Future<List<AppNotificationModel>> list();

  Future<void> markRead(String notificationId);

  Future<void> registerFcmToken(String token);
}
