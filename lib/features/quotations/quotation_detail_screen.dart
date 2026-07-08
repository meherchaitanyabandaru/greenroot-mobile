import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../orders/orders.dart';
import 'quotations.dart';

// ── Nursery address fetch ──────────────────────────────────────────────────────

Future<String?> _fetchNurseryAddress(int nurseryId) async {
  try {
    final addresses = await ApiClient.instance.get<List<dynamic>>(
      ApiConstants.nurseryAddresses(nurseryId),
      fromJson: (data) =>
          (data as Map<String, dynamic>)['addresses'] as List<dynamic>,
    );
    if (addresses.isEmpty) return null;
    final raw = addresses.firstWhere(
          (a) => (a as Map<String, dynamic>)['is_primary'] == true,
          orElse: () => addresses.first,
        ) as Map<String, dynamic>;
    final parts = <String>[
      if (raw['address_line1'] != null) raw['address_line1'] as String,
      if (raw['address_line2'] != null) raw['address_line2'] as String,
      if (raw['city'] != null) raw['city'] as String,
      if (raw['state'] != null) raw['state'] as String,
      if (raw['country'] != null) raw['country'] as String,
      if (raw['postal_code'] != null) raw['postal_code'] as String,
    ];
    return parts.isNotEmpty ? parts.join(', ') : null;
  } catch (_) {
    return null;
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class QuotationDetailScreen extends ConsumerStatefulWidget {
  final int quotationId;
  const QuotationDetailScreen({super.key, required this.quotationId});

  @override
  ConsumerState<QuotationDetailScreen> createState() =>
      _QuotationDetailScreenState();
}

class _QuotationDetailScreenState
    extends ConsumerState<QuotationDetailScreen> {
  bool _deleting = false;
  bool _exporting = false;
  bool _buyerActing = false;
  bool _approving = false;
  bool _recalling = false;
  bool _converting = false;
  bool _assigning = false;

  Future<void> _buyerAccept(Quotation q) async {
    setState(() => _buyerActing = true);
    try {
      await ref.read(quotationRepositoryProvider).acceptQuotation(q.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation accepted'),
          backgroundColor: AppColors.primaryMain,
        ));
        context.pop(true);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _buyerActing = false);
    }
  }

  Future<void> _buyerReject(Quotation q) async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Quotation'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
            onChanged: (v) => reason = v,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Reject', style: TextStyle(color: AppColors.red600)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _buyerActing = true);
    try {
      await ref.read(quotationRepositoryProvider).rejectQuotation(q.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation rejected'),
          backgroundColor: AppColors.red600,
        ));
        context.pop(true);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _buyerActing = false);
    }
  }

  Future<void> _approve(Quotation q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to Customer'),
        content: Text('Send ${q.quotationCode} to the customer for review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain, foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _approving = true);
    try {
      await ref.read(quotationRepositoryProvider).approveQuotation(q.id);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation sent to customer'),
          backgroundColor: AppColors.primaryMain,
        ));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _recall(Quotation q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recall Quotation'),
        content: Text('Pull back ${q.quotationCode} to draft for editing?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber600, foregroundColor: Colors.white),
            child: const Text('Recall'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _recalling = true);
    try {
      await ref.read(quotationRepositoryProvider).recallQuotation(q.id);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation recalled to draft'),
          backgroundColor: AppColors.amber600,
        ));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _recalling = false);
    }
  }

  Future<void> _assignManager(Quotation q) async {
    if (q.nurseryId == null) return;
    final managerUserId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ManagerPickerSheet(nurseryId: q.nurseryId!),
    );
    if (managerUserId == null || !mounted) return;
    setState(() => _assigning = true);
    try {
      await ref.read(quotationRepositoryProvider).assignManager(q.id, managerUserId: managerUserId);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Manager assigned'),
          backgroundColor: AppColors.primaryMain,
        ));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _convertToOrder(Quotation q) async {
    final orderId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _OrderPickerSheet(quotation: q),
    );
    if (orderId == null || !mounted) return;
    setState(() => _converting = true);
    try {
      await ref.read(quotationRepositoryProvider).convertToOrder(q.id, orderId: orderId);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation converted to order'),
          backgroundColor: AppColors.primaryMain,
        ));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _confirmDelete(Quotation q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text(
            'Permanently delete ${q.quotationCode}?\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(quotationRepositoryProvider).deleteQuotation(q.id);
      if (mounted) context.pop(true);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  // Shared: build PDF bytes + filename
  Future<(List<int>, String)> _buildPdfBytes(Quotation q) async {
    String? nurseryAddress;
    if (q.nurseryId != null) {
      nurseryAddress = await _fetchNurseryAddress(q.nurseryId!);
    }
    final session = ref.read(sessionProvider);
    final downloadedBy =
        session.user?.name ?? session.user?.mobile ?? 'GreenRoot User';
    final doc = _buildProfessionalPdf(
      q: q,
      nurseryAddress: nurseryAddress,
      downloadedBy: downloadedBy,
    );
    return (await doc.save(), '${q.quotationCode}.pdf');
  }

  Future<void> _downloadPdf(Quotation q) async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _buildPdfBytes(q);
      if (kIsWeb) {
        final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
        await launchUrl(Uri.parse(dataUrl), mode: LaunchMode.externalApplication);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to Documents: $filename')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareViaWhatsApp(Quotation q) async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _buildPdfBytes(q);
      if (kIsWeb) {
        // Download PDF first, then open WhatsApp Web with pre-filled message
        final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
        await launchUrl(Uri.parse(dataUrl), mode: LaunchMode.externalApplication);
        final msg = Uri.encodeComponent(
          'Quotation ${q.quotationCode}'
          '${q.nurseryName != null ? " from ${q.nurseryName}" : ""}'
          ' — PDF downloaded to your device.',
        );
        await launchUrl(
          Uri.parse('https://wa.me/?text=$msg'),
          mode: LaunchMode.externalApplication,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text:
              'Quotation ${q.quotationCode}'
              '${q.nurseryName != null ? " from ${q.nurseryName}" : ""}',
          subject: q.quotationCode,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('WhatsApp share failed: $e'),
              backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _sharePdf(Quotation q) async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _buildPdfBytes(q);
      if (kIsWeb) {
        final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
        await launchUrl(Uri.parse(dataUrl), mode: LaunchMode.externalApplication);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: '${q.quotationCode} — GreenRoot Quotation',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Share failed: $e'),
              backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quotationDetailProvider(widget.quotationId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
            title: const Text('Quotation'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primaryMain)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
            title: const Text('Quotation'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Failed to load quotation',
                style: AppTypography.body.copyWith(color: AppColors.red600)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => ref.invalidate(quotationDetailProvider(widget.quotationId)),
                child: const Text('Retry')),
          ]),
        ),
      ),
      data: (q) => _buildScaffold(q),
    );
  }

  Widget _buildScaffold(Quotation q) {
    final caps = ref.watch(sessionProvider).capabilities;
    final isBuyerView = !caps.canSell;
    // Business rule: only the nursery owner may delete a quotation.
    final canDelete = caps.isNurseryOwner;
    final isManagerOnly = caps.isManager && !caps.isNurseryOwner;
    // Quotations are editable only while in a DRAFT status.
    final isEditable = q.status == 'INTERNAL_DRAFT' || q.status == 'CUSTOMER_DRAFT';
    final buyerCanAct = isBuyerView && q.status == 'CUSTOMER_SENT';
    final isBusy = _deleting || _exporting || _buyerActing || _approving || _recalling || _converting || _assigning;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(q.quotationCode,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMain)),
            )
          else if (!isBuyerView) ...[
            // Edit — only available in DRAFT statuses
            if (isEditable)
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () async {
                  final edited = await context.push<bool>(
                      '/quotations/${q.id}/edit',
                      extra: q);
                  if (edited == true && mounted) {
                    ref.invalidate(quotationDetailProvider(widget.quotationId));
                  }
                },
              ),
            // More options
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                if (v == 'pdf') await _downloadPdf(q);
                if (v == 'delete') await _confirmDelete(q);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'pdf', child: _MenuOption(icon: Icons.download_rounded, label: 'Download PDF')),
                if (canDelete) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: _MenuOption(icon: Icons.delete_outline, label: 'Delete', color: AppColors.red600),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Header: code + date + status
          _InfoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(q.quotationCode,
                        style: AppTypography.h3
                            .copyWith(color: AppColors.primaryMain))),
                _StatusBadge(status: q.status),
              ]),
              const SizedBox(height: 4),
              Text(_fmt(q.createdAt),
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Nursery
          _InfoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (q.createdByName != null) ...[
                Text(q.createdByName!,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              ],
              if (q.nurseryName != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.storefront_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(q.nurseryName!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ]),
              ],
              if (q.nurseryPhone != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(q.nurseryPhone!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ]),
              ],
              if (q.assignedManagerName != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.manage_accounts_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(q.assignedManagerName!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ]),
              ],
              if (q.validUntil != null && q.status == 'CUSTOMER_SENT') ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(
                    Icons.schedule,
                    size: 13,
                    color: q.isExpired ? AppColors.red600 : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${q.isExpired ? "Expired" : "Valid until"}: ${q.validUntil!.day} ${_monthAbbr(q.validUntil!.month)} ${q.validUntil!.year}',
                    style: AppTypography.caption.copyWith(
                      color: q.isExpired ? AppColors.red600 : AppColors.textMuted,
                      fontWeight: q.isExpired ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Recipient
          if (q.recipientName != null || q.recipientMobile != null || (isManagerOnly && !q.isInternal)) ...[
            _InfoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Bill To / Recipient'),
                    if (q.recipientName != null) ...[
                      const SizedBox(height: 4),
                      Text(q.recipientName!,
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                    if (q.recipientMobile != null) ...[
                      const SizedBox(height: 2),
                      Text(q.recipientMobile!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ],
                    if (isManagerOnly && q.recipientName == null && q.recipientMobile == null && !q.isInternal) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text('Customer details are not visible to managers',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                      ]),
                    ],
                  ]),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Items table
          _InfoCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Table header
              Container(
                color: AppColors.forest100,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: [
                  Expanded(flex: 5,
                      child: Text('Plant / Item',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain))),
                  SizedBox(
                      width: 40,
                      child: Text('Qty',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain),
                          textAlign: TextAlign.right)),
                  SizedBox(
                      width: 68,
                      child: Text('Unit ₹',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain),
                          textAlign: TextAlign.right)),
                  SizedBox(
                      width: 70,
                      child: Text('Total ₹',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain),
                          textAlign: TextAlign.right)),
                ]),
              ),
              // Item rows
              ...q.items.asMap().entries.map((e) {
                final item = e.value;
                final even = e.key % 2 == 0;
                return Container(
                  color: even ? Colors.white : AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.scientificName,
                                    style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600)),
                                if (item.commonName != null)
                                  Text(item.commonName!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted)),
                                if (item.description != null)
                                  Text(item.description!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted,
                                          fontStyle: FontStyle.italic)),
                              ]),
                        ),
                        SizedBox(
                            width: 40,
                            child: Text(_qty(item.quantity),
                                style: AppTypography.bodySmall,
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 68,
                            child: Text('₹${item.unitPrice.toStringAsFixed(2)}',
                                style: AppTypography.bodySmall,
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 70,
                            child: Text('₹${item.totalPrice.toStringAsFixed(2)}',
                                style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryMain),
                                textAlign: TextAlign.right)),
                      ]),
                );
              }),
              // Grand total
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius:
                      BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Expanded(
                      flex: 5,
                      child: Text('Grand Total',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryMain))),
                  SizedBox(width: 40 + 68),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '₹${q.totalAmount.toStringAsFixed(2)}',
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryMain),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Notes
          if (q.notes != null) ...[
            _InfoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Notes'),
                    const SizedBox(height: 6),
                    Text(q.notes!, style: AppTypography.body),
                  ]),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // ── Buyer actions ───────────────────────────────────────────────
          if (buyerCanAct) ...[
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _buyerActing ? null : () => _buyerReject(q),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red600,
                    side: const BorderSide(color: AppColors.red600),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _buyerActing ? null : () => _buyerAccept(q),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ]

          // ── Seller status-based actions ─────────────────────────────────
          else if (!isBuyerView) ...[
            if (q.status == 'CUSTOMER_DRAFT') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _approving ? null : () => _approve(q),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send to Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (q.status == 'CUSTOMER_SENT') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _recalling ? null : () => _recall(q),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Recall to Draft'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber600,
                    side: const BorderSide(color: AppColors.amber600),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (q.status == 'CUSTOMER_ACCEPTED') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _converting ? null : () => _convertToOrder(q),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Convert to Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Owner-only: assign or reassign manager on any non-terminal quotation
            if (canDelete &&
                !['CONVERTED', 'CUSTOMER_REJECTED'].contains(q.status) &&
                q.nurseryId != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _assigning ? null : () => _assignManager(q),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(q.assignedManagerUserId != null
                      ? 'Reassign Manager'
                      : 'Assign Manager'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMain,
                    side: const BorderSide(color: AppColors.primaryMain),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          // ── PDF share row — always visible ──────────────────────────────
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : () => _downloadPdf(q),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  fixedSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: ElevatedButton(
                onPressed: _exporting ? null : () => _shareViaWhatsApp(q),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                child: SvgPicture.asset(
                  'assets/icons/whatsapp.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                onPressed: _exporting ? null : () => _sharePdf(q),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                child: const Icon(Icons.ios_share_rounded, size: 22),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }
}

// ── Professional PDF builder ──────────────────────────────────────────────────

pw.Document _buildProfessionalPdf({
  required Quotation q,
  required String? nurseryAddress,
  required String downloadedBy,
}) {
  // Enterprise design tokens
  const green = PdfColor.fromInt(0xFF166534);
  const darkSlate = PdfColor.fromInt(0xFF1F2937);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const lightGray = PdfColor.fromInt(0xFFF8FAFC);
  const borderGray = PdfColor.fromInt(0xFFE5E7EB);
  const amber = PdfColor.fromInt(0xFFD97706);
  const amberLight = PdfColor.fromInt(0xFFFEF3C7);

  pw.TextStyle _body({bool bold = false, PdfColor color = darkSlate, double size = 10}) =>
      pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontSize: size,
        color: color,
      );

  pw.TextStyle _cap({bool bold = false, PdfColor color = muted}) =>
      _body(bold: bold, color: color, size: 8);

  final createdDt = DateTime.tryParse(q.createdAt)?.toLocal() ?? DateTime.now();
  final validUntil = q.validUntil ?? createdDt.add(const Duration(days: 15));
  final validUntilStr = '${validUntil.day} ${_monthAbbr(validUntil.month)} ${validUntil.year}';

  final doc = pw.Document(
    title: q.quotationCode,
    author: q.nurseryName ?? 'GreenRoot',
    creator: 'GreenRoot Platform',
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 36),
    header: (context) => _pdfHeader(
      q, nurseryAddress, _body, _cap,
      validUntilStr: validUntilStr,
    ),
    footer: (context) => _pdfFooter(
      context, muted, borderGray, green, _cap,
    ),
    build: (context) => [
      pw.SizedBox(height: 16),

      // ── Internal notice ──────────────────────────────────────────────────
      if (q.isInternal) ...[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF0FFF4),
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFBBF7D0), width: 0.5),
          ),
          child: pw.Text(
            'INTERNAL PLANNING DOCUMENT  ·  Not intended for external distribution.',
            style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: green),
          ),
        ),
        pw.SizedBox(height: 12),
      ],

      // ── FROM / TO ────────────────────────────────────────────────────────
      if (q.isInternal)
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: lightGray,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: borderGray, width: 0.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('NURSERY', style: _cap(bold: true, color: green)),
                    pw.SizedBox(height: 6),
                    if (q.nurseryName != null)
                      pw.Text(q.nurseryName!,
                          style: _body(bold: true, size: 11, color: darkSlate)),
                    if (nurseryAddress != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(nurseryAddress, style: _body(size: 8.5, color: muted)),
                    ],
                    if (q.nurseryPhone != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(q.nurseryPhone!, style: _body(size: 8.5, color: muted)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('PREPARED BY',
                      style: pw.TextStyle(fontSize: 6.5, color: muted)),
                  pw.SizedBox(height: 4),
                  pw.Text(q.createdByName ?? '—',
                      style: _body(size: 9, color: darkSlate)),
                ],
              ),
            ],
          ),
        )
      else
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: lightGray,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderGray, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FROM', style: _cap(bold: true, color: green)),
                    pw.SizedBox(height: 6),
                    if (q.nurseryName != null)
                      pw.Text(q.nurseryName!,
                          style: _body(bold: true, size: 11, color: darkSlate)),
                    if (nurseryAddress != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(nurseryAddress, style: _body(size: 8.5, color: muted)),
                    ],
                    if (q.nurseryPhone != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(q.nurseryPhone!, style: _body(size: 8.5, color: muted)),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Text('PREPARED BY',
                        style: pw.TextStyle(fontSize: 6.5, color: muted)),
                    pw.SizedBox(height: 2),
                    pw.Text(q.createdByName ?? '—',
                        style: _body(size: 8.5, color: darkSlate)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: lightGray,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderGray, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TO', style: _cap(bold: true, color: muted)),
                    pw.SizedBox(height: 6),
                    if (q.recipientName != null)
                      pw.Text(q.recipientName!,
                          style: _body(bold: true, size: 11, color: darkSlate)),
                    if (q.recipientMobile != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(q.recipientMobile!, style: _body(size: 8.5, color: muted)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

      pw.SizedBox(height: 18),

      // ── Items table ──────────────────────────────────────────────────────
      pw.Container(
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: borderGray, width: 0.5),
        ),
        child: pw.Column(children: [
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: green,
              borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(4),
                  topRight: pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 22,
                  child: pw.Text('#',
                      style: _cap(bold: true, color: PdfColors.white))),
              pw.Expanded(
                  flex: 4,
                  child: pw.Text('PLANT / ITEM',
                      style: _cap(bold: true, color: PdfColors.white))),
              pw.SizedBox(
                  width: 72,
                  child: pw.Text('SIZE',
                      style: _cap(bold: true, color: PdfColors.white))),
              pw.SizedBox(
                  width: 36,
                  child: pw.Text('QTY',
                      style: _cap(bold: true, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
              pw.SizedBox(
                  width: 70,
                  child: pw.Text('UNIT PRICE',
                      style: _cap(bold: true, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
              pw.SizedBox(
                  width: 70,
                  child: pw.Text('AMOUNT',
                      style: _cap(bold: true, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
            ]),
          ),
          ...q.items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return pw.Container(
              color: i.isEven ? PdfColors.white : lightGray,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                      width: 22, child: pw.Text('${i + 1}', style: _cap())),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.scientificName,
                              style: _body(bold: true, size: 9.5, color: darkSlate)),
                          if (item.commonName != null)
                            pw.Text(item.commonName!, style: _cap()),
                        ]),
                  ),
                  pw.SizedBox(
                      width: 72,
                      child: pw.Text(item.description ?? '—', style: _cap())),
                  pw.SizedBox(
                      width: 36,
                      child: pw.Text(
                          item.quantity % 1 == 0
                              ? item.quantity.toInt().toString()
                              : item.quantity.toString(),
                          style: _body(size: 9.5),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 70,
                      child: pw.Text('Rs. ${item.unitPrice.toStringAsFixed(2)}',
                          style: _body(size: 9.5),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 70,
                      child: pw.Text('Rs. ${item.totalPrice.toStringAsFixed(2)}',
                          style: _body(bold: true, size: 9.5, color: darkSlate),
                          textAlign: pw.TextAlign.right)),
                ],
              ),
            );
          }),
          // Grand total — clean, spacious
          pw.Divider(color: borderGray, thickness: 0.5, height: 0),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 16, 10, 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GRAND TOTAL',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: green,
                        letterSpacing: 0.5)),
                pw.Text('Rs. ${q.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: darkSlate)),
              ],
            ),
          ),
        ]),
      ),

      // ── Notes ────────────────────────────────────────────────────────────
      if (q.notes != null) ...[
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: lightGray,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: borderGray, width: 0.5),
          ),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('NOTES', style: _cap(bold: true)),
                pw.SizedBox(height: 4),
                pw.Text(q.notes!, style: _body(size: 9.5)),
              ]),
        ),
      ],

      // ── Disclaimer ───────────────────────────────────────────────────────
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: amberLight,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: amber, width: 0.5),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('!  ', style: _body(bold: true, color: amber, size: 8)),
            pw.Expanded(
                child: pw.Text(
              'Prices subject to availability. '
              'All prices are provided by the issuing nursery.',
              style: _body(size: 7.5, color: amber),
            )),
          ],
        ),
      ),

      // ── Verification ─────────────────────────────────────────────────────
      pw.SizedBox(height: 20),
      _pdfSignatureBlock(q, darkSlate, green, muted, borderGray, lightGray, _body, _cap),
    ],
  ));

  return doc;
}

