import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Gives create requests an Idempotency-Key derived from what they create,
/// so a retry after a lost response, or a double tap, replays the first
/// result on the API instead of creating a second ad, dispatch, item or
/// invite. (The API remembers keys for 24 hours, per user and path.)
///
/// The key is a hash of the path, the JSON body and a 10-minute window: the
/// same create resent within minutes is the same request. Forms that hold an
/// explicit key (orders, quotations: newIdempotencyKey) keep theirs. Chat
/// replies are not listed: sending "ok" twice is two messages.
class IdempotencyInterceptor extends Interceptor {
  IdempotencyInterceptor({DateTime Function()? now, this.window = const Duration(minutes: 10)})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration window;

  static const header = 'Idempotency-Key';

  /// POST paths that create something (after /api/v1).
  static final List<RegExp> createPaths = [
    RegExp(r'^/market/ads/?$'),
    RegExp(r'^/market/ads/\d+/enquiries$'),
    RegExp(r'^/market/enquiries/\d+/offers$'),
    RegExp(r'^/dispatches/?$'),
    RegExp(r'^/dispatches/\d+/items$'),
    RegExp(r'^/orders/\d+/items$'),
    RegExp(r'^/payments(/manual)?/?$'),
    RegExp(r'^/invites/?$'),
    RegExp(r'^/vehicles/?$'),
    RegExp(r'^/top-items/?$'),
    RegExp(r'^/(users|nurseries)/\d+/addresses$'),
    RegExp(r'^/plants/suggestions$'),
    RegExp(r'^/drivers/apply$'),
    RegExp(r'^/ratings/'),
  ];

  static bool isCreate(String path) {
    final p = path.replaceFirst(RegExp(r'^https?://[^/]+'), '').replaceFirst('/api/v1', '');
    return createPaths.any((r) => r.hasMatch(p));
  }

  /// The key for [path] and [body] at [at] (exposed for tests).
  String keyFor(String path, Object? body, DateTime at) {
    final bucket = at.millisecondsSinceEpoch ~/ window.inMilliseconds;
    final digest = sha256.convert(utf8.encode('$path|${jsonEncode(body)}|$bucket'));
    return digest.toString().substring(0, 32);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final body = options.data;
    if (options.method.toUpperCase() == 'POST' &&
        !options.headers.containsKey(header) &&
        body is! FormData && // uploads are not JSON creates
        isCreate(options.path)) {
      options.headers[header] = keyFor(options.path, body, _now());
    }
    handler.next(options);
  }
}
