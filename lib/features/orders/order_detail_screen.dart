import '../../core/utilities/number_input.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/services/recent_items.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/order_timeline.dart';
import '../../core/widgets/next_action_pulse.dart';
import '../../core/domain/lifecycle_presenter.dart';
import '../../core/testing/test_keys.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../../core/services/geocoding/geocoding_service.dart'
    show MapPickResult;
import '../dispatches/dispatches.dart';
import '../plants/plants.dart';
import '../plants/plant_picker.dart';
import '../profile/address_map_picker_screen.dart';
import '../ratings/ratings.dart';
import 'orders.dart';
import '../../core/feedback/app_haptics.dart';
import '../../core/widgets/live_activity_strip.dart';
import '../../core/widgets/app_loader.dart';

part 'order_detail_sheets.dart';
part 'order_detail_items.dart';
part 'order_detail_delivery.dart';
part 'order_detail_hero.dart';

// Fetches dispatches for a single order, shown inline in the order detail.
final _orderDispatchesProvider =
    FutureProvider.autoDispose.family<List<Dispatch>, int>(
  (ref, orderId) => ref.watch(dispatchRepositoryProvider).listByOrder(orderId),
);

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final caps = ref.watch(sessionProvider).capabilities;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: async.maybeWhen(
          data: (o) => Text(o.orderNumber, style: AppTypography.h4),
          orElse: () => const Text('Order Details'),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: async.when(
        loading: () => const Center(
            child: AppLoader(),),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textMuted,),
              const SizedBox(height: AppSpacing.md),
              Text(err.toString(), style: AppTypography.body),
              TextButton(
                onPressed: () => ref.refresh(orderDetailProvider(orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (order) {
          // Seller controls only for this order's own nursery; an owner or
          // manager who bought from another nursery is a buyer here.
          final canManage = caps.sellsFor(order.sellerNurseryId);
          final isOwner = caps.ownedNurseryId != null &&
              caps.ownedNurseryId == order.sellerNurseryId;
          final isBuyer = !canManage && !caps.hasDriverProfile;
          // "Continue Working" -- deferred to a post-frame callback rather
          // than called directly in build(), since it writes to a provider
          // another still-mounted screen (Home) may be watching.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(recentItemsProvider.notifier).record(RecentItem(
                  type: RecentItemType.order,
                  id: order.id,
                  title: order.orderNumber,
                  subtitle: order.buyerName ?? order.sellerNursery ?? '',
                  viewedAt: DateTime.now(),
                ),);
          });
          return _OrderDetailBody(
            order: order,
            orderId: orderId,
            fmt: fmt,
            canManage: canManage,
            isOwner: isOwner,
            isBuyer: isBuyer,
          );
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _OrderDetailBody extends StatelessWidget {
  final Order order;
  final int orderId;
  final NumberFormat fmt;
  final bool canManage;
  final bool isOwner;
  final bool isBuyer;

  const _OrderDetailBody({
    required this.order,
    required this.orderId,
    required this.fmt,
    required this.canManage,
    required this.isOwner,
    required this.isBuyer,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // ── Hero: status + amount + action — always first ─────────────────
        _HeroCard(
          order: order,
          orderId: orderId,
          fmt: fmt,
          canManage: canManage,
          isOwner: isOwner,
          isBuyer: isBuyer,
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── PDF download/share row — always visible, any role/status ──────
        _DownloadOrderPdfRow(order: order),

        const SizedBox(height: AppSpacing.x2l),

        if (isBuyer) ...[
          // ── BUYER VIEW ───────────────────────────────────────────────────
          // No operational timeline — buyers don't care about loading steps.
          // Just: delivery tracking (if a dispatch exists) → info → items.
          _BuyerDeliverySection(orderId: orderId),
          const SizedBox(height: AppSpacing.x2l),
        ] else ...[
          // ── SELLER / MANAGER VIEW ────────────────────────────────────────
          // Operational timeline (loading steps matter here).
          _SectionCard(
            title: 'Order Timeline',
            child: OrderTimeline(order: order, role: OrderTimelineRole.seller),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Dispatch cards below timeline
          _SellerDispatchSection(orderId: orderId),
        ],

        // ── Collapsible order info (buyer + seller) ───────────────────────
        _CollapsibleInfoCard(order: order),

        if (order.deliverySnapshot != null || canManage) ...[
          const SizedBox(height: AppSpacing.x2l),
          _DeliverySnapshotCard(
            order: order,
            canManage: canManage,
          ),
        ],

        // ── Items ─────────────────────────────────────────────────────────
        if (order.items.isNotEmpty ||
            (order.status == 'LOADING' && canManage)) ...[
          const SizedBox(height: AppSpacing.x2l),
          _ItemsCard(order: order, fmt: fmt, canManage: canManage),
        ],

        // ── Rate this order (buyer only, after completion) ────────────────
        if (isBuyer && order.status == 'COMPLETED') ...[
          const SizedBox(height: AppSpacing.x2l),
          _RateOrderCard(order: order),
        ],

        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────
// Combines order summary + current status + role-appropriate actions.
// The user sees their next step immediately — no scrolling required.
