import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
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
  _NurseryRegNotifier() : super(const _NurseryRegState());

  Future<void> submit({
    required String name,
    required String? mobile,
    required String? email,
    required String? description,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiClient.instance.post(
        '/api/v1/nurseries',
        data: {
          'name': name,
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          if (email != null && email.isNotEmpty) 'email': email,
          if (description != null && description.isNotEmpty)
            'description': description,
          'status': 'PENDING',
        },
      );
      state = state.copyWith(isLoading: false, success: true);
    } on ServerError catch (e) {
      // 409 means this user already owns a nursery — refresh session and go home
      if (e.statusCode == 409) {
        state = state.copyWith(isLoading: false, alreadyRegistered: true);
      } else {
        state = state.copyWith(isLoading: false, error: e.message);
      }
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to register nursery. Please try again.',
      );
    }
  }
}

final _nurseryRegProvider =
    StateNotifierProvider.autoDispose<_NurseryRegNotifier, _NurseryRegState>(
  (ref) => _NurseryRegNotifier(),
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(_nurseryRegProvider.notifier).submit(
          name: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim().isEmpty
              ? null
              : _mobileCtrl.text.trim(),
          email:
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
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

              // Contact Mobile (optional)
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

              // Email (optional)
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
                textInputAction: TextInputAction.done,
                maxLines: 3,
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