String _monthAbbr(int m) => const [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][m];

pw.Widget _pdfHeader(
  Quotation q,
  String? nurseryAddress,
  pw.TextStyle Function({bool bold, PdfColor color, double size}) body,
  pw.TextStyle Function({bool bold, PdfColor color}) cap, {
  required String validUntilStr,
}) {
  const darkSlate = PdfColor.fromInt(0xFF1F2937);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const borderGray = PdfColor.fromInt(0xFFE5E7EB);
  const green = PdfColor.fromInt(0xFF166534);

  final typeLabel = q.isInternal ? 'INTERNAL QUOTATION' : 'QUOTATION';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Thin forest-green accent bar
      pw.Container(height: 3, color: green),
      pw.SizedBox(height: 16),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left — nursery is the primary entity
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  q.nurseryName ?? 'Nursery',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: darkSlate),
                ),
                if (q.nurseryPhone != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(q.nurseryPhone!, style: body(color: muted, size: 8.5)),
                ],
                if (nurseryAddress != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(nurseryAddress, style: body(color: muted, size: 7.5)),
                ],
                pw.SizedBox(height: 9),
                // Quotation type — outlined badge, secondary
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: green, width: 0.75),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(typeLabel,
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: green)),
                ),
              ],
            ),
          ),
          // Right — quotation metadata
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('QUOTATION',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: muted,
                      letterSpacing: 1.2)),
              pw.SizedBox(height: 4),
              pw.Text(q.quotationCode,
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: darkSlate)),
              pw.SizedBox(height: 10),
              _headerMeta('Date', _fmt(q.createdAt),
                  labelColor: muted, valueColor: darkSlate),
              pw.SizedBox(height: 3),
              _headerMeta('Valid Until', validUntilStr,
                  labelColor: muted, valueColor: darkSlate),
              if (q.createdByName != null) ...[
                pw.SizedBox(height: 3),
                _headerMeta('Prepared By', q.createdByName!,
                    labelColor: muted, valueColor: darkSlate),
              ],
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Divider(color: borderGray, thickness: 0.5),
    ],
  );
}

