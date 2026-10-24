import '../../core/utilities/number_input.dart';
import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'offer_fairness.dart';
import 'market_area.dart';
import '../../core/media/photos.dart';

part 'screen/browse.dart';
part 'screen/my_ads.dart';
part 'screen/ad_detail.dart';
part 'screen/post_want.dart';
part 'screen/post_ad.dart';
part 'screen/chats.dart';
part 'screen/seller_profile.dart';
part 'screen/shared.dart';

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

// Offer fairness (offer_fairness.dart): green fair, orange haggling, red too low.
const _offerOrange = Color(0xFFEA580C);
const _offerOrangeBg = Color(0xFFFFEDD5);

(Color, Color) _bandColors(OfferBand band) => switch (band) {
      OfferBand.good => (_stPublished, _stPublishedBg),
      OfferBand.bargain => (_offerOrange, _offerOrangeBg),
      OfferBand.tooLow => (_stExpired, _stExpiredBg),
    };

/// "Fair offer · 3% below asking" chip, coloured by how fair the offer is.
class _FairnessChip extends StatelessWidget {
  final double offer;
  final double asking;
  const _FairnessChip({required this.offer, required this.asking});

  @override
  Widget build(BuildContext context) {
    final band = offerBand(offer, asking);
    final (fg, bg) = _bandColors(band);
    final verdict = switch (band) {
      // Read by both sides of the chat, so no "you"/"seller" wording.
      OfferBand.good => 'Fair offer',
      OfferBand.bargain => 'Bargaining',
      OfferBand.tooLow => 'Too low',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$verdict · ${offerVsAsking(offer, asking)}',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

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
          ref.invalidate(marketPositionProvider);
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
            SliverToBoxAdapter(child: _areaCaption()),
            listAsync.when(
              loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorState(
                  message: e.toString(),
                  onRetry: () {
                    ref.invalidate(marketPositionProvider);
                    ref.invalidate(provider);
                  },
                ),
              ),
              data: (ads) {
                if (ads.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: want ? Icons.campaign_outlined : Icons.storefront_outlined,
                      title: want
                          ? 'No one nearby is asking for plants'
                          : 'No plants for sale within ${ref.watch(marketRadiusProvider).round()} km',
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

  /// The market is local: say how far, and let the user change it.
  Widget _areaCaption() {
    final km = ref.watch(marketRadiusProvider).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, size: 16, color: _mkGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Showing ads within $km km of you',
              style: AppTypography.caption.copyWith(color: _mkTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _BrowseScreen(type: _type, openFilters: true),
              ),
            ),
            child: const Text('Change'),
          ),
        ],
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
