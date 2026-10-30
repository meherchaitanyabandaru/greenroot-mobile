import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/media/image_policy.dart';
import '../../../../core/media/photos.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../vehicles/my_lorries_screen.dart';
import '../../../vehicles/vehicles.dart';
import '../providers/session_provider.dart';

class _DriverRegState {
  final bool isLoading;
  final bool submitted;
  final String? error;

  const _DriverRegState({
    this.isLoading = false,
    this.submitted = false,
    this.error,
  });

  _DriverRegState copyWith({bool? isLoading, bool? submitted, String? error}) =>
      _DriverRegState(
        isLoading: isLoading ?? this.isLoading,
        submitted: submitted ?? this.submitted,
        error: error,
      );
}

class _DriverRegNotifier extends StateNotifier<_DriverRegState> {
  final ApiClient _client;
  final StorageService _storage;
  _DriverRegNotifier(this._client, this._storage)
      : super(const _DriverRegState());

  Future<void> apply({
    required String licenceNumber,
    required DateTime licenceExpiry,
    required String vehicleNumber,
    String vehicleType = 'TRUCK',
    required LorryOwner owner,
    XFile? licencePhoto,
    required ImagePolicy licencePolicy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      String? photoUrl;
      if (licencePhoto != null) {
        // Private bucket: only admins (and the driver) open it, by a short link.
        final photo = await preparePhoto(licencePhoto, licencePolicy);
        photoUrl = await _storage.uploadImage(
            ImageCategory.driverLicence, photo, licencePhoto.name,);
      }
      await _client.post(
        '/api/v1/drivers/apply',
        data: {
          'licence_number': licenceNumber,
          'licence_expiry_date':
              licenceExpiry.toIso8601String().substring(0, 10),
          'vehicle_number': vehicleNumber,
          'vehicle_type': vehicleType,
          ...owner.toJson(),
          if (photoUrl != null) 'licence_photo_url': photoUrl,
        },
      );
      state = state.copyWith(isLoading: false, submitted: true);
    } on PhotoRejected catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to submit. Please try again.',);
    }
  }
}

final _driverRegProvider =
    StateNotifierProvider.autoDispose<_DriverRegNotifier, _DriverRegState>(
  (ref) => _DriverRegNotifier(
    ApiClient.instance,
    ref.read(storageServiceProvider),
  ),
);

class DriverRegistrationScreen extends ConsumerStatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  ConsumerState<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends ConsumerState<DriverRegistrationScreen> {
  final _licenceCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerMobileCtrl = TextEditingController();
  String _vehicleType = 'TRUCK';
  bool _isOwner = true;
  DateTime? _licenceExpiry;
  XFile? _licencePhoto; // optional
  bool _tried = false; // show "required" only after a submit attempt

  @override
  void dispose() {
    _licenceCtrl.dispose();
    _vehicleCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerMobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      helpText: 'Licence valid until',
      initialDate: _licenceExpiry ?? today.add(const Duration(days: 365)),
      firstDate: today, // an expired licence cannot register
      lastDate: today.add(const Duration(days: 365 * 40)),
    );
    if (picked != null) setState(() => _licenceExpiry = picked);
  }

  Future<void> _submit() async {
    // Licence and plate numbers are written in capitals.
    final licence = _licenceCtrl.text.trim().toUpperCase();
    final vehicle = _vehicleCtrl.text.trim().toUpperCase();
    if (licence.isEmpty ||
        vehicle.isEmpty ||
        _licenceExpiry == null ||
        !LorryOwnerFields.valid(
            _isOwner, _ownerNameCtrl.text, _ownerMobileCtrl.text,)) {
      setState(() => _tried = true); // used to return silently
      return;
    }
    await ref.read(_driverRegProvider.notifier).apply(
          licenceNumber: licence,
          licenceExpiry: _licenceExpiry!,
          vehicleNumber: vehicle,
          vehicleType: _vehicleType,
          owner: _isOwner
              ? const LorryOwner.me()
              : LorryOwner.other(_ownerNameCtrl.text, _ownerMobileCtrl.text),
          licencePhoto: _licencePhoto,
          licencePolicy: await ref
              .read(imagePolicyProvider(ImageCategory.driverLicence).future),
        );
    if (ref.read(_driverRegProvider).submitted) {
      await ref.read(sessionProvider.notifier).bootstrap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_driverRegProvider);

    if (state.submitted) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Driver Registration'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.forest100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryMain,
                    size: 44,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2l),
                const Text('Application Submitted!',
                    style: AppTypography.h2, textAlign: TextAlign.center,),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your driver application is under review. You will be notified once approved.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x3l),
                AppButton(
                  label: 'Continue as Customer',
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register as Driver'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.amber100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.amber600,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text('Driver Registration',
              style: AppTypography.h3, textAlign: TextAlign.center,),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Submit your details to join as a delivery driver. '
            'An admin will review and approve your application.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x3l),

          AppTextField(
            controller: _licenceCtrl,
            label: 'Driving Licence Number',
            hint: 'Enter your licence number',
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            errorText: _tried && _licenceCtrl.text.trim().isEmpty
                ? 'Enter your driving licence number'
                : null,
            onChanged: (_) => _tried ? setState(() {}) : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            button: true,
            label: 'Licence valid until',
            child: InkWell(
              onTap: _pickExpiry,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Licence valid until',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.event_outlined),
                  errorText: _tried && _licenceExpiry == null
                      ? 'Choose the expiry date on your licence'
                      : null,
                ),
                child: Text(
                  _licenceExpiry == null
                      ? 'Choose date'
                      : MaterialLocalizations.of(context)
                          .formatMediumDate(_licenceExpiry!),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _LicencePhotoPicker(
            photo: _licencePhoto,
            onChanged: (f) => setState(() => _licencePhoto = f),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _vehicleCtrl,
            label: 'Lorry Number',
            hint: 'e.g. KA-01-AB-1234',
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            errorText: _tried && _vehicleCtrl.text.trim().isEmpty
                ? 'Enter your vehicle number'
                : null,
            onChanged: (_) => _tried ? setState(() {}) : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Vehicle type selector
          const Text('Vehicle Type', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: lorryTypes.map((type) {
              final selected = _vehicleType == type;
              return ChoiceChip(
                // TRUCK → Truck: the value sent stays the API's code.
                label: Text(type[0] + type.substring(1).toLowerCase()),
                selected: selected,
                onSelected: (_) => setState(() => _vehicleType = type),
                selectedColor: AppColors.primaryMain,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              );
            }).toList(),
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
          const SizedBox(height: AppSpacing.x2l),

          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.red100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(state.error!,
                  style: AppTypography.body.copyWith(color: AppColors.red600),),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          AppButton(
            label: 'Submit Application',
            isLoading: state.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }
}

/// Optional photo of the driving licence, so the admin can check it.
class _LicencePhotoPicker extends StatelessWidget {
  final XFile? photo;
  final ValueChanged<XFile?> onChanged;
  const _LicencePhotoPicker({required this.photo, required this.onChanged});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final file = await pickPhoto(context, source);
    if (file != null) onChanged(file);
  }

  @override
  Widget build(BuildContext context) {
    final p = photo;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Driving licence photo (optional)',
              style: AppTypography.label,),
          const SizedBox(height: 4),
          Text(
            'Helps the admin approve you faster. Only GreenRoot admins see it.',
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (p != null)
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(p.path),
                    width: 96, height: 64, fit: BoxFit.cover,),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text('Photo added', style: AppTypography.body),
              ),
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text('Remove'),
              ),
            ],)
          else
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],),
        ],
      ),
    );
  }
}
