abstract class AppConstants {
  // Secure Storage keys
  static const String keyAccessToken  = 'gr_access_token';
  static const String keyRefreshToken = 'gr_refresh_token';
  static const String keyUserId       = 'gr_user_id';
  static const String keyActiveRole   = 'gr_active_role';
  static const String keyTermsAgreed  = 'gr_terms_agreed';
  /// Version of the Terms & Conditions; a new one asks everyone to agree again.
  static const String termsVersion = '2026-10-27';

  // API timeouts
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;
  static const int sendTimeoutMs    = 30000;

  // Pagination
  static const int defaultPageSize = 20;

  // OTP
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;
  // Matches otpTTL in greenroot-api auth/model.go.
  static const int otpValidMinutes = 5;
}
