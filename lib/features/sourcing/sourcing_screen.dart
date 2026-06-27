import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'sourcing.dart';

class SourcingScreen extends ConsumerStatefulWidget {
  const SourcingScreen({super.key});

  @override
  ConsumerState<SourcingScreen> createState() => _SourcingScreenState();
}

class _SourcingScreenState extends ConsumerState<SourcingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sourcingNetworkProvider.notifier).load();
      ref.read(sourcingPostsProvider('NEED').notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(sessionProvider).capabilities;

    if (!caps.isNurseryOwner && !caps.isManager) {
      return const _SourcingNoAccessScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plant Sourcing', style: AppTypography.h3),
            Text(
              'Private nursery discovery network',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          labelStyle: AppTypography.label,
          tabs: const [
            Tab(text: 'Nearby'),
            Tab(text: 'Need'),
            Tab(text: 'Available'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NearbyNurseriesTab(searchCtrl: _searchCtrl),
          const _SourcingPostsTab(postType: 'NEED'),
          const _SourcingPostsTab(postType: 'AVAILABLE'),
        ],
      ),
    );
  }
}

class _SourcingNoAccessScreen extends StatelessWidget {
  const _SourcingNoAccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Plant Sourcing'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: 96),
          Icon(
            Icons.lock_outline_rounded,
            size: 56,
            color: AppColors.textMuted.withValues(alpha: 0.8),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Network unavailable',
            style: AppTypography.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Plant sourcing is available only for nursery owners and managers.',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NearbyNurseriesTab extends ConsumerStatefulWidget {
  final TextEditingController searchCtrl;

  const _NearbyNurseriesTab({required this.searchCtrl});

  @override
  ConsumerState<_NearbyNurseriesTab> createState() =>
      _NearbyNurseriesTabState();
}

class _NearbyNurseriesTabState extends ConsumerState<_NearbyNurseriesTab> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(sourcingNetworkProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourcingNetworkProvider);
    final paged = state.paged;

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref
          .read(sourcingNetworkProvider.notifier)
          .load(search: widget.searchCtrl.text),
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppSearchField(
                hint: 'Search Mango, Neem, Coconut...',
                controller: widget.searchCtrl,
                onChanged: (value) {
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (widget.searchCtrl.text == value) {
                      ref
                          .read(sourcingNetworkProvider.notifier)
                          .load(search: value);
                    }
                  });
                },
                onClear: () =>
                    ref.read(sourcingNetworkProvider.notifier).load(search: ''),
              ),
            ),
          ),
          if (paged.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryMain),
              ),
            )
          else if (paged.error != null && paged.items.isEmpty)
            SliverFillRemaining(
              child: _CenteredMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load sourcing network',
                message: paged.error!.message,
              ),
            )
          else if (paged.items.isEmpty)
            const SliverFillRemaining(
              child: _CenteredMessage(
                icon: Icons.travel_explore_rounded,
                title: 'No nearby nurseries found',
                message: 'Try another plant name or increase your search area.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                0,
                AppSpacing.screenPadding,
                AppSpacing.screenPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i >= paged.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryMain,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _NearbyNurseryCard(nursery: paged.items[i]),
                    );
                  },
                  childCount: paged.items.length + (paged.hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourcingPostsTab extends ConsumerStatefulWidget {
  final String postType;

  const _SourcingPostsTab({required this.postType});

  @override
  ConsumerState<_SourcingPostsTab> createState() => _SourcingPostsTabState();
}

class _SourcingPostsTabState extends ConsumerState<_SourcingPostsTab> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sourcingPostsProvider(widget.postType).notifier).load();
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(sourcingPostsProvider(widget.postType).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = sourcingPostsProvider(widget.postType);
    final paged = ref.watch(provider).paged;
    final label =
        widget.postType == 'NEED' ? 'need posts' : 'availability posts';

    return RefreshIndicator(
      color: AppColors.primaryMain,
      onRefresh: () => ref.read(provider.notifier).load(),
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          if (paged.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryMain),
              ),
            )
          else if (paged.error != null && paged.items.isEmpty)
            SliverFillRemaining(
              child: _CenteredMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load $label',
                message: paged.error!.message,
              ),
            )
          else if (paged.items.isEmpty)
            SliverFillRemaining(
              child: _CenteredMessage(
                icon: Icons.eco_outlined,
                title: 'No open $label',
                message: 'Posts from participating nurseries will appear here.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i >= paged.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryMain,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _SourcingPostCard(post: paged.items[i]),
                    );
                  },
                  childCount: paged.items.length + (paged.hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NearbyNurseryCard extends StatelessWidget {
  final NearbyNursery nursery;

  const _NearbyNurseryCard({required this.nursery});

  @override
  Widget build(BuildContext context) {
    final plants =
        nursery.featuredPlants.take(3).map((p) => p.plantName).join(', ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primaryMain,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nursery.nurseryName, style: AppTypography.h4),
                    if (nursery.village?.isNotEmpty == true)
                      Text(
                        nursery.village!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (nursery.distanceKm != null)
                Text(
                  '${nursery.distanceKm!.toStringAsFixed(1)} km',
                  style: AppTypography.label.copyWith(
                    color: AppColors.primaryMain,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FactChip(
                icon: Icons.alt_route_rounded,
                label: nursery.roadAccessible ? 'Road access' : 'Road unknown',
              ),
              _FactChip(
                icon: Icons.local_shipping_outlined,
                label:
                    nursery.lorryAccessible ? 'Lorry access' : 'Small vehicle',
              ),
              if (nursery.contactNumber?.isNotEmpty == true)
                const _FactChip(
                  icon: Icons.call_outlined,
                  label: 'Contact visible',
                ),
            ],
          ),
          if (plants.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              plants,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourcingPostCard extends StatelessWidget {
  final SourcingPost post;

  const _SourcingPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final isNeed = post.postType == 'NEED';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: isNeed ? 'Need' : 'Available',
                variant: isNeed ? BadgeVariant.warning : BadgeVariant.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: post.urgency.replaceAll('_', ' '),
                variant: post.urgency == 'TODAY'
                    ? BadgeVariant.error
                    : BadgeVariant.info,
              ),
              const Spacer(),
              Text(
                post.postCode,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(post.plantName, style: AppTypography.h4),
          const SizedBox(height: 2),
          Text(
            post.nurseryName,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (post.quantity != null)
                _FactChip(
                  icon: Icons.format_list_numbered_rounded,
                  label: '${post.quantity} plants',
                ),
              if (post.sizeDescription?.isNotEmpty == true)
                _FactChip(
                  icon: Icons.straighten_rounded,
                  label: post.sizeDescription!,
                ),
              _FactChip(
                icon: Icons.radar_rounded,
                label: '${post.radiusKm} km',
              ),
              _FactChip(
                icon: Icons.forum_outlined,
                label: '${post.responseCount} responses',
              ),
            ],
          ),
          if (post.notes?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              post.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.h4, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
