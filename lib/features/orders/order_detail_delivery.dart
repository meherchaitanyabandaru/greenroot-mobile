part of 'order_detail_screen.dart';

class _BuyerDeliverySection extends ConsumerWidget {
  final int orderId;
  const _BuyerDeliverySection({required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_orderDispatchesProvider(orderId)).maybeWhen(
          data: (dispatches) {
            if (dispatches.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Delivery', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.md),
                ...dispatches.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _BuyerDeliveryCard(dispatch: d),
                    ),),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _BuyerDeliveryCard extends StatelessWidget {
  final Dispatch dispatch;
  const _BuyerDeliveryCard({required this.dispatch});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final isOnWay = {'DISPATCHED', 'IN_TRANSIT'}.contains(d.status);
    final isDelivered = d.status == 'DELIVERED';
    final hasDriver = d.driverName?.isNotEmpty == true;
    final hasPhone = d.driverMobile?.isNotEmpty == true;
    final display = LifecyclePresenter.forDispatch(
      dispatch: d,
      role: LifecycleRole.buyer,
    );
    final statusColor = display.color;
    final statusBg = display.color.withValues(alpha: 0.12);
    final statusIcon = switch (d.status.toUpperCase()) {
      'DELIVERED' => Icons.check_circle_rounded,
      'DISPATCHED' || 'IN_TRANSIT' => Icons.local_shipping_rounded,
      'ACCEPTED' => Icons.person_rounded,
      _ => Icons.schedule_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: isOnWay ? AppColors.amber500 : AppColors.border,
          width: isOnWay ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Status strip + icon row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 26),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(display.label,
                          style: AppTypography.h4.copyWith(color: statusColor),),
                      if (isOnWay)
                        Text(
                          'Your order is on its way to you',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        )
                      else if (isDelivered)
                        Text(
                          'Successfully delivered',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        )
                      else if (hasDriver)
                        Text(
                          'Driver will pick up your order soon',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Driver + vehicle details with call button
          if (hasDriver || d.vehicleNumber?.isNotEmpty == true) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding, vertical: AppSpacing.md,),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.textMuted,),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDriver)
                          Text(d.driverName!, style: AppTypography.label),
                        if (d.vehicleNumber?.isNotEmpty == true)
                          Text(d.vehicleNumber!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary),),
                      ],
                    ),
                  ),
                  // Call driver button — the most useful thing for a buyer
                  if (hasPhone)
                    GestureDetector(
                      onTap: () => _call(d.driverMobile!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8,),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_rounded,
                                size: 15, color: AppColors.primaryMain,),
                            const SizedBox(width: 5),
                            Text('Call Driver',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.primaryMain,
                                    fontWeight: FontWeight.w700,),),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Track / View details footer
          // Buyers have their own tracking page; /dispatches/:id is the seller's.
          GestureDetector(
            onTap: () => context.push('/dispatches/${d.id}/buyer-track'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.xl),),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isOnWay ? 'Track Shipment' : 'View Details',
                    style: AppTypography.label
                        .copyWith(color: AppColors.primaryMain),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.primaryMain,),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seller dispatch section ────────────────────────────────────────────────────
// Compact dispatch cards for seller/manager, shown below the operational timeline.

