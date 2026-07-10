import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'quotation_create_screen.dart';
import 'quotation_pins.dart';
import 'quotations.dart';

// ── Grouped list item types ────────────────────────────────────────────────────

sealed class _ListItem {}

class _MonthHeader extends _ListItem {
  final String label;
  _MonthHeader(this.label);
}

class _PinnedHeader extends _ListItem {}

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

  List<_ListItem> _buildItems(List<Quotation> all, Set<int> pinnedIds) {
    final pinned = all.where((q) => pinnedIds.contains(q.id)).toList();
    final rest = all.where((q) => !pinnedIds.contains(q.id)).toList();
    final items = <_ListItem>[];
    if (pinned.isNotEmpty) {
      items.add(_PinnedHeader());
      for (final q in pinned) items.add(_QuotationEntry(q));
    }
    items.addAll(_buildGrouped(rest));
    return items;
  }

  // Raw delete — no dialog. Used after swipe confirmation.
  Future<void> _doDelete(Quotation q) async {
    try {
      await ref.read(quotationRepositoryProvider).deleteQuotation(q.id);
      ref.read(quotationListProvider.notifier).remove(q.id);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('${q.quotationCode} deleted'),
            ]),
            backgroundColor: AppColors.primaryMain,
          ),
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

  void _showFilterSheet(BuildContext context, QuotationListState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilterSheet(
        current: state,
        onApply: (dateFrom, dateTo, amountMin, amountMax) {
          ref.read(quotationListProvider.notifier).applyFilters(
            dateFrom: dateFrom,
            dateTo: dateTo,
            amountMin: amountMin,
            amountMax: amountMax,
            clearDateFrom: dateFrom == null,
            clearDateTo: dateTo == null,
            clearAmountMin: amountMin == null,
            clearAmountMax: amountMax == null,
          );
        },
        onClear: () => ref.read(quotationListProvider.notifier).clearAllFilters(),
      ),
    );
  }

  // With confirm dialog — used by ⋮ menu.
  Future<void> _delete(Quotation q) async {
    HapticFeedback.mediumImpact();
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
    final pinnedIds = ref.watch(quotationPinsProvider);
    final session = ref.watch(sessionProvider);
    final caps = session.capabilities;
    final canDelete = caps.isNurseryOwner;
    final isOwner = caps.isNurseryOwner;
    final isManagerOnly = caps.isManager && !caps.isNurseryOwner;

    // Tab options differ by role
    final tabOptions = isOwner
        ? [
            (label: 'All', tab: QuotationTab.all),
            (label: 'Unassigned', tab: QuotationTab.unassigned),
            (label: 'Mine', tab: QuotationTab.mine),
          ]
        : isManagerOnly
            ? [
                (label: 'All', tab: QuotationTab.all),
                (label: 'Created by Me', tab: QuotationTab.createdByMe),
                (label: 'Assigned to Me', tab: QuotationTab.assignedToMe),
              ]
            : <({String label, QuotationTab tab})>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Quotations'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(tabOptions.isNotEmpty ? 132 : 96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: () => _showFilterSheet(context, state),
                          icon: const Icon(Icons.tune_rounded, size: 22),
                          color: state.hasActiveFilters ? AppColors.primaryMain : AppColors.textSecondary,
                          style: IconButton.styleFrom(
                            backgroundColor: state.hasActiveFilters ? AppColors.forest100 : AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: state.hasActiveFilters ? AppColors.primaryMain : AppColors.border,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        if (state.hasActiveFilters)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryMain,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Role-aware tab row
              if (tabOptions.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    itemCount: tabOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final opt = tabOptions[i];
                      final isSelected = state.tab == opt.tab;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(quotationListProvider.notifier).setTab(opt.tab);
                        },
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
              // Status filter row
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
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(quotationListProvider.notifier).setStatusFilter(opt.value);
                      },
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
          return const _QuotationSkeletonList();
        }
        if (paged.error != null) {
          final isNetwork = paged.error is NetworkError;
          return EmptyState(
            icon: isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
            title: isNetwork ? 'No internet connection' : 'Could not load',
            subtitle: isNetwork
                ? 'Check your connection and try again'
                : paged.error!.message,
            actionLabel: 'Retry',
            onAction: () => ref.read(quotationListProvider.notifier).load(),
          );
        }
        if (paged.items.isEmpty) {
          if (state.search.isNotEmpty || state.hasActiveFilters) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results',
              subtitle: 'Try adjusting your search or filters',
              actionLabel: 'Clear filters',
              onAction: () {
                _searchCtrl.clear();
                ref.read(quotationListProvider.notifier).clearAllFilters();
              },
            );
          }
          return const EmptyState(
            icon: Icons.description_outlined,
            title: 'No quotations yet',
            subtitle: 'Tap + to create your first quotation',
          );
        }

        final grouped = _buildItems(paged.items, pinnedIds);
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

              if (item is _PinnedHeader) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.push_pin_rounded, size: 13, color: AppColors.amber600),
                    const SizedBox(width: 6),
                    Text('Pinned',
                        style: AppTypography.label.copyWith(
                            color: AppColors.amber600, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ]),
                );
              }

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
              final isDraftStatus = ['CUSTOMER_DRAFT', 'INTERNAL_DRAFT'].contains(q.status);
              final canDeleteThis = canDelete && isDraftStatus;
              final isPinned = pinnedIds.contains(q.id);
              final card = _QuotationCard(
                quotation: q,
                canDelete: canDeleteThis,
                isPinned: isPinned,
                onTap: () async {
                  final edited = await context.push<bool>('/quotations/${q.id}');
                  if (edited == true) ref.read(quotationListProvider.notifier).load();
                },
                onDelete: () => _delete(q),
                onPin: () => ref.read(quotationPinsProvider.notifier).toggle(q.id),
              );
              if (!canDeleteThis) return card;
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

