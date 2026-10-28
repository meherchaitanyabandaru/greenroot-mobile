part of '../local_market_screen.dart';

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
    // Closing ends every chat on the ad; the reason is shown to them.
    String? closeReason;
    if (action == 'archive') {
      closeReason = await _askCloseReason(context, widget.ad);
      if (closeReason == null) return;
    } else if (action == 'delete' &&
        !await _confirmDeleteAd(context, widget.ad)) {
      return;
    }
    setState(() => _actioning = true);
    try {
      // A draft saved with location off has no place; publishing needs one.
      if (action == 'publish' && widget.ad.status == 'DRAFT') {
        final gps = await _gpsPickup(ref);
        if (gps.isNotEmpty) {
          await ref
              .read(postAdProvider.notifier)
              .update(widget.ad.id, extra: gps);
        }
      }
      await ref.read(adActionProvider.notifier).perform(
            widget.ad.id,
            action,
            data: closeReason == null ? null : {'reason': closeReason},
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
          ('archive', 'Close', Icons.archive_outlined),
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
          ('archive', 'Close', Icons.archive_outlined),
        ],
      'PAUSED' => [
          ('edit', 'Edit', Icons.edit_outlined),
          ('resume', 'Resume', Icons.play_circle_outline_rounded),
          ('archive', 'Close', Icons.archive_outlined),
        ],
      'EXPIRED' => [
          ('renew', 'Renew', Icons.refresh_rounded),
          ('archive', 'Close', Icons.archive_outlined),
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

/// Why the ad is closing; null when the user backs out.
Future<String?> _askCloseReason(BuildContext context, MarketAd ad) =>
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ad.isWant ? 'Close this need?' : 'Close this ad?'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'It leaves the market and its chats end. They will see why.',
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'SOLD_OUT'),
            child: Text(ad.isWant ? 'I found the plants' : 'Sold out'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'NO_LONGER_AVAILABLE'),
            child: Text(ad.isWant ? 'No longer needed' : 'No longer available'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
