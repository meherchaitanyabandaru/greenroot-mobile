abstract class ApiConstants {
  static const String v1 = '/api/v1';

  // Auth
  static const String sendOtp      = '$v1/auth/send-otp';
  static const String verifyOtp    = '$v1/auth/verify-otp';
  static const String refreshToken = '$v1/auth/refresh-token';
  static const String logout       = '$v1/auth/logout';
  static const String me           = '$v1/auth/me';

  // Users
  static const String usersMe       = '$v1/users/me';
  static String userById(int id)    => '$v1/users/$id';
  static String userRoles(int id)   => '$v1/users/$id/roles';
  static String userAddresses(int id) => '$v1/users/$id/addresses';

  // Plants
  static const String plants           = '$v1/plants';
  static const String plantCategories  = '$v1/plants/categories';
  static const String plantSizes       = '$v1/plants/sizes';
  static String plantById(int id)      => '$v1/plants/$id';
  static String plantCareGuide(int id) => '$v1/plants/$id/care-guide';

  // Nurseries
  static const String nurseries             = '$v1/nurseries';
  static const String myNurseries           = '$v1/nurseries/mine';
  static String nurseryById(int id)         => '$v1/nurseries/$id';
  static String nurseryAddresses(int id)    => '$v1/nurseries/$id/addresses';
  static String nurseryUsers(int id)        => '$v1/nurseries/$id/users';

  // Inventory
  static const String inventory          = '$v1/inventory';
  static String inventoryById(int id)    => '$v1/inventory/$id';

  // Plant Requests
  static const String plantRequests         = '$v1/plant-requests';
  static String plantRequestById(int id)    => '$v1/plant-requests/$id';
  static String plantRequestRespond(int id) => '$v1/plant-requests/$id/responses';

  // Orders
  static const String orders          = '$v1/orders';
  static String orderById(int id)     => '$v1/orders/$id';
  static String orderItems(int id)    => '$v1/orders/$id/items';

  // Payments
  static const String payments        = '$v1/payments';
  static String paymentById(int id)   => '$v1/payments/$id';

  // Subscriptions
  static const String subscriptions               = '$v1/subscriptions';
  static const String subscriptionPlans           = '$v1/subscription-plans';
  static String subscriptionById(int id)          => '$v1/subscriptions/$id';
  static String subscriptionRenew(int id)         => '$v1/subscriptions/$id/renew';
  static String subscriptionCancel(int id)        => '$v1/subscriptions/$id/cancel';

  // Dispatches
  static const String dispatches        = '$v1/dispatches';
  static String dispatchById(int id)    => '$v1/dispatches/$id';

  // Drivers
  static const String drivers           = '$v1/drivers';
  static String driverById(int id)      => '$v1/drivers/$id';
  static String driverLocation(int id)  => '$v1/drivers/$id/location';

  // Tracking
  static String trackingVehicle(int id)  => '$v1/tracking/vehicle/$id';
  static String trackingDriver(int id)   => '$v1/tracking/driver/$id';
  static String trackingDispatch(int id) => '$v1/tracking/dispatch/$id';

  // Notifications
  static const String notifications            = '$v1/notifications';
  static String notificationById(int id)       => '$v1/notifications/$id';
  static String markNotificationRead(int id)   => '$v1/notifications/$id/read';
  static const String markAllNotificationsRead = '$v1/notifications/read-all';
  static const String notificationDevices      = '$v1/notifications/devices';
}
