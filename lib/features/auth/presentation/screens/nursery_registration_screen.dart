import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

class _NurseryRegState {
  final bool isLoading;
  final bool success;
  final bool alreadyRegistered; // 409 already_owner — navigate to home
  final String? error;

  const _NurseryRegState({
    this.isLoading = false,
    this.success = false,
    this.alreadyRegistered = false,
    this.error,
  });

  _NurseryRegState copyWith({
    bool? isLoading,
    bool? success,
    bool? alreadyRegistered,
    String? error,
  }) =>
      _NurseryRegState(
        isLoading: isLoading ?? this.isLoading,
        success: success ?? this.success,
        alreadyRegistered: alreadyRegistered ?? this.alreadyRegistered,
        error: error,
      );
}

class _NurseryRegNotifier extends StateNotifier<_NurseryRegState> {
  final AuthRepository _repo;

  _NurseryRegNotifier(this._repo) : super(const _NurseryRegState());

  Future<void> submit({
    required String name,
    required String? mobile,
    required String? email,
    required String? description,
    required String? addressLine1,
    required String? city,
    required String? state,
    required String? postalCode,
  }) async {
    this.state = this.state.copyWith(isLoading: true, error: null);
    try {
      await _repo.registerNursery(
        name: name,
        mobile: mobile,
        email: email,
        description: description,
        addressLine1: addressLine1,
        city: city,
        state: state,
        postalCode: postalCode,
      );
      this.state = this.state.copyWith(isLoading: false, success: true);
    } on ServerError catch (e) {
      // 409 means this user already owns a nursery — refresh session and go home
      if (e.statusCode == 409) {
        this.state =
            this.state.copyWith(isLoading: false, alreadyRegistered: true);
      } else {
        this.state = this.state.copyWith(isLoading: false, error: e.message);
      }
    } on AppError catch (e) {
      this.state = this.state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      this.state = this.state.copyWith(
        isLoading: false,
        error: 'Failed to register nursery. Please try again.',
      );
    }
  }
}

final _nurseryRegProvider =
    StateNotifierProvider.autoDispose<_NurseryRegNotifier, _NurseryRegState>(
  (ref) => _NurseryRegNotifier(ref.watch(authRepositoryProvider)),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class NurseryRegistrationScreen extends ConsumerStatefulWidget {
  const NurseryRegistrationScreen({super.key});

  @override
  ConsumerState<NurseryRegistrationScreen> createState() =>
      _NurseryRegistrationScreenState();
}

class _NurseryRegistrationScreenState
    extends ConsumerState<NurseryRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressLine1Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill nursery contact from the owner's personal profile.
    final user = ref.read(sessionProvider).user;
    if (user != null) {
      if (user.mobile?.isNotEmpty ?? false) {
        _mobileCtrl.text = user.mobile!;
      }
      if (user.email?.isNotEmpty ?? false) {
        _emailCtrl.text = user.email!;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _descCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String val) => val.trim().isEmpty ? null : val.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(_nurseryRegProvider.notifier).submit(
          name: _nameCtrl.text.trim(),
          mobile: _nullIfEmpty(_mobileCtrl.text),
          email: _nullIfEmpty(_emailCtrl.text),
          description: _nullIfEmpty(_descCtrl.text),
          addressLine1: _nullIfEmpty(_addressLine1Ctrl.text),
          city: _nullIfEmpty(_cityCtrl.text),
          state: _nullIfEmpty(_stateCtrl.text),
          postalCode: _nullIfEmpty(_postalCodeCtrl.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_nurseryRegProvider);

    // On success → refresh session, go to pending screen.
    // On alreadyRegistered (409) → refresh session, let routing decide destination.
    ref.listen(_nurseryRegProvider, (_, next) {
      if (!mounted) return;
      final router = GoRouter.of(context);
      if (next.success) {
        ref.read(sessionProvider.notifier).bootstrap().then((_) {
          if (mounted) router.go('/nursery/pending');
        });
      } else if (next.alreadyRegistered) {
        ref.read(sessionProvider.notifier).bootstrap().then((_) {
          if (!mounted) return;
          final caps = ref.read(sessionProvider).capabilities;
          if (caps.hasPendingNursery) {
            router.go('/nursery/pending');
          } else if (caps.hasRejectedNursery) {
            router.go('/nursery/rejected');
          } else {
            router.go('/home');
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register Nursery'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Header
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.forest100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_florist_rounded,
                  color: AppColors.primaryMain,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const Text('Register Your Nursery', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Fill in your nursery details. Your application will be reviewed by GreenRoot.',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3l),

              // ── Section: Nursery Info ──────────────────────────────────────
              _SectionLabel(label: 'Nursery Info'),
              const SizedBox(height: AppSpacing.md),

              // Nursery Name (required)
              AppTextField(
                label: 'Nursery Name *',
                hint: 'e.g. Green Valley Nursery',
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                autofocus: true,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nursery name is required';
                  }
                  if (val.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Contact Mobile (pre-filled from profile, editable)
              AppTextField(
                label: 'Contact Mobile',
                hint: 'Nursery contact number',
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length < 7) {
                    return 'Enter a valid mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Email (pre-filled from profile, editable)
              AppTextField(
                label: 'Email Address',
                hint: 'nursery@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Enter a valid email address';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Description (optional)
              AppTextField(
                label: 'Description',
                hint: 'Brief description of your nursery...',
                controller: _descCtrl,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 3,
              ),

              const SizedBox(height: AppSpacing.x2l),

              // ── Section: Nursery Address ───────────────────────────────────
              _SectionLabel(label: 'Nursery Address'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Where is your nursery located? This helps customers find you.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                label: 'Address Line 1 *',
                hint: 'Street, area, locality',
                controller: _addressLine1Ctrl,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'City *',
                      hint: 'e.g. Bengaluru',
                      controller: _cityCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'City is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'State *',
                      hint: 'e.g. Karnataka',
                      controller: _stateCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'State is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Postal Code',
                hint: '560001',
                controller: _postalCodeCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.red100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.red600.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.red600, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: AppTypography.body
                              .copyWith(color: AppColors.red600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.x3l),

              // Info card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primaryMain, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'After submission, GreenRoot will review your application. You will be notified once approved.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.forest700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),

              AppButton(
                label: 'Submit Application',
                onPressed: _submit,
                isLoading: state.isLoading,
                trailingIcon: Icons.send_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () {
                  if (context.canPop()) context.pop();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size(double.infinity, AppSpacing.buttonHeight),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: AppSpacing.x3l),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: AppTypography.label
            .copyWith(color: AppColors.textPrimary, letterSpacing: 0.4));
  }
}
