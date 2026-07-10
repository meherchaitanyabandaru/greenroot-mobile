# GreenRoot Mobile — Test Guide

## How Tests Are Organised

```
test/
├── helpers/
│   ├── fake_api_client.dart        # FakeApiClient: interceptor-based fake with no real HTTP
│   ├── test_provider_container.dart # makeTestContainer() helper
│   ├── test_data.dart              # Centralised fixtures (orders, ads, subscriptions, …)
│   └── test_exceptions.dart        # Reusable AppError instances
├── common/
│   └── provider_override_test.dart # DI chain: apiClientProvider override works end-to-end
├── auth/
│   ├── session_notifier_test.dart  # SessionNotifier state machine + bootstrap + logout
│   └── auth_repository_test.dart   # OtpSendNotifier + OtpVerifyNotifier success & error paths
├── orders/
│   ├── orders_notifier_test.dart   # OrderListNotifier load/loadMore + repository methods
│   └── order_state_sync_test.dart  # Status transitions, tab isolation, failed-mutation safety
├── market/
│   ├── market_repository_test.dart # MarketRepository CRUD + presign + error mapping
│   ├── browse_ads_notifier_test.dart # BrowseAdsNotifier load/sort/filter/loadMore/refresh
│   └── market_state_sync_test.dart  # toggleSave state sync + postAd + adAction
├── invites/
│   └── invite_repository_test.dart # sendInvite success + 422/403/500 error mapping
├── subscriptions/
│   ├── subscription_notifier_test.dart # subscriptionProvider + plans + renew + cancel
│   └── subscription_state_sync_test.dart # invalidation after renew/cancel + model helpers
├── driver_test.dart                # (pre-existing) Driver role, dispatch model, notifications
└── widget_test.dart                # (pre-existing) AppConfig initialisation
```

## How to Run

```bash
# All tests
flutter test

# By module
flutter test test/auth/
flutter test test/orders/
flutter test test/market/
flutter test test/invites/
flutter test test/subscriptions/
flutter test test/common/

# Specific file
flutter test test/auth/auth_repository_test.dart

# With verbose output
flutter test --reporter expanded
```

## How ProviderContainer Overrides Work

All repository providers in the app read from `apiClientProvider`:

```dart
// Production code — example
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = AuthRemoteDataSource(ref.watch(apiClientProvider));
  return AuthRepository(dataSource);
});
```

In tests we override `apiClientProvider` with a `FakeApiClient`:

```dart
final fake = FakeApiClient();
fake.enqueue(response: {'message': 'OTP sent'});

final container = makeTestContainer(fake.apiClient);
// container now uses the fake for all HTTP calls
await container.read(otpSendProvider.notifier).sendOtp('9300000000');
```

`FakeApiClient` inserts a Dio interceptor that intercepts every request before it reaches the network, dequeues the next programmed response, and resolves/rejects accordingly.

### Special case: orderRepositoryProvider

`orderRepositoryProvider` uses `ApiClient.instance` directly (not `ref.watch(apiClientProvider)`). Override it explicitly:

```dart
final container = makeTestContainer(
  fake.apiClient,
  extraOverrides: [
    orderRepositoryProvider.overrideWith(
      (ref) => OrderRepository(fake.apiClient),
    ),
  ],
);
```

### Special case: BrowseAdsNotifier constructor

`BrowseAdsNotifier` fires `_load()` in its constructor. In tests that use `postAdProvider` or `adActionProvider` (which invalidate `browseAdsProvider`), override `browseAdsProvider` with a no-op notifier to prevent queue contamination:

```dart
final container = makeTestContainer(
  fake.apiClient,
  extraOverrides: [
    browseAdsProvider.overrideWith(
      (ref) => BrowseAdsNotifier(_NoOpMarketRepo()),
    ),
  ],
);
```

## P0 Tests (Must Pass to Ship)

| Test | Why P0 |
|---|---|
| `test/common/provider_override_test.dart` | Proves DI chain works — all other tests depend on it |
| `test/auth/auth_repository_test.dart: OtpVerifyNotifier verify invalid OTP` | Core login contract |
| `test/auth/session_notifier_test.dart: bootstrap: getCurrentUser throws UnauthorizedError → unauthenticated` | Session expiry handling |
| `test/auth/session_notifier_test.dart: logout → status unauthenticated` | Logout clears state |
| `test/orders/orders_notifier_test.dart: API failure preserves previous state` | State safety |
| `test/orders/order_state_sync_test.dart: failed cancel mutation does not update list state` | No false positives |
| `test/market/market_state_sync_test.dart: failed toggle → adSavedProvider unchanged` | UI consistency |
| `test/subscriptions/subscription_notifier_test.dart: renew server error throws — no false success` | Payment correctness |
| `test/subscriptions/subscription_notifier_test.dart: cancel server error throws — no silent state update` | Subscription safety |
| `test/invites/invite_repository_test.dart: duplicate invite error handled` | UX correctness |

## How to Add a New Module Test

1. Create `test/<module>/` directory.
2. Add a `<module>_test.dart` file.
3. Import helpers:
   ```dart
   import '../helpers/fake_api_client.dart';
   import '../helpers/test_data.dart';
   import '../helpers/test_provider_container.dart';
   ```
4. Add fixtures to `test/helpers/test_data.dart` if needed.
5. Use `makeTestContainer(fake.apiClient)` to get a container.
6. Enqueue responses with `fake.enqueue(response: ...)` **before** each test action.
7. Run `flutter test test/<module>/` and fix failures before committing.
8. Commit with message: `test(mobile): add <module> unit tests`
