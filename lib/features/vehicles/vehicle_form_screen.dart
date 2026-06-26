import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'vehicles.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _mobileCtrl;

  String? _vehicleType;
  String _status = 'ACTIVE';
  bool _saving = false;

  bool get _isEdit => widget.vehicle != null;

  static const _types = ['TRUCK', 'VAN', 'PICKUP', 'AUTO', 'OTHER'];
  static const _statuses = ['ACTIVE', 'INACTIVE', 'MAINTENANCE'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _numberCtrl = TextEditingController(text: v?.vehicleNumber ?? '');
    _capacityCtrl =
        TextEditingController(text: v?.capacityKG?.toStringAsFixed(0) ?? '');
    _ownerCtrl = TextEditingController(text: v?.ownerName ?? '');
    _mobileCtrl = TextEditingController(text: v?.mobile ?? '');
    _vehicleType = v?.vehicleType;
    _status = v?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _capacityCtrl.dispose();
    _ownerCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final capacityStr = _capacityCtrl.text.trim();
    final body = <String, dynamic>{
      'vehicle_number': _numberCtrl.text.trim(),
      'status': _status,
      if (_vehicleType != null) 'vehicle_type': _vehicleType,
      if (capacityStr.isNotEmpty)
        'capacity_kg': double.tryParse(capacityStr),
      if (_ownerCtrl.text.trim().isNotEmpty)
        'owner_name': _ownerCtrl.text.trim(),
      if (_mobileCtrl.text.trim().isNotEmpty)
        'mobile': _mobileCtrl.text.trim(),
    };

    try {
      final repo = ref.read(vehicleRepositoryProvider);
      if (_isEdit) {
        await repo.updateVehicle(widget.vehicle!.id, body);
      } else {
        await repo.createVehicle(body);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Vehicle' : 'Add Vehicle'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            _Section(
              title: 'Vehicle Details',
              children: [
                _Field(
                  label: 'Vehicle Number *',
                  child: TextFormField(
                    controller: _numberCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _inputDecoration('e.g. KA01AB1234'),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Field(
                  label: 'Vehicle Type',
                  child: DropdownButtonFormField<String>(
                    value: _vehicleType,
                    hint: const Text('Select type'),
                    decoration: _inputDecoration(null),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _vehicleType = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Field(
                  label: 'Capacity (kg)',
                  child: TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('e.g. 5000'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _Section(
              title: 'Owner Details',
              children: [
                _Field(
                  label: 'Owner Name',
                  child: TextFormField(
                    controller: _ownerCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Full name'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Field(
                  label: 'Mobile',
                  child: TextFormField(
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration('10-digit number'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _Section(
              title: 'Status',
              children: [
                _Field(
                  label: 'Vehicle Status',
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: _inputDecoration(null),
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Update Vehicle' : 'Add Vehicle',
                        style: AppTypography.label),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(color: AppColors.primaryMain, width: 1.5),
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
