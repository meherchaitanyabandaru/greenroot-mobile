import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../utilities/logger.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Access Token ────────────────────────────────────────────────────────────
  static Future<void> saveAccessToken(String token) =>
      _write(AppConstants.keyAccessToken, token);

  static Future<String?> getAccessToken() =>
      _read(AppConstants.keyAccessToken);

  // ── Refresh Token ───────────────────────────────────────────────────────────
  static Future<void> saveRefreshToken(String token) =>
      _write(AppConstants.keyRefreshToken, token);

  static Future<String?> getRefreshToken() =>
      _read(AppConstants.keyRefreshToken);

  // ── User ID ─────────────────────────────────────────────────────────────────
  static Future<void> saveUserId(int id) =>
      _write(AppConstants.keyUserId, id.toString());

  static Future<int?> getUserId() async {
    final val = await _read(AppConstants.keyUserId);
    return val != null ? int.tryParse(val) : null;
  }

  // ── Active Role ─────────────────────────────────────────────────────────────
  static Future<void> saveActiveRole(String role) =>
      _write(AppConstants.keyActiveRole, role);

  static Future<String?> getActiveRole() =>
      _read(AppConstants.keyActiveRole);

  // ── Session ─────────────────────────────────────────────────────────────────
  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserId(userId),
    ]);
  }

  static Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    await Future.wait([
      _delete(AppConstants.keyAccessToken),
      _delete(AppConstants.keyRefreshToken),
      _delete(AppConstants.keyUserId),
      _delete(AppConstants.keyActiveRole),
    ]);
    AppLogger.i('Session cleared');
  }

  // ── Terms Agreement ─────────────────────────────────────────────────────────
  static Future<void> saveTermsAgreed() =>
      _write(AppConstants.keyTermsAgreed, 'true');

  static Future<bool> hasAgreedToTerms() async {
    final val = await _read(AppConstants.keyTermsAgreed);
    return val == 'true';
  }

  // ── Private helpers ─────────────────────────────────────────────────────────
  static Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      AppLogger.e('SecureStorage write error: $key', e);
    }
  }

  static Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      AppLogger.e('SecureStorage read error: $key', e);
      return null;
    }
  }

  static Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      AppLogger.e('SecureStorage delete error: $key', e);
    }
  }
}