class _SellerDispatchSection extends ConsumerWidget {
  final int orderId;
  const _SellerDispatchSection({required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_orderDispatchesProvider(orderId)).maybeWhen(
          data: (dispatches) {
            if (dispatches.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dispatches', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.md),
                ...dispatches.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _SellerDispatchRow(dispatch: d),
                    ),),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _SellerDispatchRow extends StatelessWidget {
  final Dispatch dispatch;
  const _SellerDispatchRow({required this.dispatch});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final d = dispatch;
    final display = LifecyclePresenter.forDispatch(
      dispatch: d,
      role: LifecycleRole.operator,
    );
    final isActive =
        {'ACCEPTED', 'DISPATCHED', 'IN_TRANSIT'}.contains(d.status);
    final isDelivered = d.status == 'DELIVERED';

    final chipColor = isDelivered
        ? AppColors.primaryMain
        : isActive
            ? AppColors.amber700
            : AppColors.textSecondary;
    final chipBg = isDelivered
        ? AppColors.primaryLight
        : isActive
            ? AppColors.amber100
            : AppColors.slate50;

    return GestureDetector(
      onTap: () => context.push('/dispatches/${d.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isActive ? AppColors.amber500 : AppColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: chipBg, borderRadius: BorderRadius.circular(10),),
              child: Icon(Icons.local_shipping_rounded,
                  color: chipColor, size: 20,),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.dispatchCode, style: AppTypography.label),
                  if (d.driverName?.isNotEmpty == true)
                    Text(d.driverName!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),),
                  if (d.vehicleNumber?.isNotEmpty == true)
                    Text(d.vehicleNumber!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),),
                ],
              ),
            ),
            // Call driver pill for seller too
            if (d.driverMobile?.isNotEmpty == true) ...[
              GestureDetector(
                onTap: () => _call(d.driverMobile!),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 16, color: AppColors.primaryMain,),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: chipBg, borderRadius: BorderRadius.circular(20),),
              child: Text(
                display.label,
                style: AppTypography.caption
                    .copyWith(color: chipColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Collapsible info card ─────────────────────────────────────────────────────
// Collapsed by default — progressive disclosure for order metadata.

class _CollapsibleInfoCard extends StatefulWidget {
  final Order order;
  const _CollapsibleInfoCard({required this.order});

  @override
  State<_CollapsibleInfoCard> createState() => _CollapsibleInfoCardState();
}

class _CollapsibleInfoCardState extends State<_CollapsibleInfoCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _turn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200),);
    _turn = Tween(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final date = DateTime.tryParse(o.orderDate);
    final dateStr =
        date != null ? DateFormat('dd MMM yyyy').format(date.toLocal()) : '';
    final buyerLabel = o.buyerName ?? o.customerName ?? 'Unknown Buyer';
    final responsibleLabel = o.assignedManagerName ??
        (o.assignedManagerUserId != null
            ? 'Manager #${o.assignedManagerUserId}'
            : 'Nursery Owner');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Tappable header
          InkWell(
            onTap: _toggle,
            borderRadius: AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardPadding, vertical: AppSpacing.md,),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: AppColors.forest100, shape: BoxShape.circle,),
                    child: const Icon(Icons.info_outline_rounded,
                        size: 17, color: AppColors.primaryMain,),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text('Order Details', style: AppTypography.label),
                  ),
                  RotationTransition(
                    turns: _turn,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted, size: 20,),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Buyer',
                value: buyerLabel,),
            if (o.sellerNursery != null) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.store_outlined,
                  label: 'Seller',
                  value: o.sellerNursery!,),
            ],
            const Divider(height: 1, indent: 56),
            _InfoRow(
                icon: Icons.manage_accounts_outlined,
                label: 'Responsible',
                value: responsibleLabel,),
            if (dateStr.isNotEmpty) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Order Date',
                  value: dateStr,),
            ],
            if (o.notes?.isNotEmpty == true) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.notes_outlined, label: 'Notes', value: o.notes!,),
            ],
            if (o.cancelReason?.isNotEmpty == true) ...[
              const Divider(height: 1, indent: 56),
              _InfoRow(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel Reason',
                  value: o.cancelReason!,
                  valueColor: AppColors.red600,),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md,),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.forest100, shape: BoxShape.circle,),
            child: Icon(icon, size: 17, color: AppColors.primaryMain),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),),
                Text(value,
                    style: AppTypography.body
                        .copyWith(color: valueColor ?? AppColors.textPrimary),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Opens the delivery address sheet and saves the result. Shared by the Hero
// card's "Add Delivery Address First" button and _DeliverySnapshotCard's edit
// action, so both actually open the form instead of one of them silently
// re-running an action that's guaranteed to fail without an address.
Future<void> _openAndSaveDeliverySheet(
    BuildContext context, WidgetRef ref, Order order,) async {
  final session = ref.read(sessionProvider);
  // The seller fills this in for the customer, so default to the customer's
  // contact, not the seller's own profile.
  final forCustomer = session.capabilities.sellsFor(order.sellerNurseryId);
  final profile = session.user;
  final profileName =
      (forCustomer ? order.customerName ?? order.buyerName : profile?.name)
          ?.trim();
  final profileMobile =
      (forCustomer ? order.customerMobile : profile?.mobile)?.trim();
  final result = await showModalBottomSheet<DeliverySnapshotRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeliveryEditSheet(
      snapshot: order.deliverySnapshot,
      profileName: profileName,
      profileMobile: profileMobile,
      contactLabel:
          forCustomer ? 'Use customer contact' : 'Use profile contact',
    ),
  );
  if (result == null) return;
  try {
    await ref
        .read(orderRepositoryProvider)
        .updateDeliverySnapshot(order.id, result);
    ref.invalidate(orderDetailProvider(order.id));
    ref.invalidate(_orderDispatchesProvider(order.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.emergencyUpdate
              ? 'Emergency delivery update sent to driver.'
              : 'Delivery address updated.',),
          backgroundColor: AppColors.primaryMain,
        ),
      );
    }
  } on AppError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppColors.red600,),
      );
    }
  }
}

