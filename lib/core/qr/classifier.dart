import '../errors/app_error.dart';

// QR content classifier — pure functions, no Flutter dependency, no network.
//
// Every GreenRoot QR maps to exactly one QrType determined by content:
//
//   invite          → UUID  (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
//   quotationVerify → 64-char hex token OR URL containing /verify/<64-hex>
//   orderVerify     → URL containing /verify-order/<64-hex>
//   tripCode        → any other non-empty string (dispatch code)
//   unknown         → empty / unrecognised
//
// A bare 64-hex token (no URL) is ambiguous between quotationVerify and
// orderVerify — it's treated as quotationVerify for backward compatibility.
// Order PDFs always encode the full /verify-order/ URL, never a bare token, so
// this doesn't affect real order QR codes in practice.
//
// RBAC gating (enforced in sheet layer, not here):
//   invite          → any registered user; server enforces role conflicts
//   quotationVerify → any user; public endpoint, no auth required
//   orderVerify     → any user; public endpoint, no auth required
//   tripCode        → drivers only; non-drivers see role-gate UI
//   unknown         → error screen

enum QrType { invite, quotationVerify, orderVerify, tripCode, unknown }

class QrDetection {
  final QrType type;
  final String? verifyToken; // set when type == quotationVerify or orderVerify

  const QrDetection({required this.type, this.verifyToken});
}

// What the result sheet signals back to the scanner.
enum QrSheetResult { resume, goToTrip, close }

// ── Regex patterns ────────────────────────────────────────────────────────────

final _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _hexTokenRe = RegExp(r'^[0-9a-f]{64}$', caseSensitive: false);
final _verifyUrlRe = RegExp(r'/verify/([0-9a-f]{64})', caseSensitive: false);
final _orderVerifyUrlRe =
    RegExp(r'/verify-order/([0-9a-f]{64})', caseSensitive: false);

// ── Main classifier ───────────────────────────────────────────────────────────

QrDetection classifyQr(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return const QrDetection(type: QrType.unknown);

  // 1. UUID → invite
  if (_uuidRe.hasMatch(v)) return const QrDetection(type: QrType.invite);

  // 2. URL containing /verify-order/<64-hex> → orderVerify (extract token).
  //    Checked before the bare-hex and quotation-URL patterns since this is a
  //    more specific match.
  final orderMatch = _orderVerifyUrlRe.firstMatch(v);
  if (orderMatch != null) {
    return QrDetection(
        type: QrType.orderVerify,
        verifyToken: orderMatch.group(1)!.toLowerCase());
  }

  // 3. 64-char hex raw token → quotationVerify
  if (_hexTokenRe.hasMatch(v)) {
    return QrDetection(type: QrType.quotationVerify, verifyToken: v.toLowerCase());
  }

  // 4. URL containing /verify/<64-hex> → quotationVerify (extract token)
  final m = _verifyUrlRe.firstMatch(v);
  if (m != null) {
    return QrDetection(type: QrType.quotationVerify, verifyToken: m.group(1)!.toLowerCase());
  }

  // 5. Non-empty string → trip code
  return const QrDetection(type: QrType.tripCode);
}

// ── Invite error message helper ───────────────────────────────────────────────

String inviteErrorMessage(Object e) {
  if (e is WrongTargetInviteError) return e.message;
  if (e is ConflictingRoleError) return e.message;
  if (e is AlreadyMemberError) return e.message;
  if (e is NotFoundError) return 'This invite no longer exists. It may have been cancelled.';
  if (e is ForbiddenError) return "You don't have permission to accept this invite.";
  return 'Failed to accept invite. Please try again.';
}
