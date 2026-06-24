import 'package:logger/logger.dart';
import '../config/app_config.dart';

class AppLogger {
  static late Logger _logger;

  static void init() {
    _logger = Logger(
      level: AppConfig.enableLogging ? Level.debug : Level.off,
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  static void d(dynamic message, [dynamic error, StackTrace? st]) =>
      _logger.d(message, error: error, stackTrace: st);

  static void i(dynamic message, [dynamic error, StackTrace? st]) =>
      _logger.i(message, error: error, stackTrace: st);

  static void w(dynamic message, [dynamic error, StackTrace? st]) =>
      _logger.w(message, error: error, stackTrace: st);

  static void e(dynamic message, [dynamic error, StackTrace? st]) =>
      _logger.e(message, error: error, stackTrace: st);

  static void api(String method, String url, {int? status, dynamic body}) {
    if (!AppConfig.enableLogging) return;
    _logger.d('[$method] $url${status != null ? ' → $status' : ''}${body != null ? '\n$body' : ''}');
  }
}
