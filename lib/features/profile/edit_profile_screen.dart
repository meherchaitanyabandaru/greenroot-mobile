import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../auth/data/datasources/auth_remote_datasource.dart';
import '../auth/data/models/user_models.dart';
import '../auth/data/repositories/auth_repository.dart';
import '../auth/presentation/providers/session_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _gender;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    if (user != null) {
      _firstNameCtrl.text = user.firstName ?? '';
      _lastNameCtrl.text = user.lastName ?? '';
      _emailCtrl.text = user.email ?? '';
      _gender = user.gender;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = ref.read(sessionProvider).user;
      final lastName = _lastNameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final repo = AuthRepository(AuthRemoteDataSource(ApiClient.instance));
      final updated = await repo.updateProfile(
        UpdateProfileRequest(
          firstName: _firstNameCtrl.text.trim(),
          lastName: lastName.isEmpty ? null : lastName,
          email: (user?.emailVerified == true)
              ? null
              : (email.isEmpty ? null : email),
          gender: _gender,
        ),
      );
      ref.read(sessionProvider.notifier).updateUser(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AppError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final emailLocked = user?.emailVerified == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Edit Profile', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primaryMain, width: 2.5),
                      ),
                      child: Center(
                        child: Text(
                          user?.initials ?? '?',
                          style: AppTypography.h2
                              .copyWith(color: AppColors.primaryMain),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),

              // ── Account (locked) ──────────────────────────────────────────
              _sectionLabel('Account'),
              const SizedBox(height: AppSpacing.sm),
              _LockedField(
                icon: Icons.phone_outlined,
                label: 'Mobile Number',
                value: user?.mobile ?? '—',
                note: 'Verified via OTP',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (emailLocked)
                _LockedField(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? '—',
                  note: 'Verified',
                )
              else ...[
                AppTextField(
                  label: 'Email (optional)',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.x2l),

              // ── Personal details (editable) ───────────────────────────────
              _sectionLabel('Personal Details'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'First Name',
                hint: 'Enter your first name',
                controller: _firstNameCtrl,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Last Name',
                hint: 'Enter your last name (optional)',
                controller: _lastNameCtrl,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.x2l),

              // ── Gender ────────────────────────────────────────────────────
              _sectionLabel('Gender'),
              const SizedBox(height: AppSpacing.sm),
              _GenderSelector(
                value: _gender,
                onChanged: (g) => setState(() => _gender = g),
              ),

              // ── Error ─────────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.errorText.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: AppColors.errorText),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.errorText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.x3l),
              AppButton(
                label: 'Save Changes',
                onPressed: _save,
                isLoading: _isLoading,
                trailingIcon: Icons.check_rounded,
              ),
              const SizedBox(height: AppSpacing.x3l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
      );
}

// ── Locked field ──────────────────────────────────────────────────────────────

class _LockedField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;

  const _LockedField({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 15, color: AppColors.textMuted),
              const SizedBox(height: 2),
              Text(note,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.primaryMain)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gender selector ───────────────────────────────────────────────────────────

class _GenderSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _GenderSelector({required this.value, required this.onChanged});

  static const _options = [
    ('MALE', 'Male', Icons.male_rounded),
    ('FEMALE', 'Female', Icons.female_rounded),
    ('NON_BINARY', 'Non-binary', Icons.transgender_rounded),
    ('OTHER', 'Other', Icons.people_outline_rounded),
    ('PREFER_NOT_TO_SAY', 'Prefer not\nto say', Icons.visibility_off_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _options
          .map(
            (o) => _GenderChip(
              label: o.$2,
              icon: o.$3,
              selected: value == o.$1,
              onTap: () => onChanged(value == o.$1 ? null : o.$1),
            ),
          )
          .toList(),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMain : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryMain : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
