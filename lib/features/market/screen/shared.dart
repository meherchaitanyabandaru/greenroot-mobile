part of '../local_market_screen.dart';

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
