import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/qr/classifier.dart';

void main() {
  group('classifyQr — invite (UUID)', () {
    test('standard lowercase UUID v4 → invite', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final r = classifyQr(uuid);
      expect(r.type, QrType.invite);
      expect(r.verifyToken, isNull);
    });

    test('uppercase UUID → invite (case insensitive)', () {
      const uuid = '550E8400-E29B-41D4-A716-446655440000';
      final r = classifyQr(uuid);
      expect(r.type, QrType.invite);
    });

    test('UUID with wrong segment lengths → tripCode (not recognised as UUID)', () {
      // 7-char first segment — not a valid UUID
      const notUuid = '550e840-e29b-41d4-a716-446655440000';
      final r = classifyQr(notUuid);
      expect(r.type, QrType.tripCode);
    });
  });

  group('classifyQr — quotationVerify (64-hex token)', () {
    const validToken =
        'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

    test('64-char lowercase hex → quotationVerify with token', () {
      final r = classifyQr(validToken);
      expect(r.type, QrType.quotationVerify);
      expect(r.verifyToken, validToken);
    });

    test('64-char uppercase hex → quotationVerify (token lowercased)', () {
      final r = classifyQr(validToken.toUpperCase());
      expect(r.type, QrType.quotationVerify);
      expect(r.verifyToken, validToken);
    });

    test('URL containing /verify/<64hex> → quotationVerify + token extracted', () {
      final url = 'https://app.greenroot.in/verify/$validToken';
      final r = classifyQr(url);
      expect(r.type, QrType.quotationVerify);
      expect(r.verifyToken, validToken);
    });

    test('URL with mixed-case /verify/<hex> → quotationVerify', () {
      final url = 'https://app.greenroot.in/verify/${validToken.toUpperCase()}';
      final r = classifyQr(url);
      expect(r.type, QrType.quotationVerify);
      expect(r.verifyToken, validToken);
    });

    test('URL without /verify/ path → tripCode', () {
      final url = 'https://app.greenroot.in/quotation/$validToken';
      final r = classifyQr(url);
      expect(r.type, QrType.tripCode);
    });

    test('63-char hex (one short) → tripCode, not quotationVerify', () {
      final short = validToken.substring(1); // 63 chars
      final r = classifyQr(short);
      expect(r.type, QrType.tripCode);
    });
  });

  group('classifyQr — tripCode', () {
    test('dispatch code format → tripCode', () {
      final r = classifyQr('DSP-20260712-0001');
      expect(r.type, QrType.tripCode);
      expect(r.verifyToken, isNull);
    });

    test('arbitrary alphanumeric string → tripCode', () {
      final r = classifyQr('SOME-RANDOM-CODE-123');
      expect(r.type, QrType.tripCode);
    });

    test('non-GreenRoot URL → tripCode', () {
      final r = classifyQr('https://amazon.com/product/12345');
      expect(r.type, QrType.tripCode);
    });
  });

  group('classifyQr — unknown', () {
    test('empty string → unknown', () {
      final r = classifyQr('');
      expect(r.type, QrType.unknown);
    });

    test('whitespace-only → unknown', () {
      final r = classifyQr('   ');
      expect(r.type, QrType.unknown);
    });
  });

  group('inviteErrorMessage', () {
    test('conflicting_role → role conflict message', () {
      final msg = inviteErrorMessage(Exception('409 conflicting_role'));
      expect(msg, contains('Role conflict'));
    });

    test('already_member → already member message', () {
      final msg = inviteErrorMessage(Exception('already_member'));
      expect(msg, contains('already a manager'));
    });

    test('forbidden → no permission message', () {
      final msg = inviteErrorMessage(Exception('forbidden'));
      expect(msg, contains("don't have permission"));
    });

    test('not_found → expired message', () {
      final msg = inviteErrorMessage(Exception('not_found'));
      expect(msg, contains('no longer exists'));
    });

    test('wrong_target → sent to someone else message', () {
      final msg = inviteErrorMessage(Exception('403 wrong_target'));
      expect(msg, contains('someone else'));
    });

    test('unknown error → generic fallback', () {
      final msg = inviteErrorMessage(Exception('something weird'));
      expect(msg, contains('Failed to accept'));
    });
  });
}
