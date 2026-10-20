import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/green_root_app_bar.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../plants/plant_picker.dart';
import '../plants/plants.dart';
import 'local_market_providers.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _mkGreen = Color(0xFF00A86B);
const _mkDark = Color(0xFF047857);
const _mkLight = Color(0xFFD1FAE5);
const _mkBg = Color(0xFFF0FDF4);
const _mkCard = Color(0xFFFFFFFF);
const _mkBorder = Color(0xFFE2E8F0);
const _mkTextPrimary = Color(0xFF0F172A);
const _mkTextSecondary = Color(0xFF64748B);

const _stPublished = Color(0xFF16A34A);
const _stPublishedBg = Color(0xFFDCFCE7);
const _stDraft = Color(0xFF64748B);
const _stDraftBg = Color(0xFFF1F5F9);
const _stPaused = Color(0xFFF59E0B);
const _stPausedBg = Color(0xFFFEF3C7);
const _stExpired = Color(0xFFDC2626);
const _stExpiredBg = Color(0xFFFEE2E2);
const _stArchived = Color(0xFF334155);
const _stArchivedBg = Color(0xFFE2E8F0);

const _cardShadow = BoxShadow(
  color: Color(0x0D000000),
  blurRadius: 16,
  offset: Offset(0, 2),
);
const _heartRed = Color(0xFFED4956);

// Ad types have their own colours everywhere: green offers plants (FOR SALE),
// orange asks for them (WANTED). Orange, not amber, so it never reads as the
// "Paused" status.
const _saleColor = _mkDark;

/// Icon buttons drawn over an ad photo.
final _overPhoto = IconButton.styleFrom(
  backgroundColor: Colors.white.withValues(alpha: 0.88),
  foregroundColor: _mkTextPrimary,
);
const _saleBg = _mkLight;
const _wantColor = Color(0xFFC2410C);
const _wantBg = Color(0xFFFFEDD5);

/// FOR SALE / WANTED label in the type's colours.
class _TypePill extends StatelessWidget {
  final bool want;
  const _TypePill({required this.want});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: want ? _wantBg : _saleBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          want ? 'WANTED' : 'FOR SALE',
          style: TextStyle(
            color: want ? _wantColor : _saleColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _shortDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inDays >= 30) return _shortDate(dt);
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'just now';
}

/// "₹120 per plant", or "Price on request" when the seller left it out (or 0).
String _priceLabel(double? price, String? unit) =>
    price == null || price <= 0 ? 'Price on request' : '${_rupees(price)} ${_unitLabel(unit)}';

String _daysLeft(DateTime? exp) {
  if (exp == null) return '';
  final d = exp.difference(DateTime.now()).inDays;
  return d > 0 ? '$d days left' : 'Expired';
}

InputDecoration _inputDec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: _mkTextSecondary.withValues(alpha: 0.6),
        fontSize: 14,
      ),
      filled: true,
      fillColor: _mkCard,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _mkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _mkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _mkGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );

// ══════════════════════════════════════════════════════════════════════════════
// 1. LOCAL MARKET HOME
// ══════════════════════════════════════════════════════════════════════════════

class LocalMarketScreen extends ConsumerStatefulWidget {
  const LocalMarketScreen({super.key});

  @override
  ConsumerState<LocalMarketScreen> createState() => _LocalMarketScreenState();
}

class _LocalMarketScreenState extends ConsumerState<LocalMarketScreen> {
  /// Which list the home shows: SELL (↑ for sale) or WANT (↓ wanted).
  String _type = 'SELL';

  @override
  Widget build(BuildContext context) {
    final want = _type == 'WANT';
    final provider = want ? latestWantsProvider : latestAdsProvider;
    final listAsync = ref.watch(provider);

    return Scaffold(
      key: const ValueKey('local_market_screen'),
      backgroundColor: _mkBg,
      appBar: const GreenRootAppBar(
        title: 'Local Market',
        subtitle: 'Nursery to nursery. Grow together.',
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _mkBorder),
        ),
      ),
      body: RefreshIndicator(
        color: _mkGreen,
        onRefresh: () async {
          ref.invalidate(latestAdsProvider);
          ref.invalidate(latestWantsProvider);
          ref.invalidate(marketUnreadProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _homeSearchBar(context)),
            SliverToBoxAdapter(child: _createAdButton(context)),
            SliverToBoxAdapter(child: _homeQuickActions(context, ref)),
            SliverToBoxAdapter(child: _typeSwitch()),
            listAsync.when(
              loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(provider),
                ),
              ),
              data: (ads) {
                if (ads.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: want ? Icons.campaign_outlined : Icons.storefront_outlined,
                      title: want ? 'No one is asking for plants' : 'No plants for sale yet',
                      subtitle: want
                          ? 'Looking for a plant? Tap "Create a Plant Ad", then "Plants I Want"'
                          : 'Have surplus? Tap "Create a Plant Ad", then "Plants I Have"',
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: i < ads.length
                          ? _BrowseAdCard(ad: ads[i])
                          : TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _BrowseScreen(type: _type),
                                ),
                              ),
                              child: Text(
                                want ? 'See all wanted posts' : 'See all ads for sale',
                                style: TextStyle(
                                  color: want ? _wantColor : _saleColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                    childCount: ads.length + 1,
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

  /// ↑ For sale / ↓ Wanted: one switch, one list.
  Widget _typeSwitch() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'SELL',
                label: Text('For sale'),
                icon: Icon(Icons.arrow_upward_rounded),
              ),
              ButtonSegment(
                value: 'WANT',
                label: Text('Wanted'),
                icon: Icon(Icons.arrow_downward_rounded),
              ),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _type = v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? (_type == 'WANT' ? _wantBg : _saleBg)
                    : _mkCard,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? (_type == 'WANT' ? _wantColor : _saleColor)
                    : _mkTextSecondary,
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      );

  Widget _createAdButton(BuildContext context) => Container(
        color: _mkCard,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: _CreatePlantAdButton(),
      );

  Widget _homeSearchBar(BuildContext context) {
    return Semantics(
      key: const ValueKey('local_market_search_button'),
      button: true,
      label: 'Search market listings',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _BrowseScreen(autoFocus: true),
          ),
        ),
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
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: _mkGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search plants...',
                    style: AppTypography.body.copyWith(
                      color: _mkTextSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const Icon(Icons.tune_rounded,
                    color: _mkTextSecondary, size: 18,),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeQuickActions(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(marketUnreadProvider).valueOrNull ?? 0;
    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return Container(
      color: _mkCard,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionTile(Icons.inventory_2_outlined, 'My Ads',
                () => open(const _MyAdsScreen()),),
          ),
          Expanded(
            child: _QuickActionTile(Icons.favorite_rounded, 'Saved',
                () => open(const _SavedAdsScreen()), iconColor: _heartRed,),
          ),
          Expanded(
            child: _QuickActionTile(Icons.chat_bubble_outline_rounded, 'Chats',
                () => open(const _EnquiriesScreen()), badge: unread,),
          ),
        ],
      ),
    );
  }
}

/// "Create a Plant Ad": choose Plants I Have (an ad for sale) or Plants I Want
/// (a wanted post), then open that form. Every post button opens this.
Future<void> showCreatePlantAdSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _mkCard,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) {
        Widget option(String key, String title, String sub, IconData icon,
                Color fg, Color bg, Widget screen,) =>
            Material(
              key: ValueKey(key),
              color: bg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => screen, fullscreenDialog: true),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: _mkCard,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: fg),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              style: TextStyle(color: fg, fontSize: 13, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: fg),
                    ],
                  ),
                ),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a Plant Ad 🌱',
                  style: AppTypography.h3.copyWith(color: _mkTextPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the type of ad you want to publish.',
                  style: AppTypography.body.copyWith(color: _mkTextSecondary),
                ),
                const SizedBox(height: 16),
                option(
                  'create_ad_have',
                  'Plants I Have',
                  'Offer plants you have to other nurseries',
                  Icons.arrow_upward_rounded,
                  _saleColor,
                  _saleBg,
                  const _PostAdScreen(),
                ),
                const SizedBox(height: 10),
                option(
                  'create_ad_want',
                  'Plants I Want',
                  'Ask nurseries for a plant you need',
                  Icons.arrow_downward_rounded,
                  _wantColor,
                  _wantBg,
                  const _PostWantScreen(),
                ),
              ],
            ),
          ),
        );
      },
    );

