import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/green_root_app_bar.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'local_market_providers.dart';
import '../manager/top_items_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _mkGreen    = Color(0xFF00A86B);
const _mkDark   = Color(0xFF047857);
const _mkLight  = Color(0xFFD1FAE5);
const _mkBg     = Color(0xFFF0FDF4);
const _mkCard   = Color(0xFFFFFFFF);
const _mkBorder = Color(0xFFE2E8F0);
const _mkTextPrimary   = Color(0xFF0F172A);
const _mkTextSecondary = Color(0xFF64748B);

const _stPublished   = Color(0xFF16A34A);
const _stPublishedBg = Color(0xFFDCFCE7);
const _stDraft       = Color(0xFF64748B);
const _stDraftBg     = Color(0xFFF1F5F9);
const _stPaused      = Color(0xFFF59E0B);
const _stPausedBg    = Color(0xFFFEF3C7);
const _stExpired     = Color(0xFFDC2626);
const _stExpiredBg   = Color(0xFFFEE2E2);
const _stArchived    = Color(0xFF334155);
const _stArchivedBg  = Color(0xFFE2E8F0);

const _cardShadow = BoxShadow(
  color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 2),
);
const _heartRed = Color(0xFFED4956);

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _isNewAd(MarketAd ad) {
  final published = ad.publishedAt ?? ad.createdAt;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final adDay = DateTime(published.year, published.month, published.day);
  return today.difference(adDay).inDays <= 1;
}

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  return '${d.inMinutes}m ago';
}

String _daysLeft(DateTime? exp) {
  if (exp == null) return '';
  final d = exp.difference(DateTime.now()).inDays;
  return d > 0 ? '$d days left' : 'Expired';
}

InputDecoration _inputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: _mkTextSecondary.withValues(alpha: 0.6), fontSize: 14),
  filled: true,
  fillColor: _mkCard,
  counterText: '',
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _mkBorder)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _mkBorder)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _mkGreen, width: 1.5)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
);

// ══════════════════════════════════════════════════════════════════════════════
// 1. LOCAL MARKET HOME
// ══════════════════════════════════════════════════════════════════════════════