class _QuotationCard extends ConsumerWidget {
  final Quotation quotation;
  final bool canDelete;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  const _QuotationCard({
    required this.quotation,
    required this.canDelete,
    required this.isPinned,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTime.tryParse(quotation.createdAt)?.toLocal();
    final dateStr = dt != null ? DateFormat('d MMM yyyy').format(dt) : '';
    final caps = ref.watch(sessionProvider).capabilities;
    final isOwner = caps.isNurseryOwner;
    final isUnassigned = quotation.assignedManagerUserId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Icon(
                      isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                      color: AppColors.amber600,
                    ),
                    title: Text(isPinned ? 'Unpin' : 'Pin quotation',
                        style: AppTypography.body),
                    onTap: () {
                      Navigator.pop(context);
                      onPin();
                    },
                  ),
                  if (canDelete)
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: AppColors.red600),
                      title: Text('Delete',
                          style: AppTypography.body.copyWith(color: AppColors.red600)),
                      onTap: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
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
                  if (isPinned)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.amber600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.push_pin_rounded,
                            size: 9, color: Colors.white),
                      ),
                    ),
                ],
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
                    // Assignment label — owner sees assigned manager or unassigned warning
                    if (isOwner) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        if (isUnassigned) ...[
                          const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.amber600),
                          const SizedBox(width: 3),
                          Text('Unassigned',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.amber600, fontWeight: FontWeight.w600)),
                        ] else ...[
                          const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.teal700),
                          const SizedBox(width: 3),
                          Text('→ ${quotation.assignedManagerName ?? 'Manager'}',
                              style: AppTypography.caption.copyWith(color: AppColors.teal700)),
                        ],
                      ]),
                    ],
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'pin') onPin();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(children: [
                      Icon(
                        isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                        color: AppColors.amber600, size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(isPinned ? 'Unpin' : 'Pin',
                          style: AppTypography.body),
                    ]),
                  ),
                  if (canDelete)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline, color: AppColors.red600, size: 18),
                        const SizedBox(width: 10),
                        Text('Delete',
                            style: AppTypography.body.copyWith(color: AppColors.red600)),
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

// ── Skeleton list ─────────────────────────────────────────────────────────────

class _QuotationSkeletonList extends StatefulWidget {
  const _QuotationSkeletonList();

  @override
  State<_QuotationSkeletonList> createState() => _QuotationSkeletonListState();
}

class _QuotationSkeletonListState extends State<_QuotationSkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({required double w, required double h, double radius = 6}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.border, AppColors.background, _anim.value),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _box(w: 38, h: 38, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _box(w: 140, h: 12),
                  const Spacer(),
                  _box(w: 52, h: 18, radius: 4),
                ]),
                const SizedBox(height: 7),
                _box(w: 100, h: 10),
                const SizedBox(height: 7),
                Row(children: [
                  _box(w: 72, h: 10),
                  const Spacer(),
                  _box(w: 60, h: 10),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, 100),
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(6, (_) => _card()),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final QuotationListState current;
  final void Function(DateTime? dateFrom, DateTime? dateTo, double? amountMin, double? amountMax) onApply;
  final VoidCallback onClear;

  const _FilterSheet({required this.current, required this.onApply, required this.onClear});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.current.dateFrom;
    _dateTo   = widget.current.dateTo;
    _minCtrl.text = widget.current.amountMin?.toStringAsFixed(0) ?? '';
    _maxCtrl.text = widget.current.amountMax?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.day} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_dateFrom ?? now.subtract(const Duration(days: 30)))
        : (_dateTo ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: AppTypography.h3),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onClear();
                },
                child: Text('Clear all', style: AppTypography.bodySmall.copyWith(color: AppColors.red600)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date range
          Text('Date Range', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _DateTile(
                label: 'From',
                date: _dateFrom,
                onTap: () => _pickDate(isFrom: true),
                onClear: () => setState(() => _dateFrom = null),
                fmtDate: _fmtDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DateTile(
                label: 'To',
                date: _dateTo,
                onTap: () => _pickDate(isFrom: false),
                onClear: () => setState(() => _dateTo = null),
                fmtDate: _fmtDate,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Amount range
          Text('Amount Range (₹)', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _minCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Min',
                  hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryMain)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _maxCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Max',
                  hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryMain)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onApply(
                  _dateFrom,
                  _dateTo,
                  double.tryParse(_minCtrl.text.trim()),
                  double.tryParse(_maxCtrl.text.trim()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String Function(DateTime) fmtDate;

  const _DateTile({
    required this.label, required this.date, required this.onTap,
    required this.onClear, required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: date != null ? AppColors.primaryMain : AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              date != null ? fmtDate(date!) : label,
              style: AppTypography.caption.copyWith(
                color: date != null ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          if (date != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
            ),
        ]),
      ),
    );
  }
}
