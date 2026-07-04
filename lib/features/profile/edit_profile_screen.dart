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

  // Avatar state — bytes for local preview after pick
  Uint8List? _pickedBytes;
  bool _uploadingImage = false;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    // Try immediate fill — works when session is already loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFill());
  }

  /// Pre-fills editable controllers from the session user.
  /// Safe to call multiple times — only fills empty fields.
  void _tryFill() {
    if (!mounted) return;
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    if (_firstNameCtrl.text.isEmpty) _firstNameCtrl.text = user.firstName ?? '';
    if (_lastNameCtrl.text.isEmpty) _lastNameCtrl.text = user.lastName ?? '';
    if (_emailCtrl.text.isEmpty) _emailCtrl.text = user.email ?? '';
    if (_gender == null && user.gender != null) {
      setState(() => _gender = user.gender);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Pick an image, upload via POST /api/v1/users/me/avatar (multipart).
  /// The API uploads to MinIO and updates profile_image_url in one step.
  /// Session is updated immediately — no need to wait for Save.
  Future<void> _pickAndUploadImage() async {
    setState(() => _imageError = null);
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
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

      final updated = await StorageService(ApiClient.instance)
          .uploadAvatar(bytes, fileName, contentType);

      ref.read(sessionProvider.notifier).updateUser(updated);
      if (mounted) setState(() => _pickedBytes = bytes);
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
          // Preserve the current profileImageUrl — avatar is saved separately via uploadAvatar.
          profileImageUrl: user?.profileImageUrl,
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
    final session = ref.watch(sessionProvider);

    // When bootstrap completes and user data arrives, fill empty controllers.
    ref.listen<UserProfile?>(
      sessionProvider.select((s) => s.user),
      (_, user) { if (user != null) _tryFill(); },
    );

    final user = session.user;
    final firstNameLocked = user?.firstName?.isNotEmpty == true;
    final lastNameLocked  = user?.lastName?.isNotEmpty == true;
    final emailLocked     = user?.email?.isNotEmpty == true;
    final genderLocked    = user?.gender?.isNotEmpty == true;

    // Show spinner while bootstrap is still running.
    if (session.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text('Edit Profile', style: AppTypography.h3),
          foregroundColor: AppColors.textPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryMain,
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(child: _buildAvatarContent(user)),
                          ),
                          // Camera badge
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
                                  color: AppColors.background,
                                  width: 2,
                                ),
                              ),
                              child: _uploadingImage
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _uploadingImage ? 'Uploading…' : 'Tap to change photo',
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
                  value: user!.email!,
                  note: user.emailVerified ? 'Verified' : 'Set',
                )
              else
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
              const SizedBox(height: AppSpacing.x2l),

              // ── Personal details ──────────────────────────────────────────
              _sectionLabel('Personal Details'),
              const SizedBox(height: AppSpacing.sm),
              if (firstNameLocked)
                _LockedField(
                  icon: Icons.person_outline_rounded,
                  label: 'First Name',
                  value: user!.firstName!,
                  note: 'Set',
                )
              else
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
              const SizedBox(height: AppSpacing.sm),
              if (lastNameLocked)
                _LockedField(
                  icon: Icons.person_outline_rounded,
                  label: 'Last Name',
                  value: user!.lastName!,
                  note: 'Set',
                )
              else
                AppTextField(
                  label: 'Last Name (optional)',
                  hint: 'Enter your last name',
                  controller: _lastNameCtrl,
                  textInputAction: TextInputAction.done,
                ),
              const SizedBox(height: AppSpacing.x2l),

              // ── Gender ────────────────────────────────────────────────────
              _sectionLabel('Gender'),
              const SizedBox(height: AppSpacing.sm),
              if (genderLocked)
                _LockedField(
                  icon: _genderIcon(user!.gender!),
                  label: 'Gender',
                  value: _genderLabel(user.gender!),
                  note: 'Set',
                )
              else
                _GenderDropdown(
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
                      color: AppColors.errorText.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: AppColors.errorText,
                      ),
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
              if (firstNameLocked && lastNameLocked && emailLocked && genderLocked)
                Center(
                  child: Text(
                    'Profile is complete. You can still update your photo.',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                )
              else
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
    // 1. Local bytes preview (just picked, session already updated)
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, width: 96, height: 96, fit: BoxFit.cover);
    }
    // 2. Network image from session
    final url = user?.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initials(user),
      );
    }
    // 3. Initials fallback
    return _initials(user);
  }

  Widget _initials(UserProfile? user) => Center(
        child: Text(
          user?.initials ?? '?',
          style: AppTypography.h2.copyWith(color: AppColors.primaryMain),
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
      );

  static IconData _genderIcon(String g) {
    switch (g) {
      case 'MALE': return Icons.male_rounded;
      case 'FEMALE': return Icons.female_rounded;
      default: return Icons.visibility_off_outlined;
    }
  }

  static String _genderLabel(String g) {
    switch (g) {
      case 'MALE': return 'Male';
      case 'FEMALE': return 'Female';
      default: return 'Prefer not to say';
    }
  }
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
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
                Text(
                  label,
                  style:
                      AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 2),
              Text(
                note,
                style:
                    AppTypography.caption.copyWith(color: AppColors.primaryMain),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gender dropdown (3 options) ───────────────────────────────────────────────

class _GenderDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _GenderDropdown({required this.value, required this.onChanged});

  static const _options = [
    ('MALE', 'Male', Icons.male_rounded),
    ('FEMALE', 'Female', Icons.female_rounded),
    ('PREFER_NOT_TO_SAY', 'Prefer not to say', Icons.visibility_off_outlined),
  ];

  // Normalise any existing DB value that isn't in our 3 options to null.
  String? get _normalisedValue {
    if (value == null) return null;
    return _options.any((o) => o.$1 == value) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _normalisedValue,
          isExpanded: true,
          hint: Text(
            'Select gender',
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          items: _options
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.$1,
                  child: Row(
                    children: [
                      Icon(o.$3, size: 20, color: AppColors.primaryMain),
                      const SizedBox(width: AppSpacing.sm),
                      Text(o.$2, style: AppTypography.body),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
