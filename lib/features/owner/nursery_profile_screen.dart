import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/nursery_branding_badge.dart';
import '../auth/presentation/providers/session_provider.dart';
import '../nurseries/nurseries.dart';

class NurseryProfileScreen extends ConsumerWidget {
  final int nurseryId;

  const NurseryProfileScreen({super.key, required this.nurseryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nurseryDetailProvider(nurseryId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Nursery Profile', style: AppTypography.h3),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryMain),
        ),
        error: (err, _) => Center(
          child: Text(err.toString(), style: AppTypography.body),
        ),
        data: (nursery) => _NurseryProfileForm(nursery: nursery),
      ),
    );
  }
}

class _NurseryProfileForm extends ConsumerStatefulWidget {
  final Nursery nursery;

  const _NurseryProfileForm({required this.nursery});

  @override
  ConsumerState<_NurseryProfileForm> createState() =>
      _NurseryProfileFormState();
}

class _NurseryProfileFormState extends ConsumerState<_NurseryProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _descriptionCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.nursery.name);
    _mobileCtrl = TextEditingController(text: widget.nursery.mobile ?? '');
    _emailCtrl = TextEditingController(text: widget.nursery.email ?? '');
    _websiteCtrl = TextEditingController(text: widget.nursery.website ?? '');
    _descriptionCtrl =
        TextEditingController(text: widget.nursery.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(nurseryRepositoryProvider).updateProfile(
            widget.nursery.id,
            name: _nameCtrl.text.trim(),
            mobile: _mobileCtrl.text,
            email: _emailCtrl.text,
            website: _websiteCtrl.text,
            description: _descriptionCtrl.text,
          );
      ref.invalidate(nurseryDetailProvider(widget.nursery.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nursery profile saved')),
      );
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Save failed. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                _NurserySummaryCard(nursery: widget.nursery),
                const SizedBox(height: AppSpacing.x2l),
                Text('Public Details', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.sm),
                _FormPanel(
                  children: [
                    AppTextField(
                      label: 'Nursery Name',
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nursery name is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Description',
                      hint: 'Tell customers what your nursery is known for',
                      controller: _descriptionCtrl,
                      keyboardType: TextInputType.multiline,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Website',
                      hint: 'https://example.com',
                      controller: _websiteCtrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2l),
                Text('Contact', style: AppTypography.h4),
                const SizedBox(height: AppSpacing.sm),
                _FormPanel(
                  children: [
                    AppTextField(
                      label: 'Mobile',
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3l),
                _CloseNurserySection(nurseryId: widget.nursery.id),
                const SizedBox(height: AppSpacing.x3l),
              ],
            ),
          ),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: AppTypography.body.copyWith(color: AppColors.errorText),
              ),
            ),
          ],
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: AppButton(
                label: 'Save Profile',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NurserySummaryCard extends StatelessWidget {
  final Nursery nursery;

  const _NurserySummaryCard({required this.nursery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/nursery/branding', extra: nursery.id),
            child: Stack(
              children: [
                NurseryBrandingBadge(
                  logoUrl: nursery.logoUrl,
                  brandIconKey: nursery.brandIconKey,
                  brandColor: nursery.brandColor,
                  nurseryName: nursery.name,
                  size: 58,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nursery.name, style: AppTypography.h4),
                const SizedBox(height: 4),
                Text(
                  nursery.nurseryCode ?? nursery.status,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Close nursery ─────────────────────────────────────────────────────────────

class _CloseNurserySection extends ConsumerStatefulWidget {
  final int nurseryId;
  const _CloseNurserySection({required this.nurseryId});

  @override
  ConsumerState<_CloseNurserySection> createState() =>
      _CloseNurserySectionState();
}

class _CloseNurserySectionState extends ConsumerState<_CloseNurserySection> {
  bool _deleting = false;

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Nursery'),
        content: const Text(
          'This will permanently close your nursery. All active operations must be completed first.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red600),
            child: const Text('Close Nursery'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(nurseryRepositoryProvider).deleteNursery(widget.nurseryId);
      await ref.read(sessionProvider.notifier).bootstrap();
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final code = (body is Map && body['error'] is Map)
          ? (body['error'] as Map)['code'] as String?
          : null;
      final message = code == 'nursery_has_active_records'
          ? 'Complete or cancel all active orders and quotations before closing the nursery.'
          : 'Could not close nursery. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not close nursery. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Danger Zone',
            style: AppTypography.h4.copyWith(color: AppColors.red600)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.red600.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.red600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _deleting
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.red600,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded,
                      color: AppColors.red600, size: 20),
            ),
            title: Text(
              'Close Nursery',
              style: AppTypography.body.copyWith(color: AppColors.red600),
            ),
            subtitle: Text(
              'Permanently closes your nursery account',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            onTap: _deleting ? null : _confirmClose,
          ),
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  final List<Widget> children;

  const _FormPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
