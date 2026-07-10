import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/status_badge.dart';
import 'requests.dart';

class RequestListScreen extends ConsumerStatefulWidget {
  final bool canCreate;

  const RequestListScreen({super.key, this.canCreate = false});

  @override
  ConsumerState<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends ConsumerState<RequestListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(requestListProvider.notifier).load();
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(requestListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(requestListProvider);
    final paged = listState.paged;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: widget.canCreate
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              onPressed: () async {
                final created = await context.push<bool>('/requests/create');
                if (created == true && mounted) ref.read(requestListProvider.notifier).load(search: _searchCtrl.text);
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(requestListProvider.notifier)
            .load(search: _searchCtrl.text),
        color: AppColors.primaryMain,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    AppSearchField(
                      hint: 'Search requests...',
                      controller: _searchCtrl,
                      onChanged: (val) {
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (_searchCtrl.text == val) {
                            ref
                                .read(requestListProvider.notifier)
                                .load(search: val);
                          }
                        });
                      },
                      onClear: () =>
                          ref.read(requestListProvider.notifier).load(search: ''),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (label, value) in [
                            ('All', null),
                            ('Open', 'OPEN'),
                            ('Fulfilled', 'FULFILLED'),
                            ('Expired', 'EXPIRED'),
                            ('Cancelled', 'CANCELLED'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: _StatusChip(
                                label: label,
                                selected: listState.statusFilter == value,
                                onTap: () => ref
                                    .read(requestListProvider.notifier)
                                    .load(statusFilter: value),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (paged.isLoading)
              const SliverFillRemaining(
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primaryMain)),
              )
            else if (paged.error != null && paged.items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.md),
                      Text(paged.error!.message, style: AppTypography.body),
                      TextButton(
                        onPressed: () =>
                            ref.read(requestListProvider.notifier).load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (paged.items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.md),
                      const Text('No requests found', style: AppTypography.h4),
                      if (widget.canCreate) ...[
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMain,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('New Request'),
                          onPressed: () async {
                            final created = await context.push<bool>('/requests/create');
                            if (created == true && mounted) ref.read(requestListProvider.notifier).load(search: _searchCtrl.text);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _RequestCard(
                        request: paged.items[i],
                        onTap: () =>
                            context.push('/requests/${paged.items[i].id}'),
                      ),
                    ),
                    childCount: paged.items.length,
                  ),
                ),
              ),
              if (paged.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.x2l),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryMain)),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x5l)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMain : AppColors.surface,
          border: Border.all(
              color: selected ? AppColors.primaryMain : AppColors.border),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final PlantRequest request;
  final VoidCallback onTap;

  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(request.createdAt);
    final dateStr = date != null
        ? DateFormat('dd MMM yyyy').format(date.toLocal())
        : '';

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.displayName,
                    style: AppTypography.h4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: request.status,
                  variant: badgeVariantFromStatus(request.status),
                  dot: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              request.requestingNursery,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.format_list_numbered_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Qty: ${request.quantityRequired}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.radar_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${request.radiusKm} km',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (request.responses.isNotEmpty)
                  StatusBadge(
                    label: '${request.responses.length} responses',
                    variant: BadgeVariant.info,
                  ),
              ],
            ),
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                dateStr,
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
