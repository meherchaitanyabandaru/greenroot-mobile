part of 'order_detail_screen.dart';

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String headline;
  final String message;
  final String? label;
  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.headline,
    required this.message,
    this.label,
  });
}

class _HeroCard extends ConsumerStatefulWidget {
  final Order order;
  final int orderId;
  final NumberFormat fmt;
  final bool canManage;
  final bool isOwner;
  final bool isBuyer;

  const _HeroCard({
    required this.order,
    required this.orderId,
    required this.fmt,
    required this.canManage,
    required this.isOwner,
    required this.isBuyer,
  });

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<_HeroCard> {
  bool _busy = false;

  Order get _order => widget.order;
  String get _status => _order.status;
  bool get _hasDeliveryAddress =>
      _order.deliverySnapshot?.addressLine1?.trim().isNotEmpty == true;

  // ── Status visual config ───────────────────────────────────────────────────

  _StatusConfig _cfgFor(Dispatch? dispatch) {
    final display = LifecyclePresenter.forOrder(
      order: _order,
      dispatch: dispatch,
      role: widget.isBuyer ? LifecycleRole.buyer : LifecycleRole.operator,
    );
    final message =
        _status == 'CANCELLED' && _order.cancelReason?.isNotEmpty == true
            ? 'Reason: ${_order.cancelReason}'
            : display.subtitle;
    return _StatusConfig(
      color: display.color,
      icon: _iconFor(display, dispatch),
      headline: display.title,
      message: message,
      label: display.label,
    );
  }

  IconData _iconFor(LifecycleDisplay display, Dispatch? dispatch) {
    final dispatchStatus = dispatch?.status.toUpperCase();
    if (display.variant == BadgeVariant.error) return Icons.cancel_rounded;
    if (dispatchStatus == 'IN_TRANSIT' || dispatchStatus == 'DISPATCHED') {
      return Icons.local_shipping_rounded;
    }
    if (dispatchStatus == 'ACCEPTED') return Icons.person_rounded;
    if (display.variant == BadgeVariant.success) {
      return Icons.check_circle_rounded;
    }
    if (_status == 'CONFIRMED' || _status == 'LOADING') {
      return Icons.inventory_2_outlined;
    }
    return Icons.schedule_rounded;
  }

  // ── API actions ────────────────────────────────────────────────────────────

  Future<void> _doAction(Future<Order> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(orderListProvider);
      ref.invalidate(buyingOrderListProvider);
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.red600);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (!_hasDeliveryAddress) {
      _snack('Add a delivery address before confirming this order.',
          AppColors.amber700,);
      return;
    }
    await _doAction(
        () => ref.read(orderRepositoryProvider).confirmOrder(widget.orderId),);
    if (mounted) _snack('Order confirmed', AppColors.primaryMain);
  }