class LocalMarketScreen extends ConsumerWidget {
  const LocalMarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestAdsProvider);

    return Scaffold(
      backgroundColor: _mkBg,
      appBar: GreenRootAppBar(
        title: 'Local Market',
        subtitle: 'Nursery to nursery. Grow together.',
        extraActions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _mkTextSecondary),
            tooltip: 'Market Settings',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _MarketSettingsScreen())),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _mkBorder),
        ),
      ),
      body: RefreshIndicator(
        color: _mkGreen,
        onRefresh: () async => ref.invalidate(latestAdsProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _HomeSearchBar(context)),
            SliverToBoxAdapter(child: _HomeQuickActions(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: _SectionHeader(
                  title: 'Latest Listings',
                  actionLabel: 'View All',
                  onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _BrowseScreen())),
                ),
              ),
            ),
            latestAsync.when(
              loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorState(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(latestAdsProvider)),
              ),
              data: (ads) {
                if (ads.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No ads yet',
                      subtitle: 'Be the first to post plants on the market',
                    ),
                  );
                }
                final latest = ads.take(6).toList();
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: EdgeInsets.fromLTRB(16, i == 0 ? 0 : 0, 16, 14),
                      child: _BrowseAdCard(ad: latest[i]),
                    ),
                    childCount: latest.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _HomeSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _BrowseScreen(autoFocus: true))),
      child: Container(
        color: _mkCard,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _mkBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _mkBorder),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: _mkGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Search plants...',
                  style: AppTypography.body.copyWith(
                      color: _mkTextSecondary.withValues(alpha: 0.7))),
            ),
            const Icon(Icons.tune_rounded, color: _mkTextSecondary, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _HomeQuickActions(BuildContext context) {
    final items = [
      (Icons.grid_view_rounded, 'Browse', () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const _BrowseScreen()))),
      (Icons.favorite_rounded, 'Saved', () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const _SavedAdsScreen()))),
      (Icons.add_business_outlined, 'My Ads', () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const _MyAdsScreen()))),
      (Icons.workspace_premium_rounded, 'Top Items', () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TopItemsScreen()))),
      (Icons.chat_bubble_outline_rounded, 'Enquiries', () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const _EnquiriesScreen()))),
    ];
    return Container(
      color: _mkCard,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      child: Row(
        children: items.map((e) => Expanded(
          child: _QuickActionTile(
            e.$1, e.$2, e.$3,
            iconColor: e.$2 == 'Saved' ? _heartRed : null,
          ),
        )).toList(),
      ),
    );
  }

}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  const _QuickActionTile(this.icon, this.label, this.onTap, {this.iconColor});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? _mkGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: _mkLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _mkGreen.withValues(alpha: 0.18))),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 7),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. BROWSE SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _BrowseScreen extends ConsumerStatefulWidget {
  final bool autoFocus;

  const _BrowseScreen({this.autoFocus = false});

  @override
  ConsumerState<_BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<_BrowseScreen> {
  final _searchCtrl = TextEditingController();
  late final FocusNode _focus;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _scroll = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Restore search text from provider state
      final q = ref.read(browseAdsProvider).query;
      if (_searchCtrl.text != q) _searchCtrl.text = q;
      if (widget.autoFocus) _focus.requestFocus();
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(browseAdsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    final browse = ref.read(browseAdsProvider);
    String? selCat = browse.category;
    final minCtrl = TextEditingController(
      text: browse.minPrice != null ? browse.minPrice!.toStringAsFixed(0) : '',
    );
    final maxCtrl = TextEditingController(
      text: browse.maxPrice != null ? browse.maxPrice!.toStringAsFixed(0) : '',
    );
    const cats = ['Fruit Plants', 'Flower Plants', 'Forest Plants', 'Ornamentals'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: _mkBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Filter Ads', style: AppTypography.h4.copyWith(
                    color: _mkTextPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                const Text('Category',
                    style: TextStyle(
                        color: _mkTextSecondary, fontSize: 12,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _catChip('All', selCat == null, () => setS(() => selCat = null)),
                    for (final c in cats)
                      _catChip(c, selCat == c, () => setS(() => selCat = c)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Price Range (₹ per unit)',
                    style: TextStyle(
                        color: _mkTextSecondary, fontSize: 12,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDec('Min price'))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('–',
                        style: TextStyle(color: _mkTextSecondary, fontSize: 18)),
                  ),
                  Expanded(child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDec('Max price'))),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mkTextSecondary,
                      side: const BorderSide(color: _mkBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      setS(() => selCat = null);
                      minCtrl.clear();
                      maxCtrl.clear();
                    },
                    child: const Text('Clear All'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mkGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        final min = double.tryParse(minCtrl.text.trim());
                        final max = double.tryParse(maxCtrl.text.trim());
                        ref.read(browseAdsProvider.notifier).setFilters(
                              category: selCat,
                              minPrice: min,
                              maxPrice: max,
                            );
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _catChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _mkGreen : _mkCard,
            border: Border.all(
                color: selected ? _mkGreen : _mkBorder, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : _mkTextPrimary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      );

  void _showSortSheet() {
    final notifier = ref.read(browseAdsProvider.notifier);
    final currentSort = ref.read(browseAdsProvider).sort;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: _mkBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Sort by',
                  style: AppTypography.h4.copyWith(
                      color: _mkTextPrimary, fontWeight: FontWeight.w700)),
            ),
            for (final s in MarketSort.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.label,
                    style: TextStyle(
                        color: currentSort == s ? _mkGreen : _mkTextPrimary,
                        fontWeight: currentSort == s
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 15)),
                trailing: currentSort == s
                    ? const Icon(Icons.check_rounded, color: _mkGreen, size: 20)
                    : null,
                onTap: () {
                  notifier.setSort(s);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final browse = ref.watch(browseAdsProvider);

    final filterCount = browse.activeFilterCount;
    final hasFilters = filterCount > 0;

    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: const Text('Browse'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.tune_rounded,
                    color: hasFilters ? _mkGreen : _mkTextSecondary),
                if (hasFilters)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: _mkGreen, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('$filterCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.sort_rounded,
                color: browse.sort != MarketSort.newest
                    ? _mkGreen
                    : _mkTextSecondary),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(hasFilters ? 101 : 57),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focus,
                onChanged: (q) =>
                    ref.read(browseAdsProvider.notifier).onQueryChanged(q),
                decoration: _inputDec('Search plants...').copyWith(
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _mkGreen, size: 20),
                  suffixIcon: browse.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref
                                .read(browseAdsProvider.notifier)
                                .onQueryChanged('');
                          })
                      : null,
                  filled: true,
                  fillColor: _mkBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            if (hasFilters) _activeFilterChips(browse),
            const Divider(height: 1, color: _mkBorder),
          ]),
        ),
      ),
      body: _buildBody(browse),
    );
  }

  Widget _activeFilterChips(BrowseAdsState browse) {
    final notifier = ref.read(browseAdsProvider.notifier);
    return SizedBox(
      height: 36,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        children: [
          if (browse.category != null)
            _activeChip(browse.category!, onRemove: () => notifier.setFilters(
              category: null,
              minPrice: browse.minPrice,
              maxPrice: browse.maxPrice,
            )),
          if (browse.minPrice != null || browse.maxPrice != null)
            _activeChip(
              '₹${browse.minPrice?.toStringAsFixed(0) ?? '0'}'
              '–'
              '${browse.maxPrice != null ? '₹${browse.maxPrice!.toStringAsFixed(0)}' : '∞'}',
              onRemove: () => notifier.setFilters(
                category: browse.category,
                minPrice: null,
                maxPrice: null,
              ),
            ),
          TextButton(
            onPressed: () => notifier.setFilters(),
            style: TextButton.styleFrom(
              foregroundColor: _mkTextSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear All',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _activeChip(String label, {required VoidCallback onRemove}) =>
      Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _mkLight,
          border: Border.all(color: _mkGreen.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _mkDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 14, color: _mkDark),
            ),
          ],
        ),
      );

  Widget _buildBody(BrowseAdsState browse) {
    if (browse.isLoading) return const _SkeletonList();

    if (browse.error != null && browse.ads.isEmpty) {
      return _ErrorState(
        message: browse.error!,
        onRetry: () => ref.read(browseAdsProvider.notifier).refresh(),
      );
    }

    if (browse.ads.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'Try a different search term',
      );
    }

    return Column(children: [
      Container(
        color: _mkCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(
            '${browse.total} result${browse.total == 1 ? '' : 's'}',
            style: AppTypography.caption.copyWith(color: _mkTextSecondary),
          ),
          const Spacer(),
          Text(
            browse.sort.label,
            style: AppTypography.caption
                .copyWith(color: _mkGreen, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
      const Divider(height: 1, color: _mkBorder),
      Expanded(
        child: RefreshIndicator(
          color: _mkGreen,
          backgroundColor: _mkCard,
          onRefresh: () => ref.read(browseAdsProvider.notifier).refresh(),
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding, vertical: 16),
            itemCount: browse.ads.length + (browse.isLoadingMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              if (i == browse.ads.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: _mkGreen, strokeWidth: 2)),
                );
              }
              return _BrowseAdCard(ad: browse.ads[i]);
            },
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. BROWSE AD CARD
// ══════════════════════════════════════════════════════════════════════════════

class _BrowseAdCard extends ConsumerWidget {
  final MarketAd ad;
  final bool isOwn;
  const _BrowseAdCard({required this.ad, this.isOwn = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _AdDetailScreen(ad: ad, isOwn: isOwn))),
      child: Container(
        decoration: BoxDecoration(
          color: _mkCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _mkBorder),
          boxShadow: const [_cardShadow],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardPhoto(ad: ad, isOwn: isOwn),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (ad.nurseryVerified)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.verified_rounded, size: 12, color: _mkGreen),
                      ),
                    Expanded(
                      child: Text(ad.nurseryName,
                          style: AppTypography.caption.copyWith(
                              color: _mkTextSecondary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(ad.title,
                      style:
                          AppTypography.h4.copyWith(color: _mkTextPrimary, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (ad.pricePerUnit != null) ...[
                        Text(
                          '₹${ad.pricePerUnit!.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _mkGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 18),
                        ),
                        if (ad.priceUnit != null)
                          Text(' / ${ad.priceUnit}',
                              style: AppTypography.caption
                                  .copyWith(color: _mkTextSecondary)),
                        const SizedBox(width: 10),
                      ],
                      if (ad.quantity != null)
                        _Chip('${ad.quantity} available', _mkLight, _mkDark),
                      if (ad.sizeDescription != null) ...[
                        const SizedBox(width: 6),
                        _Chip(ad.sizeDescription!, _stDraftBg, _stDraft),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  _TrustBar(ad: ad),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPhoto extends ConsumerWidget {
  final MarketAd ad;
  final bool isOwn;
  const _CardPhoto({required this.ad, required this.isOwn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(adSavedProvider(ad.id)) ?? ad.isSavedByMe;
    final myNurseryId = ref.watch(sessionProvider.select((s) => s?.capabilities.ownedNurseryId));
    final effectiveIsOwn = isOwn || (myNurseryId != null && myNurseryId == ad.nurseryId);

    return Stack(children: [
      Container(
        height: 196,
        width: double.infinity,
        color: _mkLight,
        child: ad.photos.isNotEmpty
            ? Image.network(ad.photos.first,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _photoPlaceholder())
            : _photoPlaceholder(),
      ),
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x33000000)],
            ),
          ),
        ),
      ),
      if (effectiveIsOwn)
        Positioned(
            top: 10, left: 10, child: _StatusChip(status: ad.status)),
      if (!effectiveIsOwn && _isNewAd(ad))
        Positioned(
          top: 10, left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _mkGreen,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6, offset: const Offset(0, 1)),
              ],
            ),
            child: const Text('NEW',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
          ),
        ),
      if (ad.photos.length > 1)
        Positioned(
          bottom: 10, right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xAA000000),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('1/${ad.photos.length}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
      if (!effectiveIsOwn)
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: () => ref.read(toggleSaveProvider(ad.id).notifier).toggle(),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
              ),
              child: Icon(
                isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: isSaved ? _heartRed : _mkTextSecondary,
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _photoPlaceholder() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.local_florist_outlined, size: 44, color: _mkGreen),
      SizedBox(height: 4),
      Text('No photo', style: TextStyle(fontSize: 11, color: _mkTextSecondary)),
    ]),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      );
}

class _TrustBar extends StatelessWidget {
  final MarketAd ad;
  const _TrustBar({required this.ad});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _ti(Icons.visibility_outlined, '${ad.viewCount}'),
      const SizedBox(width: 12),
      _ti(Icons.bookmark_outline_rounded, '${ad.saveCount}'),
    ];
    if (ad.expiresAt != null) {
      items.add(const SizedBox(width: 12));
      items.add(_ti(Icons.timer_outlined, _daysLeft(ad.expiresAt),
          color: _daysLeft(ad.expiresAt) == 'Expired' ? _stExpired : null));
    }
    if (ad.enquiryCount > 0) {
      items.add(const SizedBox(width: 12));
      items.add(_ti(Icons.mail_outline_rounded, '${ad.enquiryCount}'));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }

  Widget _ti(IconData icon, String label, {Color? color}) {
    final c = color ?? _mkTextSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. MY ADS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _MyAdsScreen extends ConsumerStatefulWidget {
  const _MyAdsScreen();

  @override
  ConsumerState<_MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends ConsumerState<_MyAdsScreen> {
  String _filter = 'All';

  static const _filters = ['All', 'Live', 'Drafts', 'Closed'];

  @override
  Widget build(BuildContext context) {
    final adsAsync = ref.watch(myAdsProvider);

    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: const Text('My Ads'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _mkBorder)),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
              color: _mkCard,
              border: Border(top: BorderSide(color: _mkBorder))),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _mkGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post New Ad',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _PostAdScreen(), fullscreenDialog: true)),
            ),
          ),
        ),
      ),
      body: adsAsync.when(
        loading: () => const _SkeletonList(),
        error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(myAdsProvider)),
        data: (all) {
          List<MarketAd> _forTab(String tab) => switch (tab) {
            'Live'   => all.where((a) => a.status == 'PUBLISHED' || a.status == 'PAUSED').toList(),
            'Drafts' => all.where((a) => a.status == 'DRAFT').toList(),
            'Closed' => all.where((a) => a.status == 'EXPIRED' || a.status == 'ARCHIVED').toList(),
            _        => all,
          };
          final counts = {for (final f in _filters) f: _forTab(f).length};
          final ads = _forTab(_filter);

          return Column(children: [
            Container(
              color: _mkCard,
              child: SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _filters.length,
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final n = counts[f] ?? 0;
                    final sel = _filter == f;
                    return ChoiceChip(
                      label: Text('$f${n > 0 ? " ($n)" : ""}',
                          style: TextStyle(
                              color: sel ? Colors.white : _mkTextSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      selected: sel,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: _mkGreen,
                      backgroundColor: _mkBg,
                      side: BorderSide(color: sel ? _mkGreen : _mkBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1, color: _mkBorder),
            Expanded(
              child: ads.isEmpty
                  ? const _EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No ads here',
                      subtitle: 'Post your first ad to connect with local nurseries',
                    )
                  : RefreshIndicator(
                      color: _mkGreen,
                      backgroundColor: _mkCard,
                      onRefresh: () async => ref.invalidate(myAdsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        itemCount: ads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _MyAdCard(ad: ads[i]),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _MyAdCard extends ConsumerStatefulWidget {
  final MarketAd ad;
  const _MyAdCard({required this.ad});

  @override
  ConsumerState<_MyAdCard> createState() => _MyAdCardState();
}

class _MyAdCardState extends ConsumerState<_MyAdCard> {
  bool _actioning = false;

  Future<void> _doAdAction(String action) async {
    setState(() => _actioning = true);
    try {
      await ref.read(adActionProvider.notifier).perform(widget.ad.id, action);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: _stExpired,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  List<(String, String, IconData)> get _actions => switch (widget.ad.status) {
        'DRAFT' => [
            ('edit', 'Edit', Icons.edit_outlined),
            ('publish', 'Publish', Icons.publish_rounded),
          ],
        'PUBLISHED' => [
            ('edit', 'Edit', Icons.edit_outlined),
            ('pause', 'Pause', Icons.pause_circle_outline_rounded),
            ('archive', 'Archive', Icons.archive_outlined),
          ],
        'PAUSED' => [
            ('edit', 'Edit', Icons.edit_outlined),
            ('resume', 'Resume', Icons.play_circle_outline_rounded),
            ('archive', 'Archive', Icons.archive_outlined),
          ],
        'EXPIRED' => [
            ('renew', 'Renew', Icons.refresh_rounded),
            ('archive', 'Archive', Icons.archive_outlined),
          ],
        _ => <(String, String, IconData)>[],
      };

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    return Container(
      decoration: BoxDecoration(
        color: _mkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _mkBorder),
        boxShadow: const [_cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _AdDetailScreen(ad: ad, isOwn: true))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 88, height: 88,
                  color: _mkLight,
                  child: ad.photos.isNotEmpty
                      ? Image.network(ad.photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_florist_outlined,
                              color: _mkGreen, size: 30))
                      : const Icon(Icons.local_florist_outlined,
                          color: _mkGreen, size: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _StatusChip(status: ad.status),
                        const Spacer(),
                        if (ad.expiresAt != null)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.timer_outlined,
                                size: 11, color: _mkTextSecondary),
                            const SizedBox(width: 2),
                            Text(_daysLeft(ad.expiresAt),
                                style: AppTypography.caption
                                    .copyWith(color: _mkTextSecondary)),
                          ]),
                      ]),
                      const SizedBox(height: 6),
                      Text(ad.title,
                          style: AppTypography.h4.copyWith(color: _mkTextPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      if (ad.pricePerUnit != null)
                        Text(
                          '₹${ad.pricePerUnit!.toStringAsFixed(0)} / ${ad.priceUnit ?? "unit"}',
                          style: const TextStyle(
                              color: _mkGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      const SizedBox(height: 6),
                      Row(children: [
                        _miniStat(Icons.visibility_outlined, '${ad.viewCount}'),
                        const SizedBox(width: 10),
                        _miniStat(Icons.bookmark_outline_rounded, '${ad.saveCount}'),
                        if (ad.enquiryCount > 0) ...[
                          const SizedBox(width: 10),
                          _miniStat(Icons.mail_outline_rounded, '${ad.enquiryCount}'),
                        ],
                      ]),
                    ]),
              ),
            ]),
          ),
        ),
        if (_actions.isNotEmpty) ...[
          const Divider(height: 1, color: _mkBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: _actions.map((a) {
                final isPositive = a.$1 == 'publish' || a.$1 == 'renew' || a.$1 == 'resume';
                return Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isPositive ? _mkGreen : _mkTextSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: _actioning && (a.$1 != 'edit' && a.$1 != 'enquiries')
                        ? const SizedBox(
                            width: 13, height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _mkGreen))
                        : Icon(a.$3, size: 14),
                    label: Text(a.$2,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: _actioning
                        ? null
                        : () {
                            if (a.$1 == 'edit') {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => _PostAdScreen(editingAd: widget.ad),
                                  fullscreenDialog: true));
                            } else if (a.$1 == 'enquiries') {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const _EnquiriesScreen()));
                            } else {
                              _doAdAction(a.$1);
                            }
                          },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _miniStat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _mkTextSecondary),
          const SizedBox(width: 3),
          Text(label, style: AppTypography.caption),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// 5. AD DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _AdDetailScreen extends ConsumerStatefulWidget {
  final MarketAd ad;
  final bool isOwn;
  const _AdDetailScreen({required this.ad, this.isOwn = false});

  @override
  ConsumerState<_AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends ConsumerState<_AdDetailScreen> {
  final _pageCtrl = PageController();
  int _photoPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final isSaved = ref.watch(adSavedProvider(ad.id)) ?? ad.isSavedByMe;
    final myNurseryId = ref.watch(sessionProvider.select((s) => s?.capabilities.ownedNurseryId));
    final effectiveIsOwn = widget.isOwn || (myNurseryId != null && myNurseryId == ad.nurseryId);

    return Scaffold(
      backgroundColor: _mkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _mkCard,
            foregroundColor: _mkTextPrimary,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (!effectiveIsOwn) ...[
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isSaved ? _heartRed : _mkTextPrimary,
                  ),
                  onPressed: () => ref.read(toggleSaveProvider(ad.id).notifier).toggle(),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => _showMoreSheet(context, ad),
                ),
              ],
              if (effectiveIsOwn)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _PostAdScreen(editingAd: ad),
                      fullscreenDialog: true)),
                ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: ad.photos.isEmpty
                  ? Container(
                      color: _mkLight,
                      child: const Center(
                        child: Icon(Icons.local_florist_outlined, size: 72, color: _mkGreen),
                      ),
                    )
                  : Stack(children: [
                      PageView.builder(
                        controller: _pageCtrl,
                        itemCount: ad.photos.length,
                        onPageChanged: (i) => setState(() => _photoPage = i),
                        itemBuilder: (_, i) => Image.network(
                          ad.photos[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: _mkLight,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 48, color: _mkTextSecondary),
                          ),
                        ),
                      ),
                      if (ad.photos.length > 1)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              ad.photos.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _photoPage ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i == _photoPage
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: _mkCard,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _StatusChip(status: ad.status),
                    const Spacer(),
                    if (ad.expiresAt != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.timer_outlined, size: 12, color: _mkTextSecondary),
                        const SizedBox(width: 3),
                        Text(_daysLeft(ad.expiresAt),
                            style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
                      ]),
                  ]),
                  const SizedBox(height: 10),
                  Text(ad.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, color: _mkTextPrimary)),
                  const SizedBox(height: 10),
                  if (ad.pricePerUnit != null)
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text('₹${ad.pricePerUnit!.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900, color: _mkGreen)),
                      if (ad.priceUnit != null)
                        Text(' / ${ad.priceUnit}',
                            style: AppTypography.body.copyWith(color: _mkTextSecondary)),
                    ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (ad.quantity != null)
                      _Chip('${ad.quantity} available', _mkLight, _mkDark),
                    if (ad.sizeDescription != null)
                      _Chip(ad.sizeDescription!, _stDraftBg, _stDraft),
                    if (ad.categoryName != null)
                      _Chip(ad.categoryName!, _stPublishedBg, _stPublished),
                    _Chip(ad.plantName, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                  ]),
                  if (ad.description != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: _mkBorder),
                    const SizedBox(height: 12),
                    Text(ad.description!,
                        style: AppTypography.body.copyWith(
                            color: _mkTextPrimary.withValues(alpha: 0.85), height: 1.6)),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    _ti(Icons.visibility_outlined, '${ad.viewCount} views'),
                    const SizedBox(width: 16),
                    _ti(Icons.bookmark_outline_rounded, '${ad.saveCount} saved'),
                    if (ad.enquiryCount > 0) ...[
                      const SizedBox(width: 16),
                      _ti(Icons.mail_outline_rounded, '${ad.enquiryCount} enquiries'),
                    ],
                  ]),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _mkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _mkBorder),
                boxShadow: const [_cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(color: _mkLight, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          ad.nurseryName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              color: _mkGreen, fontWeight: FontWeight.w800, fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            if (ad.nurseryVerified)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.verified_rounded, size: 13, color: _mkGreen),
                              ),
                            Expanded(
                              child: Text(ad.nurseryName,
                                  style: AppTypography.h4.copyWith(color: _mkTextPrimary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                          if (ad.nurseryMobile != null)
                            Text(ad.nurseryMobile!,
                                style: AppTypography.caption.copyWith(color: _mkTextSecondary))
                          else
                            Text('Nursery',
                                style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
                        ],
                      ),
                    ),
                  ]),
                  if (ad.nurseryMobile != null) ...[
                    const SizedBox(height: 14),
                    const Divider(color: _mkBorder, height: 1),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _mkGreen,
                            side: const BorderSide(color: _mkGreen),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: const Text('Call',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () => launchUrl(
                              Uri(scheme: 'tel', path: ad.nurseryMobile!)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 16),
                          label: const Text('WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () {
                            final digits = ad.nurseryMobile!.replaceAll(RegExp(r'\D'), '');
                            final number = digits.startsWith('91') ? digits : '91$digits';
                            launchUrl(Uri.parse('https://wa.me/$number'),
                                mode: LaunchMode.externalApplication);
                          },
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
      bottomNavigationBar: effectiveIsOwn
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                    color: _mkCard,
                    border: Border(top: BorderSide(color: _mkBorder))),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Send Enquiry',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    onPressed: () => _showEnquirySheet(context, ad),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _ti(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _mkTextSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
        ],
      );

  void _showMoreSheet(BuildContext context, MarketAd ad) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: _mkBorder, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: _stExpired),
                title: const Text('Report this ad',
                    style: TextStyle(
                        color: _stExpired, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showReportSheet(context, ad);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context, MarketAd ad) {
    // Keys are API codes; values are display labels
    const reasons = {
      'SPAM':        'Spam or misleading',
      'FRAUD':       'Fake listing / fraud',
      'WRONG_PLANT': 'Wrong plant / misleading info',
      'DUPLICATE':   'Duplicate listing',
      'OTHER':       'Other',
    };
    String? selected;
    final notesCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: _mkBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                const Icon(Icons.flag_outlined, color: _stExpired, size: 20),
                const SizedBox(width: 8),
                Text('Report Ad',
                    style: AppTypography.h4.copyWith(
                        color: _mkTextPrimary, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text('Help us understand the issue',
                  style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
              const SizedBox(height: 12),
              for (final entry in reasons.entries)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value,
                      style: TextStyle(
                          color: _mkTextPrimary,
                          fontWeight: selected == entry.key
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 14)),
                  value: entry.key,
                  groupValue: selected,
                  activeColor: _mkGreen,
                  onChanged: (v) => setS(() => selected = v),
                ),
              if (selected == 'OTHER') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: _inputDec('Add details (optional)'),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _stExpired,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: selected == null || submitting
                      ? null
                      : () async {
                          setS(() => submitting = true);
                          try {
                            final notes = notesCtrl.text.trim();
                            await ref.read(reportAdProvider(ad.id).notifier).report(
                                  selected!,
                                  notes: notes.isEmpty ? null : notes,
                                );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Report submitted. Thank you.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setS(() => submitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: _stExpired,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Report',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEnquirySheet(BuildContext context, MarketAd ad) {
    final msgCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EnquirySheet(ad: ad, msgCtrl: msgCtrl, qtyCtrl: qtyCtrl),
    );
  }
}

class _EnquirySheet extends ConsumerStatefulWidget {
  final MarketAd ad;
  final TextEditingController msgCtrl;
  final TextEditingController qtyCtrl;
  const _EnquirySheet({required this.ad, required this.msgCtrl, required this.qtyCtrl});

  @override
  ConsumerState<_EnquirySheet> createState() => _EnquirySheetState();
}

class _EnquirySheetState extends ConsumerState<_EnquirySheet> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _mkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _mkBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Send Enquiry',
                style: AppTypography.h3.copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.ad.title,
                style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
            const SizedBox(height: 20),
            TextField(
              controller: widget.msgCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: _inputDec('Describe what you need...'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDec('Quantity needed (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mkGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _sending ? null : () async {
                  final msg = widget.msgCtrl.text.trim();
                  if (msg.isEmpty) return;
                  setState(() => _sending = true);
                  try {
                    final qty = int.tryParse(widget.qtyCtrl.text.trim());
                    await ref.read(sendEnquiryProvider(widget.ad.id).notifier)
                        .send(msg, qty: qty);
                    if (mounted) Navigator.of(context).pop();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: _stExpired,
                          behavior: SnackBarBehavior.floating));
                    }
                  } finally {
                    if (mounted) setState(() => _sending = false);
                  }
                },
                child: _sending
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Enquiry',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 6. POST AD SCREEN (multi-step wizard)
// ══════════════════════════════════════════════════════════════════════════════

class _PostAdScreen extends ConsumerStatefulWidget {
  final MarketAd? editingAd;
  const _PostAdScreen({this.editingAd});

  @override
  ConsumerState<_PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<_PostAdScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Form fields
  final _plantCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _qtyCtrl   = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _sizeCtrl  = TextEditingController();

  List<XFile> _pickedFiles = [];
  List<String> _existingPhotos = [];
  String? _selectedCategory;
  bool _saving = false;
  bool _publishing = false;

  static const _categories = [
    'Fruit Plants',
    'Flower Plants',
    'Forest Plants',
    'Ornamentals',
  ];

  @override
  void initState() {
    super.initState();
    _plantCtrl.addListener(_onRequiredFieldChanged);
    _titleCtrl.addListener(_onRequiredFieldChanged);
    final ad = widget.editingAd;
    if (ad != null) {
      _plantCtrl.text = ad.plantName;
      _titleCtrl.text = ad.title;
      _descCtrl.text  = ad.description ?? '';
      _qtyCtrl.text   = ad.quantity?.toString() ?? '';
      _priceCtrl.text = ad.pricePerUnit?.toStringAsFixed(0) ?? '';
      _sizeCtrl.text  = ad.sizeDescription ?? '';
      _existingPhotos = List<String>.from(ad.photos);
      _selectedCategory = ad.categoryName;
    }
  }

  void _onRequiredFieldChanged() => setState(() {});

  @override
  void dispose() {
    _plantCtrl.removeListener(_onRequiredFieldChanged);
    _titleCtrl.removeListener(_onRequiredFieldChanged);
    _pageCtrl.dispose();
    _plantCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  bool get _step1Valid => _titleCtrl.text.trim().isNotEmpty;

  String get _effectivePlantName {
    final p = _plantCtrl.text.trim();
    return p.isNotEmpty ? p : _titleCtrl.text.trim();
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final uploaded = await _uploadNew();
      final photos = [..._existingPhotos, ...uploaded];
      final plantName = _effectivePlantName;
      if (widget.editingAd != null) {
        await ref.read(postAdProvider.notifier).update(
          widget.editingAd!.id,
          plantName: plantName.isNotEmpty ? plantName : null,
          title: _titleCtrl.text.trim(),
          categoryName: _selectedCategory,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          quantity: int.tryParse(_qtyCtrl.text.trim()),
          pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
          sizeDescription: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
          photos: photos,
        );
      } else {
        await ref.read(postAdProvider.notifier).create(
          plantName: plantName,
          title: _titleCtrl.text.trim(),
          categoryName: _selectedCategory,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          quantity: int.tryParse(_qtyCtrl.text.trim()),
          pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
          sizeDescription: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
          photos: photos,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: _stExpired,
          behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final uploaded = await _uploadNew();
      final photos = [..._existingPhotos, ...uploaded];
      int adId;
      final plantName = _effectivePlantName;
      if (widget.editingAd != null) {
        await ref.read(postAdProvider.notifier).update(
          widget.editingAd!.id,
          plantName: plantName.isNotEmpty ? plantName : null,
          title: _titleCtrl.text.trim(),
          categoryName: _selectedCategory,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          quantity: int.tryParse(_qtyCtrl.text.trim()),
          pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
          sizeDescription: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
          photos: photos,
        );
        adId = widget.editingAd!.id;
      } else {
        adId = await ref.read(postAdProvider.notifier).create(
          plantName: plantName,
          title: _titleCtrl.text.trim(),
          categoryName: _selectedCategory,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          quantity: int.tryParse(_qtyCtrl.text.trim()),
          pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
          sizeDescription: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
          photos: photos,
        );
      }
      // Only publish if the ad is in DRAFT state (already-live ads just need the update)
      final currentStatus = widget.editingAd?.status;
      final needsPublish = currentStatus == null ||
          currentStatus == 'DRAFT' ||
          currentStatus == 'PAUSED';
      if (needsPublish) {
        await ref.read(adActionProvider.notifier).perform(adId, 'publish');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: _stExpired,
          behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<List<String>> _uploadNew() async {
    final results = <String>[];
    for (final f in _pickedFiles) {
      final url = await uploadAdPhoto(f, ref.read(marketRepositoryProvider));
      results.add(url);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(widget.editingAd != null ? 'Edit Ad' : 'Post Ad'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: List.generate(3, (i) {
                  final done = i < _step;
                  final active = i == _step;
                  return Expanded(
                    child: Row(children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: done || active ? _mkGreen : _mkBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 6),
                    ]),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stepLabel(0, 'Details'),
                  _stepLabel(1, 'Photos'),
                  _stepLabel(2, 'Preview'),
                ],
              ),
            ),
          ]),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _DetailsStep(
            plantCtrl: _plantCtrl,
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            qtyCtrl: _qtyCtrl,
            priceCtrl: _priceCtrl,
            sizeCtrl: _sizeCtrl,
            selectedCategory: _selectedCategory,
            categories: _categories,
            onCategoryChanged: (c) => setState(() => _selectedCategory = c),
          ),
          _PhotosStep(
            existingPhotos: _existingPhotos,
            pickedFiles: _pickedFiles,
            onExistingRemoved: (url) => setState(() => _existingPhotos.remove(url)),
            onNewPicked: (files) => setState(() => _pickedFiles.addAll(files)),
            onNewRemoved: (f) => setState(() => _pickedFiles.remove(f)),
          ),
          _PreviewStep(
            plantCtrl: _plantCtrl,
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            qtyCtrl: _qtyCtrl,
            priceCtrl: _priceCtrl,
            sizeCtrl: _sizeCtrl,
            existingPhotos: _existingPhotos,
            pickedFiles: _pickedFiles,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
              color: _mkCard, border: Border(top: BorderSide(color: _mkBorder))),
          child: Row(children: [
            if (_step > 0)
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mkTextSecondary,
                    side: const BorderSide(color: _mkBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving || _publishing ? null : () => _goTo(_step - 1),
                  child: const Text('Back',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            if (_step == 2) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mkGreen,
                    side: const BorderSide(color: _mkGreen),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving || _publishing ? null : _saveDraft,
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _mkGreen))
                      : const Text('Save Draft',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving || _publishing ? null : _publish,
                  child: _publishing
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          widget.editingAd?.status == 'PUBLISHED' ||
                                  widget.editingAd?.status == 'PAUSED'
                              ? 'Save Changes'
                              : 'Publish',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ] else
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_step == 0 && !_step1Valid) ? null : () => _goTo(_step + 1),
                  child: const Text('Next',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _stepLabel(int i, String label) {
    final active = _step == i;
    return Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _mkGreen : _mkTextSecondary));
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController plantCtrl, titleCtrl, descCtrl, qtyCtrl, priceCtrl, sizeCtrl;
  final String? selectedCategory;
  final List<String> categories;
  final ValueChanged<String?> onCategoryChanged;

  const _DetailsStep({
    required this.plantCtrl,
    required this.titleCtrl,
    required this.descCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.sizeCtrl,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('Ad Title *'),
        TextField(controller: titleCtrl, maxLength: 120, decoration: _inputDec('What are you selling?')),
        const SizedBox(height: 14),
        _label('Plant Name'),
        TextField(controller: plantCtrl, decoration: _inputDec('e.g. Mango, Rose, Gulmohar...')),
        const SizedBox(height: 14),
        _label('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...categories.map((c) {
              final sel = selectedCategory == c;
              return ChoiceChip(
                label: Text(c,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : _mkTextSecondary)),
                selected: sel,
                onSelected: (_) => onCategoryChanged(sel ? null : c),
                selectedColor: _mkGreen,
                backgroundColor: _mkCard,
                side: BorderSide(color: sel ? _mkGreen : _mkBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              );
            }),
          ],
        ),
        const SizedBox(height: 14),
        _label('Description'),
        TextField(
            controller: descCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: _inputDec('Describe the plants, condition, and any details...')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Quantity'),
              TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDec('e.g. 50')),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Price / unit (₹)'),
              TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDec('e.g. 120')),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        _label('Size / Height'),
        TextField(
            controller: sizeCtrl, decoration: _inputDec('e.g. 3-4 ft, 2 years old...')),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: _mkTextPrimary)));
}

class _PhotosStep extends StatelessWidget {
  final List<String> existingPhotos;
  final List<XFile> pickedFiles;
  final void Function(String) onExistingRemoved;
  final void Function(List<XFile>) onNewPicked;
  final void Function(XFile) onNewRemoved;

  const _PhotosStep({
    required this.existingPhotos,
    required this.pickedFiles,
    required this.onExistingRemoved,
    required this.onNewPicked,
    required this.onNewRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Photos',
            style: AppTypography.h3.copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Add up to 6 photos. First photo is the cover.',
            style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            ...existingPhotos.map((url) => _PhotoTile(
                  child: Image.network(url, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined,
                          color: _mkTextSecondary)),
                  onRemove: () => onExistingRemoved(url),
                )),
            ...pickedFiles.map((f) => _PhotoTile(
                  child: Image.network(f.path, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.photo_outlined,
                          color: _mkTextSecondary)),
                  onRemove: () => onNewRemoved(f),
                )),
            if (existingPhotos.length + pickedFiles.length < 6)
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final files = await picker.pickMultiImage(limit: 6);
                  if (files.isNotEmpty) onNewPicked(files);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _mkBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _mkBorder, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: _mkGreen, size: 28),
                      SizedBox(height: 4),
                      Text('Add Photo',
                          style: TextStyle(
                              fontSize: 10, color: _mkGreen, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _PhotoTile({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.expand(child: child),
      ),
      Positioned(
        top: 4, right: 4,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
                color: Color(0xDD000000), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
          ),
        ),
      ),
    ]);
  }
}