pw.Widget _headerMeta(
  String label,
  String value, {
  required PdfColor labelColor,
  required PdfColor valueColor,
}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text('$label  ',
          style: pw.TextStyle(fontSize: 8, color: labelColor)),
      pw.Text(value,
          style: pw.TextStyle(
              fontSize: 8,
              color: valueColor,
              fontWeight: pw.FontWeight.bold)),
    ],
  );
}

pw.Widget _pdfFooter(
  pw.Context context,
  PdfColor muted,
  PdfColor borderGray,
  PdfColor green,
  pw.TextStyle Function({bool bold, PdfColor color}) cap,
) {
  return pw.Column(children: [
    pw.Divider(color: borderGray, thickness: 0.5),
    pw.SizedBox(height: 5),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Powered by GreenRoot  ·  www.greenroot.app',
            style: cap(color: muted)),
        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: cap(color: muted)),
      ],
    ),
    pw.SizedBox(height: 4),
    pw.Text(
      'GreenRoot provides quotation management software only. '
      'All quotation information is provided by the issuing nursery.',
      style: pw.TextStyle(fontSize: 6, color: muted),
      textAlign: pw.TextAlign.center,
    ),
  ]);
}

pw.Widget _pdfSignatureBlock(
  Quotation q,
  PdfColor darkSlate,
  PdfColor green,
  PdfColor muted,
  PdfColor borderGray,
  PdfColor lightGray,
  pw.TextStyle Function({bool bold, PdfColor color, double size}) body,
  pw.TextStyle Function({bool bold, PdfColor color}) cap,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: lightGray,
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: borderGray, width: 0.5),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: q.quotationCode,
          width: 48,
          height: 48,
          color: darkSlate,
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('DOCUMENT VERIFICATION',
                  style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: muted,
                      letterSpacing: 0.8)),
              pw.SizedBox(height: 4),
              pw.Text('Quote ID: ${q.quotationCode}',
                  style: body(bold: true, size: 8.5, color: darkSlate)),
              pw.SizedBox(height: 2),
              pw.Text('Generated on: ${_fmt(q.createdAt)}', style: cap()),
              pw.SizedBox(height: 3),
              pw.Text(
                'Digitally generated  ·  No physical signature required.',
                style: pw.TextStyle(fontSize: 7, color: muted),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('PREPARED BY',
                style: pw.TextStyle(fontSize: 6.5, color: muted)),
            pw.SizedBox(height: 3),
            pw.Text(q.createdByName ?? '—',
                style: body(size: 8.5, color: darkSlate)),
          ],
        ),
      ],
    ),
  );
}