class _CreatePlantAdButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const ValueKey('local_market_create_ad'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _mkGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.x2l),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Create a Plant Ad',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          onPressed: () => showCreatePlantAdSheet(context),
        ),
      );
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  /// Unread count shown as a red dot on the tile (0 = none).
  final int badge;
  const _QuickActionTile(this.icon, this.label, this.onTap,
      {this.iconColor, this.badge = 0,});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? _mkGreen;
    return InkWell(
      key: ValueKey(
        'local_market_action_${label.toLowerCase().replaceAll(' ', '_')}',
      ),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              offset: const Offset(4, -4),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _mkLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _mkGreen.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: _mkTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
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

  /// SELL (for sale) or WANT (wanted posts) to open on.
  final String type;

  const _BrowseScreen({this.autoFocus = false, this.type = 'SELL'});

  @override
  ConsumerState<_BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<_BrowseScreen> {
  final _searchCtrl = TextEditingController();
  late final FocusNode _focus;
  late final ScrollController _scroll;
  bool _nearbyLoading = false;

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

  Future<void> _toggleNearby() async {
    final browse = ref.read(browseAdsProvider);
    if (browse.nearLat != null) {
      ref.read(browseAdsProvider.notifier).setNearby();
      return;
    }
    setState(() => _nearbyLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission required for nearby search'),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) {
        ref.read(browseAdsProvider.notifier).setNearby(
              lat: pos.latitude,
              lon: pos.longitude,
            );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location')),
        );
      }
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
  }

  void _showFilterSheet() {
    FocusScope.of(context).unfocus();
    final browse = ref.read(browseAdsProvider);
    String? selCat = browse.category;
    final minCtrl = TextEditingController(
      text: browse.minPrice != null ? browse.minPrice!.toStringAsFixed(0) : '',
    );
    final maxCtrl = TextEditingController(
      text: browse.maxPrice != null ? browse.maxPrice!.toStringAsFixed(0) : '',
    );
    const cats = [
      'Fruit Plants',
      'Flower Plants',
      'Forest Plants',
      'Ornamentals',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
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
                Text(
                  'Filter Ads',
                  style: AppTypography.h4.copyWith(
                    color: _mkTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Category',
                  style: TextStyle(
                    color: _mkTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _catChip(
                      'All',
                      selCat == null,
                      () => setS(() => selCat = null),
                    ),
                    for (final c in cats)
                      _catChip(c, selCat == c, () => setS(() => selCat = c)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Price Range (₹ per unit)',
                  style: TextStyle(
                    color: _mkTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDec('Min price'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '–',
                        style: TextStyle(color: _mkTextSecondary, fontSize: 18),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: maxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDec('Max price'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _mkTextSecondary,
                        side: const BorderSide(color: _mkBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
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
            border:
                Border.all(color: selected ? _mkGreen : _mkBorder, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _mkTextPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );

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

    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(browse.type == 'WANT' ? 'Wanted' : 'For sale'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          _nearbyLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _mkGreen,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: browse.nearLat != null ? 'Near Me (on)' : 'Near Me',
                  onPressed: _toggleNearby,
                  icon: Icon(
                    browse.nearLat != null
                        ? Icons.location_on_rounded
                        : Icons.location_off_outlined,
                    color: browse.nearLat != null ? _mkGreen : _mkTextSecondary,
                  ),
                ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: hasFilters ? _mkGreen : _mkTextSecondary,
                ),
                if (hasFilters)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: _mkGreen,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$filterCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.sort_rounded,
              color: browse.sort != MarketSort.newest
                  ? _mkGreen
                  : _mkTextSecondary,
            ),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(hasFilters ? 145 : 101),
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
              if (hasFilters) _activeFilterChips(browse),
              const Divider(height: 1, color: _mkBorder),
            ],
          ),
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
          if (browse.nearLat != null)
            _activeChip(
              '📍 Near Me${browse.radiusKm != null ? ' (${browse.radiusKm!.toStringAsFixed(0)} km)' : ''}',
              onRemove: () => notifier.setNearby(),
            ),
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
              const Spacer(),
              Text(
                browse.sort.label,
                style: AppTypography.caption
                    .copyWith(color: _mkGreen, fontWeight: FontWeight.w600),
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
                          _timeAgo(ad.publishedAt ?? ad.createdAt),
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
          child: Divider(height: 1, color: _mkBorder),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: _mkCard,
            border: Border(top: BorderSide(color: _mkBorder)),
          ),
          child: _CreatePlantAdButton(),
        ),
      ),
      body: adsAsync.when(
        loading: () => const _SkeletonList(),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myAdsProvider),
        ),
        data: (all) {
          List<MarketAd> forTab(String tab) => switch (tab) {
                'Live' => all
                    .where(
                      (a) => const {'PUBLISHED', 'PAUSED', 'SUSPENDED'}
                          .contains(a.status),
                    )
                    .toList(),
                'Drafts' => all.where((a) => a.status == 'DRAFT').toList(),
                'Closed' => all
                    .where(
                      (a) => const {'EXPIRED', 'ARCHIVED', 'REMOVED'}
                          .contains(a.status),
                    )
                    .toList(),
                _ => all,
              };
          final counts = {for (final f in _filters) f: forTab(f).length};
          final ads = forTab(_filter);

          return Column(
            children: [
              Container(
                color: _mkCard,
                child: SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: _filters.length,
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final n = counts[f] ?? 0;
                      final sel = _filter == f;
                      return ChoiceChip(
                        label: Text(
                          '$f${n > 0 ? " ($n)" : ""}',
                          style: TextStyle(
                            color: sel ? Colors.white : _mkTextSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        selected: sel,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: _mkGreen,
                        backgroundColor: _mkBg,
                        side: BorderSide(color: sel ? _mkGreen : _mkBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
                        subtitle:
                            'Post your first ad to connect with local nurseries',
                      )
                    : RefreshIndicator(
                        color: _mkGreen,
                        backgroundColor: _mkCard,
                        onRefresh: () async => ref.invalidate(myAdsProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          itemCount: ads.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _MyAdCard(ad: ads[i]),
                        ),
                      ),
              ),
            ],
          );
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
    if (action == 'delete' && !await _confirmDeleteAd(context, widget.ad)) {
      return;
    }
    setState(() => _actioning = true);
    try {
      await ref.read(adActionProvider.notifier).perform(widget.ad.id, action);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _stExpired,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  List<(String, String, IconData)> get _actions {
    final caps = widget.ad.capabilities;
    if (caps != null) {
      return [
        if (caps.canEdit) ('edit', 'Edit', Icons.edit_outlined),
        if (caps.canPublish) ('publish', 'Publish', Icons.publish_rounded),
        if (caps.canPause)
          ('pause', 'Pause', Icons.pause_circle_outline_rounded),
        if (caps.canResume)
          ('resume', 'Resume', Icons.play_circle_outline_rounded),
        if (caps.canRenew) ('renew', 'Renew', Icons.refresh_rounded),
        // A draft is deleted, not archived.
        if (caps.canArchive && !(caps.canDelete && widget.ad.status == 'DRAFT'))
          ('archive', 'Archive', Icons.archive_outlined),
        if (caps.canDelete) ('delete', 'Delete', Icons.delete_outline_rounded),
      ];
    }
    return switch (widget.ad.status) {
      'DRAFT' => [
          ('edit', 'Edit', Icons.edit_outlined),
          ('publish', 'Publish', Icons.publish_rounded),
          ('delete', 'Delete', Icons.delete_outline_rounded),
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
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final closed = const {'EXPIRED', 'ARCHIVED', 'REMOVED'}.contains(ad.status);
    return _greyIf(closed, Container(
      decoration: BoxDecoration(
        color: _mkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _mkBorder),
        boxShadow: const [_cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _AdDetailScreen(ad: ad, isOwn: true),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 88,
                      height: 88,
                      color: _mkLight,
                      child: ad.photos.isNotEmpty
                          ? Image.network(
                              ad.photos.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_florist_outlined,
                                color: _mkGreen,
                                size: 30,
                              ),
                            )
                          : const Icon(
                              Icons.local_florist_outlined,
                              color: _mkGreen,
                              size: 30,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusChip(status: ad.status),
                            const SizedBox(width: 6),
                            _TypePill(want: ad.isWant),
                            const Spacer(),
                            // A countdown only means something while live.
                            if (ad.expiresAt != null &&
                                (ad.status == 'PUBLISHED' || ad.status == 'PAUSED'))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 11,
                                    color: _mkTextSecondary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _daysLeft(ad.expiresAt),
                                    style: AppTypography.caption
                                        .copyWith(color: _mkTextSecondary),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ad.title,
                          style:
                              AppTypography.h4.copyWith(color: _mkTextPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        if (ad.isWant)
                          Text(
                            [
                              'Wanted',
                              if (ad.quantity != null) '${ad.quantity}',
                              if (ad.sizeDescription != null) ad.sizeDescription!,
                              if (ad.neededBy != null) 'by ${_shortDate(ad.neededBy!)}',
                            ].join(' · '),
                            style: const TextStyle(
                              color: _wantColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          )
                        else
                          Text(
                            _priceLabel(ad.pricePerUnit, ad.priceUnit),
                            style: const TextStyle(
                              color: _mkGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        if (ad.moderationNote != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            ad.moderationNote!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ad.status == 'REMOVED'
                                  ? _stExpired
                                  : _stPaused,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _miniStat(
                              Icons.visibility_outlined,
                              '${ad.viewCount} ${ad.viewCount == 1 ? 'view' : 'views'}',
                            ),
                            const SizedBox(width: 10),
                            _miniStat(
                              Icons.bookmark_outline_rounded,
                              '${ad.saveCount} saved',
                            ),
                            if (ad.enquiryCount > 0) ...[
                              const SizedBox(width: 10),
                              _miniStat(
                                Icons.mail_outline_rounded,
                                '${ad.enquiryCount} ${ad.enquiryCount == 1 ? 'chat' : 'chats'}',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_actions.isNotEmpty) ...[
            const Divider(height: 1, color: _mkBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: _actions.map((a) {
                  final isPositive =
                      a.$1 == 'publish' || a.$1 == 'renew' || a.$1 == 'resume';
                  return Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: a.$1 == 'delete'
                            ? _stExpired
                            : isPositive
                                ? _mkGreen
                                : _mkTextSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon:
                          _actioning && (a.$1 != 'edit' && a.$1 != 'enquiries')
                              ? const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _mkGreen,
                                  ),
                                )
                              : Icon(a.$3, size: 14),
                      label: Text(
                        a.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _actioning
                          ? null
                          : () {
                              if (a.$1 == 'edit') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => widget.ad.isWant
                                        ? _PostWantScreen(editing: widget.ad)
                                        : _PostAdScreen(editingAd: widget.ad),
                                    fullscreenDialog: true,
                                  ),
                                );
                              } else if (a.$1 == 'enquiries') {
                                _openAdChats(context, ref, widget.ad);
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
        ],
      ),
    ),);
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
    // The list's copy first, then the full ad (it knows the viewer's chat).
    final ad =
        ref.watch(adDetailProvider(widget.ad.id)).valueOrNull ?? widget.ad;
    final isSaved = ref.watch(adSavedProvider(ad.id)) ?? ad.isSavedByMe;
    final myNurseryId =
        ref.watch(sessionProvider.select((s) => s.capabilities.ownedNurseryId));
    final effectiveIsOwn =
        widget.isOwn || (myNurseryId != null && myNurseryId == ad.nurseryId);
    final canSave = ad.capabilities?.canSave ?? !effectiveIsOwn;
    final canReport = ad.capabilities?.canReport ?? !effectiveIsOwn;

    return Scaffold(
      backgroundColor: _mkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            // A want has no photos: a short bar instead of a photo header.
            expandedHeight: ad.isWant ? null : 300,
            pinned: true,
            backgroundColor: _mkCard,
            foregroundColor: _mkTextPrimary,
            surfaceTintColor: Colors.transparent,
            // Light circles keep the icons visible over any photo.
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                style: _overPhoto,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            actions: [
              if (canSave || canReport) ...[
                IconButton(
                  style: _overPhoto,
                  tooltip: isSaved ? 'Saved' : 'Save',
                  icon: Icon(
                    isSaved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isSaved ? _heartRed : _mkTextPrimary,
                  ),
                  onPressed: canSave
                      ? () =>
                          ref.read(toggleSaveProvider(ad.id).notifier).toggle()
                      : null,
                ),
                if (canReport)
                  IconButton(
                    style: _overPhoto,
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => _showMoreSheet(context, ad),
                  ),
              ],
              if (effectiveIsOwn)
                IconButton(
                  style: _overPhoto,
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ad.isWant
                          ? _PostWantScreen(editing: ad)
                          : _PostAdScreen(editingAd: ad),
                      fullscreenDialog: true,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: ad.isWant ? null : FlexibleSpaceBar(
              background: ad.photos.isEmpty
                  ? Container(
                      color: _mkLight,
                      child: const Center(
                        child: Icon(
                          Icons.local_florist_outlined,
                          size: 72,
                          color: _mkGreen,
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _pageCtrl,
                          itemCount: ad.photos.length,
                          onPageChanged: (i) => setState(() => _photoPage = i),
                          // Tap opens the photos full screen, uncropped.
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => _openPhotos(ad.photos, i),
                            child: Image.network(
                              ad.photos[i],
                              fit: BoxFit.cover,
                              // Decode at screen size, not the full upload.
                              cacheWidth: (MediaQuery.sizeOf(context).width *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                              errorBuilder: (_, __, ___) => Container(
                                color: _mkLight,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: _mkTextSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 8,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.zoom_out_map_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (ad.photos.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                ad.photos.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
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
                      ],
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: _mkCard,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypePill(want: ad.isWant),
                      // Status and expiry matter to the owner; buyers only
                      // see the ad while it is live.
                      if (effectiveIsOwn) ...[
                        const SizedBox(width: 6),
                        _StatusChip(status: ad.status),
                      ],
                      const Spacer(),
                      Text(
                        effectiveIsOwn && ad.expiresAt != null
                            ? _daysLeft(ad.expiresAt)
                            : 'Posted ${_timeAgo(ad.publishedAt ?? ad.createdAt)}',
                        style: AppTypography.caption
                            .copyWith(color: _mkTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _mkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ad.isWant)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _wantBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'WANTED · sellers offer a price in the chat',
                        style: TextStyle(
                          color: _wantColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (!ad.isWant)
                    Text(
                      _priceLabel(ad.pricePerUnit, ad.priceUnit),
                      style: TextStyle(
                        fontSize: (ad.pricePerUnit ?? 0) > 0 ? 26 : 18,
                        fontWeight: FontWeight.w900,
                        color: _saleColor,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (ad.quantity != null)
                        _Chip(
                          ad.isWant
                              ? 'Needs ${ad.quantity}'
                              : '${ad.quantity} available',
                          _mkLight,
                          _mkDark,
                        ),
                      if (ad.sizeDescription != null)
                        _Chip('Size ${ad.sizeDescription!}', _stDraftBg, _stDraft),
                      if (ad.isWant && ad.neededBy != null)
                        _Chip(
                          'Needed by ${_shortDate(ad.neededBy!)}',
                          _wantBg,
                          _wantColor,
                        ),
                      if (ad.categoryName != null)
                        _Chip(ad.categoryName!, _stPublishedBg, _stPublished),
                      _Chip(
                        ad.plantName,
                        const Color(0xFFEFF6FF),
                        const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                  if (ad.description != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: _mkBorder),
                    const SizedBox(height: 12),
                    Text(
                      ad.description!,
                      style: AppTypography.body.copyWith(
                        color: _mkTextPrimary.withValues(alpha: 0.85),
                        height: 1.6,
                      ),
                    ),
                  ],
                  if (!ad.isWant) ...[
                    const SizedBox(height: 16),
                    const Divider(color: _mkBorder),
                    const SizedBox(height: 12),
                    _AccessInfo(
                      road: ad.roadAccessible,
                      truck: ad.truckAccessible,
                      pickupPoint: ad.pickupPoint,
                      instructions: ad.accessInstructions,
                    ),
                  ],
                  // How the ad is doing: only for the nursery that posted it.
                  if (effectiveIsOwn) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _ti(Icons.visibility_outlined, '${ad.viewCount} views'),
                        const SizedBox(width: 16),
                        _ti(
                          Icons.bookmark_outline_rounded,
                          '${ad.saveCount} saved',
                        ),
                        const SizedBox(width: 16),
                        _ti(
                          Icons.forum_outlined,
                          '${ad.enquiryCount} chat${ad.enquiryCount == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _SellerProfileScreen(nurseryId: ad.nurseryId),
                      ),
                    ),
                    child: Row(
                      children: [
                        _SellerAvatar(
                          photo: ad.postedByPhoto,
                          name: ad.postedByName ?? ad.nurseryName,
                          size: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (ad.nurseryVerified)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.verified_rounded,
                                        size: 13,
                                        color: _mkGreen,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      ad.nurseryName,
                                      style: AppTypography.h4
                                          .copyWith(color: _mkTextPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                [
                                  if (ad.postedByName != null)
                                    'Posted by ${ad.postedByName}',
                                  if (ad.nurseryMobile != null)
                                    ad.nurseryMobile!,
                                ].join(' · '),
                                style: AppTypography.caption
                                    .copyWith(color: _mkTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _mkTextSecondary,
                        ),
                      ],
                    ),
                  ),
                  if (ad.nurseryMobile != null) ...[
                    const SizedBox(height: 14),
                    const Divider(color: _mkBorder, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _mkGreen,
                              side: const BorderSide(color: _mkGreen),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.phone_outlined, size: 16),
                            label: const Text(
                              'Call',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => launchUrl(
                              Uri(scheme: 'tel', path: ad.nurseryMobile!),
                            ),
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              final digits = ad.nurseryMobile!
                                  .replaceAll(RegExp(r'\D'), '');
                              final number = digits.startsWith('91')
                                  ? digits
                                  : '91$digits';
                              launchUrl(
                                Uri.parse('https://wa.me/$number'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
      bottomNavigationBar: effectiveIsOwn
          ? (ad.enquiryCount > 0
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: _mkCard,
                      border: Border(top: BorderSide(color: _mkBorder)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _mkGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.forum_outlined, size: 18),
                        label: Text(
                          ad.enquiryCount == 1
                              ? 'Open chat'
                              : 'Chats about this ad (${ad.enquiryCount})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () => _openAdChats(context, ref, ad),
                      ),
                    ),
                  ),
                )
              : null)
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: _mkCard,
                  border: Border(top: BorderSide(color: _mkBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: Text(
                      ad.myEnquiryId != null
                          ? 'Open chat'
                          : ad.isWant
                              ? 'I have this'
                              : 'Chat with seller',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: ad.myEnquiryId != null
                        ? () => _openChat(context, ad.myEnquiryId!, ad)
                        : (ad.capabilities?.canEnquire ?? true)
                            ? () => _showEnquirySheet(context, ad)
                            : null,
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _openPhotos(List<String> photos, int index) async {
    final last = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(photos: photos, initial: index),
        fullscreenDialog: true,
      ),
    );
    // Come back on the photo the viewer ended on.
    if (last != null && last != _photoPage && _pageCtrl.hasClients) {
      _pageCtrl.jumpToPage(last);
    }
  }

  Widget _ti(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _mkTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: _mkTextSecondary),
          ),
        ],
      );

  void _showMoreSheet(BuildContext context, MarketAd ad) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _mkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: _stExpired),
                title: const Text(
                  'Report this ad',
                  style: TextStyle(
                    color: _stExpired,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    // EXPLICIT_CONTENT and PROHIBITED hide the ad at once until GreenRoot
    // reviews it; the rest wait for review.
    const reasons = {
      'EXPLICIT_CONTENT': 'Nude or sexual images',
      'PROHIBITED': 'Banned or illegal item',
      'SCAM': 'Scam (e.g. asks for advance payment)',
      'FRAUD': 'Fake information',
      'WRONG_PLANT': 'Wrong plant / misleading info',
      'SPAM': 'Spam',
      'DUPLICATE': 'Duplicate listing',
      'OTHER': 'Other',
    };
    String? selected;
    final notesCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _mkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
              Row(
                children: [
                  const Icon(Icons.flag_outlined, color: _stExpired, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Report Ad',
                    style: AppTypography.h4.copyWith(
                      color: _mkTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Help us understand the issue',
                style: AppTypography.caption.copyWith(color: _mkTextSecondary),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v),
                child: Column(
                  children: [
                    for (final entry in reasons.entries)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          entry.value,
                          style: TextStyle(
                            color: _mkTextPrimary,
                            fontWeight: selected == entry.key
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        value: entry.key,
                        activeColor: _mkGreen,
                      ),
                  ],
                ),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: selected == null || submitting
                      ? null
                      : () async {
                          setS(() => submitting = true);
                          try {
                            final notes = notesCtrl.text.trim();
                            await ref
                                .read(reportAdProvider(ad.id).notifier)
                                .report(
                                  selected!,
                                  notes: notes.isEmpty ? null : notes,
                                );
                            if (ctx.mounted) {
                              final hidden = selected == 'EXPLICIT_CONTENT' ||
                                  selected == 'PROHIBITED';
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(ctx).pop();
                              // The ad is gone for everyone; leave its page.
                              if (hidden) Navigator.of(context).pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    hidden
                                        ? 'Thank you. The ad is hidden while GreenRoot reviews it.'
                                        : 'Report submitted. GreenRoot will review it.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setS(() => submitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: _stExpired,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEnquirySheet(BuildContext context, MarketAd ad) async {
    final msgCtrl = TextEditingController(
      text: ad.isWant
          ? 'I have ${ad.plantName}${ad.sizeDescription != null ? ' (${ad.sizeDescription})' : ''}.'
          : 'Is it still available?',
    );
    final qtyCtrl = TextEditingController();
    final enquiryId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EnquirySheet(ad: ad, msgCtrl: msgCtrl, qtyCtrl: qtyCtrl),
    );
    ref.invalidate(adDetailProvider(ad.id));
    if (enquiryId != null && context.mounted) _openChat(context, enquiryId, ad);
  }

  void _openChat(BuildContext context, int enquiryId, MarketAd ad) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _EnquiryDetailScreen(enquiryId: enquiryId, title: ad.nurseryName),
        ),
      );
}

class _EnquirySheet extends ConsumerStatefulWidget {
  final MarketAd ad;
  final TextEditingController msgCtrl;
  final TextEditingController qtyCtrl;
  const _EnquirySheet({
    required this.ad,
    required this.msgCtrl,
    required this.qtyCtrl,
  });

  @override
  ConsumerState<_EnquirySheet> createState() => _EnquirySheetState();
}

class _EnquirySheetState extends ConsumerState<_EnquirySheet> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _mkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.ad.isWant ? 'I have this plant' : 'Chat with seller',
              style: AppTypography.h3.copyWith(
                color: _mkTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.ad.title,
              style: AppTypography.caption.copyWith(color: _mkTextSecondary),
            ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _sending
                    ? null
                    : () async {
                        final msg = widget.msgCtrl.text.trim();
                        if (msg.isEmpty) return;
                        setState(() => _sending = true);
                        try {
                          final qty = int.tryParse(widget.qtyCtrl.text.trim());
                          final enquiryId = await ref
                              .read(sendEnquiryProvider(widget.ad.id).notifier)
                              .send(msg, qty: qty);
                          if (context.mounted) {
                            Navigator.of(context).pop(enquiryId);
                          }
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
                        } finally {
                          if (mounted) setState(() => _sending = false);
                        }
                      },
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start chat',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// POST A WANT: plant + size (+ quantity, date, note). No price, no photos:
// nurseries that have the plant answer "I have this" and offer in the chat.
// ══════════════════════════════════════════════════════════════════════════════

class _PostWantScreen extends ConsumerStatefulWidget {
  final MarketAd? editing;
  const _PostWantScreen({this.editing});

  @override
  ConsumerState<_PostWantScreen> createState() => _PostWantScreenState();
}

class _PostWantScreenState extends ConsumerState<_PostWantScreen> {
  int? _plantId;
  String? _plantName;
  String? _size;
  DateTime? _neededBy;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ad = widget.editing;
    if (ad != null) {
      _plantId = ad.plantId;
      _plantName = ad.plantName;
      _size = ad.sizeDescription;
      _neededBy = ad.neededBy;
      _qtyCtrl.text = ad.quantity?.toString() ?? '';
      _noteCtrl.text = ad.description ?? '';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _mkTextPrimary,
          ),
        ),
      );

  bool get _valid =>
      _plantId != null &&
      _size != null &&
      (_qtyCtrl.text.trim().isEmpty ||
          (int.tryParse(_qtyCtrl.text.trim()) ?? 0) > 0);

  String? get _dateParam => _neededBy == null
      ? null
      : '${_neededBy!.year}-${_neededBy!.month.toString().padLeft(2, '0')}-${_neededBy!.day.toString().padLeft(2, '0')}';

  void _pickPlant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PlantPickerSheet(
        title: 'Which plant do you need?',
        onSelected: (plant) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _plantId = plant.id;
            _plantName = plant.displayName;
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Needed by',
    );
    if (picked != null) setState(() => _neededBy = picked);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final qty = int.tryParse(_qtyCtrl.text.trim());
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      final post = ref.read(postAdProvider.notifier);
      if (widget.editing != null) {
        await post.update(
          widget.editing!.id,
          sizeDescription: _size,
          quantity: qty,
          description: note,
          neededBy: _dateParam ?? '',
        );
      } else {
        final id = await post.create(
          adType: 'WANT',
          neededBy: _dateParam,
          plantId: _plantId,
          plantName: _plantName!,
          title: 'Wanted: ${_plantName!}',
          sizeDescription: _size,
          quantity: qty,
          description: note,
        );
        // A want goes live at once: there is no draft step for a request.
        await ref.read(adActionProvider.notifier).perform(id, 'publish');
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editing != null
                ? 'Wanted post updated'
                : 'Posted. Nurseries that have it can now reply.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _stExpired,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(plantSizesProvider);
    final editing = widget.editing != null;
    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(editing ? 'Edit wanted post' : 'Plants I Want'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tell nurseries what you are looking for. No price here: '
            'nurseries that have it reply and offer a price in the chat.',
            style: AppTypography.bodySmall.copyWith(color: _mkTextSecondary),
          ),
          const SizedBox(height: 18),
          _label('Plant *'),
          InkWell(
            onTap: editing ? null : _pickPlant,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _inputDec('Search plants, e.g. Neem, Rose...').copyWith(
                suffixIcon: editing ? null : const Icon(Icons.search_rounded),
              ),
              isEmpty: _plantName == null,
              child: _plantName == null
                  ? null
                  : Text(_plantName!, style: AppTypography.body),
            ),
          ),
          const SizedBox(height: 16),
          _label('Size *'),
          sizes.when(
            loading: () => const LinearProgressIndicator(color: _mkGreen),
            error: (e, _) => Text(e.toString(), style: const TextStyle(color: _stExpired)),
            data: (list) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final PlantSize size in list)
                  ChoiceChip(
                    label: Text(size.displayName),
                    selected: _size == size.displayName,
                    onSelected: (_) => setState(() => _size = size.displayName),
                    selectedColor: _mkGreen,
                    labelStyle: TextStyle(
                      color: _size == size.displayName ? Colors.white : _mkTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _label('How many (optional)'),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: _inputDec('e.g. 300'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _label('Needed by (optional)'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _inputDec('Pick a date').copyWith(
                suffixIcon: _neededBy == null
                    ? const Icon(Icons.event_outlined)
                    : IconButton(
                        tooltip: 'Clear date',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _neededBy = null),
                      ),
              ),
              isEmpty: _neededBy == null,
              child: _neededBy == null
                  ? null
                  : Text(_shortDate(_neededBy!), style: AppTypography.body),
            ),
          ),
          const SizedBox(height: 16),
          _label('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: _inputDec('e.g. For a highway project, need healthy stock'),
          ),
          const SizedBox(height: 12),
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
              onPressed: _valid && !_saving ? _submit : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      editing ? 'Save' : 'Post',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
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
  int? _plantId;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();

  final List<XFile> _pickedFiles = [];
  List<String> _existingPhotos = [];
  String? _selectedCategory;

  // Pickup & access: road and truck are asked separately (a road may be too
  // narrow for a truck); null until the seller answers.
  bool? _road;
  bool? _truck;
  final _pickupCtrl = TextEditingController();
  final _accessCtrl = TextEditingController();
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
      _plantId = ad.plantId;
      _titleCtrl.text = ad.title;
      _descCtrl.text = ad.description ?? '';
      _qtyCtrl.text = ad.quantity?.toString() ?? '';
      _priceCtrl.text = ad.pricePerUnit?.toStringAsFixed(0) ?? '';
      _sizeCtrl.text = ad.sizeDescription ?? '';
      _existingPhotos = List<String>.from(ad.photos);
      _selectedCategory = ad.categoryName;
      _road = ad.roadAccessible;
      _truck = ad.truckAccessible;
      _pickupCtrl.text = ad.pickupPoint ?? '';
      _accessCtrl.text = ad.accessInstructions ?? '';
    }
    _pickupCtrl.addListener(_onRequiredFieldChanged);
  }

  void _onRequiredFieldChanged() => setState(() {});

  @override
  void dispose() {
    _plantCtrl.removeListener(_onRequiredFieldChanged);
    _titleCtrl.removeListener(_onRequiredFieldChanged);
    _pickupCtrl.removeListener(_onRequiredFieldChanged);
    _pickupCtrl.dispose();
    _accessCtrl.dispose();
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
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _step1Valid =>
      _titleCtrl.text.trim().isNotEmpty && _plantCtrl.text.trim().isNotEmpty;

  /// What still blocks the photos & pickup step, or null when it is complete.
  String? get _accessError {
    if (_road == null) return 'Tell buyers if a road reaches your plants';
    if (_truck == null) return 'Tell buyers if a truck can reach your plants';
    if (_road == false && _pickupCtrl.text.trim().isEmpty) {
      return 'No road: add a pickup point buyers can reach';
    }
    return null;
  }

  Map<String, dynamic> get _accessJson => {
        'road_accessible': _road,
        'truck_accessible': _truck,
        'pickup_landmark': _pickupCtrl.text.trim(),
        'access_instructions': _accessCtrl.text.trim(),
      };

  void _pickPlant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PlantPickerSheet(
        title: 'Which plant are you selling?',
        onSelected: (plant) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _plantId = plant.id;
            _plantCtrl.text = plant.displayName;
            if (_titleCtrl.text.trim().isEmpty) {
              _titleCtrl.text = plant.displayName;
            }
          });
        },
      ),
    );
  }

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
              plantId: _plantId,
              plantName: plantName.isNotEmpty ? plantName : null,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              access: _accessJson,
            );
      } else {
        await ref.read(postAdProvider.notifier).create(
              plantId: _plantId,
              plantName: plantName,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              access: _accessJson,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _stExpired,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
              plantId: _plantId,
              plantName: plantName.isNotEmpty ? plantName : null,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              access: _accessJson,
            );
        adId = widget.editingAd!.id;
      } else {
        adId = await ref.read(postAdProvider.notifier).create(
              plantId: _plantId,
              plantName: plantName,
              title: _titleCtrl.text.trim(),
              categoryName: _selectedCategory,
              description:
                  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              quantity: int.tryParse(_qtyCtrl.text.trim()),
              pricePerUnit: double.tryParse(_priceCtrl.text.trim()),
              sizeDescription:
                  _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              photos: photos,
              access: _accessJson,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _stExpired,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        title: Text(widget.editingAd != null ? 'Edit Ad' : 'Plants I Have'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: List.generate(3, (i) {
                    final done = i < _step;
                    final active = i == _step;
                    return Expanded(
                      child: Row(
                        children: [
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
                        ],
                      ),
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
                    _stepLabel(1, 'Photos & pickup'),
                    _stepLabel(2, 'Preview'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _DetailsStep(
            onPickPlant: _pickPlant,
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
            onExistingRemoved: (url) =>
                setState(() => _existingPhotos.remove(url)),
            onNewPicked: (files) => setState(() => _pickedFiles.addAll(files)),
            onNewRemoved: (f) => setState(() => _pickedFiles.remove(f)),
            onReplace: (old, file) => setState(() {
              if (old is XFile) {
                _pickedFiles[_pickedFiles.indexOf(old)] = file;
              } else {
                _existingPhotos.remove(old);
                _pickedFiles.insert(0, file);
              }
            }),
            pickup: _PickupAccessForm(
              road: _road,
              truck: _truck,
              pickupCtrl: _pickupCtrl,
              instructionsCtrl: _accessCtrl,
              error: _accessError,
              onRoad: (v) => setState(() {
                _road = v;
                if (!v) _truck = false; // a truck needs a road
              }),
              onTruck: (v) => setState(() => _truck = v),
            ),
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
            access: _AccessInfo(
              road: _road,
              truck: _truck,
              pickupPoint: _pickupCtrl.text.trim(),
              instructions: _accessCtrl.text.trim(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: _mkCard,
            border: Border(top: BorderSide(color: _mkBorder)),
          ),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mkTextSecondary,
                      side: const BorderSide(color: _mkBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        _saving || _publishing ? null : () => _goTo(_step - 1),
                    child: const Text(
                      'Back',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving || _publishing ? null : _saveDraft,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _mkGreen,
                            ),
                          )
                        : const Text(
                            'Save Draft',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving || _publishing ? null : _publish,
                    child: _publishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.editingAd?.status == 'PUBLISHED' ||
                                    widget.editingAd?.status == 'PAUSED'
                                ? 'Save Changes'
                                : 'Publish',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (_step == 0 && !_step1Valid) ||
                            (_step == 1 && _accessError != null)
                        ? null
                        : () => _goTo(_step + 1),
                    child: const Text(
                      'Next',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLabel(int i, String label) {
    final active = _step == i;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        color: active ? _mkGreen : _mkTextSecondary,
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController plantCtrl,
      titleCtrl,
      descCtrl,
      qtyCtrl,
      priceCtrl,
      sizeCtrl;
  final String? selectedCategory;
  final List<String> categories;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onPickPlant;

  const _DetailsStep({
    required this.onPickPlant,
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
    // Plant first: picking it fills the title. Then what buyers compare:
    // quantity, price, size. Category and description are extras.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('Plant *'),
        TextField(
          controller: plantCtrl,
          readOnly: true,
          onTap: onPickPlant,
          decoration: _inputDec('Search plants, e.g. Mango, Rose...').copyWith(
            suffixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        _label('Ad title *'),
        TextField(
          controller: titleCtrl,
          maxLength: 120,
          decoration: _inputDec('e.g. Grafted mango saplings, 2 ft'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Quantity available'),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDec('e.g. 50'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Price per plant (₹)'),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDec('Leave empty: on request'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('Size'),
        _SizeChips(controller: sizeCtrl),
        const SizedBox(height: 14),
        _label('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...categories.map((c) {
              final sel = selectedCategory == c;
              return ChoiceChip(
                label: Text(
                  c,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _mkTextSecondary,
                  ),
                ),
                selected: sel,
                onSelected: (_) => onCategoryChanged(sel ? null : c),
                selectedColor: _mkGreen,
                backgroundColor: _mkCard,
                side: BorderSide(color: sel ? _mkGreen : _mkBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
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
          decoration: _inputDec(
            'Condition, age, pot size, pickup times...',
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _mkTextPrimary,
          ),
        ),
      );
}

/// The catalog sizes as chips, writing the chosen name into [controller]
/// (the same sizes wanted posts use, so buyers and sellers match).
class _SizeChips extends ConsumerWidget {
  final TextEditingController controller;
  const _SizeChips({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(plantSizesProvider).when(
          loading: () => const LinearProgressIndicator(color: _mkGreen),
          // No free-text fallback: a typed "44" has no unit buyers can read.
          error: (_, __) => TextButton.icon(
            onPressed: () => ref.invalidate(plantSizesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Could not load sizes. Tap to retry'),
          ),
          data: (sizes) => ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in sizes)
                  ChoiceChip(
                    label: Text(size.displayName),
                    selected: value.text == size.displayName,
                    onSelected: (on) =>
                        controller.text = on ? size.displayName : '',
                    selectedColor: _mkGreen,
                    labelStyle: TextStyle(
                      color: value.text == size.displayName
                          ? Colors.white
                          : _mkTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ),
        );
  }
}

const _maxAdPhotos = 3;

/// Asks camera or gallery, then picks up to [count] photos (the camera takes
/// one). Shrinks at pick time: less memory and a faster preview; uploads are
/// resized again to 1200px.
Future<List<XFile>> _pickAdPhotos(BuildContext context, int count) async {
  if (count <= 0) return const [];
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: _mkCard,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: _mkGreen),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(sheet, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: _mkGreen),
            title: Text(count == 1 ? 'Choose from gallery' : 'Choose from gallery (up to $count)'),
            onTap: () => Navigator.pop(sheet, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return const [];
  final picker = ImagePicker();
  try {
    if (source == ImageSource.camera || count == 1) {
      final f = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      return f == null ? const [] : [f];
    }
    final files = await picker.pickMultiImage(
      limit: count,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return files.take(count).toList();
  } catch (_) {
    // Camera or gallery permission refused, or no camera.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(source == ImageSource.camera
              ? 'Could not open the camera. Allow camera access in Settings.'
              : 'Could not open the gallery.',),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return const [];
  }
}

class _PhotosStep extends StatelessWidget {
  final List<String> existingPhotos;
  final List<XFile> pickedFiles;
  final void Function(String) onExistingRemoved;
  final void Function(List<XFile>) onNewPicked;
  final void Function(XFile) onNewRemoved;

  /// Swaps a photo (an existing URL or a picked file) for a new pick.
  final void Function(Object old, XFile file) onReplace;
  final Widget pickup;

  const _PhotosStep({
    required this.existingPhotos,
    required this.pickedFiles,
    required this.onExistingRemoved,
    required this.onNewPicked,
    required this.onNewRemoved,
    required this.onReplace,
    required this.pickup,
  });

  Future<void> _replace(BuildContext context, Object old) async {
    final files = await _pickAdPhotos(context, 1);
    if (files.isNotEmpty) onReplace(old, files.first);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Upload images (${existingPhotos.length + pickedFiles.length}/$_maxAdPhotos)',
          style: AppTypography.h3
              .copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Take photos or pick from your gallery, up to $_maxAdPhotos. The first is the cover. Tap a photo to replace it.',
          style: AppTypography.caption.copyWith(color: _mkTextSecondary),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            ...existingPhotos.map(
              (url) => _PhotoTile(
                onTap: () => _replace(context, url),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: _mkTextSecondary,
                  ),
                ),
                onRemove: () => onExistingRemoved(url),
              ),
            ),
            ...pickedFiles.map(
              (f) => _PhotoTile(
                onTap: () => _replace(context, f),
                child: Image.file(
                  File(f.path),
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.photo_outlined,
                    color: _mkTextSecondary,
                  ),
                ),
                onRemove: () => onNewRemoved(f),
              ),
            ),
            if (existingPhotos.length + pickedFiles.length < _maxAdPhotos)
              GestureDetector(
                onTap: () async {
                  final files = await _pickAdPhotos(
                    context,
                    _maxAdPhotos - existingPhotos.length - pickedFiles.length,
                  );
                  if (files.isNotEmpty) onNewPicked(files);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _mkBg,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _mkBorder, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _mkGreen,
                        size: 28,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          fontSize: 10,
                          color: _mkGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        pickup,
      ],
    );
  }
}

/// "Pickup & access" questions on Plants I Have. Road and truck are separate:
/// a road may be too narrow for a truck. No road means a pickup point.
class _PickupAccessForm extends StatelessWidget {
  final bool? road;
  final bool? truck;
  final TextEditingController pickupCtrl;
  final TextEditingController instructionsCtrl;
  final String? error;
  final ValueChanged<bool> onRoad;
  final ValueChanged<bool> onTruck;

  const _PickupAccessForm({
    required this.road,
    required this.truck,
    required this.pickupCtrl,
    required this.instructionsCtrl,
    required this.error,
    required this.onRoad,
    required this.onTruck,
  });

  Widget _yesNo(String label, IconData icon, bool? value,
          ValueChanged<bool>? onChanged, {String? note,}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: _mkGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _mkTextPrimary,
                    ),
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Yes')),
                    ButtonSegment(value: false, label: Text('No')),
                  ],
                  selected: {if (value != null) value},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: onChanged == null
                      ? null
                      : (v) {
                          if (v.isNotEmpty) onChanged(v.first);
                        },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (st) => st.contains(WidgetState.selected)
                          ? (value == false ? _stExpiredBg : _mkLight)
                          : _mkCard,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (st) => st.contains(WidgetState.selected)
                          ? (value == false ? _stExpired : _mkDark)
                          : _mkTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  note,
                  style: AppTypography.caption.copyWith(color: _stPaused),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pickupRequired = road == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pickup & road access',
          style: AppTypography.h3
              .copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Helps buyers know if they can bring a truck or must meet you somewhere.',
          style: AppTypography.caption.copyWith(color: _mkTextSecondary),
        ),
        const SizedBox(height: 16),
        _yesNo('Road to the plants?', Icons.add_road_rounded, road, onRoad),
        _yesNo(
          'Truck can reach directly?',
          Icons.local_shipping_outlined,
          truck,
          road == false ? null : onTruck,
          note: road == false
              ? 'No road, so no truck: buyers collect at the pickup point.'
              : truck == false
                  ? 'Buyers will see that a truck cannot reach your plants.'
                  : null,
        ),
        Text(
          pickupRequired ? 'Pickup point *' : 'Pickup point (optional)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _mkTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: pickupCtrl,
          maxLength: 255,
          decoration: _inputDec('e.g. Gate on NH-44, near the banyan tree')
              .copyWith(prefixIcon: const Icon(Icons.place_outlined)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Additional instructions (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _mkTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: instructionsCtrl,
          maxLines: 3,
          maxLength: 500,
          decoration: _inputDec('Directions, narrow roads, best time to come...'),
        ),
        if (error != null)
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: _stExpired),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error!,
                  style: AppTypography.caption.copyWith(color: _stExpired),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// How buyers reach a for-sale ad's plants: road, truck, pickup point, notes.
class _AccessInfo extends StatelessWidget {
  final bool? road;
  final bool? truck;
  final String? pickupPoint;
  final String? instructions;

  const _AccessInfo({
    this.road,
    this.truck,
    this.pickupPoint,
    this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    final point = (pickupPoint ?? '').trim();
    final notes = (instructions ?? '').trim();
    if (road == null && truck == null && point.isEmpty && notes.isEmpty) {
      return const SizedBox.shrink();
    }
    final limited = road == false || truck == false;
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.body.copyWith(color: _mkTextPrimary),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pickup & access',
              style: AppTypography.h4.copyWith(color: _mkTextPrimary),
            ),
            const Spacer(),
            if (limited)
              const _Chip('⚠ Limited access', Color(0xFFFEF3C7), Color(0xFFB45309)),
          ],
        ),
        const SizedBox(height: 10),
        if (road != null)
          road!
              ? row(Icons.add_road_rounded, _mkGreen, 'Road accessible')
              : row(Icons.block_rounded, _stExpired, 'No road to the plants'),
        if (truck != null)
          truck!
              ? row(Icons.local_shipping_rounded, _mkGreen, 'Truck accessible')
              : row(Icons.local_shipping_outlined, _stPaused,
                  'A truck cannot reach directly',),
        if (point.isNotEmpty)
          row(Icons.place_rounded, _mkGreen, 'Pickup point: $point'),
        if (notes.isNotEmpty)
          row(Icons.info_outline_rounded, _mkTextSecondary, notes),
      ],
    );
  }
}

/// Ad photos full screen: swipe between them, pinch or double-tap to zoom,
/// nothing cropped. Pops with the photo it ended on.
class _PhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initial;
  const _PhotoViewer({required this.photos, required this.initial});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _ctrl = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(_page);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              '${_page + 1} / ${widget.photos.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: PageView.builder(
            controller: _ctrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _ZoomablePhoto(url: widget.photos[i]),
          ),
        ),
      );
}

class _ZoomablePhoto extends StatefulWidget {
  final String url;
  const _ZoomablePhoto({required this.url});

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _zoom = TransformationController();

  // Dragging moves a zoomed photo; unzoomed, swipes go to the page view.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        // Double-tap toggles 2.5x zoom; pinch zooms freely.
        onDoubleTap: () => _zoom.value = _zoom.value.isIdentity()
            ? (Matrix4.identity()..scaleByDouble(2.5, 2.5, 1, 1))
            : Matrix4.identity(),
        child: InteractiveViewer(
          transformationController: _zoom,
          panEnabled: _zoomed,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const CircularProgressIndicator(color: Colors.white),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      );
}

class _PhotoTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _PhotoTile({
    required this.child,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.expand(child: child),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xDD000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 13,),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  final TextEditingController plantCtrl,
      titleCtrl,
      descCtrl,
      qtyCtrl,
      priceCtrl,
      sizeCtrl;
  final List<String> existingPhotos;
  final List<XFile> pickedFiles;
  final Widget access;

  const _PreviewStep({
    required this.access,
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
        Text(
          'Preview',
          style: AppTypography.h3
              .copyWith(color: _mkTextPrimary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'This is how your ad will look.',
          style: AppTypography.caption.copyWith(color: _mkTextSecondary),
        ),
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
                  child: Image(
                    image: existingPhotos.isNotEmpty
                        ? NetworkImage(allPhotos.first)
                        : FileImage(File(allPhotos.first)) as ImageProvider,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _mkLight,
                      child: const Icon(
                        Icons.local_florist_outlined,
                        size: 56,
                        color: _mkGreen,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 160,
                  color: _mkLight,
                  child: const Center(
                    child: Icon(
                      Icons.local_florist_outlined,
                      size: 56,
                      color: _mkGreen,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleCtrl.text.trim().isEmpty
                          ? 'Ad Title'
                          : titleCtrl.text.trim(),
                      style: AppTypography.h4.copyWith(color: _mkTextPrimary),
                    ),
                    const SizedBox(height: 6),
                    if (priceCtrl.text.trim().isNotEmpty)
                      Text(
                        _priceLabel(double.tryParse(priceCtrl.text.trim()), 'PER_PLANT'),
                        style: const TextStyle(
                          color: _mkGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    if (qtyCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Chip(
                        '${qtyCtrl.text.trim()} available',
                        _mkLight,
                        _mkDark,
                      ),
                    ],
                    if (descCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        descCtrl.text.trim(),
                        style: AppTypography.body
                            .copyWith(color: _mkTextPrimary, height: 1.5),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    access,
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
    final firstPage = ref.watch(savedAdsProvider(1));

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
          child: Divider(height: 1, color: _mkBorder),
        ),
      ),
      body: firstPage.when(
        loading: () => const _SkeletonList(),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(savedAdsProvider),
        ),
        data: (first) {
          if (first.total == 0) {
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
              itemCount: first.total,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              // Each row watches its page, so pages load as they scroll in.
              itemBuilder: (_, i) {
                final page = ref
                    .watch(savedAdsProvider(i ~/ savedAdsPageSize + 1))
                    .valueOrNull;
                final j = i % savedAdsPageSize;
                return page == null || j >= page.ads.length
                    ? const _SkeletonCard()
                    : _BrowseAdCard(ad: page.ads[j]);
              },
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
          title: const Text('Chats'),
          backgroundColor: _mkCard,
          foregroundColor: _mkTextPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            labelColor: _mkGreen,
            unselectedLabelColor: _mkTextSecondary,
            indicatorColor: _mkGreen,
            tabs: [
              Tab(text: 'On my ads'),
              Tab(text: 'I contacted'),
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
        onRetry: () => ref.invalidate(provider),
      ),
      data: (enquiries) {
        if (enquiries.isEmpty) {
          return _EmptyState(
            icon: Icons.mail_outline_rounded,
            title: isReceived ? 'No chats on your ads yet' : 'You have not contacted anyone',
            subtitle: isReceived
                ? 'When a nursery messages you about one of your ads, it appears here'
                : 'Chats you start from an ad ("Chat with seller" or "I have this") appear here',
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
            itemBuilder: (_, i) =>
                _EnquiryCard(enquiry: enquiries[i], isReceived: isReceived),
          ),
        );
      },
    );
  }
}

/// One chat in the list: who, which ad, the latest message and unread count.
class _EnquiryCard extends StatelessWidget {
  final MarketEnquiry enquiry;
  final bool isReceived;
  const _EnquiryCard({required this.enquiry, required this.isReceived});

  @override
  Widget build(BuildContext context) {
    final other = isReceived ? enquiry.enquiryNurseryName : enquiry.adNurseryName;
    final unread = enquiry.unreadCount;
    final bold = unread > 0 ? FontWeight.w800 : FontWeight.w600;
    // Only states the user acts on get a label; "new"/"in progress" is noise.
    final ended = const {'DEAL_AGREED', 'CLOSED', 'CANCELLED'}.contains(enquiry.status);
    final adClosed = enquiry.adStatus != 'PUBLISHED';
    return _greyIf(ended || adClosed, Material(
      color: _mkCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _EnquiryDetailScreen(enquiryId: enquiry.id, title: other),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: unread > 0 ? _mkGreen : _mkBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _mkLight,
                child: Text(
                  other.isEmpty ? '?' : other[0].toUpperCase(),
                  style: const TextStyle(color: _mkGreen, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            other,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(color: _mkTextPrimary, fontWeight: bold),
                          ),
                        ),
                        Text(
                          _timeAgo(enquiry.lastMessageAt ?? enquiry.createdAt),
                          style: AppTypography.caption.copyWith(
                            color: unread > 0 ? _mkGreen : _mkTextSecondary,
                            fontWeight: unread > 0 ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _TypePill(want: enquiry.adType == 'WANT'),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            enquiry.adTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(color: _mkTextSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            enquiry.lastMessage ?? enquiry.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              color: unread > 0 ? _mkTextPrimary : _mkTextSecondary,
                              fontSize: 13,
                              fontWeight: unread > 0 ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                        if (ended) ...[
                          const SizedBox(width: 6),
                          _EnquiryStatusChip(status: enquiry.status),
                        ] else if (adClosed) ...[
                          const SizedBox(width: 6),
                          const _Chip('Ad closed', _stArchivedBg, _stArchived),
                        ],
                        if (unread > 0) ...[
                          const SizedBox(width: 6),
                          Badge(
                            label: Text(unread > 99 ? '99+' : '$unread'),
                            backgroundColor: _mkGreen,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}

class _AdChatsScreen extends StatelessWidget {
  final MarketAd ad;
  const _AdChatsScreen({required this.ad});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _mkBg,
        appBar: AppBar(
          title: Text('Chats · ${ad.title}', overflow: TextOverflow.ellipsis),
          backgroundColor: _mkCard,
          foregroundColor: _mkTextPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: _EnquiryList(
          provider: adEnquiriesProvider(ad.id),
          isReceived: true,
        ),
      );
}

/// One chat between two nurseries about one ad, opened by its enquiry id.
/// Both sides talk, bargain with offers (accept / counter / decline), and the
/// chat turns read-only once it ends or the ad stops being live.
class _EnquiryDetailScreen extends ConsumerStatefulWidget {
  final int enquiryId;
  final String title;
  const _EnquiryDetailScreen({required this.enquiryId, required this.title});

  @override
  ConsumerState<_EnquiryDetailScreen> createState() =>
      _EnquiryDetailScreenState();
}

class _EnquiryDetailScreenState extends ConsumerState<_EnquiryDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // shortcut: polls every 5 s while the chat is open; switch to push or a
    // websocket when chat traffic grows.
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => ref.invalidate(enquiryDetailProvider(widget.enquiryId)),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  EnquiryChatNotifier get _chat =>
      ref.read(replyEnquiryProvider(widget.enquiryId).notifier);

  /// Runs a chat action with a spinner, showing the API message on failure.
  Future<bool> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (e) {
      // The chat may have turned read-only (ad paused or removed, chat
      // closed): reload it so the screen shows why, not a stale reply box.
      ref.invalidate(enquiryDetailProvider(widget.enquiryId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _stExpired,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _busy) return;
    if (await _act(() => _chat.reply(body))) _replyCtrl.clear();
  }

  Future<void> _offer(MarketEnquiry enquiry,
      {MarketEnquiryMessage? countering,}) async {
    final result = await showModalBottomSheet<(double, int?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfferSheet(
        enquiry: enquiry,
        initialPrice: countering?.offerPrice ?? enquiry.adPricePerUnit,
        initialQuantity: countering?.offerQuantity ?? enquiry.quantityNeeded,
        isCounter: countering != null,
      ),
    );
    if (result == null) return;
    await _act(() => _chat.offer(result.$1, quantity: result.$2));
  }

  Future<void> _end(MarketEnquiry enquiry) async {
    final seller = enquiry.capabilities?.canClose ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(seller ? 'Close this chat?' : 'Cancel this enquiry?'),
        content: const Text('Nobody can send messages or offers after this.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep chatting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              seller ? 'Close chat' : 'Cancel enquiry',
              style: const TextStyle(color: _stExpired),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _act(() => _chat.end(seller ? 'close' : 'cancel'));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(enquiryDetailProvider(widget.enquiryId));
    // Scroll to the newest message when one arrives, ours or theirs.
    ref.listen(enquiryDetailProvider(widget.enquiryId), (prev, next) {
      // Loading the chat marked it read on the server: refresh the badges.
      if (next.hasValue) ref.invalidate(marketUnreadProvider);
      if (next.valueOrNull?.messages.length ==
          prev?.valueOrNull?.messages.length) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });

    final enquiry = detailAsync.valueOrNull;
    final isSeller = enquiry?.summary?.isSeller ?? false;
    final other = enquiry == null
        ? widget.title
        : (isSeller ? enquiry.enquiryNurseryName : enquiry.adNurseryName);
    final caps = enquiry?.capabilities;

    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: Text(other, overflow: TextOverflow.ellipsis),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (enquiry != null &&
              ((caps?.canClose ?? false) || (caps?.canCancel ?? false)))
            PopupMenuButton<String>(
              onSelected: (_) => _end(enquiry),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'end',
                  child: Text(
                    (caps?.canClose ?? false) ? 'Close chat' : 'Cancel enquiry',
                  ),
                ),
              ],
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _mkBorder),
        ),
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _mkGreen)),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(enquiryDetailProvider(widget.enquiryId)),
        ),
        data: (enquiry) {
          final caps = enquiry.capabilities;
          final canReply = caps?.canReply ?? false;
          return Column(
            children: [
              InkWell(
                onTap: () => _openAd(enquiry),
                child: _EnquiryDetailHeader(enquiry: enquiry),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: enquiry.messages.length,
                  itemBuilder: (_, i) {
                    final msg = enquiry.messages[i];
                    if (msg.isSystem) return _SystemNote(text: msg.body);
                    if (msg.isOffer) {
                      return _OfferCard(
                        msg: msg,
                        priceUnit: enquiry.adPriceUnit,
                        busy: _busy,
                        onAccept: () => _act(
                          () => _chat.respond(msg.id, accept: true),
                        ),
                        onDecline: () => _act(
                          () => _chat.respond(msg.id, accept: false),
                        ),
                        onCounter: (caps?.canOffer ?? false)
                            ? () => _offer(enquiry, countering: msg)
                            : null,
                      );
                    }
                    return _MessageBubble(
                      body: msg.body,
                      senderName: msg.senderName.isEmpty
                          ? msg.nurseryName
                          : '${msg.senderName} · ${msg.nurseryName}',
                      isMe: msg.isMine,
                      time: msg.createdAt,
                    );
                  },
                ),
              ),
              if (canReply)
                _ReplyInput(
                  controller: _replyCtrl,
                  replying: _busy,
                  onSend: () => _send(_replyCtrl.text),
                  // On a want the ad's nursery is the buyer: replies follow
                  // who is selling, not who posted the ad.
                  // Skip replies this side already sent in the chat.
                  quickReplies: _quickReplies(
                    enquiry,
                    isSeller: enquiry.adType == 'WANT' ? !isSeller : isSeller,
                  )
                      .where(
                        (q) => !enquiry.messages.any((m) => m.isMine && m.body == q),
                      )
                      .toList(),
                  onQuickReply: _send,
                  onOffer:
                      (caps?.canOffer ?? false) ? () => _offer(enquiry) : null,
                )
              else
                _ReadOnlyBar(
                  reason: caps?.readOnlyReason ??
                      (enquiry.status == 'CANCELLED'
                          ? 'this enquiry was cancelled'
                          : 'this chat is closed'),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Opens the ad this chat is about; ads no longer live are gone for others.
  Future<void> _openAd(MarketEnquiry enquiry) async {
    try {
      final ad = await ref.read(marketRepositoryProvider).getAd(enquiry.adId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _AdDetailScreen(ad: ad)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This ad is no longer available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static List<String> _quickReplies(MarketEnquiry e, {required bool isSeller}) {
    if (e.isDealAgreed) {
      return isSeller
          ? const [
              'Ready for pickup',
              'Sharing the location',
              'Please confirm the date',
            ]
          : const [
              'When can I pick up?',
              'Please share the location',
              'On my way',
            ];
    }
    return isSeller
        ? const [
            'Yes, it is available',
            'Price is fixed',
            'Pickup only',
            'Sorry, sold out',
          ]
        : const [
            'Is it still available?',
            'What is your best price?',
            'Can you deliver?',
            'Please share more photos',
          ];
  }
}

String _rupees(double v) =>
    '₹${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

/// Price unit codes in words; ads posted from the app are per plant.
String _unitLabel(String? unit) => switch (unit) {
      null || '' || 'PER_PLANT' => 'per plant',
      'PER_100' => 'per 100',
      'PER_DOZEN' => 'per dozen',
      'PER_KG' => 'per kg',
      _ => unit.toLowerCase().replaceAll('_', ' '),
    };

/// The ad this chat is about, its live status, and the agreed deal if any.
class _EnquiryDetailHeader extends StatelessWidget {
  final MarketEnquiry enquiry;
  const _EnquiryDetailHeader({required this.enquiry});

  @override
  Widget build(BuildContext context) {
    final live = enquiry.adStatus == 'PUBLISHED';
    return Container(
      color: _mkCard,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: enquiry.adPhoto != null
                      ? Image.network(
                          enquiry.adPhoto!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: _mkLight,
                            child: Icon(
                              Icons.local_florist_outlined,
                              color: _mkGreen,
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: _mkLight,
                          child: Icon(Icons.local_florist_outlined,
                              color: _mkGreen,),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypePill(want: enquiry.adType == 'WANT'),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            enquiry.adTitle,
                            style: AppTypography.label.copyWith(
                              color: _mkTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (enquiry.adType == 'WANT')
                          'Wanted'
                        else
                          _priceLabel(enquiry.adPricePerUnit, enquiry.adPriceUnit),
                        if (!live) 'Ad no longer active' else 'Tap to view the ad',
                      ].join(' · '),
                      style: AppTypography.caption.copyWith(
                        color: live ? _mkTextSecondary : _stExpired,
                      ),
                    ),
                  ],
                ),
              ),
              if (const {'CLOSED', 'CANCELLED'}.contains(enquiry.status)) ...[
                const SizedBox(width: 8),
                _EnquiryStatusChip(status: enquiry.status),
              ] else if (live)
                const Icon(Icons.chevron_right_rounded, color: _mkTextSecondary),
            ],
          ),
          if (enquiry.isDealAgreed && enquiry.agreedPricePerUnit != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _mkLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined,
                      size: 18, color: _mkGreen,),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deal agreed: ${_rupees(enquiry.agreedPricePerUnit!)} ${_unitLabel(enquiry.adPriceUnit)}'
                      '${enquiry.agreedQuantity != null ? ' × ${enquiry.agreedQuantity}' : ''}',
                      style: const TextStyle(
                        color: _mkDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// An offer in the chat. The nursery that did not make it can accept,
/// counter (a new offer back) or decline while it is pending.
class _OfferCard extends StatelessWidget {
  final MarketEnquiryMessage msg;
  final String? priceUnit;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onCounter;
  const _OfferCard({
    required this.msg,
    required this.priceUnit,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
  });

  @override
  Widget build(BuildContext context) {
    final price = msg.offerPrice ?? 0;
    final qty = msg.offerQuantity;
    final (label, color) = switch (msg.offerStatus) {
      'ACCEPTED' => ('Accepted', _stPublished),
      'DECLINED' => ('Declined', _stExpired),
      'WITHDRAWN' => ('Replaced by a newer offer', _mkTextSecondary),
      _ => (msg.isMine ? 'Waiting for reply' : 'Waiting for you', _stPaused),
    };
    final who = msg.isMine ? 'Your offer' : 'Offer from ${msg.nurseryName}';
    return Align(
      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _mkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: msg.offerStatus == 'PENDING' ? _mkGreen : _mkBorder,
            width: msg.offerStatus == 'PENDING' ? 1.5 : 1,
          ),
          boxShadow: const [_cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    size: 16, color: _mkGreen,),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    who,
                    style: AppTypography.caption.copyWith(
                      color: _mkTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_rupees(price)} ${_unitLabel(priceUnit)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _mkTextPrimary,
              ),
            ),
            if (qty != null)
              Text(
                '× $qty  =  ${_rupees(price * qty)} total',
                style: AppTypography.caption.copyWith(color: _mkTextSecondary),
              ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (msg.canRespond) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _stExpired,
                        side: const BorderSide(color: _mkBorder),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  if (onCounter != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onCounter,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _mkGreen,
                          side: const BorderSide(color: _mkGreen),
                        ),
                        child: const Text('Counter'),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mkGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  final String text;
  const _SystemNote({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _mkLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: _mkDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

class _ReadOnlyBar extends StatelessWidget {
  final String reason;
  const _ReadOnlyBar({required this.reason});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: _mkCard,
          border: Border(top: BorderSide(color: _mkBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: _mkTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Read-only: ${reason[0].toUpperCase()}${reason.substring(1)}.',
                  style:
                      AppTypography.caption.copyWith(color: _mkTextSecondary),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Price (pre-filled with the ad's price or the offer being countered) and an
/// optional quantity. Pops (price, quantity).
class _OfferSheet extends StatefulWidget {
  final MarketEnquiry enquiry;
  final double? initialPrice;
  final int? initialQuantity;
  final bool isCounter;
  const _OfferSheet({
    required this.enquiry,
    required this.initialPrice,
    required this.initialQuantity,
    required this.isCounter,
  });

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  late final _priceCtrl = TextEditingController(
    text: widget.initialPrice == null
        ? ''
        : widget.initialPrice!.toStringAsFixed(
            widget.initialPrice! == widget.initialPrice!.roundToDouble()
                ? 0
                : 2,
          ),
  );
  late final _qtyCtrl =
      TextEditingController(text: widget.initialQuantity?.toString() ?? '');

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  double? get _price => double.tryParse(_priceCtrl.text.trim());
  int? get _qty => int.tryParse(_qtyCtrl.text.trim());

  @override
  Widget build(BuildContext context) {
    final price = _price;
    final qty = _qty;
    final valid = price != null &&
        price > 0 &&
        (_qtyCtrl.text.trim().isEmpty || (qty != null && qty > 0));
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _mkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isCounter ? 'Counter offer' : 'Make an offer',
                style: AppTypography.h3.copyWith(
                  color: _mkTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.enquiry.adPricePerUnit == null
                    ? widget.enquiry.adTitle
                    : 'Listed at ${_rupees(widget.enquiry.adPricePerUnit!)} ${_unitLabel(widget.enquiry.adPriceUnit)}',
                style: AppTypography.caption.copyWith(color: _mkTextSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDec('Your price').copyWith(
                  prefixText: '₹ ',
                  suffixText: _unitLabel(widget.enquiry.adPriceUnit),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDec('Quantity (optional)'),
                onChanged: (_) => setState(() {}),
              ),
              if (price != null && qty != null && qty > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Total ${_rupees(price * qty)}',
                  style: const TextStyle(
                    color: _mkDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: valid
                      ? () => Navigator.of(context).pop((price, qty))
                      : null,
                  child: Text(
                    widget.isCounter ? 'Send counter offer' : 'Send offer',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration:
                  const BoxDecoration(color: _mkLight, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  senderName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: _mkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
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
                    child: Text(
                      senderName,
                      style: AppTypography.caption.copyWith(
                        color: _mkTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  child: Text(
                    body,
                    style: TextStyle(
                      color: isMe ? Colors.white : _mkTextPrimary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _timeAgo(time),
                  style: AppTypography.caption.copyWith(
                    color: _mkTextSecondary.withValues(alpha: 0.7),
                  ),
                ),
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
  final List<String> quickReplies;
  final ValueChanged<String> onQuickReply;

  /// Null when offers are not allowed, e.g. after a deal is agreed.
  final VoidCallback? onOffer;
  const _ReplyInput({
    required this.controller,
    required this.replying,
    required this.onSend,
    required this.quickReplies,
    required this.onQuickReply,
    required this.onOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: _mkCard,
        border: Border(top: BorderSide(color: _mkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickReplies.length + (onOffer != null ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  if (onOffer != null && i == 0) {
                    return ActionChip(
                      avatar: const Icon(
                        Icons.local_offer_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text('Make offer'),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      backgroundColor: _mkGreen,
                      side: BorderSide.none,
                      onPressed: replying ? null : onOffer,
                    );
                  }
                  final text = quickReplies[i - (onOffer != null ? 1 : 0)];
                  return ActionChip(
                    label: Text(text),
                    labelStyle: const TextStyle(color: _mkDark, fontSize: 12),
                    backgroundColor: _mkLight,
                    side: BorderSide.none,
                    onPressed: replying ? null : () => onQuickReply(text),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: _inputDec('Write a message...').copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10,),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: _mkGreen, shape: BoxShape.circle,),
                  child: replying
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Send message',
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: onSend,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerTopItemTile extends StatelessWidget {
  final SellerTopItem item;
  const _SellerTopItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: _mkLight,
      child: Icon(Icons.local_florist_outlined, color: _mkGreen),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _mkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mkBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: item.photo == null
                  ? placeholder
                  : Image.network(
                      item.photo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.commonName ?? item.plantName,
                  style: AppTypography.label.copyWith(
                    color: _mkTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    if (item.commonName != null) item.plantName,
                    item.sizeName,
                  ].join(' · '),
                  style:
                      AppTypography.caption.copyWith(color: _mkTextSecondary),
                ),
                if (item.qualityNotes != null && item.qualityNotes!.isNotEmpty)
                  Text(
                    item.qualityNotes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.caption.copyWith(color: _mkTextSecondary),
                  ),
              ],
            ),
          ),
          if (item.unitPrice != null)
            Text(
              _rupees(item.unitPrice!),
              style:
                  const TextStyle(color: _mkGreen, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

/// The poster's camera selfie in a circle; their initial when there is none.
class _SellerAvatar extends StatelessWidget {
  final String? photo;
  final String name;
  final double size;
  const _SellerAvatar(
      {required this.photo, required this.name, required this.size,});

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: _mkGreen,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _mkLight, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: photo == null || photo!.isEmpty
          ? initial
          : Image.network(
              photo!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => initial,
            ),
    );
  }
}

/// A nursery's public market page: who runs it, how long it has been here,
/// its activity and its live ads.
class _SellerProfileScreen extends ConsumerWidget {
  final int nurseryId;
  const _SellerProfileScreen({required this.nurseryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerProfileProvider(nurseryId));
    return Scaffold(
      backgroundColor: _mkBg,
      appBar: AppBar(
        title: const Text('Seller'),
        backgroundColor: _mkCard,
        foregroundColor: _mkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _mkGreen)),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(sellerProfileProvider(nurseryId)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: _SellerAvatar(
                photo: p.ownerPhoto,
                name: p.ownerName ?? p.nurseryName,
                size: 96,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (p.verified)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child:
                        Icon(Icons.verified_rounded, size: 18, color: _mkGreen),
                  ),
                Flexible(
                  child: Text(
                    p.nurseryName,
                    style: AppTypography.h3.copyWith(color: _mkTextPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (p.ownerName != null) p.ownerName!,
                if (p.city != null) p.city!,
                'On GreenRoot since ${_monthYear(p.memberSince)}',
              ].join(' · '),
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: _mkTextSecondary),
            ),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                p.description!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: _mkTextPrimary),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _sellerStat('${p.liveAds}', 'Live ads'),
                _sellerStat('${p.adsPosted}', 'Ads posted'),
                _sellerStat('${p.dealsAgreed}', 'Deals agreed'),
              ],
            ),
            if (p.topItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Top items',
                style: AppTypography.h4.copyWith(color: _mkTextPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Plants this nursery is known for',
                style: AppTypography.caption.copyWith(color: _mkTextSecondary),
              ),
              const SizedBox(height: 10),
              for (final t in p.topItems) _SellerTopItemTile(item: t),
            ],
            const SizedBox(height: 20),
            Text(
              'Live ads',
              style: AppTypography.h4.copyWith(color: _mkTextPrimary),
            ),
            const SizedBox(height: 10),
            if (p.ads.isEmpty)
              Text(
                'No live ads right now.',
                style: AppTypography.body.copyWith(color: _mkTextSecondary),
              )
            else
              for (final ad in p.ads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BrowseAdCard(ad: ad),
                ),
          ],
        ),
      ),
    );
  }

  static String _monthYear(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  static Widget _sellerStat(String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _mkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _mkBorder),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _mkTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption.copyWith(color: _mkTextSecondary),
              ),
            ],
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'PUBLISHED' => ('Published', _stPublished, _stPublishedBg),
      'DRAFT' => ('Draft', _stDraft, _stDraftBg),
      'PAUSED' => ('Paused', _stPaused, _stPausedBg),
      'EXPIRED' => ('Expired', _stExpired, _stExpiredBg),
      'ARCHIVED' => ('Archived', _stArchived, _stArchivedBg),
      'SUSPENDED' => ('Under review', _stPaused, _stPausedBg),
      'REMOVED' => ('Removed by GreenRoot', _stExpired, _stExpiredBg),
      _ => (status, _stDraft, _stDraftBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Closed things (a finished chat, a closed ad) are drawn in grey so they
/// read as done at a glance; they stay tappable.
const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

Widget _greyIf(bool closed, Widget child) => closed
    ? Opacity(
        opacity: 0.7,
        child: ColorFiltered(colorFilter: _greyscale, child: child),
      )
    : child;

/// The seller's chats on one ad: straight into the conversation when one
/// nursery wrote, otherwise the list of nurseries for this ad only.
Future<void> _openAdChats(BuildContext context, WidgetRef ref, MarketAd ad) async {
  List<MarketEnquiry> chats = const [];
  try {
    chats = await ref.read(adEnquiriesProvider(ad.id).future);
  } catch (_) {
    // Fall back to the list screen, which shows the error and a retry.
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => chats.length == 1
          ? _EnquiryDetailScreen(
              enquiryId: chats.first.id,
              title: chats.first.enquiryNurseryName,
            )
          : _AdChatsScreen(ad: ad),
    ),
  );
}

class _EnquiryStatusChip extends StatelessWidget {
  final String status;
  const _EnquiryStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'NEW' => ('New', _stPublished, _stPublishedBg),
      'IN_PROGRESS' => ('In Progress', _stPaused, _stPausedBg),
      'DEAL_AGREED' => ('Deal agreed', _stPublished, _stPublishedBg),
      'CLOSED' => ('Closed', _stArchived, _stArchivedBg),
      'CANCELLED' => ('Cancelled', _stExpired, _stExpiredBg),
      _ => (status, _stDraft, _stDraftBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  const BoxDecoration(color: _mkLight, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: _mkGreen),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.h3.copyWith(
                color: _mkTextPrimary,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.body
                  .copyWith(color: _mkTextSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: _mkTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: AppTypography.h4.copyWith(
                color: _mkTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.caption.copyWith(color: _mkTextSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _mkGreen,
                side: const BorderSide(color: _mkGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
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
      width: width,
      height: height,
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
          const Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 80, height: 10),
                SizedBox(height: 8),
                _SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 6),
                _SkeletonBox(width: 160, height: 14),
                SizedBox(height: 12),
                _SkeletonBox(width: 60, height: 20),
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
