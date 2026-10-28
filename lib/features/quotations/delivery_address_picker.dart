import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../profile/my_addresses_screen.dart';
import 'quotations.dart';

/// Before accepting: the buyer picks (or adds) where the order goes. The pick
/// becomes their default address, which the order is delivered to.
/// False when they back out.
Future<bool> pickDeliveryAddress(
  BuildContext context,
  WidgetRef ref,
  Quotation q,
) async {
  final userId = ref.read(sessionProvider).user?.id;
  if (userId == null) return false;
  final chosen = await showModalBottomSheet<UserAddress>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PickerSheet(userId: userId, quotation: q),
  );
  if (chosen == null) return false;
  if (!chosen.isDefault) {
    await ref.read(userAddressRepositoryProvider).updateAddress(
          chosen.id,
          AddressFormData(
            addressType: chosen.addressType,
            contactName: chosen.contactName,
            contactMobile: chosen.contactMobile,
            addressLine1: chosen.addressLine1 ?? '',
            addressLine2: chosen.addressLine2,
            city: chosen.city,
            state: chosen.state,
            country: chosen.country,
            postalCode: chosen.postalCode,
            latitude: chosen.latitude,
            longitude: chosen.longitude,
            isDefault: true,
          ),
        );
  }
  return true;
}

/// Straight-line km from the nursery, or null without both points.
double? approxKm(Quotation q, UserAddress a) {
  if (q.nurseryLatitude == null ||
      q.nurseryLongitude == null ||
      a.latitude == null ||
      a.longitude == null) {
    return null;
  }
  return Geolocator.distanceBetween(
        q.nurseryLatitude!,
        q.nurseryLongitude!,
        a.latitude!,
        a.longitude!,
      ) /
      1000;
}

class _PickerSheet extends ConsumerStatefulWidget {
  final int userId;
  final Quotation quotation;
  const _PickerSheet({required this.userId, required this.quotation});

  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  List<UserAddress>? _addresses;
  String? _error;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref
          .read(userAddressRepositoryProvider)
          .listAddresses(widget.userId);
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _error = null;
        final def = list.where((a) => a.isDefault).firstOrNull ??
            list.firstOrNull;
        _selected ??= def?.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load your addresses: $e');
    }
  }

  Future<void> _addNew() async {
    // Comes back here: the new address is listed and can be picked at once.
    await context.push('/my-addresses');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _addresses;
    final selected = list?.where((a) => a.id == _selected).firstOrNull;
    final km = selected == null ? null : approxKm(widget.quotation, selected);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Where should it be delivered?',
                style: AppTypography.h3,),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.red600))
            else if (list == null)
              const Center(child: CircularProgressIndicator())
            else if (list.isEmpty)
              Text(
                'You have no delivery address yet. Add one to continue.',
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: RadioGroup<int>(
                  groupValue: _selected,
                  onChanged: (v) => setState(() => _selected = v),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final a in list)
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          value: a.id,
                          title: Text(a.contactName?.isNotEmpty == true
                              ? a.contactName!
                              : (a.city ?? 'Address'),),
                          subtitle: Text(a.displayAddress),
                        ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: _addNew,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add a new address'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                [
                  if (km != null)
                    'About ${km.round()} km from ${widget.quotation.nurseryName ?? 'the nursery'} '
                        '(approximate, straight line; the road is longer).',
                  'Transport charges are not included in this quotation or '
                      'the order. Agree them with the nursery.',
                ].join(' '),
                style: AppTypography.body,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              child: const Text('Deliver here and accept'),
            ),
          ],
        ),
      ),
    );
  }
}
