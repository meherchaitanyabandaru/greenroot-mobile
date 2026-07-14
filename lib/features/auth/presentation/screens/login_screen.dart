import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/onboarding_progress.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  String? _mobileError;
  bool _agreedToTerms = false;
  bool _termsAlreadyAccepted = false; // true = returning user, hide checkbox

  @override
  void initState() {
    super.initState();
    _loadTermsStatus();
  }

  Future<void> _loadTermsStatus() async {
    final agreed = await SecureStorageService.hasAgreedToTerms();
    if (!mounted) return;
    setState(() {
      _termsAlreadyAccepted = agreed;
      _agreedToTerms = agreed;
    });
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() => _mobileError = null);
    if (!_agreedToTerms) {
      setState(() => _mobileError =
          'Please agree to the Terms & Conditions and Privacy Policy');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAlreadyAccepted) {
      await SecureStorageService.saveTermsAgreed();
    }

    await ref.read(otpSendProvider.notifier).sendOtp(_mobileCtrl.text.trim());
    final state = ref.read(otpSendProvider);

    if (state.error != null) {
      setState(() => _mobileError = state.error!.message);
      return;
    }

    if (mounted) {
      final mobile = _mobileCtrl.text.trim();
      context.go(
        Uri(path: '/otp', queryParameters: {'mobile': mobile}).toString(),
        extra: mobile,
      );
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
                const SizedBox(height: AppSpacing.x2l),

                const OnboardingProgress(currentStep: 1),
                const SizedBox(height: AppSpacing.x2l),

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

                const Text('Welcome to GreenRoot', style: AppTypography.h1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Buy. Sell. Deliver. All in one app.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter your mobile number to sign in or create an account.',
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

                // T&C + Privacy Policy consent — shown only on first login
                if (!_termsAlreadyAccepted) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreedToTerms,
                          onChanged: (v) =>
                              setState(() => _agreedToTerms = v ?? false),
                          activeColor: AppColors.primaryMain,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => setState(
                                () => _agreedToTerms = !_agreedToTerms,
                              ),
                              child: Text(
                                'I agree to the ',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            _AgreementLink(
                              label: 'Terms & Conditions',
                              onTap: () => context.push('/terms-of-service'),
                            ),
                            Text(
                              ' and ',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            _AgreementLink(
                              label: 'Privacy Policy',
                              onTap: () => context.push('/privacy-policy'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                ],

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
                    'Dev: use 9300000000 (buyer) or 9000000000 (admin) / OTP 123456',
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

class _AgreementLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AgreementLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.primaryMain,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
