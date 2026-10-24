part of '../local_market_screen.dart';

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
              inputFormatters: NumberInput.whole,
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
