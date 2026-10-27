part of 'order_detail_screen.dart';

class _RateOrderCard extends ConsumerStatefulWidget {
  final Order order;
  const _RateOrderCard({required this.order});

  @override
  ConsumerState<_RateOrderCard> createState() => _RateOrderCardState();
}

class _RateOrderCardState extends ConsumerState<_RateOrderCard> {
  late Future<Rating?> _ratingFuture;
  bool _ratedHere = false;

  @override
  void initState() {
    super.initState();
    _ratingFuture = _loadRating();
  }

  @override
  void didUpdateWidget(covariant _RateOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _ratedHere = false;
      _ratingFuture = _loadRating();
    }
  }

  Future<Rating?> _loadRating() =>
      ref.read(ratingRepositoryProvider).getMyOrderRating(widget.order.id);

  @override
  Widget build(BuildContext context) => FutureBuilder<Rating?>(
        future: _ratingFuture,
        builder: (context, snapshot) {
          // Only offer rating when the API confirms there isn't one already.
          if (_ratedHere ||
              snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError ||
              snapshot.data != null) {
            return const SizedBox.shrink();
          }

          return _buildPrompt(context);
        },
      );

  Widget _buildPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.amber500, size: 20,),
              const SizedBox(width: AppSpacing.xs),
              Text('Rate your experience',
                  style:
                      AppTypography.label.copyWith(color: AppColors.forest800),),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How was the plant quality and service for this order?',
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final submitted = await context.push<bool>(
                      '/ratings/order/${widget.order.id}?code=${widget.order.orderNumber}',
                    );
                    if (mounted && submitted == true) {
                      setState(() => _ratedHere = true);
                    }
                  },
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Rate Order'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Items card ────────────────────────────────────────────────────────────────

class _ItemsCard extends ConsumerStatefulWidget {
  final Order order;
  final NumberFormat fmt;
  final bool canManage;
  const _ItemsCard(
      {required this.order, required this.fmt, required this.canManage,});

  @override
  ConsumerState<_ItemsCard> createState() => _ItemsCardState();
}

class _ItemsCardState extends ConsumerState<_ItemsCard> {
  bool _expanded = false;

  bool get _editable => widget.order.status == 'LOADING' && widget.canManage;

  void _refresh() => ref.invalidate(orderDetailProvider(widget.order.id));

  Future<void> _deleteItem(OrderItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "${item.displayName}" from this order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Remove', style: TextStyle(color: AppColors.errorText)),),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(orderRepositoryProvider)
          .deleteOrderItem(widget.order.id, item.id);
      _refresh();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: AppColors.errorText,),
      );
    }
  }

  Future<void> _showItemSheet({OrderItem? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),),
      builder: (_) => _ItemEditSheet(
        orderId: widget.order.id,
        existing: existing,
        onSaved: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items;
    final preview = _expanded ? items : items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Items (${items.length})', style: AppTypography.h4),
            if (_editable)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.amber100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Editable',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.amber700),),
                ),
              ),
          ],
        ),
        if (_editable) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Items can be added, removed, or updated until Loading Completed.',
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty && _editable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No items yet. Tap "Add Item" to add plants to this order.',
              textAlign: TextAlign.center,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ...preview.asMap().entries.map((entry) {
                  final item = entry.value;
                  // A short load is billed on what was loaded (as the total is).
                  final loaded = item.loadedQuantity;
                  final short = loaded != null && loaded < item.quantity;
                  return Column(
                    children: [
                      if (entry.key > 0) const Divider(height: 1, indent: 16),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.displayName,
                                      style: AppTypography.body,),
                                  if (item.sizeName != null)
                                    Text(item.sizeName!,
                                        style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary,),),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    widget.fmt.format(short
                                        ? loaded * item.unitPrice
                                        : item.totalPrice,),
                                    style: AppTypography.label,),
                                Text(
                                    short
                                        ? 'Loaded ${loaded.toInt()} of ${item.quantity.toInt()}'
                                        : 'Qty: ${item.quantity.toInt()}',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,),),
                              ],
                            ),
                            if (_editable) ...[
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.primaryMain,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showItemSheet(existing: item),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.errorText,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteItem(item),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                if (items.length > 3)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Text(
                        _expanded
                            ? 'Show less'
                            : 'Show ${items.length - 3} more items',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.primaryMain,
                            fontWeight: FontWeight.w600,),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_editable) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showItemSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Item Edit Sheet ───────────────────────────────────────────────────────────

