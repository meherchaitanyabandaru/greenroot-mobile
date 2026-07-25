import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/api_constants.dart';
import '../../network/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/qr_shared_widgets.dart';
import '../qr_models.dart';

class OrderVerifySheet extends StatefulWidget {
  final String token;
  final VoidCallback onDone;

  const OrderVerifySheet({super.key, required this.token, required this.onDone});

  @override
  State<OrderVerifySheet> createState() => _OrderVerifySheetState();
}

class _OrderVerifySheetState extends State<OrderVerifySheet> {
  OrderQrVerifyData? _data;
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
        ApiConstants.publicVerifyOrder(widget.token),
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
        _data = OrderQrVerifyData(
          authenticity: (body['authenticity'] ?? 'INVALID') as String,
          orderCode: (body['order_code'] ?? '') as String,
          orderStatus: (body['order_status'] ?? 'UNKNOWN') as String,
          documentIntegrity: (body['document_integrity'] ?? 'UNVERIFIED') as String,
          issuedAt: body['issued_at'] != null
              ? DateTime.tryParse(body['issued_at'] as String)
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
          widget.onDone();
        },
      );
    }

    final v = _data;
    if (v == null) return const SizedBox.shrink();

    final isVerified = v.authenticity == 'VERIFIED';
    final accent = isVerified ? AppColors.primaryMain : AppColors.red500;
    final lightBg = isVerified ? AppColors.forest100 : AppColors.red500.withAlpha(26);
    final statusLabel = switch (v.orderStatus) {
      'PENDING' => 'Pending Confirmation',
      'CONFIRMED' => 'Confirmed',
      'LOADING' => 'Loading in Progress',
      'LOADED' => 'Loaded',
      'PARTIALLY_FULFILLED' => 'Partially Fulfilled',
      'COMPLETED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      _ => v.orderStatus,
    };
    final fmt = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QrHeaderRow(
          icon: isVerified ? Icons.verified_outlined : Icons.dangerous_outlined,
          iconColor: accent,
          iconBg: lightBg,
          title: isVerified ? 'Order Verified' : 'Invalid QR Code',
          subtitle: isVerified
              ? 'This document is authentic and issued by GreenRoot'
              : 'This QR code is not recognised or has been revoked',
        ),
        if (isVerified && v.orderCode.isNotEmpty) ...[
          const SizedBox(height: 16),
          QrInfoCard(
            children: [
              QrInfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'Order ID',
                value: v.orderCode,
              ),
              QrInfoRow(
                icon: Icons.circle,
                iconSize: 8,
                label: 'Order Status',
                value: statusLabel,
                valueColor: v.orderStatus == 'COMPLETED' ? AppColors.primaryMain : null,
              ),
              if (v.issuedAt != null)
                QrInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Issued On',
                  value: fmt.format(v.issuedAt!.toLocal()),
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
