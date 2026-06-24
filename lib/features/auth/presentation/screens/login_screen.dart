import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  String? _mobileError;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() => _mobileError = null);
    if (!_formKey.currentState!.validate()) return;

    await ref.read(otpSendProvider.notifier).sendOtp(_mobileCtrl.text.trim());
    final state = ref.read(otpSendProvider);

    if (state.error != null) {
      setState(() => _mobileError = state.error!.message);
      return;
    }

    if (mounted) {
      context.go('/otp', extra: _mobileCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(otpSendProvider).isLoading;

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

                // Logo
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'GR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2l),

                const Text('Welcome back', style: AppTypography.h1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter your mobile number to receive a one-time passcode.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x3l),

                // Mobile field
                AppTextField(
                  label: 'Mobile Number',
                  hint: '9876543210',
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  errorText: _mobileError,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  prefixIcon: const Text(
                    '+91',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onSubmitted: (_) => _requestOtp(),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (val.trim().length != 10) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.x2l),

                AppButton(
                  label: 'Send OTP',
                  onPressed: _requestOtp,
                  isLoading: isLoading,
                  trailingIcon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: AppSpacing.x2l),

                // Dev hint
                Center(
                  child: Text(
                    'Dev: use 9000000777 / OTP 123456',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