class _ItemEditSheet extends ConsumerStatefulWidget {
  final int orderId;
  final OrderItem? existing;
  final VoidCallback onSaved;

  const _ItemEditSheet(
      {required this.orderId, this.existing, required this.onSaved,});

  @override
  ConsumerState<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<_ItemEditSheet> {
  Plant? _plant;
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _qtyCtrl.text = e.quantity == e.quantity.roundToDouble()
          ? e.quantity.toInt().toString()
          : e.quantity.toStringAsFixed(2);
      _priceCtrl.text = e.unitPrice == e.unitPrice.roundToDouble()
          ? e.unitPrice.toInt().toString()
          : e.unitPrice.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPlant() async {
    final result = await showModalBottomSheet<Plant>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),),
      builder: (_) => const _PlantSearchSheet(),
    );
    if (result != null) setState(() => _plant = result);
  }

  Future<void> _save() async {
    final plantId = _plant?.id ?? widget.existing?.plantId;
    final qty = double.tryParse(_qtyCtrl.text.trim());
    final price = double.tryParse(_priceCtrl.text.trim());

    if (plantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plant')),
      );
      return;
    }
    if (qty == null || qty <= 0 || price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid quantity and price')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(orderRepositoryProvider);
    final req = OrderItemRequest(
      plantId: plantId,
      quantity: qty,
      unitPrice: price,
      totalPrice: qty * price,
    );
    try {
      if (widget.existing != null) {
        await repo.updateOrderItem(widget.orderId, widget.existing!.id, req);
      } else {
        await repo.createOrderItem(widget.orderId, req);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: AppColors.errorText,),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final plantName =
        _plant?.displayName ?? (isEdit ? widget.existing!.displayName : null);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 24,),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(isEdit ? 'Edit Item' : 'Add Item', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.lg),
            // Plant picker
            GestureDetector(
              onTap: _pickPlant,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        plantName ?? 'Select plant…',
                        style: AppTypography.body.copyWith(
                          color: plantName != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: NumberInput.whole,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: NumberInput.money,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,),)
                    : Text(isEdit ? 'Save Changes' : 'Add Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plant search sheet (reused for item add/edit) ─────────────────────────────

class _PlantSearchSheet extends ConsumerStatefulWidget {
  const _PlantSearchSheet();

  @override
  ConsumerState<_PlantSearchSheet> createState() => _PlantSearchSheetState();
}

class _PlantSearchSheetState extends ConsumerState<_PlantSearchSheet> {
  final _ctrl = TextEditingController();
  List<PlantMatch> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch('');
    _ctrl.addListener(() => _fetch(_ctrl.text.trim()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetch(String q) async {
    setState(() => _loading = true);
    try {
      final plants =
          await ref.read(plantRepositoryProvider).lookupPlants(q, limit: 20);
      // Replies can arrive out of order: keep only the one for the current text.
      if (mounted && q == _ctrl.text.trim()) setState(() => _results = plants);
    } catch (_) {
      // leave results as-is
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),),),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search plants…',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        AppLoader(),)
                : _results.isEmpty
                    ? _ctrl.text.trim().length >= 2
                        ? PlantNotFound(query: _ctrl.text)
                        : Center(
                            child: Text('No plants found',
                                style: AppTypography.body
                                    .copyWith(color: AppColors.textSecondary),),)
                    : ListView.separated(
                        controller: controller,
                        itemCount: _results.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          if (i == _results.length) {
                            return SuggestPlantTile(query: _ctrl.text);
                          }
                          final m = _results[i];
                          return ListTile(
                            title: Text(m.title),
                            subtitle: m.subtitle != null
                                ? Text(m.subtitle!,
                                    style: AppTypography.caption,)
                                : null,
                            onTap: () async {
                              final p = await resolvePickedPlant(context, ref, m);
                              if (p != null && context.mounted) {
                                Navigator.pop(context, p);
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Assign Manager Sheet ──────────────────────────────────────────────────────
