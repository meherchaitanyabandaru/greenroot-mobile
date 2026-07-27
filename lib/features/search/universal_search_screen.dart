import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/shimmer.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../market/local_market_providers.dart';
import '../orders/orders.dart';
import '../plants/plants.dart';
import '../quotations/quotations.dart';

/// One search box across Orders, Quotations, Plants and (owner/manager only)
/// Local Market ads -- all four already have a working `search`/`q` query
/// param on the backend (confirmed by reading orders/quotations/plants/
/// local_market handlers), so this composes existing list endpoints rather
/// than needing a new backend search API. Reached from the search icon in
/// [GreenRootAppBar], so it's available from every main tab.
class UniversalSearchScreen extends ConsumerStatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  ConsumerState<UniversalSearchScreen> createState() =>
      _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends ConsumerState<UniversalSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  bool _searchedOnce = false;

  List<Order> _orders = [];
  List<Quotation> _quotations = [];
  List<Plant> _plants = [];
  List<MarketAd> _ads = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _query = value;
        _loading = false;
        _searchedOnce = false;
        _orders = [];
        _quotations = [];
        _plants = [];
        _ads = [];
      });
      return;
    }
    // 400ms debounce -- avoids firing four API calls per keystroke.
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    setState(() {
      _query = query;
      _loading = true;
    });

    final caps = ref.read(sessionProvider).capabilities;
    final canSeeMarket = caps.isNurseryOwner || caps.isManager;
    final canSeeCommerce = !caps.isDriverOnly;

    // Each future starts immediately (before any await below), so these
    // four requests run concurrently even though Future.wait can't be used
    // directly here (the result lists have different element types).
    final ordersFuture = canSeeCommerce
        ? ref
            .read(orderRepositoryProvider)
            .listOrders(search: query, perPage: 5)
            .then((r) => r.$1)
            .catchError((_) => <Order>[])
        : Future.value(<Order>[]);
    final quotationsFuture = canSeeCommerce
        ? ref
            .read(quotationRepositoryProvider)
            .listQuotations(search: query, perPage: 5)
            .then((r) => r.$1)
            .catchError((_) => <Quotation>[])
        : Future.value(<Quotation>[]);
    final plantsFuture = ref
        .read(plantRepositoryProvider)
        .listPlants(search: query, perPage: 5)
        .then((r) => r.$1)
        .catchError((_) => <Plant>[]);
    final adsFuture = canSeeMarket
        ? ref
            .read(marketRepositoryProvider)
            .getAds({'q': query, 'per_page': '5'})
            .then((d) => (d['ads'] as List?)
                    ?.map((e) => MarketAd.fromJson(e as Map<String, dynamic>))
                    .toList() ??
                <MarketAd>[])
            .catchError((_) => <MarketAd>[])
        : Future.value(<MarketAd>[]);

    final orders = await ordersFuture;
    final quotations = await quotationsFuture;
    final plants = await plantsFuture;
    final ads = await adsFuture;

    // Stale-response guard: if the user kept typing while this request was
    // in flight, _query has already moved on -- don't clobber newer results.
    if (!mounted || query != _query) return;
    setState(() {
      _orders = orders;
      _quotations = quotations;
      _plants = plants;
      _ads = ads;
      _loading = false;
      _searchedOnce = true;
    });
  }

  void _goToMarketTab() {
    final caps = ref.read(sessionProvider).capabilities;
    // Tab order is role-specific (see main_shell.dart's _buildTabs) --
    // Market sits at index 3 for an owner (Home/Buying/Selling/Market) and
    // index 2 for a manager (Home/Work/Market). There's no standalone route
    // to a single ad's detail (it's a locally-pushed screen inside
    // LocalMarketScreen), so the best this can do is land on the tab.
    Navigator.of(context).pop();
    ref.read(mainTabIndexProvider.notifier).state = caps.isNurseryOwner ? 3 : 2;
  }

  bool get _hasAnyResults =>
      _orders.isNotEmpty ||
      _quotations.isNotEmpty ||
      _plants.isNotEmpty ||
      _ads.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search orders, quotations, plants, market...',
            border: InputBorder.none,
          ),
          style: AppTypography.body,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.trim().length < 2) {
      return _hint(
        icon: Icons.search_rounded,
        title: 'Search everything',
        subtitle: 'Orders, quotations, plants and market ads in one place.',
      );
    }
    if (_loading) {
      return _loadingSkeleton();
    }
    if (_searchedOnce && !_hasAnyResults) {
      return _hint(
        icon: Icons.search_off_rounded,
        title: 'No results for "$_query"',
        subtitle: 'Try a different order number, name, or plant.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        if (_orders.isNotEmpty)
          _section(
            title: 'Orders',
            icon: Icons.receipt_long_outlined,
            children: _orders
                .map((o) => _resultTile(
                      icon: Icons.receipt_long_outlined,
                      title: o.orderNumber,
                      subtitle: o.buyerName ?? o.sellerNursery ?? '',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/orders/${o.id}');
                      },
                    ))
                .toList(),
          ),
        if (_quotations.isNotEmpty)
          _section(
            title: 'Quotations',
            icon: Icons.description_outlined,
            children: _quotations
                .map((q) => _resultTile(
                      icon: Icons.description_outlined,
                      title: q.quotationCode,
                      subtitle: q.recipientName ?? q.nurseryName ?? '',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/quotations/${q.id}');
                      },
                    ))
                .toList(),
          ),
        if (_plants.isNotEmpty)
          _section(
            title: 'Plants',
            icon: Icons.eco_outlined,
            children: _plants
                .map((p) => _resultTile(
                      icon: Icons.eco_outlined,
                      title: p.commonName ?? p.scientificName,
                      subtitle: p.commonName != null ? p.scientificName : '',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/plants/${p.id}');
                      },
                    ))
                .toList(),
          ),
        if (_ads.isNotEmpty)
          _section(
            title: 'Market',
            icon: Icons.storefront_outlined,
            children: _ads
                .map((a) => _resultTile(
                      icon: Icons.storefront_outlined,
                      title: a.title,
                      subtitle: a.nurseryName,
                      onTap: _goToMarketTab,
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h4),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _resultTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryMain),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _hint({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title,
                style: AppTypography.h4, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingSkeleton() {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 90, height: 16),
            const SizedBox(height: 10),
            Container(height: 56, decoration: _skeletonCardDecoration()),
            const SizedBox(height: 6),
            Container(height: 56, decoration: _skeletonCardDecoration()),
            const SizedBox(height: AppSpacing.x2l),
            const ShimmerBox(width: 110, height: 16),
            const SizedBox(height: 10),
            Container(height: 56, decoration: _skeletonCardDecoration()),
          ],
        ),
      ),
    );
  }

  BoxDecoration _skeletonCardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      );
}
