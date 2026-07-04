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
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../providers/session_provider.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(sessionProvider).user;
      if (user == null) return;
      // Profile already complete — skip straight to activity selection
      if (user.isProfileComplete) {
        context.go('/select-activity');
        return;
      }
      // Pre-fill whatever is already saved
      if (user.firstName?.isNotEmpty == true) {
        final full = [user.firstName, user.lastName]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
        _nameCtrl.text = full;
      }
      if (user.email?.isNotEmpty == true) {
        _emailCtrl.text = user.email!;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final fullName = _nameCtrl.text.trim();
      final spaceIdx = fullName.indexOf(' ');
      final firstName = spaceIdx == -1 ? fullName : fullName.substring(0, spaceIdx);
      final lastName  = spaceIdx == -1 ? null : fullName.substring(spaceIdx + 1).trim();

      final repo = AuthRepository(AuthRemoteDataSource(ApiClient.instance));
      final updated = await repo.updateProfile(
        UpdateProfileRequest(
          firstName: firstName,
          lastName:  lastName?.isEmpty == true ? null : lastName,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        ),
      );
      ref.read(sessionProvider.notifier).updateUser(updated);

      if (!mounted) return;

      // New user — show activity selection screen once before home.
      context.go('/select-activity');
    } on AppError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.x4l),

                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    color: AppColors.primaryMain,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2l),

                const Text('Complete your profile', style: AppTypography.h1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Just a few details to get you started.',
                  style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.x3l),

                AppTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                AppTextField(
                  label: 'Email (optional)',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  validator: (val) {
                    if (val != null && val.isNotEmpty) {
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: AppTypography.caption.copyWith(color: AppColors.errorText),
                  ),
                ],

                const SizedBox(height: AppSpacing.x3l),

                AppButton(
                  label: 'Get Started',
                  onPressed: _save,
                  isLoading: _isLoading,
                  trailingIcon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
