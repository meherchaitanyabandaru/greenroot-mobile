import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import 'vehicles.dart';

/// The driver's lorries: which can take trips now and why not, add one
/// (GreenRoot approves it), remove one (never during a trip with it).
class MyLorriesScreen extends ConsumerWidget {
  const MyLorriesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddLorrySheet(),
    );
    if (added == true) ref.invalidate(myLorriesProvider);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Lorry lorry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${lorry.vehicleNumber}?'),
        content: const Text(
            'You will not be able to take trips with this lorry. You can add it again later.',),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep'),),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lorryRepositoryProvider).removeLorry(lorry.linkId!);
      ref.invalidate(myLorriesProvider);
      messenger.showSnackBar(
          SnackBar(content: Text('${lorry.vehicleNumber} removed')),);
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: AppColors.red600,),);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lorries = ref.watch(myLorriesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Lorries'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add lorry'),
      ),
      body: lorries.when(
        loading: () => const Center(child: AppLoader()),
        error: (e, _) => ErrorState(
          error: e is AppError ? e : null,
          onRetry: () => ref.invalidate(myLorriesProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'No lorries yet',
                subtitle:
                    'Add the lorries you drive. GreenRoot checks each one before you can take trips with it.',
                actionLabel: 'Add lorry',
                onAction: () => _add(context, ref),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myLorriesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                      AppSpacing.screenPadding, AppSpacing.screenPadding, 96,),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => LorryTile(
                    lorry: list[i],
                    onRemove: list[i].linkId == null
                        ? null
                        : () => _remove(context, ref, list[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A lorry with whether it can take trips. With [selected]/[onSelect] it is a
/// choice (trip preview); blocked lorries cannot be chosen and say why.
class LorryTile extends StatelessWidget {
  final Lorry lorry;
  final VoidCallback? onRemove;
  final bool? selected;
  final VoidCallback? onSelect;
  const LorryTile({
    super.key,
    required this.lorry,
    this.onRemove,
    this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final ok = lorry.isEligible;
    final subtitle = [
      lorryTypeLabel(lorry.vehicleType),
      if (lorry.capacityKg != null) '${lorry.capacityKg!.round()} kg',
      if (lorry.isOwner) 'Owned by you'
      else if (lorry.ownerName != null) 'Owner: ${lorry.ownerName}',
    ].join(' · ');
    final choosable = onSelect != null && ok;
    return Semantics(
      selected: selected,
      enabled: onSelect == null || ok,
      child: Material(
        color: selected == true ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: choosable ? onSelect : null,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected == true
                      ? AppColors.primaryMain
                      : AppColors.border,),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(
                      selected!
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: ok ? AppColors.primaryMain : AppColors.textMuted,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lorry.vehicleNumber,
                          style: AppTypography.label.copyWith(
                              color: ok
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,),),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary),),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(
                          ok
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: ok ? AppColors.primaryMain : AppColors.amber600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ok ? 'Can take trips' : lorry.blockedText,
                            style: AppTypography.caption.copyWith(
                                color: ok
                                    ? AppColors.primaryMain
                                    : AppColors.amber600,),
                          ),
                        ),
                      ],),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove ${lorry.vehicleNumber}',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Who owns this lorry?": me, or someone else by name (mobile optional).
class LorryOwnerFields extends StatelessWidget {
  final bool isMe;
  final ValueChanged<bool> onIsMeChanged;
  final TextEditingController nameCtrl;
  final TextEditingController mobileCtrl;
  final bool showErrors;
  final VoidCallback? onEdited; // re-check the errors while typing
  const LorryOwnerFields({
    super.key,
    required this.isMe,
    required this.onIsMeChanged,
    required this.nameCtrl,
    required this.mobileCtrl,
    required this.showErrors,
    this.onEdited,
  });

  static bool valid(bool isMe, String name, String mobile) {
    if (isMe) return true;
    final m = mobile.replaceAll(RegExp(r'\D'), '');
    return name.trim().isNotEmpty && (m.isEmpty || m.length >= 10);
  }

  @override
  Widget build(BuildContext context) {
    final mobileDigits = mobileCtrl.text.replaceAll(RegExp(r'\D'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who owns this lorry?', style: AppTypography.label),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, children: [
          ChoiceChip(
            label: const Text('I own it'),
            selected: isMe,
            onSelected: (_) => onIsMeChanged(true),
          ),
          ChoiceChip(
            label: const Text('Someone else'),
            selected: !isMe,
            onSelected: (_) => onIsMeChanged(false),
          ),
        ],),
        if (!isMe) ...[
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: nameCtrl,
            label: "Owner's name",
            hint: 'As on the registration certificate',
            textCapitalization: TextCapitalization.words,
            errorText: showErrors && nameCtrl.text.trim().isEmpty
                ? "Enter the owner's name"
                : null,
            onChanged: (_) => onEdited?.call(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: mobileCtrl,
            label: "Owner's mobile (optional)",
            hint: 'The owner does not need the GreenRoot app',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            errorText: showErrors &&
                    mobileDigits.isNotEmpty &&
                    mobileDigits.length < 10
                ? 'Enter a 10-digit mobile number or leave it empty'
                : null,
            onChanged: (_) => onEdited?.call(),
          ),
        ],
      ],
    );
  }
}

/// Add a lorry: number, type, capacity, owner. Pops true when added.
class AddLorrySheet extends ConsumerStatefulWidget {
  const AddLorrySheet({super.key});

  @override
  ConsumerState<AddLorrySheet> createState() => _AddLorrySheetState();
}

class _AddLorrySheetState extends ConsumerState<AddLorrySheet> {
  final _numberCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerMobileCtrl = TextEditingController();
  String _type = 'TRUCK';
  bool _isOwner = true;
  bool _tried = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _capacityCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerMobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final number = _numberCtrl.text.trim().toUpperCase();
    final capacity = double.tryParse(_capacityCtrl.text.trim());
    setState(() => _tried = true);
    if (number.length < 4 ||
        !LorryOwnerFields.valid(
            _isOwner, _ownerNameCtrl.text, _ownerMobileCtrl.text,)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(lorryRepositoryProvider).addLorry(
            vehicleNumber: number,
            vehicleType: _type,
            capacityKg: capacity,
            owner: _isOwner
                ? const LorryOwner.me()
                : LorryOwner.other(_ownerNameCtrl.text, _ownerMobileCtrl.text),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const Text('Add a lorry', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text('GreenRoot checks it before you can take trips with it.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _numberCtrl,
            label: 'Lorry number',
            hint: 'e.g. KA-01-AB-1234',
            textCapitalization: TextCapitalization.characters,
            errorText: _tried && _numberCtrl.text.trim().length < 4
                ? 'Enter the registration number'
                : null,
            onChanged: (_) => _tried ? setState(() {}) : null,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Type', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final t in lorryTypes)
                ChoiceChip(
                  label: Text(lorryTypeLabel(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _capacityCtrl,
            label: 'Capacity in kg (optional)',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpacing.md),
          LorryOwnerFields(
            isMe: _isOwner,
            onIsMeChanged: (v) => setState(() => _isOwner = v),
            nameCtrl: _ownerNameCtrl,
            mobileCtrl: _ownerMobileCtrl,
            showErrors: _tried,
            onEdited: () => _tried ? setState(() {}) : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                style: AppTypography.body.copyWith(color: AppColors.red600),),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Add lorry', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
