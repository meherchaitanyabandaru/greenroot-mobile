// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  BUYER — MY NURSERY CONNECTIONS                                              ║
// ║  Route: /buyer/connections                                                   ║
// ║  Role:  BUYER (any authenticated user can scan invites)                      ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// Shows nurseries the buyer has a relationship with (derived from orders) and
// surfaces all QR-based onboarding flows the buyer can use:
//
//   CUSTOMER_INVITE   — owner shares QR → buyer scans → linked to nursery
//   MANAGER_INVITE    — already handled in the same InviteAcceptScreen
//   NURSERY_ONBOARDING_INVITE — admin shares QR → buyer scans → becomes owner
//
// The buyer never sees internal invite mechanics; they just scan a QR code.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/qr_scanner_screen.dart';
import '../orders/orders.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _NurseryEntry {
  final int id;
  final String name;
  final int orderCount;
  final String? mobile;
  final String? email;
  final String? city;
  final String? address;

  const _NurseryEntry({
    required this.id,
    required this.name,
    required this.orderCount,
    this.mobile,
    this.email,
    this.city,
    this.address,
  });

  _NurseryEntry copyWith({int? orderCount}) => _NurseryEntry(
        id: id,
        name: name,
        orderCount: orderCount ?? this.orderCount,
        mobile: mobile,
        email: email,
        city: city,
        address: address,
      );
}

// ── Provider — derive unique nurseries from buyer's order history ──────────────

final _buyerNurseriesProvider =
    FutureProvider.autoDispose<List<_NurseryEntry>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);

  // Run orders and accepted invite connections in parallel
  final results = await Future.wait([
    repo.listBuyingOrders(page: 1, perPage: 100).then((r) => r.$1).catchError((_) => <dynamic>[]),
    ApiClient.instance
        .get<Map<String, dynamic>>('/api/v1/me/connections')
        .catchError((_) => <String, dynamic>{}),
  ]);

  final orders = results[0] as List<dynamic>;
  final connectionsData = results[1] as Map<String, dynamic>;
  final invites = (connectionsData['invites'] as List<dynamic>?) ?? [];

  final map = <int, _NurseryEntry>{};

  // Seed from accepted invites first (these are explicit connections)
  for (final inv in invites) {
    final m = inv as Map<String, dynamic>;
    final id = (m['nursery_id'] as num?)?.toInt() ?? 0;
    if (id == 0) continue;
    if (!map.containsKey(id)) {
      map[id] = _NurseryEntry(
        id: id,
        name: m['nursery_name'] as String? ?? 'Nursery',
        orderCount: 0,
      );
    }
  }

  // Add/increment from order history
  for (final o in orders) {
    // o is an Order object with sellerNurseryId / sellerNursery fields
    final dynamic ord = o;
    final id = (ord.sellerNurseryId as int?) ?? 0;
    if (id == 0) continue;
    final existing = map[id];
    if (existing == null) {
      map[id] = _NurseryEntry(
        id: id,
        name: (ord.sellerNursery as String?) ?? 'Nursery',
        orderCount: 1,
      );
    } else {
      map[id] = existing.copyWith(orderCount: existing.orderCount + 1);
    }
  }

  // Fetch contact details for each nursery
  final enriched = await Future.wait(map.values.map((e) async {
    try {
      final data = await ApiClient.instance
          .get<Map<String, dynamic>>('/api/v1/nurseries/${e.id}');
      final n = (data['nursery'] ?? data) as Map<String, dynamic>;
      final addrs = (n['addresses'] as List<dynamic>?) ?? [];
      String? city;
      String? addressLine;
      if (addrs.isNotEmpty) {
        final primary = addrs.firstWhere(
          (a) => (a as Map)['is_primary'] == true,
          orElse: () => addrs.first,
        ) as Map<String, dynamic>;
        city = primary['city'] as String?;
        addressLine = primary['address_line1'] as String?;
      }
      return _NurseryEntry(
        id: e.id,
        name: n['name'] as String? ?? e.name,
        orderCount: e.orderCount,
        mobile: n['mobile'] as String?,
        email: n['email'] as String?,
        city: city,
        address: addressLine,
      );
    } catch (_) {
      return e;
    }
  }));

  return enriched..sort((a, b) => a.name.compareTo(b.name));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class BuyerNurseryConnectionsScreen extends ConsumerWidget {
  const BuyerNurseryConnectionsScreen({super.key});

  Future<void> _scanInviteQr(BuildContext context) async {
    final uuid = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(title: 'Scan Nursery QR'),
        fullscreenDialog: true,
      ),
    );
    if (uuid != null && uuid.isNotEmpty && context.mounted) {
      context.push('/invite/${Uri.encodeComponent(uuid.trim())}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nurseriesAsync = ref.watch(_buyerNurseriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Connected Nurseries', style: AppTypography.h3),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primaryMain,
        onRefresh: () => ref.refresh(_buyerNurseriesProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // ── Scan invite QR hero card ─────────────────────────────────────
            _ScanCard(onScan: () => _scanInviteQr(context)),
            const SizedBox(height: AppSpacing.x2l),

            // ── Connected nurseries ──────────────────────────────────────────
            Text('Connected Nurseries', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.md),

            nurseriesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child:
                      CircularProgressIndicator(color: AppColors.primaryMain),
                ),
              ),
              error: (_, __) => _RetryCard(
                onRetry: () => ref.refresh(_buyerNurseriesProvider.future),
              ),
              data: (nurseries) => nurseries.isEmpty
                  ? _EmptyNurseries(
                      onScan: () => _scanInviteQr(context),
                      onBrowse: () => context.push('/nurseries'),
                    )
                  : Column(
                      children: nurseries
                          .map((n) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md),
                                child: _NurseryCard(entry: n),
                              ))
                          .toList(),
                    ),
            ),

            const SizedBox(height: AppSpacing.x2l),
          ],
        ),
      ),
    );
  }
}

