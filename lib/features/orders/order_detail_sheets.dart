part of 'order_detail_screen.dart';

class _AssignManagerSheet extends StatelessWidget {
  final List<NurseryManager> managers;
  const _AssignManagerSheet({required this.managers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.lg, AppSpacing.screenPadding, AppSpacing.x3l,),
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
          const SizedBox(height: AppSpacing.x2l),
          const Text('Assign Manager', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select a manager to handle loading for this order.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x2l),
          if (managers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Column(
                children: [
                  const Icon(Icons.person_search_rounded,
                      size: 40, color: AppColors.primaryMain,),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No managers found for this nursery.\nInvite a manager from Connections.',
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...managers.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(m),
                  borderRadius: AppRadius.cardRadius,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                              style: AppTypography.h3
                                  .copyWith(color: AppColors.primaryMain),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: AppTypography.label),
                              Text(m.identityLabel,
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,),),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted,),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Dispatch Sheet ──────────────────────────────────────────────────────

typedef _DispatchInput = ({
  String? dest,
  String? notes,
  // Set for an outside lorry (driver without the app).
  String? outsideVehicle,
  String? outsideDriverName,
  String? outsideDriverMobile,
});

class _CreateDispatchSheet extends StatefulWidget {
  final ValueChanged<_DispatchInput> onSubmit;
  final VoidCallback onCancel;
  const _CreateDispatchSheet({required this.onSubmit, required this.onCancel});

  @override
  State<_CreateDispatchSheet> createState() => _CreateDispatchSheetState();
}

class _CreateDispatchSheetState extends State<_CreateDispatchSheet> {
  final _destCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverMobileCtrl = TextEditingController();
  bool _outside = false;

  @override
  void dispose() {
    _destCtrl.dispose();
    _notesCtrl.dispose();
    _vehicleCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverMobileCtrl.dispose();
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x3l,
      ),
      child: SingleChildScrollView(
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
          const SizedBox(height: AppSpacing.x2l),
          const Text('Create Dispatch', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('GreenRoot driver')),
              ButtonSegment(value: true, label: Text('Outside lorry')),
            ],
            selected: {_outside},
            onSelectionChanged: (v) => setState(() => _outside = v.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _outside
                ? "For a lorry whose driver doesn't use GreenRoot. No tracking: you mark it dispatched, and confirm delivery with the customer's code."
                : 'After creating, share the trip QR with your driver.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_outside) ...[
            TextField(
              key: const Key('dispatchOutsideVehicle'),
              controller: _vehicleCtrl,
              decoration: const InputDecoration(
                labelText: 'Lorry number *',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _driverNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Driver name (optional)',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _driverMobileCtrl,
              decoration: const InputDecoration(
                labelText: 'Driver mobile (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            key: const Key(TestKeys.dispatchCreateDestination),
            controller: _destCtrl,
            decoration: const InputDecoration(
              labelText: 'Destination Address (optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key(TestKeys.dispatchCreateNotes),
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.x2l),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton.icon(
              key: const Key(TestKeys.dispatchCreateSubmit),
              onPressed: _outside && _text(_vehicleCtrl) == null
                  ? null
                  : () => widget.onSubmit((
                        dest: _text(_destCtrl),
                        notes: _text(_notesCtrl),
                        outsideVehicle: _outside ? _text(_vehicleCtrl) : null,
                        outsideDriverName:
                            _outside ? _text(_driverNameCtrl) : null,
                        outsideDriverMobile:
                            _outside ? _text(_driverMobileCtrl) : null,
                      ),),
              icon: const Icon(Icons.local_shipping_rounded),
              label: const Text('Create Dispatch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius,),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ),
        ],
       ),
      ),
    );
  }
}