  // Opens the delivery address form. Previously this button's label/icon
  // switched to "Add Delivery Address First" but onTap still pointed at
  // _confirm — tapping it just re-failed with the same warning instead of
  // opening anything.
  Future<void> _addDeliveryAddress() async {
    setState(() => _busy = true);
    await _openAndSaveDeliverySheet(context, ref, _order);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _startLoading() async {
    await _doAction(
        () => ref.read(orderRepositoryProvider).startLoading(widget.orderId),);
    if (mounted) _snack('Loading started', AppColors.blue600);
  }

  Future<void> _completeLoading() async {
    await _doAction(() =>
        ref.read(orderRepositoryProvider).completeLoading(widget.orderId),);
    if (mounted) _snack('Loading completed', AppColors.primaryMain);
  }

  // The Loading Workflow screen records loaded quantity per item (partial loads).
  Future<void> _loadPartially() async {
    await context.push(
      '/orders/loading?nursery=${_order.sellerNurseryId}&tab=LOADING',
    );
    if (!mounted) return;
    ref.invalidate(orderDetailProvider(widget.orderId));
    ref.invalidate(orderListProvider);
  }

  Future<void> _markCompleted() async {
    await _doAction(() => ref
        .read(orderRepositoryProvider)
        .updateStatus(widget.orderId, 'COMPLETED'),);
    if (mounted) _snack('Order marked as completed', AppColors.primaryMain);
  }

  Future<void> _createDispatch() async {
    final input = await showModalBottomSheet<_DispatchInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateDispatchSheet(
        onSubmit: (i) => Navigator.pop(ctx, i),
        onCancel: () => Navigator.pop(ctx),
      ),
    );
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final dispatch =
          await ref.read(dispatchRepositoryProvider).createDispatch(
                widget.orderId,
                destinationAddress: input.dest,
                notes: input.notes,
                outsideVehicleNumber: input.outsideVehicle,
                outsideDriverName: input.outsideDriverName,
                outsideDriverMobile: input.outsideDriverMobile,
              );
      if (mounted && dispatch.isOutsideTransport) {
        // No app driver to share a QR with: the nursery runs the trip.
        _snack(
          'Dispatch created. Mark it dispatched when the lorry leaves.',
          AppColors.primaryMain,
        );
        ref.invalidate(orderDetailProvider(widget.orderId));
        ref.invalidate(_orderDispatchesProvider(widget.orderId));
        context.push('/dispatches/${dispatch.id}');
      } else if (mounted) {
        await QrShareSheet.show(
          context,
          code: dispatch.dispatchCode,
          qrType: QrCodeType.tripQr,
          shareMessage:
              'GreenRoot Trip QR — ${dispatch.dispatchCode}\n\nShare with your driver to start the trip.\nOrder: ${_order.orderNumber}',
        );
        if (mounted) {
          ref.invalidate(orderDetailProvider(widget.orderId));
          ref.invalidate(_orderDispatchesProvider(widget.orderId));
          context.push('/dispatches/${dispatch.id}');
        }
      }
    } on AppError catch (e) {
      if (mounted) _snack(e.message, AppColors.red600);
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.red600);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewDispatch(Dispatch dispatch) async {
    await context.push('/dispatches/${dispatch.id}');
    // Cancelled or delivered there: the next step here changes (e.g. a
    // cancelled dispatch means "Create Dispatch" again, not "View Dispatch").
    if (!mounted) return;
    ref.invalidate(_orderDispatchesProvider(widget.orderId));
    ref.invalidate(orderDetailProvider(widget.orderId));
  }

  Future<void> _assignManager() async {
    final nurseryId = _order.sellerNurseryId;
    if (nurseryId == null) return;
    List<NurseryManager> managers;
    try {
      managers =
          await ref.read(orderRepositoryProvider).getNurseryManagers(nurseryId);
    } catch (_) {
      managers = [];
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<NurseryManager>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignManagerSheet(managers: managers),
    );
    if (selected == null || !mounted) return;
    await _doAction(() => ref
        .read(orderRepositoryProvider)
        .assignManager(widget.orderId, selected.userId),);
    if (mounted) _snack('${selected.name} assigned', AppColors.primaryMain);
  }

