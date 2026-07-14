import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import 'splash_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String mobile;

  const OtpScreen({super.key, required this.mobile});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(AppConstants.otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(AppConstants.otpLength, (_) => FocusNode());

  int _resendSeconds = AppConstants.otpResendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != AppConstants.otpLength) return;

    await ref.read(otpVerifyProvider.notifier).verify(widget.mobile, _otp);
    if (!mounted) return;

    final verifyState = ref.read(otpVerifyProvider);

    if (verifyState.error != null || !verifyState.verified) {
      _clearOtp();
      return;
    }

    // Bootstrap full session after verify
    await ref.read(sessionProvider.notifier).bootstrap();
    if (!mounted) return;

    await ref.read(activeRoleProvider.notifier).loadSavedRole();
    if (!mounted) return;

    final session = ref.read(sessionProvider);

    // Send to profile completion only if new user AND profile not yet complete.
    // Guards against repeat redirects when the user has already filled all fields.
    if (verifyState.isNewUser && !(session.user?.isProfileComplete ?? false)) {
      context.go('/create-profile');
      return;
    }

    SplashScreen.routeAfterLogin(context, session);
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    _clearOtp();
    setState(() => _resendSeconds = AppConstants.otpResendSeconds);
    _startTimer();
    await ref.read(otpSendProvider.notifier).sendOtp(widget.mobile);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verifyState = ref.watch(otpVerifyProvider);
    final sendState = ref.watch(otpSendProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.x2l),
              const Text('Enter verification code', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We sent a 6-digit code to +91 ${widget.mobile}',
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3l),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  AppConstants.otpLength,
                  (i) => _OtpBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    hasError: verifyState.error != null,
                    onChanged: (val) {
                      if (val.isNotEmpty && i < AppConstants.otpLength - 1) {
                        _focusNodes[i + 1].requestFocus();
                      }
                      if (val.isNotEmpty && i == AppConstants.otpLength - 1) {
                        _verify();
                      }
                    },
                    onBackspace: () {
                      if (i > 0) {
                        _focusNodes[i - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),

              if (verifyState.error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  verifyState.error!.message,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.errorText),
                ),
              ],

              const SizedBox(height: AppSpacing.x3l),

              AppButton(
                label: 'Verify OTP',
                onPressed:
                    _otp.length == AppConstants.otpLength ? _verify : null,
                isLoading: verifyState.isLoading,
              ),

              const SizedBox(height: AppSpacing.x2l),

              // Resend
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend OTP in $_resendSeconds s',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : TextButton(
                        onPressed: sendState.isLoading ? null : _resend,
                        child: Text(
                          sendState.isLoading ? 'Sending...' : 'Resend OTP',
                          style: AppTypography.button.copyWith(
                            color: AppColors.primaryMain,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      width: 48,
      height: 56,
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
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: hasError ? AppColors.red500 : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
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
