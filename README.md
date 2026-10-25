# greenroot_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Release builds

Production builds use `lib/main_prod.dart` (`https://api.greenroot.in`). Two
things are needed that never live in the repository.

### 1. Signing (Android)

Create the Play **upload key** once and keep it (and its passwords) in your
password manager; losing it means a Play support request to reset it.

```bash
keytool -genkey -v -keystore ~/greenroot-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cat > android/key.properties <<'PROPS'
storeFile=/home/you/greenroot-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
PROPS
```

`android/key.properties` and `*.jks` are git-ignored. In CI set
`GREENROOT_KEYSTORE_FILE`, `GREENROOT_KEYSTORE_PASSWORD`, `GREENROOT_KEY_ALIAS`
and `GREENROOT_KEY_PASSWORD` instead. **A release build without a keystore
fails** (it used to be signed with the debug key, which Play rejects).

### 2. Push notifications (Firebase)

In the Firebase console create the project, add an Android app
(`in.greenroot.greenroot_mobile`) and an iOS app (`in.greenroot.greenrootMobile`),
and pass their values at build time (no `google-services.json` is committed):

```bash
flutter build appbundle -t lib/main_prod.dart \
  --dart-define=FCM_PROJECT_ID=greenroot-prod \
  --dart-define=FCM_SENDER_ID=123456789012 \
  --dart-define=FCM_API_KEY=AIza... \
  --dart-define=FCM_APP_ID_ANDROID=1:123456789012:android:abc... \
  --dart-define=FCM_APP_ID_IOS=1:123456789012:ios:def...
```

Without them push is off and notifications stay in the in-app inbox. The API
needs the same project's service-account key (`FCM_SERVICE_ACCOUNT_JSON`, see
greenroot-infra `deploy/README.md`). After sign-in the app registers the
device (`POST /notifications/devices`); logout unregisters it.

### iOS

`ios/` is a standard Flutter Runner (bundle id `in.greenroot.greenrootMobile`).
On a Mac with Xcode: set your team under Signing & Capabilities, add the
**Push Notifications** capability, upload an APNs key to Firebase (Project
settings → Cloud Messaging), then `flutter build ipa -t lib/main_prod.dart`
with the same `--dart-define`s. Camera, photo and location prompts are in
`ios/Runner/Info.plist`.

### Network safety

- Release builds are HTTPS-only (`usesCleartextTraffic=false`; plain HTTP to a
  local API is allowed in debug/profile builds and, on iOS, to local addresses).
- Create requests carry an `Idempotency-Key` (`IdempotencyInterceptor`), so a
  retry after a lost response or a double tap does not create a second ad,
  dispatch, item or invite; order and quotation forms keep one key per form.
