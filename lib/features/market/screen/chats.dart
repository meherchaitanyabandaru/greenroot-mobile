part of '../local_market_screen.dart';

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

class EnquiriesScreen extends ConsumerWidget {
  const EnquiriesScreen({super.key});

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

typedef _EnquiriesScreen = EnquiriesScreen;

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
    // A deal is good news and the chat goes on (pickup): only closed or
    // cancelled chats are drawn grey.
    final ended = const {'CLOSED', 'CANCELLED'}.contains(enquiry.status);
    final showStatus = ended || enquiry.status == 'DEAL_AGREED';
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
                        if (showStatus) ...[
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
class EnquiryDetailScreen extends ConsumerStatefulWidget {
  final int enquiryId;
  final String title;
  const EnquiryDetailScreen({
    super.key,
    required this.enquiryId,
    this.title = 'Market Chat',
  });

  @override
  ConsumerState<EnquiryDetailScreen> createState() =>
      _EnquiryDetailScreenState();
}

typedef _EnquiryDetailScreen = EnquiryDetailScreen;

class _EnquiryDetailScreenState extends ConsumerState<EnquiryDetailScreen> {
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
        askingPrice: _askingPrice(enquiry),
        // Only the buyer has a floor; the seller's counters are their call.
        minPrice: _askingPrice(enquiry) != null &&
                (enquiry.summary?.isBuyer ?? false)
            ? minOfferFor(_askingPrice(enquiry)!)
            : null,
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
            const Center(child: AppLoader()),
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
                        // Judge the buyer's offers only; the seller's counters
                        // are their own price.
                        askingPrice:
                            msg.isMine == (enquiry.summary?.isBuyer ?? false)
                                ? _askingPrice(enquiry)
                                : null,
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
                      avatarUrl: msg.senderAvatarUrl,
                      receipt: msg.receipt,
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

/// The asking price offers are judged against: for-sale ads with a price.
double? _askingPrice(MarketEnquiry e) =>
    e.adType == 'SELL' && (e.adPricePerUnit ?? 0) > 0 ? e.adPricePerUnit : null;

/// ₹6,400 / ₹1,25,000 / ₹69.30 — Indian digit grouping.
String _rupees(double v) => NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: v == v.roundToDouble() ? 0 : 2,
    ).format(v);

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

  /// For-sale ads: shows how fair the offer is against this price.
  final double? askingPrice;
  const _OfferCard({
    required this.msg,
    required this.priceUnit,
    this.askingPrice,
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
    // Superseded offers step back so the live one stands out in long chats.
    final replaced = msg.offerStatus == 'WITHDRAWN';
    return Opacity(
      opacity: replaced ? 0.55 : 1,
      child: Align(
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
            if (askingPrice != null && price > 0 && !replaced) ...[
              const SizedBox(height: 8),
              _FairnessChip(offer: price, asking: askingPrice!),
            ],
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
              // Accept on its own row: three buttons side by side in a 280 px
              // card broke the words ("Decli-ne", "Acce-pt").
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Accept', maxLines: 1),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _stExpired,
                        side: const BorderSide(color: _mkBorder),
                      ),
                      child: const Text('Decline', maxLines: 1),
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
                        child: const Text('Counter', maxLines: 1),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
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

  /// For-sale ads: the asking price offers are compared with (null = none).
  final double? askingPrice;

  /// The buyer's floor (70% of asking); null when no limit applies.
  final double? minPrice;
  const _OfferSheet({
    required this.enquiry,
    required this.initialPrice,
    required this.initialQuantity,
    required this.isCounter,
    this.askingPrice,
    this.minPrice,
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
    final asking = widget.askingPrice;
    final min = widget.minPrice;
    final tooLow = price != null && min != null && price < min;
    final valid = price != null &&
        price > 0 &&
        !tooLow &&
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
                inputFormatters: NumberInput.money,
                decoration: _inputDec('Your price').copyWith(
                  prefixText: '₹ ',
                  suffixText: _unitLabel(widget.enquiry.adPriceUnit),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (price != null && price > 0 && asking != null) ...[
                const SizedBox(height: 8),
                _FairnessChip(offer: price, asking: asking),
              ],
              if (tooLow) ...[
                const SizedBox(height: 6),
                Text(
                  'Offer at least ${_rupees(min)} — 70% of the asking price. '
                  'Very low offers put sellers off.',
                  style: AppTypography.caption.copyWith(color: _stExpired),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: NumberInput.whole,
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
  final String? avatarUrl;
  final String receipt;
  const _MessageBubble({
    required this.body,
    required this.senderName,
    required this.isMe,
    required this.time,
    this.avatarUrl,
    this.receipt = 'SENT',
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
            _ChatAvatar(url: avatarUrl, name: senderName),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeAgo(time),
                      style: AppTypography.caption.copyWith(
                        color: _mkTextSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        receipt == 'SENT'
                            ? Icons.done_rounded
                            : Icons.done_all_rounded,
                        size: 16,
                        color: receipt == 'READ'
                            ? const Color(0xFF34B7F1)
                            : _mkTextSecondary,
                        semanticLabel: receipt == 'READ'
                            ? 'Read'
                            : receipt == 'DELIVERED'
                                ? 'Delivered'
                                : 'Sent',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _ChatAvatar(url: avatarUrl, name: senderName),
          ],
        ],
      ),
    );
  }
}

/// The sender's photo, or their first letter when they have none.
class _ChatAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _ChatAvatar({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: 16,
      backgroundColor: _mkLight,
      foregroundImage: hasPhoto ? NetworkImage(url!) : null,
      onForegroundImageError: hasPhoto ? (_, __) {} : null,
      // CircleAvatar paints its child over the photo: letter only without one.
      child: hasPhoto
          ? null
          : Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: _mkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
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
