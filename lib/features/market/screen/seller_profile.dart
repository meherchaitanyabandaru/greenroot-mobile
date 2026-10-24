part of '../local_market_screen.dart';

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
