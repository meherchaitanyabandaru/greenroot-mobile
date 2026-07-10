import 'package:greenroot_mobile/core/errors/app_error.dart';

// ── Reusable AppError instances for test assertions ────────────────────────────

const kNetworkError = NetworkError();
const kTimeoutError = TimeoutError();
const kUnauthorizedError = UnauthorizedError();
const kForbiddenError = ForbiddenError();
const kNotFoundError = NotFoundError();
const kServerError = ServerError(500);
const kValidationError = ValidationError('Validation failed');
const kUnknownError = UnknownError();
