# GreenRoot Mobile

Flutter mobile app for the GreenRoot nursery platform — serves nursery owners, managers, drivers, and buyers.

## Run Locally

```bash
flutter pub get
flutter run -d <device-id>
```

For a physical Android device with local API:

```bash
adb reverse tcp:8080 tcp:8080
flutter run --release -d <device-id>
```

API runs at `http://127.0.0.1:8080` (ADB tunnel from Mac).

## Dev Login

| Mobile | OTP | Role |
|---|---|---|
| `9000000777` | `123456` | Admin |
| `9111111111` | `123456` | Buyer |
| `9222222222` | `123456` | Nursery Owner |
| `9333333333` | `123456` | Driver |
| `9555555555` | `123456` | Manager |

## Stack

Flutter · Dart · Riverpod (StateNotifierProvider) · GoRouter · Dio · flutter_secure_storage

## Architecture

Feature-first layout under `lib/features/`. Each feature owns its models, repository, providers, and screens in one place.

```
lib/
├── app/            # Router, theme, app entry
├── core/           # ApiClient, errors, constants, widgets, theme
└── features/
    ├── auth/       # OTP login, session, RBAC
    ├── dashboard/  # Per-role shell + home tabs
    ├── plants/     # Plant catalog + detail
    ├── nurseries/  # Nursery list + detail
    ├── inventory/  # Inventory list + add
    ├── orders/     # Order list + detail + create (manager)
    ├── requests/   # Plant requests (nursery B2B)
    ├── dispatches/ # Dispatch list + detail + tracking
    └── ...
```

## Role Navigation

| Role | Tabs |
|---|---|
| Nursery Owner | Home · Requests · Orders · Inventory · Profile |
| Manager | Home · Orders · Inventory · Dispatches · Profile |
| Buyer | Home · My Orders · Profile |
| Driver | Home · Dispatches · Profile |

## Business Flow

- **Buyers** call the nursery and order over the phone.
- **Managers** enter the order into the app (buyer mobile + items + price).
- **Manager** loads the truck in the morning, creates a dispatch.
- **Driver** dispatches and the lorry is tracked.
- **Buyer** logs in to see their order and track delivery (read-only).
- Payments are direct between nursery and buyer — the platform only collects subscription fees.

## Full Project Context

See [`../AI_CONTEXT.md`](../AI_CONTEXT.md) for cross-repo context.
