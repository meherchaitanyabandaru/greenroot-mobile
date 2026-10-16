import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart' show ApiClient, apiClientProvider;
import '../../core/testing/test_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_state.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class SmsPreferences {
  final bool promotionalOptIn;
  final DateTime? consentAt;

  const SmsPreferences({required this.promotionalOptIn, this.consentAt});

  factory SmsPreferences.fromJson(Map<String, dynamic> json) => SmsPreferences(
        promotionalOptIn: json['promotional_opt_in'] as bool? ?? false,
        consentAt: DateTime.tryParse(json['promotional_consent_at']?.toString() ?? '')?.toLocal(),
      );
}

class SmsPreferencesRepository {
  final ApiClient _api;
  const SmsPreferencesRepository(this._api);

  Future<SmsPreferences> get() async {
    final res = await _api.get(ApiConstants.smsPreferencesMe);
    return SmsPreferences.fromJson(res['preferences'] as Map<String, dynamic>);
  }

  Future<SmsPreferences> setPromotional(bool optIn) async {
    final res = await _api.put(
      ApiConstants.smsPreferencesMe,
      data: {'promotional_opt_in': optIn, 'source': 'MOBILE_APP'},
    );
    return SmsPreferences.fromJson(res['preferences'] as Map<String, dynamic>);
  }
}

final smsPreferencesRepositoryProvider =
    Provider((ref) => SmsPreferencesRepository(ref.watch(apiClientProvider)));

final smsPreferencesProvider = FutureProvider.autoDispose<SmsPreferences>(
  (ref) => ref.watch(smsPreferencesRepositoryProvider).get(),
);

// ── Screen ────────────────────────────────────────────────────────────────────

/// Consent for optional SMS. OTP, order and payment SMS are service messages
/// under TRAI rules and are always sent; only promotional SMS need opt-in.
class SmsPreferencesScreen extends ConsumerStatefulWidget {
  const SmsPreferencesScreen({super.key});

  @override
  ConsumerState<SmsPreferencesScreen> createState() =>
      _SmsPreferencesScreenState();
}

class _SmsPreferencesScreenState extends ConsumerState<SmsPreferencesScreen> {
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    try {
      await ref.read(smsPreferencesRepositoryProvider).setPromotional(value);
      ref.invalidate(smsPreferencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            value ? 'You will receive offers by SMS' : 'Promotional SMS turned off',
          ),
        ),
      );
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(smsPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('SMS Preferences', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: prefs.when(
        loading: () => const Center(child: AppLoader()),
        error: (e, _) => ErrorState(
          error: e is AppError ? e : null,
          onRetry: () => ref.invalidate(smsPreferencesProvider),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            const _Card(
              children: [
                _Row(
                  icon: Icons.lock_outline_rounded,
                  title: 'Login OTP',
                  subtitle: 'One-time codes to sign in or create your account',
                ),
                Divider(height: 1),
                _Row(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders & payments',
                  subtitle: 'Payment receipts and failed payment alerts',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'These are service messages needed to run your account, so they are always on.',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.x2l),
            _Card(
              children: [
                SwitchListTile(
                  key: const Key(TestKeys.smsPromotionalSwitch),
                  value: p.promotionalOptIn,
                  onChanged: _saving ? null : _toggle,
                  activeThumbColor: AppColors.primaryMain,
                  secondary: const Icon(Icons.local_offer_outlined,
                      color: AppColors.textSecondary,),
                  title: const Text('Offers & updates', style: AppTypography.body),
                  subtitle: Text(
                    'Occasional offers from GreenRoot, sent between 10 AM and 9 PM',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You can turn this off any time.',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated Container) so the ListTiles' ink stays visible.
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Row({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTypography.body),
      subtitle: Text(subtitle,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),),
      trailing: Text('Always on',
          style: AppTypography.caption.copyWith(color: AppColors.primaryMain),),
    );
  }
}
