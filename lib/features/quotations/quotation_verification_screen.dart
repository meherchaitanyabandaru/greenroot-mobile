import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../auth/presentation/providers/session_provider.dart';

// ── Shared colors ─────────────────────────────────────────────────────────────

const _cGreen = Color(0xFF166534);
const _cGreenLight = Color(0xFFDCFCE7);
const _cGreenMid = Color(0xFF16A34A);
const _cAmber = Color(0xFFB45309);
const _cAmberLight = Color(0xFFFEF3C7);
const _cRed = Color(0xFF991B1B);
const _cRedLight = Color(0xFFFEE2E2);
const _cBlue = Color(0xFF1D4ED8);
const _cBlueDark = Color(0xFF1E3A8A);
const _cBlueAlt = Color(0xFF1E40AF);
const _cBlueBorder = Color(0xFFBFDBFE);
const _cBlueLight = Color(0xFFEFF6FF);
const _cGray = Color(0xFF374151);
const _cGrayLight = Color(0xFFF9FAFB);
const _cGrayMuted = Color(0xFF6B7280);
const _cBorder = Color(0xFFE5E7EB);

// ── Model ─────────────────────────────────────────────────────────────────────

class _VerifyResult {
  final String quotationCode;
  final String authenticity; // VERIFIED | INVALID
  final String quotationStatus; // ACTIVE | EXPIRED | CANCELLED | CONVERTED
  final String documentIntegrity; // UNMODIFIED | UNVERIFIED
  final DateTime issuedAt;
  final DateTime? validUntil;
  final DateTime verifiedAt;

  const _VerifyResult({
    required this.quotationCode,
    required this.authenticity,
    required this.quotationStatus,
    required this.documentIntegrity,
    required this.issuedAt,
    this.validUntil,
    required this.verifiedAt,
  });

  factory _VerifyResult.fromJson(Map<String, dynamic> j) => _VerifyResult(
        quotationCode: (j['quotation_code'] as String?) ?? '',
        authenticity: (j['authenticity'] as String?) ?? 'INVALID',
        quotationStatus: (j['quotation_status'] as String?) ?? 'UNKNOWN',
        documentIntegrity:
            (j['document_integrity'] as String?) ?? 'UNVERIFIED',
        issuedAt: DateTime.parse(j['issued_at'] as String),
        validUntil: j['valid_until'] != null
            ? DateTime.parse(j['valid_until'] as String)
            : null,
        verifiedAt: DateTime.parse(j['verified_at'] as String),
      );

  bool get isVerified => authenticity == 'VERIFIED';
  bool get isActive => quotationStatus == 'ACTIVE';
  bool get isExpired => quotationStatus == 'EXPIRED';
  bool get isCancelled => quotationStatus == 'CANCELLED';
  bool get isConverted => quotationStatus == 'CONVERTED';
  bool get isIntegrityOk => documentIntegrity == 'UNMODIFIED';
}

// ── Verification Screen ───────────────────────────────────────────────────────

class QuotationVerificationScreen extends ConsumerStatefulWidget {
  final String token;
  const QuotationVerificationScreen({super.key, required this.token});

  @override
  ConsumerState<QuotationVerificationScreen> createState() =>
      _QuotationVerificationScreenState();
}

