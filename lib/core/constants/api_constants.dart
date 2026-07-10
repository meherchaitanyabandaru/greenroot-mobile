abstract class ApiConstants {
  static const String v1 = '/api/v1';

  // Auth
  static const String sendOtp = '$v1/auth/send-otp';
  static const String verifyOtp = '$v1/auth/verify-otp';
  static const String refreshToken = '$v1/auth/refresh-token';
  static const String logout = '$v1/auth/logout';
  static const String myWorkspaces = '$v1/me/workspaces';

  // Users
  static const String usersMe = '$v1/users/me';
  static String userById(int id) => '$v1/users/$id';
  static String userRoles(int id) => '$v1/users/$id/roles';
  static String userAddresses(int id) => '$v1/users/$id/addresses';
  static String userAddressById(int addressId) =>
      '$v1/users/addresses/$addressId';

  // Plants
  static const String plants = '$v1/plants';
  static const String plantCategories = '$v1/plants/categories';
  static const String plantSizes = '$v1/plants/sizes';
  static String plantById(int id) => '$v1/plants/$id';
  static String plantCareGuide(int id) => '$v1/plants/$id/care-guide';

  // Nurseries
  static const String nurseries = '$v1/nurseries';
  static const String myNurseries = '$v1/nurseries/mine';
  static String nurseryById(int id) => '$v1/nurseries/$id';
  static String nurseryAddresses(int id) => '$v1/nurseries/$id/addresses';

  // Inventory
  static const String inventory = '$v1/inventory';
  static String inventoryById(int id) => '$v1/inventory/$id';

  // Plant Requests
  static const String plantRequests = '$v1/plant-requests';
  static String plantRequestById(int id) => '$v1/plant-requests/$id';
  static String plantRequestRespond(int id) =>
      '$v1/plant-requests/$id/responses';

  // Orders
  static const String orders = '$v1/orders';
  static String orderById(int id) => '$v1/orders/$id';
  static String orderItems(int id) => '$v1/orders/$id/items';
  static String orderStatus(int id) => '$v1/orders/$id/status';
  static String orderStartLoading(int id) => '$v1/orders/$id/start-loading';
  static String orderCompleteLoading(int id) =>
      '$v1/orders/$id/complete-loading';
  static String orderCancel(int id) => '$v1/orders/$id/cancel';
  static String orderItemLoadedQuantity(int orderId, int itemId) =>
      '$v1/orders/$orderId/items/$itemId/loaded-quantity';
  static String orderAssignManager(int id) => '$v1/orders/$id/assign-manager';
  static String orderConfirm(int id) => '$v1/orders/$id/confirm';

  // Payments
  static const String payments = '$v1/payments';
  static String paymentById(int id) => '$v1/payments/$id';

  // Subscriptions
  static const String subscriptions = '$v1/subscriptions';
  static const String subscriptionPlans = '$v1/subscription-plans';
  static String subscriptionById(int id) => '$v1/subscriptions/$id';
  static String subscriptionRenew(int id) => '$v1/subscriptions/$id/renew';
  static String subscriptionCancel(int id) => '$v1/subscriptions/$id/cancel';

  // Dispatches
  static const String dispatches = '$v1/dispatches';
  static String dispatchesByOrder(int orderId) =>
      '$v1/orders/$orderId/dispatches';
  static String dispatchById(int id) => '$v1/dispatches/$id';
  static String dispatchStatus(int id) => '$v1/dispatches/$id/status';
  static String dispatchByCode(String code) => '$v1/dispatches/code/$code';
  static String acceptDispatch(int id) => '$v1/dispatches/$id/accept';
  static String dispatchTracking(int id) => '$v1/dispatches/$id/tracking';
  static String dispatchTrackingLatest(int id) =>
      '$v1/dispatches/$id/tracking/latest';

  // Vehicles
  static const String vehicles = '$v1/vehicles';
  static String vehicleById(int id) => '$v1/vehicles/$id';
  static String vehicleTracking(int id) => '$v1/vehicles/$id/tracking';
  static String vehicleTrackingLatest(int id) =>
      '$v1/vehicles/$id/tracking/latest';

  // Drivers
  static const String drivers = '$v1/drivers';
  static const String driversMe = '$v1/drivers/me';
  static String driverById(int id) => '$v1/drivers/$id';
  static String driverLocation(int id) => '$v1/drivers/$id/location';
  static String driverTracking(int id) => '$v1/drivers/$id/tracking';
  static String driverTrackingLatest(int id) =>
      '$v1/drivers/$id/tracking/latest';

  // Tracking (post location)
  static const String postTracking = '$v1/tracking';

  // Dispatch trip events
  static String tripEvents(int dispatchId) =>
      '$v1/dispatches/$dispatchId/trip-events';

  // Attachments
  static const String attachments = '$v1/attachments';
  static String attachmentById(int id) => '$v1/attachments/$id';

  // Me / Dashboard
  static const String ownerDashboard = '$v1/me/owner-dashboard';

  // Quotations
  static const String quotations = '$v1/quotations';
  static String quotationById(int id) => '$v1/quotations/$id';
  static String quotationCustomer(int id) => '$v1/quotations/$id/customer';
  static String quotationSend(int id) => '$v1/quotations/$id/send';
  static String quotationApprove(int id) => '$v1/quotations/$id/approve';
  static String quotationRecall(int id) => '$v1/quotations/$id/recall';
  static String quotationConvert(int id) =>
      '$v1/quotations/$id/convert-to-order';
  static String quotationAssignManager(int id) =>
      '$v1/quotations/$id/assign-manager';
  static String quotationRecordDownload(int id) =>
      '$v1/quotations/$id/record-download';

  // Notifications
  static const String notifications = '$v1/notifications';
  static String notificationById(int id) => '$v1/notifications/$id';
  static String markNotificationRead(int id) => '$v1/notifications/$id/read';
  static const String markAllNotificationsRead = '$v1/notifications/read-all';
  static const String notificationDevices = '$v1/notifications/devices';
  static String deleteNotification(int id) => '$v1/notifications/$id';

  // Invites
  static const String invites = '$v1/invites';
  static String inviteByUUID(String uuid) => '$v1/invites/$uuid';
  static String acceptInvite(String uuid) => '$v1/invites/$uuid/accept';
  static String cancelInvite(String uuid) => '$v1/invites/$uuid/cancel';
  static String nurseryInvites(int nurseryId) =>
      '$v1/nurseries/$nurseryId/invites';
  static String nurseryManagers(int nurseryId) =>
      '$v1/nurseries/$nurseryId/managers';
  static String removeNurseryManager(int nurseryId, int userId) =>
      '$v1/nurseries/$nurseryId/managers/$userId';
  static String nurseryCustomers(int nurseryId) =>
      '$v1/nurseries/$nurseryId/customers';

  // Storage
  static const String storagePresign = '$v1/storage/presign';

  // Local Market
  static const String marketAds = '$v1/market/ads';
  static const String marketMyAds = '$v1/market/ads/mine';
  static const String marketSavedAds = '$v1/market/ads/saved';
  static const String marketEnquiries = '$v1/market/enquiries';
  static String marketAdById(int id) => '$v1/market/ads/$id';
  static String marketAdAction(int id, String action) =>
      '$v1/market/ads/$id/$action';
  static String marketEnquiryById(int id) => '$v1/market/enquiries/$id';
  static String marketEnquiryAction(int id, String action) =>
      '$v1/market/enquiries/$id/$action';

  // Plant Sourcing Network
  static String sourcingMembership(int nurseryId) =>
      '$v1/nurseries/$nurseryId/sourcing-membership';
  static String featuredPlants(int nurseryId) =>
      '$v1/nurseries/$nurseryId/featured-plants';
  static String featuredPlantById(int nurseryId, int featuredId) =>
      '$v1/nurseries/$nurseryId/featured-plants/$featuredId';
  static const String sourcingNetworkNurseries =
      '$v1/sourcing-network/nurseries';
  static String sourcingNetworkNursery(int nurseryId) =>
      '$v1/sourcing-network/nurseries/$nurseryId';
  static const String sourcingPosts = '$v1/sourcing-posts';
  static String sourcingPostById(int id) => '$v1/sourcing-posts/$id';
  static String sourcingPostResponses(int id) =>
      '$v1/sourcing-posts/$id/responses';
  static String sourcingPostResponse(int id, int responseId) =>
      '$v1/sourcing-posts/$id/responses/$responseId';
}
