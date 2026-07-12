// QR content classifier — pure functions, no Flutter dependency, no network.
//
// Every GreenRoot QR maps to exactly one QrType determined by content:
//
//   invite          → UUID  (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
//   quotationVerify → 64-char hex token OR URL containing /verify/<64-hex>
//   tripCode        → any other non-empty string (dispatch code)
//   unknown         → empty / unrecognised
//
// RBAC gating (enforced in sheet layer, not here):
//   invite          → any registered user; server enforces role conflicts
//   quotationVerify → any user; public endpoint, no auth required
//   tripCode        → drivers only; non-drivers see role-gate UI
//   unknown         → error screen

enum QrType { invite, quotationVerify, tripCode, unknown }

class QrDetection {
  final QrType type;
  final String? verifyToken; // only set when type == quotationVerify

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

// ── Main classifier ───────────────────────────────────────────────────────────

QrDetection classifyQr(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return const QrDetection(type: QrType.unknown);

  // 1. UUID → invite
  if (_uuidRe.hasMatch(v)) return const QrDetection(type: QrType.invite);

  // 2. 64-char hex raw token → quotationVerify
  if (_hexTokenRe.hasMatch(v)) {
    return QrDetection(type: QrType.quotationVerify, verifyToken: v.toLowerCase());
  }

  // 3. URL containing /verify/<64-hex> → quotationVerify (extract token)
  final m = _verifyUrlRe.firstMatch(v);
  if (m != null) {
    return QrDetection(type: QrType.quotationVerify, verifyToken: m.group(1)!.toLowerCase());
  }

  // 4. Non-empty string → trip code
  return const QrDetection(type: QrType.tripCode);
}

// ── Invite error message helper ───────────────────────────────────────────────

String inviteErrorMessage(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('wrong_target')) {
    return 'This invite was sent to someone else. Ask the sender to create an invite for you.';
  }
  if (s.contains('conflicting_role')) {
    return 'Role conflict: nursery owners cannot join as managers, and managers cannot become nursery owners.';
  }
  if (s.contains('already_member')) {
    return 'You are already a manager at another nursery. Leave your current nursery first, then accept this invite.';
  }
  if (s.contains('forbidden')) {
    return "You don't have permission to accept this invite.";
  }
  if (s.contains('not_found') || s.contains('404')) {
    return 'This invite no longer exists. It may have been cancelled.';
  }
  return 'Failed to accept invite. Please try again.';
}