class _QuotationVerificationScreenState
    extends ConsumerState<QuotationVerificationScreen> {
  _VerifyResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiConstants.publicVerify(widget.token),
        fromJson: (j) {
          if (j is Map<String, dynamic>) return j;
          if (j is Map) return j.cast<String, dynamic>();
          if (j is String) return jsonDecode(j) as Map<String, dynamic>;
          throw FormatException('unexpected verify response type: ${j.runtimeType}');
        },
      );
      if (mounted) {
        setState(() {
          _result = _VerifyResult.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _viewFullQuotation() {
    final session = ref.read(sessionProvider);
    final isLoggedIn = session.status == SessionStatus.authenticated;
    final destination = '/quotations/by-token/${widget.token}';
    if (!isLoggedIn) {
      context.push('/login', extra: destination);
    } else {
      context.push(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _cGreen),
              )
            : _error != null
                ? _InvalidPage(
                    onRetry: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _fetch();
                    },
                  )
                : _VerifyBody(
                    result: _result!,
                    onViewFull: _viewFullQuotation,
                    fmt: _fmt,
                  ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _VerifyBody extends StatelessWidget {
  final _VerifyResult result;
  final VoidCallback onViewFull;
  final String Function(DateTime) fmt;

  const _VerifyBody({
    required this.result,
    required this.onViewFull,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final headerColor = r.isVerified ? _cGreen : _cRed;
    final headerIconBg = r.isVerified ? _cGreenLight : _cRedLight;
    final headerTitle = r.isVerified ? 'Quotation Verified' : 'Cannot Verify';
    final headerSubtitle = r.isVerified
        ? 'This quotation is authentic and verified by GreenRoot.'
        : 'This QR code could not be verified. It may be invalid or revoked.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── GreenRoot logo ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _cGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: _cGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GreenRoot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _cGreen,
                    ),
                  ),
                  Text(
                    'NURSERY MANAGEMENT',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.2,
                      color: _cGrayMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Shield icon ────────────────────────────────────────────────
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: headerIconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              r.isVerified
                  ? Icons.verified_user_rounded
                  : Icons.gpp_bad_rounded,
              color: headerColor,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            headerTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _cGray,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            headerSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _cGrayMuted),
          ),
          const SizedBox(height: 24),

          if (r.isVerified) ...[
            _StatusCard(result: r),
            const SizedBox(height: 16),
            _DetailsCard(result: r, fmt: fmt),
            const SizedBox(height: 16),
            _IntegrityCard(result: r, fmt: fmt),
            const SizedBox(height: 16),
          ],

          _ViewFullCard(onViewFull: onViewFull),
          const SizedBox(height: 16),
          const _WhyCard(),
          const SizedBox(height: 24),

          // ── Footer ─────────────────────────────────────────────────────
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 11, color: _cGrayMuted),
              children: [
                TextSpan(text: 'Generated and verified by '),
                TextSpan(
                  text: 'GreenRoot',
                  style: TextStyle(
                    color: _cGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: ' Nursery Management System'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Quotation status card ─────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final _VerifyResult result;
  const _StatusCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final Color bg;
    final Color iconColor;
    final IconData icon;
    final String statusLabel;
    final String statusDesc;

    if (r.isActive) {
      bg = _cGreenLight;
      iconColor = _cGreenMid;
      icon = Icons.check_circle_rounded;
      statusLabel = 'Active';
      statusDesc = 'This quotation is active and valid as of today.';
    } else if (r.isExpired) {
      bg = _cAmberLight;
      iconColor = _cAmber;
      icon = Icons.schedule_rounded;
      statusLabel = 'Expired';
      statusDesc =
          'This quotation offer has expired. The document remains authentic.';
    } else if (r.isConverted) {
      bg = _cBlueLight;
      iconColor = _cBlue;
      icon = Icons.swap_horiz_rounded;
      statusLabel = 'Converted to Order';
      statusDesc = 'This quotation was accepted and converted to an order.';
    } else {
      bg = _cRedLight;
      iconColor = _cRed;
      icon = Icons.cancel_rounded;
      statusLabel = 'Cancelled';
      statusDesc = 'This quotation has been cancelled.';
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Quotation Status: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusDesc,
                  style: const TextStyle(fontSize: 12, color: _cGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quotation details card ────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final _VerifyResult result;
  final String Function(DateTime) fmt;
  const _DetailsCard({required this.result, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: _cGray),
              SizedBox(width: 8),
              Text(
                'Quotation Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _cGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('Quotation ID', r.quotationCode, bold: true),
          _divider(),
          _row(
            'Quotation Authenticity',
            'Verified',
            valueColor: _cGreenMid,
            bold: true,
          ),
          _divider(),
          _row('Issue Date', '📅 ${fmt(r.issuedAt)}'),
          if (r.validUntil != null) ...[
            _divider(),
            _row('Valid Until', '📅 ${fmt(r.validUntil!)}'),
          ],
          _divider(),
          _row('Document Type', 'Quotation (PDF)'),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: _cGrayMuted),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? _cGray,
              ),
            ),
          ],
        ),
      );

  Widget _divider() =>
      const Divider(height: 1, thickness: 0.5, color: _cBorder);
}

// ── Document integrity card ───────────────────────────────────────────────────

class _IntegrityCard extends StatelessWidget {
  final _VerifyResult result;
  final String Function(DateTime) fmt;
  const _IntegrityCard({required this.result, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isOk = result.isIntegrityOk;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security_rounded, size: 18, color: _cGray),
              SizedBox(width: 8),
              Text(
                'Document Integrity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _cGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOk ? _cGreen : _cGrayLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOk ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: isOk ? Colors.white : _cGrayMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Document Integrity: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _cGray,
                          ),
                        ),
                        Text(
                          isOk ? 'Unmodified' : 'Not Verified',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isOk ? _cGreenMid : _cGrayMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOk
                          ? 'The document is authentic and has not been modified since it was generated.'
                          : 'No official copy of this PDF has been stored by GreenRoot yet.',
                      style: const TextStyle(fontSize: 12, color: _cGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _cGrayLight,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: _cGrayMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Verification checked on ${fmt(result.verifiedAt)}',
                      style:
                          const TextStyle(fontSize: 11, color: _cGrayMuted),
                    ),
                  ],
                ),
                const Text(
                  'Verified by GreenRoot',
                  style: TextStyle(fontSize: 11, color: _cGrayMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── View Full Quotation card ──────────────────────────────────────────────────

class _ViewFullCard extends StatelessWidget {
  final VoidCallback onViewFull;
  const _ViewFullCard({required this.onViewFull});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cBlueLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cBlueBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: _cBlueAlt, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View Full Quotation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _cBlueAlt,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Login to view complete quotation details including plants, prices, totals and terms.',
                  style: TextStyle(fontSize: 12, color: _cBlue),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onViewFull,
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text(
              'View Full Quotation',
              style: TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cBlueDark,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Why card ──────────────────────────────────────────────────────────────────

class _WhyCard extends StatelessWidget {
  const _WhyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cGrayLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.security_outlined, size: 18, color: _cGrayMuted),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why am I seeing this page?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _cGray,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'You scanned a QR code from a GreenRoot quotation. This page shows public verification information only.',
                  style: TextStyle(fontSize: 12, color: _cGrayMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _cGrayMuted,
              side: const BorderSide(color: _cBorder),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded, size: 14),
                SizedBox(width: 4),
                Text('Learn more', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Invalid / error page ──────────────────────────────────────────────────────

class _InvalidPage extends StatelessWidget {
  final VoidCallback onRetry;
  const _InvalidPage({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gpp_bad_rounded, color: _cRed, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Invalid QR Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _cGray,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This QR code could not be verified.\nIt may be invalid, revoked, or from an older version.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _cGrayMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