// ── Manager picker bottom sheet ───────────────────────────────────────────────

class _ManagerPickerSheet extends StatefulWidget {
  final int nurseryId;
  const _ManagerPickerSheet({required this.nurseryId});

  @override
  State<_ManagerPickerSheet> createState() => _ManagerPickerSheetState();
}

class _ManagerPickerSheetState extends State<_ManagerPickerSheet> {
  List<NurseryManager>? _managers;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final managers = await ApiClient.instance.get<List<NurseryManager>>(
        ApiConstants.nurseryManagers(widget.nurseryId),
        fromJson: (json) {
          final map = json as Map<String, dynamic>;
          final list = map['managers'] as List<dynamic>? ??
              map['users'] as List<dynamic>? ??
              [];
          return list
              .cast<Map<String, dynamic>>()
              .map(NurseryManager.fromJson)
              .toList();
        },
      );
      if (mounted) setState(() { _managers = managers; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 8),
            child: Row(children: [
              Expanded(child: Text('Assign Manager', style: AppTypography.h3)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMain))
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Failed to load managers',
                            style: AppTypography.body.copyWith(color: AppColors.red600)),
                        TextButton(onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
                            child: const Text('Retry')),
                      ]))
                    : _managers == null || _managers!.isEmpty
                        ? Center(child: Text('No managers in this nursery',
                              style: AppTypography.body.copyWith(color: AppColors.textMuted)))
                        : ListView.separated(
                            controller: ctrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
                            itemCount: _managers!.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (_, i) {
                              final m = _managers![i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.forest100,
                                  child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                                      style: AppTypography.body.copyWith(
                                          color: AppColors.primaryMain, fontWeight: FontWeight.w700)),
                                ),
                                title: Text(m.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(m.mobile, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                                onTap: () => Navigator.pop(context, m.userId),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Order picker bottom sheet ──────────────────────────────────────────────────

class _OrderPickerSheet extends StatefulWidget {
  final Quotation quotation;
  const _OrderPickerSheet({required this.quotation});

  @override
  State<_OrderPickerSheet> createState() => _OrderPickerSheetState();
}

class _OrderPickerSheetState extends State<_OrderPickerSheet> {
  List<Order>? _orders;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static const _linkableStatuses = {'PENDING', 'CONFIRMED', 'LOADING'};

  Future<void> _load() async {
    try {
      final repo = OrderRepository(ApiClient.instance);
      final (orders, _) = await repo.listOrders(
        nurseryId: widget.quotation.nurseryId,
        perPage: 100,
      );
      if (mounted) {
        setState(() {
          _orders = orders
              .where((o) => _linkableStatuses.contains(o.status))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 8),
            child: Row(children: [
              Expanded(child: Text('Select Order to Link', style: AppTypography.h3)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryMain))
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Failed to load orders',
                            style: AppTypography.body.copyWith(color: AppColors.red600)),
                        TextButton(onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
                            child: const Text('Retry')),
                      ]))
                    : _orders == null || _orders!.isEmpty
                        ? Center(child: Text('No active orders to link (need PENDING, CONFIRMED or LOADING)',
                              style: AppTypography.body.copyWith(color: AppColors.textMuted)))
                        : ListView.separated(
                            controller: ctrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
                            itemCount: _orders!.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (_, i) {
                              final o = _orders![i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                title: Text(o.orderNumber, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${o.status}  ·  ₹${o.totalAmount.toStringAsFixed(0)}',
                                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                ),
                                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                                onTap: () => Navigator.pop(context, o.id),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _InfoCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label = status;
    switch (status) {
      case 'INTERNAL_DRAFT':
        bg = AppColors.border;
        fg = AppColors.textSecondary;
        label = 'Internal';
        break;
      case 'CUSTOMER_DRAFT':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        label = 'Draft';
        break;
      case 'CUSTOMER_SENT':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        label = 'Sent to Customer';
        break;
      case 'CUSTOMER_ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Customer Accepted';
        break;
      case 'CUSTOMER_REJECTED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        label = 'Customer Rejected';
        break;
      case 'CONVERTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Converted to Order';
        break;
      // Legacy
      case 'DRAFT':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        label = 'Draft';
        break;
      case 'SENT':
      case 'APPROVED':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        label = 'Sent';
        break;
      case 'BUYER_ACCEPTED':
      case 'ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Accepted';
        break;
      default:
        bg = AppColors.red100;
        fg = AppColors.red600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: AppTypography.caption
              .copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuOption({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Row(children: [
      Icon(icon, size: 18, color: c),
      const SizedBox(width: 10),
      Text(label, style: AppTypography.body.copyWith(color: c)),
    ]);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmt(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('d MMM yyyy, HH:mm').format(dt);
  } catch (_) {
    return iso;
  }
}

String _qty(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