// ── Hero scan card ─────────────────────────────────────────────────────────────

class _ScanCard extends StatelessWidget {
  final VoidCallback onScan;
  const _ScanCard({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryMain, Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connect to a Nursery',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      "Scan a nursery's invite QR code",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan Invite QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryMain,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: AppTypography.button,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nursery card ──────────────────────────────────────────────────────────────

class _NurseryCard extends StatelessWidget {
  final _NurseryEntry entry;
  const _NurseryCard({required this.entry});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NurseryDetailSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: AppColors.primaryMain, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: AppTypography.h4),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${entry.orderCount} order${entry.orderCount == 1 ? '' : 's'}',
                      if (entry.city != null) entry.city!,
                    ].join(' · '),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Nursery detail bottom sheet ───────────────────────────────────────────────

class _NurseryDetailSheet extends StatelessWidget {
  final _NurseryEntry entry;
  const _NurseryDetailSheet({required this.entry});

  Future<void> _call() async {
    final mobile = entry.mobile;
    if (mobile == null) return;
    final uri = Uri(scheme: 'tel', path: mobile);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final mobile = entry.mobile;
    if (mobile == null) return;
    // Prepend India country code if not already international
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    final intl = digits.length == 10 ? '91$digits' : digits;
    final uri = Uri.parse('https://wa.me/$intl');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _email() async {
    final mail = entry.email;
    if (mail == null) return;
    final uri = Uri(scheme: 'mailto', path: mail);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final hasCall = entry.mobile != null && entry.mobile!.isNotEmpty;
    final hasEmail = entry.email != null && entry.email!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x2l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: AppColors.primaryMain, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: AppTypography.h3),
                    if (entry.city != null)
                      Text(entry.city!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.verified_rounded,
                  color: AppColors.primaryMain, size: 22),
            ],
          ),
          const SizedBox(height: AppSpacing.x2l),
          // Info rows
          if (entry.address != null)
            _InfoRow(
                icon: Icons.location_on_outlined,
                text: [entry.address, entry.city]
                    .where((v) => v != null)
                    .join(', ')),
          if (hasCall)
            _InfoRow(icon: Icons.phone_outlined, text: entry.mobile!),
          if (hasEmail)
            _InfoRow(icon: Icons.email_outlined, text: entry.email!),
          _InfoRow(
            icon: Icons.shopping_bag_outlined,
            text:
                '${entry.orderCount} order${entry.orderCount == 1 ? '' : 's'} placed',
          ),
          const SizedBox(height: AppSpacing.x2l),
          // Action buttons
          if (hasCall || hasEmail)
            Row(
              children: [
                if (hasCall)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        textStyle: AppTypography.button,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (hasCall)
                  const SizedBox(width: AppSpacing.sm),
                if (hasCall)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _whatsapp,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/whatsapp.svg',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'WhatsApp',
                            style: TextStyle(
                              color: Color(0xFF25D366),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasEmail) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _email,
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Email'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryMain,
                        side: const BorderSide(color: AppColors.primaryMain),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        textStyle: AppTypography.button,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppTypography.body
                    .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyNurseries extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onBrowse;
  const _EmptyNurseries({required this.onScan, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          const Text('No nurseries yet', style: AppTypography.h4,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            "Scan a nursery's invite QR to connect, or browse public nurseries.",
            style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Browse'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('Scan QR'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryMain),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Retry card ────────────────────────────────────────────────────────────────

class _RetryCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _RetryCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 36, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Could not load nurseries',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
