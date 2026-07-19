sealed class AppError implements Exception {
  final String message;
  const AppError(this.message);

  @override
  String toString() => message;
}

class NetworkError extends AppError {
  const NetworkError([super.message = 'No internet connection.']);
}

class TimeoutError extends AppError {
  const TimeoutError([super.message = 'Request timed out. Please try again.']);
}

class ServerError extends AppError {
  final int statusCode;
  const ServerError(this.statusCode, [super.message = 'Server error occurred.']);
}

class UnauthorizedError extends AppError {
  const UnauthorizedError([super.message = 'Session expired. Please login again.']);
}

class ForbiddenError extends AppError {
  const ForbiddenError([super.message = 'You do not have permission to perform this action.']);
}

class NotFoundError extends AppError {
  const NotFoundError([super.message = 'Resource not found.']);
}

class ValidationError extends AppError {
  final Map<String, String>? fieldErrors;
  const ValidationError(super.message, {this.fieldErrors});
}

class UnknownError extends AppError {
  const UnknownError([super.message = 'Something went wrong. Please try again.']);
}

class AccountSuspendedError extends AppError {
  final String? reason;
  final DateTime? suspendedAt;
  const AccountSuspendedError({this.reason, this.suspendedAt})
      : super('Your account has been suspended. Contact support.');
}

class WrongTargetInviteError extends AppError {
  const WrongTargetInviteError()
      : super("This invite isn't for you. Ask the nursery to send a new invite to your number.");
}

class ConflictingRoleError extends AppError {
  const ConflictingRoleError([super.message = "Your current role doesn't allow you to accept this invite."]);
}

class AlreadyMemberError extends AppError {
  const AlreadyMemberError([super.message = 'You are already a member of a nursery. Leave your current nursery first.']);
}
