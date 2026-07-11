import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../auth/data/models/user_models.dart';
import '../auth/presentation/providers/auth_provider.dart';
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

      final updated = await ref
          .read(storageServiceProvider)
          .uploadAvatar(bytes, fileName, contentType);

      ref.read(sessionProvider.notifier).updateUser(updated);
      if (mounted) setState(() => _pickedBytes = bytes);
    } on AppError catch (e) {
      if (mounted) setState(() => _imageError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _imageError = 'Upload failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _showSheet(_IdentityType type, String? current) async {
    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeIdentitySheet(
        type: type,
        currentValue: current,
        updateProfile: (email) async {
          final user = ref.read(sessionProvider).user;
          final repo = ref.read(authRepositoryProvider);
          final updated = await repo.updateProfile(UpdateProfileRequest(
            firstName: user?.firstName ?? '',
            lastName: user?.lastName,
            email: email,
            gender: user?.gender,
            profileImageUrl: user?.profileImageUrl,
          ));
          ref.read(sessionProvider.notifier).updateUser(updated);
        },
      ),
    );
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated)),
      );
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
      final repo = ref.read(authRepositoryProvider);
      final updated = await repo.updateProfile(
        UpdateProfileRequest(
          firstName: _firstNameCtrl.text.trim(),
          lastName: lastName.isEmpty ? null : lastName,
          // Don't send email if verified — identity change requires a verification flow.
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
      (_, user) {
        if (user != null) _tryFill();
      },
    );

    final user = session.user;
    final emailLocked = user?.emailVerified == true;

    // Show spinner while bootstrap is still running.
    if (session.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text('Personal Information', style: AppTypography.h3),
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
        title: const Text('Personal Information', style: AppTypography.h3),
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

              // ── Account ───────────────────────────────────────────────────
              _sectionLabel('Account'),
              const SizedBox(height: AppSpacing.sm),
              _LockedField(
                icon: Icons.phone_outlined,
                label: 'Mobile Number',
                value: user?.mobile ?? '—',
                note: 'Verified',
                onChangeTap: () => _showSheet(_IdentityType.mobile, user?.mobile),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (emailLocked)
                _LockedField(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user!.email!,
                  note: 'Verified',
                  onChangeTap: () => _showSheet(_IdentityType.email, user.email),
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
      return Image.memory(
        _pickedBytes!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
      );
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
      case 'MALE':
        return Icons.male_rounded;
      case 'FEMALE':
        return Icons.female_rounded;
      default:
        return Icons.visibility_off_outlined;
    }
  }

  static String _genderLabel(String g) {
    switch (g) {
      case 'MALE':
        return 'Male';
      case 'FEMALE':
        return 'Female';
      default:
        return 'Prefer not to say';
    }
  }
}

// ── Locked field ──────────────────────────────────────────────────────────────

class _LockedField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;
  final VoidCallback? onChangeTap;

  const _LockedField({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    this.onChangeTap,
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
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
          if (onChangeTap != null)
            GestureDetector(
              onTap: onChangeTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Change',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryHover,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(height: 2),
                Text(note, style: AppTypography.caption.copyWith(color: AppColors.primaryMain)),
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

// ── Identity change flow ──────────────────────────────────────────────────────

enum _IdentityType { mobile, email }

class _ChangeIdentitySheet extends StatefulWidget {
  final _IdentityType type;
  final String? currentValue;
  final Future<void> Function(String newValue)? updateProfile;

  const _ChangeIdentitySheet({
    required this.type,
    this.currentValue,
    this.updateProfile,
  });

  @override
  State<_ChangeIdentitySheet> createState() => _ChangeIdentitySheetState();
}

class _ChangeIdentitySheetState extends State<_ChangeIdentitySheet> {
  final _inputCtrl = TextEditingController();
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());

  int _step = 1;
  bool _loading = false;
  String? _error;
  int _resendSeconds = 30;
  Timer? _timer;

  bool get _isMobile => widget.type == _IdentityType.mobile;

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otp => _otpCtrls.map((c) => c.text).join();

  void _clearOtp() {
    for (final c in _otpCtrls) c.clear();
    if (_otpNodes.isNotEmpty) _otpNodes.first.requestFocus();
  }

  bool _validateInput() {
    final v = _inputCtrl.text.trim();
    if (_isMobile) {
      if (v.length != 10 || int.tryParse(v) == null) {
        setState(() => _error = 'Enter a valid 10-digit mobile number');
        return false;
      }
      if (v == widget.currentValue?.replaceAll(RegExp(r'\D'), '')) {
        setState(() => _error = 'This is already your current number');
        return false;
      }
    } else {
      if (!v.contains('@') || !v.contains('.')) {
        setState(() => _error = 'Enter a valid email address');
        return false;
      }
      if (v == widget.currentValue) {
        setState(() => _error = 'This is already your current email');
        return false;
      }
    }
    return true;
  }

  Future<void> _sendCode() async {
    setState(() => _error = null);
    if (!_validateInput()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // simulate send
    if (!mounted) return;
    setState(() {
      _loading = false;
      _step = 2;
    });
    _startTimer();
    // Auto-focus first OTP box after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _otpNodes.isNotEmpty) _otpNodes.first.requestFocus();
    });
  }

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    setState(() { _loading = true; _error = null; });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Dev mock: only 123456 is valid
    if (_otp != '123456') {
      _clearOtp();
      setState(() { _loading = false; _error = 'Incorrect code. Use 123456 in dev.'; });
      return;
    }

    try {
      if (!_isMobile && widget.updateProfile != null) {
        await widget.updateProfile!(_inputCtrl.text.trim());
      }
      if (mounted) {
        Navigator.of(context).pop(
          _isMobile
              ? 'Mobile number updated successfully.'
              : 'Email updated successfully.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() { _loading = false; _error = 'Update failed. Please try again.'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.x2l,
        AppSpacing.screenPadding,
        AppSpacing.x2l + bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _step == 1 ? _buildStep1() : _buildStep2(),
    );
  }

  Widget _buildStep1() {
    final hint = _isMobile ? 'New mobile number' : 'New email address';
    final label = _isMobile ? 'Change Mobile Number' : 'Change Email';
    final subtitle = _isMobile
        ? 'We\'ll send a 6-digit verification code to your new number.'
        : 'We\'ll send a 6-digit verification code to your new email.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHandle(),
        const SizedBox(height: AppSpacing.lg),
        Text(label, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.x2l),
        TextField(
          controller: _inputCtrl,
          autofocus: true,
          keyboardType: _isMobile ? TextInputType.phone : TextInputType.emailAddress,
          inputFormatters: _isMobile ? [FilteringTextInputFormatter.digitsOnly] : [],
          maxLength: _isMobile ? 10 : null,
          style: AppTypography.body,
          decoration: InputDecoration(
            counterText: '',
            labelText: hint,
            filled: true,
            fillColor: AppColors.background,
            prefixText: _isMobile ? '+91 ' : null,
            prefixStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryMain, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onSubmitted: (_) => _sendCode(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: AppTypography.caption.copyWith(color: AppColors.errorText)),
        ],
        const SizedBox(height: AppSpacing.x2l),
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Send Code'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final destination = _isMobile ? '+91 ${_inputCtrl.text.trim()}' : _inputCtrl.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHandle(),
        const SizedBox(height: AppSpacing.lg),
        Text('Enter verification code', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'We sent a 6-digit code to $destination',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x2l),
        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _OtpBox(
            controller: _otpCtrls[i],
            focusNode: _otpNodes[i],
            hasError: _error != null,
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) _otpNodes[i + 1].requestFocus();
              if (val.isNotEmpty && i == 5) _verify();
            },
            onBackspace: () {
              if (i > 0) _otpNodes[i - 1].requestFocus();
            },
          )),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: AppTypography.caption.copyWith(color: AppColors.errorText)),
        ],
        const SizedBox(height: AppSpacing.x2l),
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: (_otp.length == 6 && !_loading) ? _verify : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: _resendSeconds > 0
              ? Text(
                  'Resend code in ${_resendSeconds}s',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                )
              : TextButton(
                  onPressed: () {
                    _clearOtp();
                    _startTimer();
                  },
                  child: Text(
                    'Resend Code',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.primaryMain),
                  ),
                ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() { _step = 1; _error = null; _clearOtp(); }),
            child: Text(
              'Change ${_isMobile ? 'number' : 'email'}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 54,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.background,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? AppColors.red500 : AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.red500 : AppColors.primaryMain,
                width: 1.5,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
