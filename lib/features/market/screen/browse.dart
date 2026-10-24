part of '../local_market_screen.dart';

class _BrowseScreen extends ConsumerStatefulWidget {
  final bool autoFocus;

  /// SELL (for sale) or WANT (wanted posts) to open on.
  final String type;

  /// Open with the Filters panel showing (from "Change" on the home).
  final bool openFilters;

  const _BrowseScreen({
    this.autoFocus = false,
    this.type = 'SELL',
    this.openFilters = false,
  });

  @override
  ConsumerState<_BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<_BrowseScreen> {
  final _searchCtrl = TextEditingController();
  late final FocusNode _focus;
  late final ScrollController _scroll;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
      ref.read(browseAdsProvider.notifier).setType(widget.type);
      if (widget.autoFocus) _focus.requestFocus();
      if (widget.openFilters) _openFilters();
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

  void _openFilters() {
    FocusScope.of(context).unfocus();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showSortSheet() {
    // Otherwise the search box takes focus back and the keyboard reopens.
    FocusScope.of(context).unfocus();
    final notifier = ref.read(browseAdsProvider.notifier);
    final currentSort = ref.read(browseAdsProvider).sort;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  color: _mkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Sort by',
                style: AppTypography.h4.copyWith(
                  color: _mkTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final s in MarketSort.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.label,
                  style: TextStyle(
                    color: currentSort == s ? _mkGreen : _mkTextPrimary,
                    fontWeight:
                        currentSort == s ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
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
    final radius = (browse.radiusKm ?? kDefaultRadiusKm).round();

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const _MarketFiltersDrawer(),
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(browse.type == 'WANT' ? 'Wanted' : 'For sale'),
        // The Filters button opens the side panel; no extra menu icon.
        automaticallyImplyActions: false,
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(hasFilters ? 189 : 145),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'SELL',
                      label: Text('For sale'),
                      icon: Icon(Icons.storefront_outlined),
                    ),
                    ButtonSegment(
                      value: 'WANT',
                      label: Text('Wanted'),
                      icon: Icon(Icons.campaign_outlined),
                    ),
                  ],
                  selected: {browse.type},
                  showSelectedIcon: false,
                  // The selected side takes its type's colour.
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? (browse.type == 'WANT' ? _wantBg : _saleBg)
                          : null,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? (browse.type == 'WANT' ? _wantColor : _saleColor)
                          : _mkTextSecondary,
                    ),
                  ),
                  onSelectionChanged: (v) =>
                      ref.read(browseAdsProvider.notifier).setType(v.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focus,
                  onChanged: (q) =>
                      ref.read(browseAdsProvider.notifier).onQueryChanged(q),
                  decoration: _inputDec('Search plants...').copyWith(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _mkGreen,
                      size: 20,
                    ),
                    suffixIcon: browse.query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(browseAdsProvider.notifier)
                                  .onQueryChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _mkBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              // Every control labelled, in one row: no unlabelled icons.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    // The market is always local; this shows how far.
                    _controlButton(
                      icon: Icons.location_on_rounded,
                      label: '$radius km',
                      active: true,
                      onTap: _openFilters,
                    ),
                    const SizedBox(width: 8),
                    _controlButton(
                      icon: Icons.tune_rounded,
                      label: hasFilters ? 'Filters ($filterCount)' : 'Filters',
                      active: hasFilters,
                      onTap: _openFilters,
                    ),
                    const SizedBox(width: 8),
                    // Sort takes the rest, right-aligned; only it may shorten.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _controlButton(
                          icon: Icons.swap_vert_rounded,
                          label: switch (browse.sort) {
                            MarketSort.newest => 'Newest',
                            MarketSort.oldest => 'Oldest',
                            MarketSort.name => 'Name A–Z',
                            MarketSort.priceAsc => 'Price ↑',
                            MarketSort.priceDesc => 'Price ↓',
                            MarketSort.popular => 'Popular',
                          },
                          active: browse.sort != MarketSort.newest,
                          trailing: Icons.arrow_drop_down_rounded,
                          onTap: _showSortSheet,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFilters) _activeFilterChips(browse),
              const Divider(height: 1, color: _mkBorder),
            ],
          ),
        ),
      ),
      body: _buildBody(browse),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? trailing,
  }) {
    final fg = active ? _mkDark : _mkTextSecondary;
    return Material(
      color: active ? _mkLight : _mkCard,
      shape: StadiumBorder(
        side: BorderSide(color: active ? _mkGreen : _mkBorder),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? _mkGreen : fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) Icon(trailing, size: 18, color: fg),
            ],
          ),
        ),
      ),
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
            _activeChip(
              browse.category!,
              onRemove: () => notifier.setFilters(
                category: null,
                minPrice: browse.minPrice,
                maxPrice: browse.maxPrice,
              ),
            ),
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
            child: const Text(
              'Clear All',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
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
            Text(
              label,
              style: const TextStyle(
                color: _mkDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 14, color: _mkDark),
            ),
          ],
        ),
      );

  Widget _buildBody(BrowseAdsState browse) {
    if (browse.isLoading) return const _SkeletonList();

    if (browse.error != null && browse.ads.isEmpty) {
      return _ErrorState(
        message: browse.error!,
        // A missing location is fixed by asking for it again.
        onRetry: () {
          ref.invalidate(marketPositionProvider);
          ref.read(browseAdsProvider.notifier).refresh();
        },
      );
    }

    if (browse.ads.isEmpty) {
      final km = (browse.radiusKm ?? kDefaultRadiusKm).round();
      final searching = browse.query.isNotEmpty || browse.activeFilterCount > 0;
      return _EmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.location_searching_rounded,
        title: searching ? 'No matches within $km km' : 'No ads within $km km',
        subtitle: km < kMaxRadiusKm
            ? 'Try a larger distance in Filters${searching ? ', or a different search' : ''}'
            : searching
                ? 'Try a different search or fewer filters'
                : 'Nothing nearby yet. Post what you have, or check back soon',
      );
    }

    return Column(
      children: [
        Container(
          color: _mkCard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${browse.total} result${browse.total == 1 ? '' : 's'}',
                style: AppTypography.caption.copyWith(color: _mkTextSecondary),
              ),
            ],
          ),
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
                horizontal: AppSpacing.screenPadding,
                vertical: 16,
              ),
              itemCount: browse.ads.length + (browse.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                if (i == browse.ads.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _mkGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                return _BrowseAdCard(ad: browse.ads[i]);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. BROWSE AD CARD
// ══════════════════════════════════════════════════════════════════════════════

/// One ad in a list: a compact row so several ads fit on a screen.
/// Green border and label for FOR SALE, orange for WANTED.
/// Side panel with everything that narrows the list: how far (saved per
/// account), category and price. Sort stays a one-tap button on the screen.
class _MarketFiltersDrawer extends ConsumerStatefulWidget {
  const _MarketFiltersDrawer();

  @override
  ConsumerState<_MarketFiltersDrawer> createState() =>
      _MarketFiltersDrawerState();
}

class _MarketFiltersDrawerState extends ConsumerState<_MarketFiltersDrawer> {
  static const _cats = ['Fruit Plants', 'Flower Plants', 'Forest Plants', 'Ornamentals'];

  late double _radius;
  String? _cat;
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final b = ref.read(browseAdsProvider);
    _radius = ref.read(marketRadiusProvider);
    _cat = b.category;
    _min = TextEditingController(text: b.minPrice?.toStringAsFixed(0) ?? '');
    _max = TextEditingController(text: b.maxPrice?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(browseAdsProvider.notifier)
      ..setArea(radiusKm: _radius)
      ..setFilters(
        category: _cat,
        minPrice: double.tryParse(_min.text.trim()),
        maxPrice: double.tryParse(_max.text.trim()),
      );
    ref.read(marketRadiusProvider.notifier).save(_radius);
    Navigator.of(context).pop();
  }

  void _reset() => setState(() {
        _radius = kDefaultRadiusKm;
        _cat = null;
        _min.clear();
        _max.clear();
      });

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          t,
          style: const TextStyle(
            color: _mkTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(marketPositionProvider);
    final usingPhone = pos.valueOrNull != null;
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(0, 380) * 0.9,
      backgroundColor: _mkCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Filters',
                    style: AppTypography.h3.copyWith(color: _mkTextPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _heading('DISTANCE'),
                  Text(
                    'Within ${_radius.round()} km of you',
                    style: const TextStyle(
                      color: _mkDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Slider(
                    value: _radius,
                    min: kMinRadiusKm,
                    max: kMaxRadiusKm,
                    divisions: 9,
                    label: '${_radius.round()} km',
                    activeColor: _mkGreen,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('10 km', style: TextStyle(color: _mkTextSecondary, fontSize: 12)),
                      Text('100 km max', style: TextStyle(color: _mkTextSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        usingPhone ? Icons.my_location_rounded : Icons.home_work_outlined,
                        size: 16,
                        color: _mkGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pos.isLoading
                              ? 'Finding your location...'
                              : usingPhone
                                  ? "Measured from your phone's location."
                                  : "Measured from your nursery's address. Turn on location for distances from where you are.",
                          style: AppTypography.caption.copyWith(color: _mkTextSecondary),
                        ),
                      ),
                    ],
                  ),
                  if (!usingPhone && !pos.isLoading)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(marketPositionProvider),
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('Use my location'),
                      ),
                    ),
                  _heading('CATEGORY'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in [null, ..._cats])
                        ChoiceChip(
                          label: Text(c ?? 'All'),
                          selected: _cat == c,
                          onSelected: (_) => setState(() => _cat = c),
                          selectedColor: _mkGreen,
                          labelStyle: TextStyle(
                            color: _cat == c ? Colors.white : _mkTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  _heading('PRICE PER PLANT (₹)'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _min,
                          keyboardType: TextInputType.number,
                          inputFormatters: NumberInput.money,
                          decoration: _inputDec('Min'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('–', style: TextStyle(color: _mkTextSecondary)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _max,
                          keyboardType: TextInputType.number,
                          inputFormatters: NumberInput.money,
                          decoration: _inputDec('Max'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Buttons sit in Expanded: the app theme makes buttons full-width,
            // which cannot be laid out side by side otherwise.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _mkBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('Reset'),
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
                      ),
                      onPressed: _apply,
                      child: const Text(
                        'Show results',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDeleteAd(BuildContext context, MarketAd ad) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ad.isWant ? 'Delete this need?' : 'Delete this ad?'),
        content: const Text(
          'It will be removed from the market and from My Ads. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _stExpired)),
          ),
        ],
      ),
    ) ??
    false;

/// Asks, then soft-deletes the viewer's own ad; the lists refresh themselves.
Future<void> _deleteOwnAd(BuildContext context, WidgetRef ref, MarketAd ad) async {
  if (!await _confirmDeleteAd(context, ad)) return;
  try {
    await ref.read(adActionProvider.notifier).perform(ad.id, 'delete');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: _stExpired,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Swipe background: a coloured strip with an icon and label on one side.
Widget _swipeBg(IconData icon, String label, Color fg, Color bg, {required bool left}) =>
    Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );

class _BrowseAdCard extends ConsumerWidget {
  final MarketAd ad;
  const _BrowseAdCard({required this.ad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ad.isWant ? _wantColor : _saleColor;
    final myNurseryId =
        ref.watch(sessionProvider.select((s) => s.capabilities.ownedNurseryId));
    final isOwn = myNurseryId != null && myNurseryId == ad.nurseryId;
    final isSaved = ref.watch(adSavedProvider(ad.id)) ?? ad.isSavedByMe;
    final canSave = !isOwn && ad.status == 'PUBLISHED';
    final canDelete = isOwn && (ad.capabilities?.canDelete ?? false);
    void toggleSave() => ref.read(toggleSaveProvider(ad.id).notifier).toggle();
    final details = ad.isWant
        ? [
            if (ad.quantity != null) 'Needs ${ad.quantity}',
            if (ad.sizeDescription != null) ad.sizeDescription!,
            if (ad.neededBy != null) 'by ${_shortDate(ad.neededBy!)}',
          ]
        : [
            if (ad.quantity != null) '${ad.quantity} available',
            if (ad.sizeDescription != null) 'Size ${ad.sizeDescription}',
          ];
    final card = Material(
      color: _mkCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _AdDetailScreen(ad: ad)),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Row(
            children: [
              _AdThumb(ad: ad, size: 100),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypePill(want: ad.isWant),
                        const Spacer(),
                        if (canDelete)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _deleteOwnAd(context, ref, ad),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: _stExpired,
                                semanticLabel: 'Delete',
                              ),
                            ),
                          )
                        else if (canSave)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: toggleSave,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isSaved
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: isSaved ? _heartRed : _mkTextSecondary,
                                semanticLabel: isSaved ? 'Saved' : 'Save',
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ad.isWant ? ad.plantName : ad.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h4.copyWith(
                        color: _mkTextPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Sale: the price. Want: what is needed (the label already
                    // says it is a want, and wants have no price).
                    Text(
                      ad.isWant
                          ? (details.isEmpty ? 'Any quantity' : details.join(' · '))
                          : _priceLabel(ad.pricePerUnit, ad.priceUnit),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: ad.isWant ? 14 : 16,
                      ),
                    ),
                    if (!ad.isWant && details.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        details.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: _mkTextSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _SellerAvatar(
                          photo: ad.postedByPhoto,
                          name: ad.postedByName ?? ad.nurseryName,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        if (ad.nurseryVerified)
                          const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 12,
                              color: _mkGreen,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            ad.nurseryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: _mkTextSecondary),
                          ),
                        ),
                        Text(
                          [
                            if (ad.distanceKm != null)
                              ad.distanceKm! < 1 ? '<1 km' : '${ad.distanceKm!.round()} km',
                            _timeAgo(ad.publishedAt ?? ad.createdAt),
                          ].join(' · '),
                          style: AppTypography.caption
                              .copyWith(color: _mkTextSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!canSave && !canDelete) return card;
    // Swipe right saves (others' ads), swipe left deletes (own ads). The card
    // always springs back: the lists refresh themselves after the action.
    return Dismissible(
      key: ValueKey('swipe_ad_${ad.id}'),
      direction: canDelete ? DismissDirection.endToStart : DismissDirection.startToEnd,
      background: _swipeBg(
        isSaved ? Icons.heart_broken_outlined : Icons.favorite_rounded,
        isSaved ? 'Unsave' : 'Save',
        _heartRed,
        _wantBg,
        left: true,
      ),
      secondaryBackground: _swipeBg(
        Icons.delete_outline_rounded,
        'Delete',
        _stExpired,
        _stExpiredBg,
        left: false,
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          toggleSave();
        } else {
          await _deleteOwnAd(context, ref, ad);
        }
        return false;
      },
      child: card,
    );
  }
}

/// Square picture for an ad: its first photo, a plant icon when it has none,
/// or an orange "wanted" tile (wants have no photos).
class _AdThumb extends StatelessWidget {
  final MarketAd ad;
  final double size;
  const _AdThumb({required this.ad, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: ad.isWant ? _wantBg : _mkLight,
      child: Icon(
        ad.isWant ? Icons.campaign_outlined : Icons.local_florist_outlined,
        color: ad.isWant ? _wantColor : _mkGreen,
        size: size * 0.38,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: ad.isWant || ad.photos.isEmpty
            ? placeholder
            : Image.network(
                ad.photos.first,
                fit: BoxFit.cover,
                cacheWidth:
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
