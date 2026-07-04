import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/pagination.dart' show ApiPagination;
import '../../core/network/api_client.dart' show ApiClient;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class Payment {
  final int id;
  final String paymentCode;
  final String? orderNumber;
  final double amount;
  final String paymentStatus;
  final String? paymentMethod;
  final String? transactionReference;
  final String? notes;
  final String? createdAt;

  const Payment({
    required this.id,
    required this.paymentCode,
    this.orderNumber,
    required this.amount,
    required this.paymentStatus,
    this.paymentMethod,
    this.transactionReference,
    this.notes,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: (j['id'] as num).toInt(),
        paymentCode: j['payment_code'] as String? ?? '',
        orderNumber: j['order_number'] as String?,
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: j['payment_status'] as String? ?? 'UNKNOWN',
        paymentMethod: j['payment_method'] as String?,
        transactionReference: j['transaction_reference'] as String?,
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

final paymentRepositoryProvider =
    Provider((ref) => PaymentRepository(ApiClient.instance));

class PaymentRepository {
  final ApiClient _api;
  const PaymentRepository(this._api);

  Future<(List<Payment>, ApiPagination)> listPayments({
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await _api.get(
      ApiConstants.payments,
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final list = res['payments'] as List<dynamic>? ?? [];
    final payments =
        list.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    final paginationJson = res['pagination'] as Map<String, dynamic>? ?? {};
    final meta = ApiPagination.fromJson(paginationJson);
    return (payments, meta);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Buyer-only: payment history for the authenticated buyer.
/// RBAC: Payments → Buyer → own. Only accessible to BUYER role.
class BuyerPaymentsScreen extends ConsumerStatefulWidget {
  const BuyerPaymentsScreen({super.key});

  @override
  ConsumerState<BuyerPaymentsScreen> createState() =>
      _BuyerPaymentsScreenState();
}

class _BuyerPaymentsScreenState extends ConsumerState<BuyerPaymentsScreen> {
  List<Payment> _payments = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          _hasMore &&
          !_loadingMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final (payments, meta) = await ref
          .read(paymentRepositoryProvider)
          .listPayments(page: 1);
      if (mounted) {
        setState(() {
          _payments = payments;
          _hasMore = meta.hasMore;
          _page = 1;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final (payments, meta) = await ref
          .read(paymentRepositoryProvider)
          .listPayments(page: nextPage);
      if (mounted) {
        setState(() {
          _payments = [..._payments, ...payments];
          _page = nextPage;
          _hasMore = meta.hasMore;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Payment History', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryMain))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!, style: AppTypography.body),
                      TextButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.forest100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.payments_outlined,
                                size: 36, color: AppColors.primaryMain),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Text('No Payments Yet',
                              style: AppTypography.h3),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Your payment history will appear here\nonce orders are paid.',
                            style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primaryMain,
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenPadding,
                            AppSpacing.md,
                            AppSpacing.screenPadding,
                            AppSpacing.x3l),
                        itemCount:
                            _payments.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _payments.length) {
                            return const Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryMain),
                                ),
                              ),
                            );
                          }
                          return _PaymentCard(payment: _payments[i]);
                        },
                      ),
                    ),
    );
  }
}

// ── Payment card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  const _PaymentCard({required this.payment});

  Color get _statusColor {
    switch (payment.paymentStatus.toUpperCase()) {
      case 'PAID':
      case 'SUCCESS':
      case 'COMPLETED':
        return AppColors.primaryMain;
      case 'PENDING':
        return AppColors.amber600;
      case 'FAILED':
      case 'REFUNDED':
        return AppColors.red600;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _statusBg {
    switch (payment.paymentStatus.toUpperCase()) {
      case 'PAID':
      case 'SUCCESS':
      case 'COMPLETED':
        return AppColors.forest100;
      case 'PENDING':
        return AppColors.amber100;
      case 'FAILED':
      case 'REFUNDED':
        return AppColors.red100;
      default:
        return const Color(0xFFEEEEEE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dt = payment.createdAt != null
        ? DateTime.tryParse(payment.createdAt!)?.toLocal()
        : null;
    final dateStr =
        dt != null ? DateFormat('d MMM yyyy, h:mm a').format(dt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.payments_outlined,
                  color: _statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(payment.paymentCode,
                          style: AppTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusBg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        payment.paymentStatus.replaceAll('_', ' '),
                        style: AppTypography.caption.copyWith(
                            color: _statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(fmt.format(payment.amount),
                        style: AppTypography.body.copyWith(
                            color: AppColors.primaryMain,
                            fontWeight: FontWeight.w700)),
                    if (payment.orderNumber != null) ...[
                      const SizedBox(width: 8),
                      Text('· ${payment.orderNumber}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ]),
                  if (payment.paymentMethod?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      payment.paymentMethod!
                          .replaceAll('_', ' ')
                          .toLowerCase()
                          .split(' ')
                          .map((w) => w.isEmpty
                              ? w
                              : '${w[0].toUpperCase()}${w.substring(1)}')
                          .join(' '),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
