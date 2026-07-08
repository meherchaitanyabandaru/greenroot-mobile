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
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
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

  Future<void> _buyerAccept(Quotation q) async {
    setState(() => _buyerActing = true);
    try {
      await ref.read(quotationRepositoryProvider).acceptQuotation(q.id);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation accepted'),
          backgroundColor: AppColors.primaryMain,
        ));
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
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation rejected'),
          backgroundColor: AppColors.red600,
        ));
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

  Future<void> _exportPdf(Quotation q) async {
    setState(() => _exporting = true);
    try {
      String? nurseryAddress;
      if (q.nurseryId != null) {
        nurseryAddress = await _fetchNurseryAddress(q.nurseryId!);
      }

      final session = ref.read(sessionProvider);
      final downloadedBy = session.user?.name ?? session.user?.mobile ?? 'GreenRoot User';

      final doc = _buildProfessionalPdf(
        q: q,
        nurseryAddress: nurseryAddress,
        downloadedBy: downloadedBy,
      );

      final bytes = await doc.save();

      if (kIsWeb) {
        final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
        await launchUrl(Uri.parse(dataUrl), mode: LaunchMode.externalApplication);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${q.quotationCode}.pdf');
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
              content: Text('PDF export failed: $e'),
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
    final canDelete = caps.isNurseryOwner || caps.isManager;
    final buyerCanAct = isBuyerView &&
        (q.status == 'CUSTOMER_SENT' ||
            q.status == 'APPROVED' ||
            q.status == 'SENT');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(q.quotationCode,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_deleting || _exporting || _buyerActing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMain)),
            )
          else if (!isBuyerView) ...[
            // Edit
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
                if (v == 'pdf') await _exportPdf(q);
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
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Recipient
          if (q.recipientName != null || q.recipientMobile != null) ...[
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

          // Buyer action buttons (Accept / Reject)
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
          ] else ...[
            ElevatedButton.icon(
              onPressed: _exporting ? null : () => _exportPdf(q),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ],
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
  final validUntil = createdDt.add(const Duration(days: 15));
  final validUntilStr =
      '${validUntil.day} ${_monthAbbr(validUntil.month)} ${validUntil.year} (15 Days)';

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
