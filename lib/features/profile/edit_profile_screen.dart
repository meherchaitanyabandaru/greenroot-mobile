import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/services/storage_service.dart';
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

  // Avatar state
  Uint8List? _pickedBytes;
  String? _pendingImageUrl;
  bool _uploadingImage = false;
  String? _imageError;

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

  Future<void> _pickAndUploadImage() async {
    setState(() => _imageError = null);
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) setState(() => _imageError = 'Could not open image picker.');
      return;
    }
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final fileName = 'avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';

      final storage = StorageService(ApiClient.instance);
      final result = await storage.presign('profile-images', fileName, contentType);
      await storage.uploadBytes(result.uploadUrl, bytes, contentType);

      if (mounted) {
        setState(() {
          _pickedBytes = bytes;
          _pendingImageUrl = result.fileUrl;
        });
      }
    } on AppError catch (e) {
      if (mounted) setState(() => _imageError = e.message);
    } catch (_) {
      if (mounted) setState(() => _imageError = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
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
          profileImageUrl:
              _pendingImageUrl ?? user?.profileImageUrl,
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
              // ── Avatar picker ─────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _uploadingImage ? null : _pickAndUploadImage,
                      child: Stack(
                        children: [
                          // Avatar circle
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.primaryMain, width: 2.5,),
                            ),
                            child: ClipOval(
                              child: _buildAvatarContent(user),
                            ),
                          ),
                          // Edit badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primaryMain,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.background, width: 2,),
                              ),
                              child: _uploadingImage
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 15,),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _uploadingImage
                          ? 'Uploading…'
                          : 'Tap to change photo',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                    if (_imageError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _imageError!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.errorText),
                      ),
                    ],
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
                        color: AppColors.errorText.withValues(alpha: 0.3),),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: AppColors.errorText,),
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
                onPressed: _uploadingImage ? null : _save,
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

  Widget _buildAvatarContent(UserProfile? user) {
    // 1. Local preview after picking
    if (_pickedBytes != null) {
      return Image.memory(
        _pickedBytes!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
      );
    }
    // 2. Existing network image from API
    final imageUrl = user?.profileImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initialsWidget(user),
      );
    }
    // 3. Fallback initials
    return _initialsWidget(user);
  }

  Widget _initialsWidget(UserProfile? user) => Center(
        child: Text(
          user?.initials ?? '?',
          style: AppTypography.h2.copyWith(color: AppColors.primaryMain),
        ),
      );

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
          horizontal: AppSpacing.md, vertical: AppSpacing.md,),
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
                        .copyWith(color: AppColors.textMuted),),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 15, color: AppColors.textMuted,),
              const SizedBox(height: 2),
              Text(note,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.primaryMain),),
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
                color: selected ? Colors.white : AppColors.textSecondary,),
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