class _PreviewStep extends StatelessWidget {
  final TextEditingController plantCtrl, titleCtrl, descCtrl, qtyCtrl, priceCtrl, sizeCtrl;
  final List<String> existingPhotos;
  final List<XFile> pickedFiles;

  const _PreviewStep({
    required this.plantCtrl,
    required this.titleCtrl,
    required this.descCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.sizeCtrl,
    required this.existingPhotos,
    required this.pickedFiles,
  });

  @override
  Widget build(BuildContext context) {
    final allPhotos = [...existingPhotos, ...pickedFiles.map((f) => f.path)];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Preview',
            style: AppTypography.h3.copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('This is how your ad will look.',
            style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _mkCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _mkBorder),
            boxShadow: const [_cardShadow],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allPhotos.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: Image.network(allPhotos.first,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: _mkLight,
                          child: const Icon(Icons.local_florist_outlined,
                              size: 56, color: _mkGreen)))
                )
              else
                Container(
                  height: 160,
                  color: _mkLight,
                  child: const Center(
                    child: Icon(Icons.local_florist_outlined, size: 56, color: _mkGreen),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleCtrl.text.trim().isEmpty ? 'Ad Title' : titleCtrl.text.trim(),
                        style: AppTypography.h4.copyWith(color: _mkTextPrimary)),
                    const SizedBox(height: 6),
                    if (priceCtrl.text.trim().isNotEmpty)
                      Text('₹${priceCtrl.text.trim()} / unit',
                          style: const TextStyle(
                              color: _mkGreen, fontWeight: FontWeight.w800, fontSize: 18)),
                    if (qtyCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Chip('${qtyCtrl.text.trim()} available', _mkLight, _mkDark),
                    ],
                    if (descCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(descCtrl.text.trim(),
                          style: AppTypography.body.copyWith(color: _mkTextPrimary, height: 1.5),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 7. SAVED ADS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _SavedAdsScreen extends ConsumerWidget {
  const _SavedAdsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(savedAdsProvider);

    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: const Text('Saved Ads'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _mkBorder)),
      ),
      body: adsAsync.when(
        loading: () => const _SkeletonList(),
        error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(savedAdsProvider)),
        data: (ads) {
          if (ads.isEmpty) {
            return const _EmptyState(
              icon: Icons.bookmark_outline_rounded,
              title: 'No saved ads',
              subtitle: 'Bookmark ads you are interested in to find them here',
            );
          }
          return RefreshIndicator(
            color: _mkGreen,
            backgroundColor: _mkCard,
            onRefresh: () async => ref.invalidate(savedAdsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: ads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _BrowseAdCard(ad: ads[i]),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 8. ENQUIRIES SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _EnquiriesScreen extends ConsumerWidget {
  const _EnquiriesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _mkBg,
        appBar: AppBar(
          title: const Text('Enquiries'),
          backgroundColor: _mkCard,
          foregroundColor: _mkTextPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            labelColor: _mkGreen,
            unselectedLabelColor: _mkTextSecondary,
            indicatorColor: _mkGreen,
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _EnquiryList(provider: receivedEnquiriesProvider, isReceived: true),
            _EnquiryList(provider: sentEnquiriesProvider, isReceived: false),
          ],
        ),
      ),
    );
  }
}

class _EnquiryList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<MarketEnquiry>>> provider;
  final bool isReceived;
  const _EnquiryList({required this.provider, required this.isReceived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(provider)),
      data: (enquiries) {
        if (enquiries.isEmpty) {
          return _EmptyState(
            icon: Icons.mail_outline_rounded,
            title: isReceived ? 'No enquiries received' : 'No enquiries sent',
            subtitle: isReceived
                ? 'Enquiries from buyers will appear here'
                : 'Enquiries you send to sellers will appear here',
          );
        }
        return RefreshIndicator(
          color: _mkGreen,
          backgroundColor: _mkCard,
          onRefresh: () async => ref.invalidate(provider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: enquiries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _EnquiryCard(
                enquiry: enquiries[i], isReceived: isReceived),
          ),
        );
      },
    );
  }
}

