/// Centralised REST endpoint paths.
///
/// All paths are relative to the API base URL configured in `AppConfig`
/// (e.g. `https://api.multiparking.local/v1`). Dynamic path builders are
/// exposed as functions where an identifier is required.
class ApiEndpoints {
  const ApiEndpoints._();

  // --- Auth ---
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String firebaseLogin = '/auth/firebase';
  static const String staffLogin = '/auth/staff/login';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // --- Bootstrap ---
  static const String publicConfig = '/config';

  // --- Users ---
  static const String me = '/users/me';
  static const String updateProfile = '/users/me';

  // --- Vehicles ---
  static const String vehicles = '/vehicles';
  static String vehicleById(String id) => '/vehicles/$id';

  // --- Subscriptions & plans ---
  static const String subscriptions = '/subscriptions';
  static String subscriptionById(String id) => '/subscriptions/$id';
  static const String plans = '/plans';
  static String planById(String id) => '/plans/$id';

  // --- Payments ---
  static const String createOrder = '/payments/create-order';
  static const String verifyPayment = '/payments/verify';
  static const String paymentHistory = '/payments';
  static const String createParkingOrder = '/payments/parking/create-order';
  static const String verifyParkingPayment = '/payments/parking/verify';

  // --- Parking ---
  static const String parkingSlot = '/parking/slot';
  static String parkingSlotById(String id) => '/parking/slot/$id';
  static const String allocateSlot = '/parking/allocate';
  static const String parkingHistory = '/parking/history';
  static const String parkingCapacity = '/parking/capacity';
  static const String releaseSlot = '/parking/release';
  static const String simulateEntry = '/parking/simulate-entry';
  static const String simulateExit = '/parking/simulate-exit';
  static const String parkingScan = '/parking/scan';

  // --- Staff console ---
  static const String staffOverview = '/staff/overview';
  static const String staffScan = '/staff/scan';
  static const String staffSessions = '/staff/sessions';
  static const String staffSessionLookup = '/staff/sessions/lookup';
  static const String staffWalkIn = '/staff/walk-in';
  static String staffCheckout(String historyId) =>
      '/staff/sessions/$historyId/checkout';
  static String staffCollect(String historyId) =>
      '/staff/sessions/$historyId/collect';

  // --- QR ---
  static const String currentQr = '/qr/current';
  static const String refreshQr = '/qr/refresh';

  // --- Notifications ---
  static const String notifications = '/notifications';
  static String notificationById(String id) => '/notifications/$id';
  static const String markNotificationRead = '/notifications/read';

  // --- FCM ---
  static const String registerFcm = '/fcm/register';
  static const String unregisterFcm = '/fcm/unregister';
}
