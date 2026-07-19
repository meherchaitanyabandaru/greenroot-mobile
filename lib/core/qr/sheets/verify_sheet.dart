import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/api_constants.dart';
import '../../network/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/qr_shared_widgets.dart';
import '../qr_models.dart';

class VerifySheet extends StatefulWidget {
  final String token;
  final VoidCallback onDone;

  const VerifySheet({super.key, required this.token, required this.onDone});

  @override
  State<VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<VerifySheet> {
  QrVerifyData? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiConstants.publicVerify(widget.token),
        // dio_web_adapter on Flutter web can return Map<Object?,Object?> (JS interop)
        // or a raw String. Normalise to Map<String,dynamic> regardless.
        fromJson: (j) {
          if (j is Map<String, dynamic>) return j;
          if (j is Map) return j.cast<String, dynamic>();
          if (j is String) return jsonDecode(j) as Map<String, dynamic>;
          throw FormatException('unexpected verify response type: ${j.runtimeType}');
        },
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = QrVerifyData(
          authenticity: (body['authenticity'] ?? 'INVALID') as String,
          quotationCode: (body['quotation_code'] ?? '') as String,
          quotationStatus: (body['quotation_status'] ?? 'UNKNOWN') as String,
          documentIntegrity: (body['document_integrity'] ?? 'UNVERIFIED') as String,
          issuedAt: body['issued_at'] != null
              ? DateTime.tryParse(body['issued_at'] as String)
              : null,
          validUntil: body['valid_until'] != null
              ? DateTime.tryParse(body['valid_until'] as String)
              : null,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not verify this document. ($e)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const QrLoadingSpinner();
    if (_error != null) {
      return QrErrorCard(
        message: _error!,
        onRetry: () {
          // onRetry resumes scanner — signal close so caller can pop
          widget.onDone();
        },
      );
    }

    final v = _data;
    if (v == null) return const SizedBox.shrink();

    final isVerified = v.authenticity == 'VERIFIED';
    final accent = isVerified ? AppColors.primaryMain : AppColors.red500;
    final lightBg = isVerified ? AppColors.forest100 : AppColors.red500.withAlpha(26);
    final statusLabel = switch (v.quotationStatus) {
      'ACTIVE'    => 'Active — Offer Open',
      'EXPIRED'   => 'Expired',
      'CONVERTED' => 'Converted to Order',
      'CANCELLED' => 'Cancelled',
      _           => v.quotationStatus,
    };
    final fmt = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QrHeaderRow(
          icon: isVerified ? Icons.verified_outlined : Icons.dangerous_outlined,
          iconColor: accent,
          iconBg: lightBg,
          title: isVerified ? 'Quotation Verified' : 'Invalid QR Code',
          subtitle: isVerified
              ? 'This document is authentic and issued by GreenRoot'
              : 'This QR code is not recognised or has been revoked',
        ),
        if (isVerified && v.quotationCode.isNotEmpty) ...[
          const SizedBox(height: 16),
          QrInfoCard(
            children: [
              QrInfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'Quotation ID',
                value: v.quotationCode,
              ),
              QrInfoRow(
                icon: Icons.circle,
                iconSize: 8,
                label: 'Offer Status',
                value: statusLabel,
                valueColor: v.quotationStatus == 'ACTIVE' ? AppColors.primaryMain : null,
              ),
              if (v.issuedAt != null)
                QrInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Issued On',
                  value: fmt.format(v.issuedAt!.toLocal()),
                ),
              if (v.validUntil != null)
                QrInfoRow(
                  icon: Icons.event_outlined,
                  label: 'Valid Until',
                  value: fmt.format(v.validUntil!.toLocal()),
                ),
              QrInfoRow(
                icon: v.documentIntegrity == 'UNMODIFIED'
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_outlined,
                label: 'Document Integrity',
                value: v.documentIntegrity == 'UNMODIFIED' ? 'Unmodified ✓' : 'Unverified',
                valueColor: v.documentIntegrity == 'UNMODIFIED' ? AppColors.primaryMain : null,
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: widget.onDone,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
