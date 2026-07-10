# GreenRoot Mobile — Test Hardening Report

## Phase 1 Audit

### Pre-existing Tests

| File | Tests | Status Before |
|---|---|---|
| `test/widget_test.dart` | 1 (AppConfig init) | FAILING (URL mismatch: `127.0.0.1` vs `localhost`) |
| `test/driver_test.dart` | ~35 (driver unit + model tests) | PASSING |

No `integration_test/` directory existed.

### Test Infrastructure Gap

| Category | Status Before |
|---|---|
| Fake HTTP client | Missing |
| ProviderContainer override helper | Missing |
| Centralised fixtures | Missing |
| Auth unit tests | Missing |
| Orders unit tests | Missing |
| Market unit tests | Missing |
| Invite tests | Missing |
| Subscription tests | Missing |
| State-sync tests | Missing |

---

## What Was Built

### Test Helpers (`test/helpers/`)

| File | What it does |
|---|---|
| `fake_api_client.dart` | Intercepts all Dio requests via `_FakeInterceptor`; maps `FakeResponseType` to HTTP status codes so `NetworkExceptions.fromDioException()` converts them correctly to typed `AppError` subclasses |
| `test_provider_container.dart` | `makeTestContainer()` — creates a `ProviderContainer` overriding `apiClientProvider`, registers `addTearDown(container.dispose)` |
| `test_data.dart` | Centralised fixtures for all modules: auth, orders, market, invites, subscriptions |
| `test_exceptions.dart` | Reusable `AppError` instances for each error scenario |

### Unit Tests Added

| File | Tests | Coverage focus |
|---|---|---|
| `test/common/provider_override_test.dart` | 5 | DI chain, no singleton escape |
| `test/auth/auth_repository_test.dart` | 10 | OTP send/verify state machine |
| `test/auth/session_notifier_test.dart` | 12 | Bootstrap, logout, state helpers, SessionState properties |
| `test/orders/orders_notifier_test.dart` | 10 | Load/loadMore, error preservation, cancel |
| `test/orders/order_state_sync_test.dart` | 7 | Status transitions, filter isolation, failed-mutation safety |
| `test/market/market_repository_test.dart` | 9 | CRUD operations + presign + error mapping |
| `test/market/browse_ads_notifier_test.dart` | 8 | Auto-load, sort, filters, loadMore, refresh |
| `test/market/market_state_sync_test.dart` | 9 | postAd invalidation, toggleSave state, adAction, photo upload path |
| `test/invites/invite_repository_test.dart` | 6 | sendInvite success + 4 error scenarios |
| `test/subscriptions/subscription_notifier_test.dart` | 10 | Active/null/most-recent selection, plans, renew, cancel |
| `test/subscriptions/subscription_state_sync_test.dart` | 8 | State sync after renew/cancel + SubscriptionModel helpers |

### Pre-existing Test Fix

| File | Fix |
|---|---|
| `test/widget_test.dart` | Updated expected URL from `127.0.0.1:8080` to `localhost:8080` to match current `EnvConfig.dev` |

---

## Technical Findings

### DI Architecture
- `apiClientProvider` override works for: `authRepositoryProvider`, `inviteRepositoryProvider`, `marketRepositoryProvider`, `subscriptionDataSourceProvider`
- **Exception**: `orderRepositoryProvider` uses `ApiClient.instance` directly instead of `ref.watch(apiClientProvider)`. Must be overridden separately in order tests.

### SecureStorage in Tests
- `flutter_secure_storage` is unavailable in Dart unit tests (MissingPluginException)
- `SecureStorageService` swallows all errors gracefully, so `hasSession()` returns `false` in tests
- Session tests use a `_FakeAuthRepo` (extends `AuthRepository`, overrides all methods) to test `SessionNotifier` in full without touching storage

### BrowseAdsNotifier Constructor Race
- `BrowseAdsNotifier` fires `_load()` in its constructor. When `_PostAdNotifier.create()` invalidates `browseAdsProvider`, a new notifier is constructed and its `_load()` consumes a queued response
- Fixed by overriding `browseAdsProvider` with a `_NoOpMarketRepo`-backed notifier in tests that use `postAdProvider` or `adActionProvider`

### _rawDio (S3 Presigned PUT)
- Intentionally not tested via unit tests — it's a module-level bare Dio that bypasses all interceptors
- The presign call (authenticated) is covered. The S3 PUT is an integration-test concern

---

## Final Test Count

| Run | Tests | Result |
|---|---|---|
| `flutter test` | 149 | ALL PASS |
| `flutter analyze` | 0 errors, 0 warnings in test files | CLEAN |

---

## Rating by Category

| Category | Before | After |
|---|---|---|
| DI / Provider override | D (untested) | A (5 tests proving chain) |
| Auth state machine | F (zero tests) | A (22 tests) |
| Orders CRUD + state | F (zero tests) | A (17 tests) |
| Market repository + notifier | F (zero tests) | A (26 tests) |
| Invites | F (zero tests) | A (6 tests) |
| Subscriptions | F (zero tests) | A (18 tests) |
| State sync safety | F (zero tests) | A (key mutation-failure tests for each domain) |
| Driver/dispatch (pre-existing) | B (35 tests) | B (unchanged, all pass) |
| **Overall** | **F** | **A-** |

The `-` reflects: no integration tests (SecureStorage, S3 upload), and `orderRepositoryProvider` DI gap (uses singleton, not ref.watch).