class _EnquiryCard extends StatelessWidget {
  final MarketEnquiry enquiry;
  final bool isReceived;
  const _EnquiryCard({required this.enquiry, required this.isReceived});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _EnquiryDetailScreen(
              enquiry: enquiry, isAdOwner: isReceived))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _mkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _mkBorder),
          boxShadow: const [_cardShadow],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: _mkLight, shape: BoxShape.circle),
            child: Center(
              child: Text(
                isReceived
                    ? enquiry.enquiryNurseryName.substring(0, 1).toUpperCase()
                    : enquiry.adNurseryName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: _mkGreen, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      isReceived
                          ? enquiry.enquiryNurseryName
                          : enquiry.adNurseryName,
                      style: AppTypography.label.copyWith(
                          color: _mkTextPrimary, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(_timeAgo(enquiry.createdAt),
                      style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
                ]),
                const SizedBox(height: 2),
                Text(enquiry.adTitle,
                    style: AppTypography.caption.copyWith(color: _mkTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(enquiry.message,
                    style: AppTypography.body.copyWith(color: _mkTextPrimary, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  _EnquiryStatusChip(status: enquiry.status),
                  if (enquiry.quantityNeeded != null) ...[
                    const SizedBox(width: 6),
                    _Chip('Qty: ${enquiry.quantityNeeded}', _mkLight, _mkDark),
                  ],
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 9. ENQUIRY DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _EnquiryDetailScreen extends ConsumerStatefulWidget {
  final MarketEnquiry enquiry;
  final bool isAdOwner;
  const _EnquiryDetailScreen({required this.enquiry, required this.isAdOwner});

  @override
  ConsumerState<_EnquiryDetailScreen> createState() => _EnquiryDetailScreenState();
}

class _EnquiryDetailScreenState extends ConsumerState<_EnquiryDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _replying = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _replying = true);
    try {
      await ref.read(replyEnquiryProvider(widget.enquiry.id).notifier).reply(body);
      _replyCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: _stExpired,
          behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(enquiryDetailProvider(widget.enquiry.id));

    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(widget.enquiry.adTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _mkBorder)),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _mkGreen)),
        error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(enquiryDetailProvider(widget.enquiry.id))),
        data: (enquiry) {
          final myNurseryName = widget.isAdOwner
              ? enquiry.adNurseryName
              : enquiry.enquiryNurseryName;

          return Column(children: [
            _EnquiryDetailHeader(enquiry: enquiry),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: enquiry.messages.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _MessageBubble(
                      body: enquiry.message,
                      senderName: enquiry.enquiryNurseryName,
                      isMe: !widget.isAdOwner,
                      time: enquiry.createdAt,
                    );
                  }
                  final msg = enquiry.messages[i - 1];
                  return _MessageBubble(
                    body: msg.body,
                    senderName: msg.nurseryName,
                    isMe: msg.nurseryName == myNurseryName,
                    time: msg.createdAt,
                  );
                },
              ),
            ),
            if (!const {'CLOSED', 'CANCELLED'}.contains(enquiry.status))
              _ReplyInput(
                controller: _replyCtrl,
                replying: _replying,
                onSend: _sendReply,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                    color: _mkCard,
                    border: Border(top: BorderSide(color: _mkBorder))),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 16, color: _mkTextSecondary),
                    const SizedBox(width: 8),
                    Text(
                      enquiry.status == 'CANCELLED'
                          ? 'This enquiry was cancelled'
                          : 'This enquiry is closed',
                      style: AppTypography.caption.copyWith(color: _mkTextSecondary),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _EnquiryDetailHeader extends StatelessWidget {
  final MarketEnquiry enquiry;
  const _EnquiryDetailHeader({required this.enquiry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _mkCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(enquiry.adTitle,
                  style: AppTypography.label.copyWith(
                      color: _mkTextPrimary, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Text('${enquiry.enquiryNurseryName} → ${enquiry.adNurseryName}',
                    style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _EnquiryStatusChip(status: enquiry.status),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String body;
  final String senderName;
  final bool isMe;
  final DateTime time;
  const _MessageBubble({
    required this.body,
    required this.senderName,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: _mkLight, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  senderName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: _mkGreen, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text(senderName,
                        style: AppTypography.caption.copyWith(
                            color: _mkTextSecondary, fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _mkGreen : _mkCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border: isMe ? null : Border.all(color: _mkBorder),
                    boxShadow: const [_cardShadow],
                  ),
                  child: Text(body,
                      style: TextStyle(
                          color: isMe ? Colors.white : _mkTextPrimary,
                          fontSize: 14,
                          height: 1.45)),
                ),
                const SizedBox(height: 3),
                Text(_timeAgo(time),
                    style: AppTypography.caption
                        .copyWith(color: _mkTextSecondary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ReplyInput extends StatelessWidget {
  final TextEditingController controller;
  final bool replying;
  final VoidCallback onSend;
  const _ReplyInput({required this.controller, required this.replying, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
          color: _mkCard, border: Border(top: BorderSide(color: _mkBorder))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: _inputDec('Write a reply...').copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: 1.0,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: _mkGreen, shape: BoxShape.circle),
              child: replying
                  ? const Center(
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ))
                  : IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: onSend,
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 10. MARKET SETTINGS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class _MarketSettingsScreen extends StatefulWidget {
  const _MarketSettingsScreen();

  @override
  State<_MarketSettingsScreen> createState() => _MarketSettingsState();
}

class _MarketSettingsState extends State<_MarketSettingsScreen> {
  bool _marketActive = true;
  bool _showPhone = true;
  bool _autoRenew = false;
  bool _notifyEnquiries = true;
  bool _notifyExpiry = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: const Text('Market Settings'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _mkBorder)),
      ),
      body: ListView(
        children: [
          _settingsSection('Market Status', [
            _SwitchTile(
              icon: Icons.storefront_outlined,
              title: 'Market Active',
              subtitle: 'Show your nursery on the local market',
              value: _marketActive,
              onChanged: (v) => setState(() => _marketActive = v),
            ),
          ]),
          _settingsSection('Privacy', [
            _SwitchTile(
              icon: Icons.phone_outlined,
              title: 'Show Phone Number',
              subtitle: 'Buyers can see your nursery phone number',
              value: _showPhone,
              onChanged: (v) => setState(() => _showPhone = v),
            ),
          ]),
          _settingsSection('Ad Settings', [
            _SwitchTile(
              icon: Icons.refresh_rounded,
              title: 'Auto-Renew Ads',
              subtitle: 'Automatically renew ads before they expire',
              value: _autoRenew,
              onChanged: (v) => setState(() => _autoRenew = v),
            ),
          ]),
          _settingsSection('Notifications', [
            _SwitchTile(
              icon: Icons.mail_outline_rounded,
              title: 'Enquiry Alerts',
              subtitle: 'Notify me when I receive a new enquiry',
              value: _notifyEnquiries,
              onChanged: (v) => setState(() => _notifyEnquiries = v),
            ),
            _SwitchTile(
              icon: Icons.timer_outlined,
              title: 'Expiry Alerts',
              subtitle: 'Notify me 3 days before an ad expires',
              value: _notifyExpiry,
              onChanged: (v) => setState(() => _notifyExpiry = v),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _settingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title,
              style: AppTypography.caption.copyWith(
                  color: _mkTextSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _mkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _mkBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: _mkGreen, size: 22),
      title: Text(title,
          style: AppTypography.label.copyWith(
              color: _mkTextPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: AppTypography.caption.copyWith(color: _mkTextSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: _mkGreen,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ══════════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'PUBLISHED' => ('Published', _stPublished, _stPublishedBg),
      'DRAFT'     => ('Draft', _stDraft, _stDraftBg),
      'PAUSED'    => ('Paused', _stPaused, _stPausedBg),
      'EXPIRED'   => ('Expired', _stExpired, _stExpiredBg),
      'ARCHIVED'  => ('Archived', _stArchived, _stArchivedBg),
      _           => (status, _stDraft, _stDraftBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _EnquiryStatusChip extends StatelessWidget {
  final String status;
  const _EnquiryStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'NEW'                => ('New', _stPublished, _stPublishedBg),
      'IN_PROGRESS'        => ('In Progress', _stPaused, _stPausedBg),
      'QUOTATION_CREATED'  => ('Quoted', const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
      'CLOSED'             => ('Closed', _stArchived, _stArchivedBg),
      'CANCELLED'          => ('Cancelled', _stExpired, _stExpiredBg),
      _                    => (status, _stDraft, _stDraftBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(title,
            style: AppTypography.h4.copyWith(
                color: _mkTextPrimary, fontWeight: FontWeight.w800)),
      ),
      if (actionLabel != null && onAction != null)
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor: _mkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 4)),
          onPressed: onAction,
          child: Text(actionLabel!,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _mkGreen)),
        ),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: _mkLight, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: _mkGreen),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: AppTypography.h3.copyWith(
                    color: _mkTextPrimary, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTypography.body.copyWith(color: _mkTextSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: _mkTextSecondary),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: AppTypography.h4.copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                style: AppTypography.caption.copyWith(color: _mkTextSecondary),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _mkGreen,
                side: const BorderSide(color: _mkGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: _mkBorder,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _mkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _mkBorder),
        boxShadow: const [_cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 196, color: _mkBorder.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 80, height: 10),
                const SizedBox(height: 8),
                const _SkeletonBox(width: double.infinity, height: 14),
                const SizedBox(height: 6),
                const _SkeletonBox(width: 160, height: 14),
                const SizedBox(height: 12),
                const _SkeletonBox(width: 60, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}
