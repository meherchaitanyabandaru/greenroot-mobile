import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

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
  _DriverRegNotifier(this._client) : super(const _DriverRegState());

  Future<void> apply({
    required String licenceNumber,
    required String vehicleNumber,
    String vehicleType = 'TRUCK',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.post(
        '/api/v1/drivers/apply',
        data: {
          'licence_number': licenceNumber,
          'vehicle_number': vehicleNumber,
          'vehicle_type': vehicleType,
        },
      );
      state = state.copyWith(isLoading: false, submitted: true);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to submit. Please try again.');
    }
  }
}

final _driverRegProvider = StateNotifierProvider.autoDispose<
    _DriverRegNotifier, _DriverRegState>(
  (ref) => _DriverRegNotifier(ApiClient.instance),
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
  String _vehicleType = 'TRUCK';

  @override
  void dispose() {
    _licenceCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final licence = _licenceCtrl.text.trim();
    final vehicle = _vehicleCtrl.text.trim();
    if (licence.isEmpty || vehicle.isEmpty) return;
    ref.read(_driverRegProvider.notifier).apply(
          licenceNumber: licence,
          vehicleNumber: vehicle,
          vehicleType: _vehicleType,
        );
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
                const Text('Application Submitted!', style: AppTypography.h2,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your driver application is under review. You will be notified once approved.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x3l),
                AppButton(
                  label: 'Back to Home',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
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
          const Text('Driver Registration', style: AppTypography.h3,
              textAlign: TextAlign.center),
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
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _vehicleCtrl,
            label: 'Vehicle Number',
            hint: 'e.g. KA-01-AB-1234',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: AppSpacing.md),

          // Vehicle type selector
          const Text('Vehicle Type', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: ['TRUCK', 'VAN', 'PICKUP', 'AUTO'].map((type) {
              final selected = _vehicleType == type;
              return ChoiceChip(
                label: Text(type),
                selected: selected,
                onSelected: (_) => setState(() => _vehicleType = type),
                selectedColor: AppColors.primaryMain,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                ),
              );
            }).toList(),
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
                  style: AppTypography.body
                      .copyWith(color: AppColors.red600)),
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