  Future<void> _confirmCancel() async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel Order', style: AppTypography.h3),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
            onChanged: (v) => reason = v,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Back'),),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Order',
                  style: TextStyle(color: AppColors.red600),),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _doAction(() => ref
        .read(orderRepositoryProvider)
        .cancelOrder(widget.orderId, reason: reason),);
    if (mounted) _snack('Order cancelled', AppColors.red600);
  }

  void _snack(String msg, Color bg) {
    bg == AppColors.red600 ? AppHaptics.error() : AppHaptics.success();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canManage = widget.canManage;
    final isOwner = widget.isOwner;
    final status = _status;
    final dispatchesAsync = ref.watch(_orderDispatchesProvider(widget.orderId));
    final dispatches = dispatchesAsync.valueOrNull ?? [];
    final isCheckingDispatches = dispatchesAsync.isLoading;
    final needsDeliveryBeforeConfirm =
        canManage && status == 'PENDING' && !_hasDeliveryAddress;
    final existingDispatch =
        LifecyclePresenter.activeDispatchForOrder(dispatches, widget.orderId);
    final cfg = _cfgFor(existingDispatch);
    final statusLabel = cfg.label ?? status.replaceAll('_', ' ');

    // Determine primary + secondary buttons for this role × state
    Widget? primaryBtn;
    Widget? secondaryBtn;
    Widget? tertiaryBtn;

    if (canManage) {
      switch (status) {
        case 'PENDING':
          primaryBtn = _BigButton(
            label: needsDeliveryBeforeConfirm
                ? 'Add Delivery Address First'
                : 'Confirm Order',
            icon: needsDeliveryBeforeConfirm
                ? Icons.location_on_outlined
                : Icons.check_circle_outline_rounded,
            color: needsDeliveryBeforeConfirm
                ? AppColors.amber700
                : AppColors.primaryMain,
            onTap: _busy
                ? null
                : (needsDeliveryBeforeConfirm ? _addDeliveryAddress : _confirm),
          );
          secondaryBtn = _OutlineButton(
            label: 'Cancel Order',
            color: AppColors.red600,
            onTap: _busy ? null : _confirmCancel,
          );
        case 'CONFIRMED':
          primaryBtn = _BigButton(
            label: 'Start Loading',
            icon: Icons.inventory_2_outlined,
            color: AppColors.blue600,
            onTap: _busy ? null : _startLoading,
          );
        case 'LOADING':
          primaryBtn = _BigButton(
            label: 'Complete Loading',
            icon: Icons.done_all_rounded,
            color: AppColors.primaryMain,
            onTap: _busy ? null : _completeLoading,
          );
          // Not everything fits or is in stock: record loaded quantities per item.
          if (_order.sellerNurseryId != null) {
            secondaryBtn = _OutlineButton(
              label: 'Load Some Items Only',
              color: AppColors.primaryMain,
              onTap: _busy ? null : _loadPartially,
            );
          }
        case 'LOADED':
        case 'PARTIALLY_FULFILLED':
          final hasDeliveredDispatch = existingDispatch?.status == 'DELIVERED';
          if (existingDispatch != null) {
            primaryBtn = _BigButton(
              label: 'View Dispatch',
              pulse: false,
              icon: Icons.local_shipping_rounded,
              color: AppColors.blue600,
              onTap: _busy ? null : () => _viewDispatch(existingDispatch),
            );
          } else if (isCheckingDispatches) {
            primaryBtn = const _BigButton(
              label: 'Checking Dispatch',
              pulse: false,
              icon: Icons.sync_rounded,
              color: AppColors.textSecondary,
              onTap: null,
            );
          } else {
            primaryBtn = _BigButton(
              label: 'Create Dispatch',
              icon: Icons.local_shipping_rounded,
              color: AppColors.blue600,
              onTap: _busy ? null : _createDispatch,
            );
          }
          if (hasDeliveredDispatch) {
            secondaryBtn = _OutlineButton(
              label: 'Mark as Completed',
              color: AppColors.primaryMain,
              onTap: _busy ? null : _markCompleted,
            );
          }
      }

      // Owner-only: assign manager — shown as a subtle tertiary link
      final canAssignMgr = isOwner &&
          _order.sellerNurseryId != null &&
          !{'CANCELLED', 'COMPLETED', 'LOADED', 'PARTIALLY_FULFILLED'}
              .contains(status);
      if (canAssignMgr) {
        tertiaryBtn = TextButton.icon(
          onPressed: _busy ? null : _assignManager,
          icon: const Icon(Icons.manage_accounts_rounded, size: 16),
          label: Text(
            _order.assignedManagerUserId != null
                ? 'Re-assign Manager'
                : 'Assign Manager',
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs,),
          ),
        );
      }
    } else if (widget.isBuyer && status == 'PENDING') {
      // Buyer can only cancel their own PENDING order
      secondaryBtn = _OutlineButton(
        label: 'Cancel Order',
        color: AppColors.red600,
        onTap: _busy ? null : _confirmCancel,
      );
    }

    final hasActions =
        primaryBtn != null || secondaryBtn != null || tertiaryBtn != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored status strip at the very top
          Container(height: 4, color: cfg.color),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order amount + item count
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fmt.format(_order.totalAmount),
                            style: AppTypography.h1
                                .copyWith(color: AppColors.textPrimary),
                          ),
                          if (_order.items.isNotEmpty)
                            Text(
                              '${_order.items.length} item${_order.items.length == 1 ? '' : 's'}',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    // Status badge pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6,),
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: cfg.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: AppTypography.caption.copyWith(
                              color: cfg.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Status icon + headline + message
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cfg.icon, color: cfg.color, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cfg.headline, style: AppTypography.label),
                          if (cfg.message.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                cfg.message,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Action buttons — only shown when there's something to do
                if (hasActions) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.md),
                  if (_busy)
                    const Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primaryMain,),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_status == 'LOADING') ...[
                          const LiveActivityStrip(activity: LiveActivity.loading),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (primaryBtn != null) ...[
                          primaryBtn,
                          if (secondaryBtn != null)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                        if (secondaryBtn != null) secondaryBtn,
                        if (tertiaryBtn != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          tertiaryBtn,
                        ],
                      ],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PDF download/share row ──────────────────────────────────────────────────
// Always visible regardless of role/status. Content shown in the PDF itself is
// gated server-side (buyers get a receipt without internal notes/handler name);
// the download action here is available to anyone who can view the order.

class _DownloadOrderPdfRow extends ConsumerStatefulWidget {
  final Order order;
  const _DownloadOrderPdfRow({required this.order});

  @override
  ConsumerState<_DownloadOrderPdfRow> createState() =>
      _DownloadOrderPdfRowState();
}

class _DownloadOrderPdfRowState extends ConsumerState<_DownloadOrderPdfRow> {
  bool _exporting = false;

  Future<(List<int>, String)> _downloadPdfFromApi() async {
    final response = await ApiClient.instance.dio.get<List<int>>(
      ApiConstants.orderRenderedDocument(widget.order.id),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    final bytes = List<int>.from(response.data ?? const <int>[]);
    final filename = _filenameFromDisposition(
          response.headers.value('content-disposition'),
        ) ??
        '${widget.order.orderCode}.pdf';
    return (bytes, filename);
  }

  String? _filenameFromDisposition(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return match?.group(1);
  }

  Future<void> _openWebPdf(List<int> bytes) async {
    final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
    await launchUrl(Uri.parse(dataUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadPdf() async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _downloadPdfFromApi();
      if (kIsWeb) {
        await _openWebPdf(bytes);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        // App documents dir is private on Android; hand the file to the OS.
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: filename,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: AppColors.red600,),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareViaWhatsApp() async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _downloadPdfFromApi();
      if (kIsWeb) {
        await _openWebPdf(bytes);
        final msg = Uri.encodeComponent(
          'Order ${widget.order.orderCode} — PDF downloaded to your device.',
        );
        await launchUrl(
          Uri.parse('https://wa.me/?text=$msg'),
          mode: LaunchMode.externalApplication,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Order ${widget.order.orderCode}',
          subject: widget.order.orderCode,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('WhatsApp share failed: $e'),
              backgroundColor: AppColors.red600,),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _exporting = true);
    try {
      final (bytes, filename) = await _downloadPdfFromApi();
      if (kIsWeb) {
        await _openWebPdf(bytes);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: '${widget.order.orderCode} — GreenRoot Order',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Share failed: $e'),
              backgroundColor: AppColors.red600,),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: _exporting ? null : _downloadPdf,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Download PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            elevation: 0,
            fixedSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 48,
        height: 48,
        child: ElevatedButton(
          onPressed: _exporting ? null : _shareViaWhatsApp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: SvgPicture.asset(
            'assets/icons/whatsapp.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          onPressed: _exporting ? null : _sharePdf,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: const Icon(Icons.ios_share_rounded, size: 22),
        ),
      ),
    ],);
  }
}

// ── Reusable button helpers ────────────────────────────────────────────────────

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  // The hero's main action is the order's next step: glow so new users see it.
  final bool pulse;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.pulse = true,
  });

  @override
  Widget build(BuildContext context) {
    return NextActionPulse(
      active: pulse && onTap != null,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),),
            elevation: 0,
            textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _OutlineButton({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeightSm),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.sm),),
          textStyle: AppTypography.label,
        ),
        child: Text(label),
      ),
    );
  }
}

// ── Section card wrapper ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h4),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ── Buyer delivery section ────────────────────────────────────────────────────
// Shown only to buyers. No operational timeline — just: "is it coming and who?"
// Large, prominent card with driver info and call button when a dispatch exists.
