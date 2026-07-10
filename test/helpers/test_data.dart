/// Centralised fixtures used across all unit tests.
/// No scattered hardcoded JSON in individual test files.
library test_data;

// ── Auth / Session ────────────────────────────────────────────────────────────

const kTestUserId = 99;
const kTestAccessToken = 'test-access-token';
const kTestRefreshToken = 'test-refresh-token';
const kTestMobile = '9300000000';
const kTestOtp = '123456';
const kTestNurseryId = 5;

/// Minimal /auth/send-otp success response.
const kSendOtpResponse = {'message': 'OTP sent successfully'};

/// Minimal /auth/verify-otp success response for an existing user.
Map<String, dynamic> verifyOtpResponse({bool isNewUser = false}) => {
      'access_token': kTestAccessToken,
      'refresh_token': kTestRefreshToken,
      'is_new_user': isNewUser,
      'user': {
        'id': kTestUserId,
        'user_code': 'USR-99',
        'first_name': 'Ravi',
        'last_name': 'Buyer',
        'mobile': kTestMobile,
        'status': 'ACTIVE',
        'roles': [],
      },
    };

/// /users/me response.
const kUserMeResponse = {
  'user': {
    'id': kTestUserId,
    'user_code': 'USR-99',
    'first_name': 'Ravi',
    'last_name': 'Buyer',
    'mobile': kTestMobile,
    'mobile_verified': true,
    'email': 'ravi@example.com',
    'email_verified': false,
    'gender': 'MALE',
    'status': 'ACTIVE',
    'created_at': '2025-01-01T00:00:00Z',
  },
};

/// Single BUYER workspace.
const kBuyerWorkspacesResponse = [
  {'type': 'PERSONAL', 'nursery_id': null, 'nursery_name': null},
];

/// Single OWNED_NURSERY workspace.
const kOwnerWorkspacesResponse = [
  {'type': 'OWNED_NURSERY', 'nursery_id': kTestNurseryId, 'nursery_name': 'Test Nursery', 'nursery_status': 'APPROVED'},
];

const kUserRolesResponse = {'roles': []};

// ── Orders ────────────────────────────────────────────────────────────────────

const kTestOrderId = 101;

Map<String, dynamic> orderJson({
  int id = kTestOrderId,
  String status = 'PENDING',
}) =>
    {
      'id': id,
      'order_code': 'ORD-00$id',
      'order_number': 'ON-$id',
      'buyer_name': 'Ravi Buyer',
      'seller_nursery': 'Test Nursery',
      'seller_nursery_id': kTestNurseryId,
      'order_status': status,
      'total_amount': 1500.0,
      'order_date': '2025-01-15T00:00:00Z',
      'created_at': '2025-01-15T00:00:00Z',
      'items': [
        {
          'id': 1,
          'plant_id': 10,
          'scientific_name': 'Ficus benjamina',
          'common_name': 'Weeping Fig',
          'quantity': 5.0,
          'unit_price': 300.0,
          'total_price': 1500.0,
        }
      ],
    };

Map<String, dynamic> ordersListResponse({
  List<Map<String, dynamic>>? orders,
  int total = 1,
}) =>
    {
      'orders': orders ?? [orderJson()],
      'pagination': {
        'page': 1,
        'per_page': 20,
        'total': total,
        'total_pages': 1,
      },
    };

Map<String, dynamic> orderDetailResponse({int id = kTestOrderId, String status = 'PENDING'}) => {
      'order': orderJson(id: id, status: status),
    };

// ── Market ────────────────────────────────────────────────────────────────────

const kTestAdId = 201;
const kTestAdCode = 'AD-00201';

Map<String, dynamic> marketAdJson({
  int id = kTestAdId,
  String status = 'PUBLISHED',
  bool isSavedByMe = false,
}) =>
    {
      'id': id,
      'code': kTestAdCode,
      'nursery_id': kTestNurseryId,
      'nursery_name': 'Test Nursery',
      'nursery_verified': true,
      'plant_name': 'Ficus benjamina',
      'title': 'Beautiful Weeping Figs for sale',
      'status': status,
      'view_count': 10,
      'save_count': 3,
      'enquiry_count': 1,
      'is_saved_by_me': isSavedByMe,
      'photos': [],
      'created_at': '2025-01-01T00:00:00Z',
    };

Map<String, dynamic> adsListResponse({
  List<Map<String, dynamic>>? ads,
  int total = 1,
}) =>
    {
      'ads': ads ?? [marketAdJson()],
      'total': total,
    };

Map<String, dynamic> savedAdsResponse({List<Map<String, dynamic>>? ads}) => {
      'ads': ads ?? [marketAdJson(isSavedByMe: true)],
    };

Map<String, dynamic> myAdsResponse({List<Map<String, dynamic>>? ads}) => {
      'ads': ads ?? [marketAdJson()],
    };

Map<String, dynamic> createAdResponse({int id = kTestAdId}) => {
      'ad': marketAdJson(id: id),
    };

Map<String, dynamic> toggleSaveResponse({bool saved = true}) => {
      'saved': saved,
    };

Map<String, dynamic> presignResponse() => {
      'upload_url': 'https://s3.example.com/upload/photo.jpg?signature=abc',
      'file_url': 'https://cdn.example.com/market-ads/photo.jpg',
    };

// ── Invites ───────────────────────────────────────────────────────────────────

const kTestInviteId = 301;

Map<String, dynamic> inviteResponse() => {
      'invite': {
        'id': kTestInviteId,
        'invite_code': 'INV-00301',
        'invite_type': 'MANAGER',
        'nursery_id': kTestNurseryId,
        'status': 'PENDING',
        'created_at': '2025-01-01T00:00:00Z',
      },
    };

// ── Subscriptions ─────────────────────────────────────────────────────────────

const kTestSubscriptionId = 401;

Map<String, dynamic> subscriptionJson({String status = 'ACTIVE'}) => {
      'id': kTestSubscriptionId,
      'subscription_code': 'SUB-00401',
      'plan_id': 1,
      'plan_code': 'PRO',
      'plan_name': 'Pro Plan',
      'start_date': '2025-01-01',
      'end_date': '2025-12-31',
      'subscription_status': status,
      'auto_renew': true,
      'days_remaining': 180,
    };

Map<String, dynamic> subscriptionsListResponse({String status = 'ACTIVE'}) => {
      'subscriptions': [subscriptionJson(status: status)],
    };

Map<String, dynamic> renewSubscriptionResponse() => {
      'subscription': subscriptionJson(status: 'ACTIVE'),
    };

Map<String, dynamic> cancelSubscriptionResponse() => {
      'subscription': subscriptionJson(status: 'CANCELLED'),
    };

Map<String, dynamic> subscriptionPlansResponse() => {
      'plans': [
        {
          'id': 1,
          'plan_code': 'PRO',
          'plan_name': 'Pro Plan',
          'six_month_price': 999.0,
          'yearly_price': 1799.0,
          'is_active': true,
        },
      ],
    };
