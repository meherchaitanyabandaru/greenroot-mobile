import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'quotation_create_screen.dart';
import 'quotations.dart';

// ── Grouped list item types ────────────────────────────────────────────────────

sealed class _ListItem {}

class _MonthHeader extends _ListItem {
  final String label;
  _MonthHeader(this.label);
}

class _QuotationEntry extends _ListItem {
  final Quotation quotation;
  _QuotationEntry(this.quotation);
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class QuotationListScreen extends ConsumerStatefulWidget {
  const QuotationListScreen({super.key});

  @override
  ConsumerState<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends ConsumerState<QuotationListScreen> {
  final _searchCtrl = TextEditingController();

  static const _statusOptions = [
    (label: 'All', value: null),
    (label: 'Internal', value: 'INTERNAL_DRAFT'),
    (label: 'Draft', value: 'CUSTOMER_DRAFT'),
    (label: 'Sent', value: 'CUSTOMER_SENT'),
    (label: 'Accepted', value: 'CUSTOMER_ACCEPTED'),
    (label: 'Rejected', value: 'CUSTOMER_REJECTED'),
    (label: 'Converted', value: 'CONVERTED'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(quotationListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_ListItem> _buildGrouped(List<Quotation> quotations) {
    final items = <_ListItem>[];
    String? lastHeader;
    for (final q in quotations) {
      final dt = DateTime.tryParse(q.createdAt)?.toLocal();
      final header = dt != null ? DateFormat('MMMM yyyy').format(dt) : 'Unknown';
      if (header != lastHeader) {
        items.add(_MonthHeader(header));
        lastHeader = header;
      }
      items.add(_QuotationEntry(q));
    }
    return items;
  }

  // Raw delete — no dialog. Used after swipe confirmation.
  Future<void> _doDelete(Quotation q) async {
    try {
      await ref.read(quotationRepositoryProvider).deleteQuotation(q.id);
      ref.read(quotationListProvider.notifier).remove(q.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Quotation deleted'),
              backgroundColor: AppColors.primaryMain),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    }
  }

  // With confirm dialog — used by ⋮ menu.
  Future<void> _delete(Quotation q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Delete ${q.quotationCode}? This cannot be undone.'),
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
    if (confirm != true || !mounted) return;
    await _doDelete(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quotationListProvider);
    final paged = state.paged;
    final activeStatus = state.statusFilter;
    final caps = ref.watch(sessionProvider).capabilities;
    final canDelete = caps.isNurseryOwner;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Quotations'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => ref.read(quotationListProvider.notifier).setSearch(v),
                  decoration: InputDecoration(
                    hintText: 'Search quotations…',
                    hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    suffixIcon: state.search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(quotationListProvider.notifier).setSearch('');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primaryMain),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  itemCount: _statusOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final opt = _statusOptions[i];
                    final isSelected = activeStatus == opt.value;
                    return GestureDetector(
                      onTap: () => ref.read(quotationListProvider.notifier).setStatusFilter(opt.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryMain : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryMain : AppColors.border,
                          ),
                        ),
                        child: Text(
                          opt.label,
                          style: AppTypography.caption.copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final choice = await showQuotationTypeDialog(context);
          if (choice == null || !context.mounted) return;
          final type = choice == QuotationTypeChoice.internal ? 'INTERNAL' : 'CUSTOMER';
          final created = await context.push<bool>('/quotations/create?type=$type');
          if (created == true) ref.read(quotationListProvider.notifier).load();
        },
        backgroundColor: AppColors.primaryMain,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Builder(builder: (_) {
        if (paged.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryMain));
        }
        if (paged.error != null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Failed to load', style: AppTypography.body.copyWith(color: AppColors.red600)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => ref.read(quotationListProvider.notifier).load(),
                  child: const Text('Retry')),
            ]),
          );
        }
        if (paged.items.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.description_outlined,
                  size: 64, color: AppColors.primaryMain.withValues(alpha: 0.3)),
              const SizedBox(height: AppSpacing.md),
              Text('No quotations yet', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text('Tap + to create your first quotation',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
            ]),
          );
        }

        final grouped = _buildGrouped(paged.items);
        final totalCount = grouped.length + (paged.hasMore ? 1 : 0);

        return RefreshIndicator(
          color: AppColors.primaryMain,
          onRefresh: () => ref.read(quotationListProvider.notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, 100),
            itemCount: totalCount,
            itemBuilder: (context, i) {
              // Load more sentinel
              if (i >= grouped.length) {
                ref.read(quotationListProvider.notifier).loadMore();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: paged.isLoadingMore
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primaryMain))
                        : const SizedBox.shrink(),
                  ),
                );
              }

              final item = grouped[i];

              if (item is _MonthHeader) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 6),
                  child: Row(children: [
                    Text(item.label,
                        style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ]),
                );
              }

              final q = (item as _QuotationEntry).quotation;
              final card = _QuotationCard(
                quotation: q,
                canDelete: canDelete,
                onTap: () async {
                  final edited = await context.push<bool>('/quotations/${q.id}');
                  if (edited == true) ref.read(quotationListProvider.notifier).load();
                },
                onDelete: () => _delete(q),
              );
              if (!canDelete) return card;
              return Dismissible(
                key: ValueKey(q.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.red600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 22),
                      SizedBox(height: 2),
                      Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
                confirmDismiss: (_) async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Quotation'),
                      content: Text('Delete ${q.quotationCode}? This cannot be undone.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete',
                              style: TextStyle(color: AppColors.red600)),
                        ),
                      ],
                    ),
                  );
                  return confirm ?? false;
                },
                onDismissed: (_) => _doDelete(q),
                child: card,
              );
            },
          ),
        );
      }),
    );
  }
}

// ── Quotation card ─────────────────────────────────────────────────────────────

class _QuotationCard extends StatelessWidget {
  final Quotation quotation;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _QuotationCard({required this.quotation, required this.canDelete, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(quotation.createdAt)?.toLocal();
    final dateStr = dt != null ? DateFormat('d MMM yyyy').format(dt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_outlined,
                    color: AppColors.primaryMain, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(quotation.quotationCode,
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (quotation.isInternal)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('INT',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 9)),
                          ),
                        ),
                      _StatusChip(status: quotation.status, quotationType: quotation.quotationType),
                      if (quotation.isExpired && quotation.status == 'CUSTOMER_SENT') ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.red100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Expired',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.red600,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    if (quotation.recipientName != null)
                      Text('To: ${quotation.recipientName}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary)),
                    Row(children: [
                      Text('₹${quotation.totalAmount.toStringAsFixed(2)}',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primaryMain,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text(
                          '· ${quotation.items.length} item${quotation.items.length == 1 ? '' : 's'}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                      const Spacer(),
                      Text(dateStr,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                    ]),
                  ],
                ),
              ),
              if (canDelete)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline, color: AppColors.red600, size: 18),
                        const SizedBox(width: 10),
                        Text('Delete',
                            style: AppTypography.body
                                .copyWith(color: AppColors.red600)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final String? quotationType;
  const _StatusChip({required this.status, this.quotationType});

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
        label = 'Sent';
        break;
      case 'CUSTOMER_ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Accepted';
        break;
      case 'CUSTOMER_REJECTED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        label = 'Rejected';
        break;
      case 'CONVERTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Converted';
        break;
      case 'DELETED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        label = 'Deleted';
        break;
      // Legacy status support
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: AppTypography.caption
              .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}