class _DeliverySnapshotCard extends ConsumerStatefulWidget {
  final Order order;
  final bool canManage;

  const _DeliverySnapshotCard({
    required this.order,
    required this.canManage,
  });

  @override
  ConsumerState<_DeliverySnapshotCard> createState() =>
      _DeliverySnapshotCardState();
}

class _DeliverySnapshotCardState extends ConsumerState<_DeliverySnapshotCard> {
  bool _busy = false;

  Future<void> _edit() async {
    setState(() => _busy = true);
    await _openAndSaveDeliverySheet(context, ref, widget.order);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.order.deliverySnapshot;
    final session = ref.watch(sessionProvider);
    final profile = session.user;
    // An empty snapshot contact means "the customer" — not whoever is looking
    // (the seller must not see their own number as the recipient).
    final forCustomer =
        session.capabilities.sellsFor(widget.order.sellerNurseryId);
    final o = widget.order;
    final profileName =
        (forCustomer ? o.customerName ?? o.buyerName : profile?.name)?.trim();
    final profileMobile =
        (forCustomer ? o.customerMobile : profile?.mobile)?.trim();
    final profileContact = [
      if (profileName?.isNotEmpty == true) profileName,
      if (profileMobile?.isNotEmpty == true) '+91 $profileMobile',
    ].whereType<String>().join(' | ');
    final snapshotContact = [
      if (delivery?.contactName?.isNotEmpty == true) delivery!.contactName,
      if (delivery?.contactMobile?.isNotEmpty == true) delivery!.contactMobile,
    ].whereType<String>().join(' | ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.forest100, shape: BoxShape.circle,),
                child: const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.primaryMain,),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                  child: Text('Delivery Snapshot', style: AppTypography.h4),),
              if (widget.canManage)
                TextButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (delivery == null)
            Text(
              'No delivery address snapshot saved yet.',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            )
          else ...[
            Text(delivery.displayAddress, style: AppTypography.body),
            if (snapshotContact.isNotEmpty || profileContact.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                snapshotContact.isNotEmpty ? snapshotContact : profileContact,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (delivery.deliveryInstructions?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                delivery.deliveryInstructions!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (delivery.requiresDriverAck) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  borderRadius: AppRadius.buttonRadius,
                  border: Border.all(color: AppColors.amber600),
                ),
                child: Text(
                  'Driver acknowledgement pending for latest delivery update.',
                  style:
                      AppTypography.caption.copyWith(color: AppColors.amber700),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DeliveryEditSheet extends StatefulWidget {
  final DeliverySnapshot? snapshot;
  final String? profileName;
  final String? profileMobile;
  final String contactLabel;

  const _DeliveryEditSheet({
    required this.snapshot,
    required this.profileName,
    required this.profileMobile,
    required this.contactLabel,
  });

  @override
  State<_DeliveryEditSheet> createState() => _DeliveryEditSheetState();
}

class _DeliveryEditSheetState extends State<_DeliveryEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _postal;
  late final TextEditingController _landmark;
  late final TextEditingController _instructions;
  bool _emergency = false;
  bool _useProfileContact = true;
  MapPickResult? _mapResult;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final s = widget.snapshot;
    _name = TextEditingController(text: s?.contactName ?? '');
    _mobile = TextEditingController(text: s?.contactMobile ?? '');
    final profileName = widget.profileName?.trim();
    final profileMobile = widget.profileMobile?.trim();
    final hasSnapshotContact = (s?.contactName?.trim().isNotEmpty ?? false) ||
        (s?.contactMobile?.trim().isNotEmpty ?? false);
    final snapshotMatchesProfile = (s?.contactName?.trim().isEmpty ?? true) ||
        s?.contactName?.trim() == profileName;
    final snapshotMobileMatchesProfile =
        (s?.contactMobile?.trim().isEmpty ?? true) ||
            s?.contactMobile?.trim() == profileMobile;
    _useProfileContact = (profileMobile?.isNotEmpty ?? false) &&
        (!hasSnapshotContact ||
            (snapshotMatchesProfile && snapshotMobileMatchesProfile));
    _line1 = TextEditingController(text: s?.addressLine1 ?? '');
    _line2 = TextEditingController(text: s?.addressLine2 ?? '');
    _city = TextEditingController(text: s?.city ?? '');
    _state = TextEditingController(text: s?.state ?? '');
    _country = TextEditingController(text: s?.country ?? 'India');
    _postal = TextEditingController(text: s?.postalCode ?? '');
    _landmark = TextEditingController(text: s?.landmark ?? '');
    _instructions = TextEditingController(text: s?.deliveryInstructions ?? '');
    _latitude = s?.latitude;
    _longitude = s?.longitude;
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddressMapPickerScreen(
          initial: (_latitude != null && _longitude != null)
              ? MapPickResult(
                  latitude: _latitude!,
                  longitude: _longitude!,
                  city: _city.text,
                  state: _state.text,
                  postalCode: _postal.text.isEmpty ? null : _postal.text,
                  country: _country.text,
                )
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _mapResult = result;
      _city.text = result.city;
      _state.text = result.state;
      if (result.postalCode?.isNotEmpty == true) {
        _postal.text = result.postalCode!;
      }
      _country.text = result.country;
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _postal.dispose();
    _landmark.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _submit() {
    if (_line1.text.trim().isEmpty) return;
    final contactName =
        _useProfileContact ? widget.profileName?.trim() : _name.text.trim();
    final contactMobile =
        _useProfileContact ? widget.profileMobile?.trim() : _mobile.text.trim();
    Navigator.pop(
      context,
      DeliverySnapshotRequest(
        contactName: contactName,
        contactMobile: contactMobile,
        addressLine1: _line1.text,
        addressLine2: _line2.text,
        city: _city.text,
        state: _state.text,
        country: _country.text,
        postalCode: _postal.text,
        landmark: _landmark.text,
        deliveryInstructions: _instructions.text,
        latitude: _latitude,
        longitude: _longitude,
        locationSource: _mapResult != null ? 'map_selected' : null,
        emergencyUpdate: _emergency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Delivery Address', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.md),
            _DeliveryContactToggle(
              label: widget.contactLabel,
              value: _useProfileContact,
              profileName: widget.profileName,
              profileMobile: widget.profileMobile,
              onChanged: (v) => setState(() => _useProfileContact = v),
            ),
            if (!_useProfileContact) ...[
              const SizedBox(height: AppSpacing.sm),
              _SheetField(controller: _name, label: 'Alternate contact name'),
              _SheetField(
                controller: _mobile,
                label: 'Alternate contact mobile',
                keyboardType: TextInputType.phone,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _pickOnMap,
              icon: Icon(
                _mapResult != null
                    ? Icons.check_circle_rounded
                    : Icons.map_outlined,
                size: 18,
                color: _mapResult != null ? AppColors.primaryMain : null,
              ),
              label: Text(_mapResult != null
                  ? 'Location pinned - City, state & PIN filled'
                  : 'Pick on map',),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SheetField(controller: _line1, label: 'Address line 1'),
            _SheetField(controller: _line2, label: 'Address line 2'),
            Row(
              children: [
                Expanded(child: _SheetField(controller: _city, label: 'City')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _SheetField(controller: _state, label: 'State'),),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: _SheetField(controller: _postal, label: 'PIN code'),),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _SheetField(controller: _country, label: 'Country'),),
              ],
            ),
            _SheetField(controller: _landmark, label: 'Landmark'),
            _SheetField(
              controller: _instructions,
              label: 'Delivery instructions',
              maxLines: 3,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _emergency,
              onChanged: (v) => setState(() => _emergency = v),
              title: const Text('Emergency update'),
              subtitle:
                  const Text('Use after trip starts. Driver must acknowledge.'),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius,),
                ),
                child: const Text('Save Delivery Address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryContactToggle extends StatelessWidget {
  final String label;
  final bool value;
  final String? profileName;
  final String? profileMobile;
  final ValueChanged<bool> onChanged;

  const _DeliveryContactToggle({
    required this.label,
    required this.value,
    required this.profileName,
    required this.profileMobile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final profileLabel = [
      if (profileName?.trim().isNotEmpty == true) profileName!.trim(),
      if (profileMobile?.trim().isNotEmpty == true)
        '+91 ${profileMobile!.trim()}',
    ].join(' - ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: AppRadius.inputRadius,
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_pin_circle_outlined,
            color: AppColors.primaryMain,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profileLabel.isEmpty
                      ? 'Saved profile contact details'
                      : profileLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  const _SheetField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(borderRadius: AppRadius.inputRadius),
        ),
      ),
    );
  }
}

// ── Rate Order Card (shown for buyers on COMPLETED orders) ───────────────────
