import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/services/recent_items.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/nursery_branding_badge.dart';
import '../../core/widgets/order_timeline.dart' show QuotationTimeline;
import '../auth/presentation/providers/session_provider.dart';
import '../orders/orders.dart';
import '../profile/my_addresses_screen.dart';
import 'accept_confirm.dart';
import 'quotations.dart';
import '../../core/utilities/money.dart';
import '../../core/feedback/app_haptics.dart';
import '../../core/widgets/app_loader.dart';

part 'quotation_detail_widgets.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

class QuotationDetailScreen extends ConsumerStatefulWidget {
  final int quotationId;
  const QuotationDetailScreen({super.key, required this.quotationId});

  @override
  ConsumerState<QuotationDetailScreen> createState() =>
      _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends ConsumerState<QuotationDetailScreen> {
  int? _recordedRecentId;
  bool _deleting = false;
  bool _exporting = false;
  bool _buyerActing = false;
  bool _approving = false;
  bool _recalling = false;
  bool _converting = false;
  bool _assigning = false;

  Future<bool> _ensureDeliveryAddress() async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return false;
    final List<UserAddress> addresses;
    try {
      addresses =
          await ref.read(userAddressRepositoryProvider).listAddresses(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not check delivery addresses: $e'),
            backgroundColor: AppColors.red600,
          ),
        );
      }
      return false;
    }
    if (addresses.isNotEmpty) return true;
    if (!mounted) return false;
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delivery address required'),
        content: const Text(
          'Add a delivery address before accepting this quotation. The nursery needs it before confirming your order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Address'),
          ),
        ],
      ),
    );
    if (add == true && mounted) {
      await context.push('/my-addresses');
    }
    return false;
  }

  Future<void> _buyerAccept(Quotation q) async {
    if (!await confirmAcceptQuotation(context, q) || !mounted) return;
    final hasDeliveryAddress = await _ensureDeliveryAddress();
    if (!hasDeliveryAddress || !mounted) return;
    setState(() => _buyerActing = true);
    try {
      await ref.read(quotationRepositoryProvider).acceptQuotation(q.id);
      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation accepted'),
          backgroundColor: AppColors.primaryMain,
        ),);
        context.pop(true);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
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
                child: const Text('Cancel'),),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject', style: TextStyle(color: AppColors.red600)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _buyerActing = true);
    try {
      await ref
          .read(quotationRepositoryProvider)
          .rejectQuotation(q.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation rejected'),
          backgroundColor: AppColors.red600,
        ),);
        context.pop(true);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _approving = true);
    try {
      await ref.read(quotationRepositoryProvider).sendToCustomer(q.id);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation sent to customer'),
          backgroundColor: AppColors.primaryMain,
        ),);
        context.pop(true);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber600,
                foregroundColor: Colors.white,),
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
        ),);
        context.pop(true);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
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
      await ref
          .read(quotationRepositoryProvider)
          .assignManager(q.id, managerUserId: managerUserId);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ref.read(quotationListProvider.notifier).load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Manager assigned'),
          backgroundColor: AppColors.primaryMain,
        ),);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _unassignManager(Quotation q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text(
            'Remove ${q.assignedManagerName ?? "this manager"} from ${q.quotationCode}? They will no longer see this quotation.',),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _assigning = true);
    try {
      await ref.read(quotationRepositoryProvider).unassignManager(q.id);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ref.read(quotationListProvider.notifier).load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Manager removed'),
          backgroundColor: AppColors.primaryMain,
        ),);
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _convertToOrder(Quotation q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Convert to Order', style: AppTypography.h3),
        content: Text(
          'Create a new order from ${q.quotationCode}?\nThe order will be created in PENDING status.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),),
            ),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _converting = true);
    try {
      final updated =
          await ref.read(quotationRepositoryProvider).convertToOrder(q.id);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ref.read(quotationListProvider.notifier).load();
        ref.read(orderListProvider.notifier).load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order created successfully'),
          backgroundColor: AppColors.primaryMain,
        ),);
        if (updated.convertedOrderId != null) {
          context.push('/orders/${updated.convertedOrderId}');
        }
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
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
            'Permanently delete ${q.quotationCode}?\nThis action cannot be undone.',),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red600)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.red600,),);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<(List<int>, String)> _downloadPdfFromApi(Quotation q) async {
    final response = await ApiClient.instance.dio.get<List<int>>(
      ApiConstants.quotationRenderedDocument(q.id),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    final bytes = List<int>.from(response.data ?? const <int>[]);
    final filename = _filenameFromDisposition(
          response.headers.value('content-disposition'),
        ) ??
        '${q.quotationCode}.pdf';
    return (bytes, filename);
  }

  Future<void> _downloadPdf(Quotation q) async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _downloadPdfFromApi(q);
      if (kIsWeb) {
        await _openWebPdf(bytes);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        // App documents dir is private on Android; hand the file to the OS so
        // the user can open/save the copy just rendered for their role.
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: q.quotationCode,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: AppColors.red600,),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareViaWhatsApp(Quotation q) async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _downloadPdfFromApi(q);
      if (kIsWeb) {
        await _openWebPdf(bytes);
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
          text: 'Quotation ${q.quotationCode}'
              '${q.nurseryName != null ? " from ${q.nurseryName}" : ""}',
          subject: q.quotationCode,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('WhatsApp share failed: $e'),
              backgroundColor: AppColors.red600,),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _sharePdf(Quotation q) async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _downloadPdfFromApi(q);
      if (kIsWeb) {
        await _openWebPdf(bytes);
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
              backgroundColor: AppColors.red600,),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openWebPdf(List<int> bytes) async {
    final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
    await launchUrl(Uri.parse(dataUrl), mode: LaunchMode.externalApplication);
  }

  String? _filenameFromDisposition(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return match?.group(1);
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
            elevation: 0,),
        body: const Center(
            child: AppLoader(),),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
            title: const Text('Quotation'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Failed to load quotation',
                style: AppTypography.body.copyWith(color: AppColors.red600),),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () =>
                    ref.invalidate(quotationDetailProvider(widget.quotationId)),
                child: const Text('Retry'),),
          ],),
        ),
      ),
      data: (q) => _buildScaffold(q),
    );
  }

  Future<void> _callPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    await launchUrl(Uri.parse('tel:$digits'));
  }

  Widget _buildScaffold(Quotation q) {
    if (_recordedRecentId != q.id) {
      _recordedRecentId = q.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(recentItemsProvider.notifier).record(RecentItem(
              type: RecentItemType.quotation,
              id: q.id,
              title: q.quotationCode,
              subtitle: q.recipientName ?? q.nurseryName ?? '',
              viewedAt: DateTime.now(),
            ),);
      });
    }
    final caps = ref.watch(sessionProvider).capabilities;
    // Seller view only for this quotation's own nursery; an owner/manager
    // who received a quotation from another nursery is the customer here.
    final isBuyerView = !caps.sellsFor(q.nurseryId);
    final backendCaps = q.capabilities;
    // Backend capabilities are preferred; local rules remain as fallback for
    // older API responses.
    final canDelete = !isBuyerView &&
        (backendCaps?.canDelete ?? caps.ownedNurseryId == q.nurseryId);
    final isManagerOnly =
        !isBuyerView && caps.isManager && !caps.isNurseryOwner;
    // Quotations are editable only while in a DRAFT status.
    final isEditable =
        q.status == 'INTERNAL_DRAFT' || q.status == 'CUSTOMER_DRAFT';
    // Exclusive-editor rule: when assigned, only the assignee may edit content.
    // Owner can edit only if unassigned or assigned to themselves.
    final myUserId = ref.watch(sessionProvider).user?.id;
    final canEditContent = backendCaps?.canEdit ??
        (isEditable &&
            !isBuyerView &&
            (q.assignedManagerUserId == null ||
                q.assignedManagerUserId == myUserId));
    final buyerCanAct = (backendCaps?.canAccept ?? false) ||
        (backendCaps?.canReject ?? false) ||
        (backendCaps == null && isBuyerView && q.status == 'CUSTOMER_SENT');
    final isBusy = _deleting ||
        _exporting ||
        _buyerActing ||
        _approving ||
        _recalling ||
        _converting ||
        _assigning;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(q.quotationCode,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),),
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
                      strokeWidth: 2, color: AppColors.primaryMain,),),
            )
          else if (!isBuyerView) ...[
            // Edit — only when this actor may edit; the locked case is
            // explained by the banner in the body, not a dead icon.
            if (isEditable && canEditContent)
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () async {
                  final edited = await context
                      .push<bool>('/quotations/${q.id}/edit', extra: q);
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
                const PopupMenuItem(
                    value: 'pdf',
                    child: _MenuOption(
                        icon: Icons.download_rounded, label: 'Download PDF',),),
                if (canDelete) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: _MenuOption(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: AppColors.red600,),
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Wraps: on a narrow phone or large text the badge goes below
              // the code instead of squeezing it.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(q.quotationCode,
                      style: AppTypography.h3
                          .copyWith(color: AppColors.primaryMain),),
                  _StatusBadge(status: q.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(_fmt(q.createdAt),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),),
              if (q.sentAt != null) ...[
                const SizedBox(height: 3),
                Text('Sent ${_fmtDate(q.sentAt!)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),),
              ],
              if (q.customerRespondedAt != null) ...[
                const SizedBox(height: 3),
                Text('Customer responded ${_fmtDate(q.customerRespondedAt!)}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),),
              ],
            ],),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Timeline: same "what stage is this at, what's next" treatment
          // as the order detail screen's OrderTimeline.
          _InfoCard(child: QuotationTimeline(quotation: q)),
          const SizedBox(height: AppSpacing.sm),

          // Nursery
          _InfoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (q.nurseryName != null || q.createdByName != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    NurseryBrandingBadge(
                      brandColor: q.nurseryBrandColor,
                      nurseryName: q.nurseryName ?? q.createdByName ?? 'N',
                      size: 40,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (q.nurseryName != null)
                            Text(q.nurseryName!,
                                style: AppTypography.body
                                    .copyWith(fontWeight: FontWeight.w600),),
                          if (q.createdByName != null)
                            Text(q.createdByName!,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary),),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (q.nurseryPhone != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.textMuted,),
                  const SizedBox(width: 4),
                  Text(q.nurseryPhone!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textMuted),),
                ],),
              ],
              // Assignment display is shown as its own card below (owners) or origin label (managers)

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
                      color:
                          q.isExpired ? AppColors.red600 : AppColors.textMuted,
                      fontWeight:
                          q.isExpired ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],),
              ],
            ],),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Converted-to-order banner
          if (q.status == 'CONVERTED' && q.convertedOrderId != null) ...[
            _InfoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lock_rounded,
                          size: 15, color: AppColors.primaryMain,),
                      const SizedBox(width: 6),
                      Text('Converted to Order',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primaryMain,
                              fontWeight: FontWeight.w700,),),
                    ],),
                    const SizedBox(height: 8),
                    if (q.convertedOrderCode != null)
                      GestureDetector(
                        onTap: () =>
                            context.push('/orders/${q.convertedOrderId}'),
                        child: Row(children: [
                          const Icon(Icons.receipt_long_rounded,
                              size: 14, color: AppColors.textSecondary,),
                          const SizedBox(width: 6),
                          Text('Order: ',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary),),
                          Text(q.convertedOrderCode!,
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.primaryMain,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,),),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 10, color: AppColors.primaryMain,),
                        ],),
                      ),
                    if (q.convertedAt != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.schedule_rounded,
                            size: 14, color: AppColors.textMuted,),
                        const SizedBox(width: 6),
                        Text(
                          'Converted on ${_fmtDate(q.convertedAt!)}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],),
                    ],
                  ],),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Assignment card — owner sees full control; manager sees origin label
          if (q.nurseryId != null && !['CONVERTED'].contains(q.status)) ...[
            if (canDelete) ...[
              _InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Assignment'),
                    const SizedBox(height: 8),
                    if (q.assignedManagerUserId == null) ...[
                      Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.amber600,),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unassigned',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.amber600,
                                      fontWeight: FontWeight.w700,),),
                              Text('No manager is handling this quotation',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textMuted),),
                            ],
                          ),
                        ),
                      ],),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _assigning ? null : () => _assignManager(q),
                          icon: const Icon(Icons.person_add_outlined, size: 16),
                          label: const Text('Assign to Manager'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryMain,
                            side:
                                const BorderSide(color: AppColors.primaryMain),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.teal100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 16, color: AppColors.teal700,),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.assignedManagerName ?? 'Manager',
                                  style: AppTypography.bodySmall
                                      .copyWith(fontWeight: FontWeight.w600),),
                              Text('Assigned manager',
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textMuted),),
                            ],
                          ),
                        ),
                      ],),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _assigning ? null : () => _assignManager(q),
                            icon:
                                const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: const Text('Reassign'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryMain,
                              side: const BorderSide(
                                  color: AppColors.primaryMain,),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _assigning ? null : () => _unassignManager(q),
                            icon: const Icon(Icons.person_remove_outlined,
                                size: 16,),
                            label: const Text('Unassign'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red600,
                              side: const BorderSide(color: AppColors.red600),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),),
                            ),
                          ),
                        ),
                      ],),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else if (isManagerOnly) ...[
              // Manager: show origin label only — no controls
              _InfoCard(
                child: Row(children: [
                  Icon(
                    q.assignedManagerUserId != null
                        ? Icons.person_outline_rounded
                        : Icons.edit_note_outlined,
                    size: 16,
                    color: AppColors.teal700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.assignedManagerUserId != null
                              ? (q.createdByName ?? 'Owner')
                              : 'Created by you',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.teal700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (q.assignedManagerUserId != null &&
                            q.nurseryPhone != null)
                          Text(
                            q.nurseryPhone!,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  if (q.assignedManagerUserId != null && q.nurseryPhone != null)
                    IconButton(
                      tooltip: 'Call owner',
                      icon: const Icon(Icons.call_outlined,
                          size: 18, color: AppColors.primaryMain,),
                      onPressed: () => _callPhone(q.nurseryPhone!),
                    ),
                ],),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],

          // Recipient
          if (q.recipientName != null ||
              q.recipientMobile != null ||
              (isManagerOnly && !q.isInternal)) ...[
            _InfoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Bill To / Recipient'),
                    if (q.recipientName != null) ...[
                      const SizedBox(height: 4),
                      Text(q.recipientName!,
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600),),
                    ],
                    if (q.recipientMobile != null) ...[
                      const SizedBox(height: 2),
                      Text(q.recipientMobile!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textMuted),),
                    ],
                    if (isManagerOnly &&
                        q.recipientName == null &&
                        q.recipientMobile == null &&
                        !q.isInternal) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.lock_outline,
                            size: 14, color: AppColors.textMuted,),
                        const SizedBox(width: 6),
                        Text('Customer details are not visible to managers',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMuted),),
                      ],),
                    ],
                  ],),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Items table
          _InfoCard(
            padding: EdgeInsets.zero,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Table header
              Container(
                color: AppColors.forest100,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: [
                  Expanded(
                      flex: 5,
                      child: Text('Plant / Item',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain,),),),
                  SizedBox(
                      width: 40,
                      child: Text('Qty',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain,),
                          textAlign: TextAlign.right,),),
                  SizedBox(
                      width: 68,
                      child: Text('Unit ₹',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain,),
                          textAlign: TextAlign.right,),),
                  SizedBox(
                      width: 70,
                      child: Text('Total ₹',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain,),
                          textAlign: TextAlign.right,),),
                ],),
              ),
              // Item rows
              ...q.items.asMap().entries.map((e) {
                final item = e.value;
                final even = e.key % 2 == 0;
                return Container(
                  color: even ? Colors.white : AppColors.background,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.scientificName,
                                    style: AppTypography.bodySmall
                                        .copyWith(fontWeight: FontWeight.w600),),
                                if (item.commonName != null)
                                  Text(item.commonName!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted,),),
                                if (item.description != null)
                                  Text(item.description!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted,
                                          fontStyle: FontStyle.italic,),),
                              ],),
                        ),
                        SizedBox(
                            width: 40,
                            child: Text(_qty(item.quantity),
                                style: AppTypography.bodySmall,
                                textAlign: TextAlign.right,),),
                        SizedBox(
                            width: 68,
                            child: Text(inr(item.unitPrice),
                                style: AppTypography.bodySmall,
                                textAlign: TextAlign.right,),),
                        SizedBox(
                            width: 70,
                            child: Text(
                                inr(item.totalPrice),
                                style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryMain,),
                                textAlign: TextAlign.right,),),
                      ],),
                );
              }),
              // Grand total
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Expanded(
                      flex: 5,
                      child: Text('Grand Total',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryMain,),),),
                  const SizedBox(width: 40 + 68),
                  SizedBox(
                    width: 70,
                    child: Text(
                      inr(q.totalAmount),
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryMain,),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],),
              ),
            ],),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Notes
          if (q.notes != null) ...[
            _InfoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Notes'),
                    const SizedBox(height: 6),
                    Text(q.notes!, style: AppTypography.body),
                  ],),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Rejection reason
          if (q.status == 'CUSTOMER_REJECTED' && q.rejectionReason != null) ...[
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.cancel_outlined,
                        size: 15, color: AppColors.red600,),
                    SizedBox(width: 6),
                    _Label('Rejection Reason'),
                  ],),
                  const SizedBox(height: 6),
                  Text(q.rejectionReason!,
                      style:
                          AppTypography.body.copyWith(color: AppColors.red600),),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Exclusive-editor lock banner — shown to anyone who cannot edit content
          if (isEditable && !isBuyerView && !canEditContent) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amber600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amber600.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline,
                    size: 16, color: AppColors.amber600,),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This quotation is assigned to ${q.assignedManagerName ?? "a manager"}. '
                    'Only they can edit its content.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.amber600),
                  ),
                ),
              ],),
            ),
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
                        borderRadius: BorderRadius.circular(9),),
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
                        borderRadius: BorderRadius.circular(9),),
                    elevation: 0,
                  ),
                ),
              ),
            ],),
            const SizedBox(height: 8),
          ]

          // ── Seller status-based actions ─────────────────────────────────
          else if (!isBuyerView) ...[
            if (backendCaps?.canSend ?? q.status == 'CUSTOMER_DRAFT') ...[
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
                        borderRadius: BorderRadius.circular(9),),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (backendCaps?.canRecall ??
                q.status == 'CUSTOMER_SENT') ...[
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
                        borderRadius: BorderRadius.circular(9),),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (backendCaps?.canConvert ??
                q.status == 'CUSTOMER_ACCEPTED') ...[
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
                        borderRadius: BorderRadius.circular(9),),
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
                      borderRadius: BorderRadius.circular(9),),
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
                      borderRadius: BorderRadius.circular(9),),
                ),
                child: SvgPicture.asset(
                  'assets/icons/whatsapp.svg',
                  width: 24,
                  height: 24,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                      borderRadius: BorderRadius.circular(9),),
                ),
                child: const Icon(Icons.ios_share_rounded, size: 22),
              ),
            ),
          ],),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }
}

// ── Manager picker bottom sheet ───────────────────────────────────────────────
