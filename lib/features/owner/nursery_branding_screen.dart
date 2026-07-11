import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/nursery_branding_badge.dart';
import '../../core/services/storage_service.dart';
import '../../features/nurseries/nurseries.dart';

// ── Brand palette (must match server-side validBrandColors) ──────────────────

const _brandColors = [
  '#2E7D32',
  '#388E3C',
  '#43A047',
  '#66BB6A',
  '#F9A825',
  '#EF6C00',
  '#5D4037',
  '#1565C0',
  '#6A1B9A',
  '#37474F',
];

const _brandIconDefs = [
  ('leaf',     'Leaf',     Icons.eco_rounded),
  ('tree',     'Tree',     Icons.park_rounded),
  ('flower',   'Flower',   Icons.local_florist_rounded),
  ('seedling', 'Seedling', Icons.grass_rounded),
  ('pot',      'Pot',      Icons.yard_rounded),
  ('cactus',   'Cactus',   Icons.spa_rounded),
  ('palm',     'Palm',     Icons.filter_vintage_rounded),
  ('bonsai',   'Bonsai',   Icons.nature_rounded),
  ('herb',     'Herb',     Icons.energy_savings_leaf_rounded),
  ('lotus',    'Lotus',    Icons.wb_sunny_rounded),
];

// ── Branding state ────────────────────────────────────────────────────────────

class _BS {
  final String? logoUrl;
  final String? brandIconKey;
  final String? brandColor;
  final bool saving;
  final String? error;

  const _BS({
    this.logoUrl,
    this.brandIconKey,
    this.brandColor,
    this.saving = false,
    this.error,
  });

  _BS with_({
    String? logoUrl,
    bool clearLogo = false,
    String? brandIconKey,
    bool clearIcon = false,
    String? brandColor,
    bool? saving,
    String? error,
    bool clearError = false,
  }) {
    return _BS(
      logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
      brandIconKey: clearIcon ? null : (brandIconKey ?? this.brandIconKey),
      brandColor: brandColor ?? this.brandColor,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NurseryBrandingScreen extends ConsumerWidget {
  final int nurseryId;

  const NurseryBrandingScreen({super.key, required this.nurseryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nurseryDetailProvider(nurseryId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nursery Branding'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primaryMain)),
        error: (err, _) => Center(
          child: Text(err.toString(), style: AppTypography.body),
        ),
        data: (nursery) => _BrandingBody(nursery: nursery),
      ),
    );
  }
}

// ── Body (StatefulWidget so we can manage local branding state) ───────────────

class _BrandingBody extends ConsumerStatefulWidget {
  final Nursery nursery;
  const _BrandingBody({required this.nursery});

  @override
  ConsumerState<_BrandingBody> createState() => _BrandingBodyState();
}

class _BrandingBodyState extends ConsumerState<_BrandingBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late _BS _bs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _bs = _BS(
      logoUrl: widget.nursery.logoUrl,
      brandIconKey: widget.nursery.brandIconKey,
      brandColor: widget.nursery.brandColor ?? _brandColors.first,
    );
    if (_bs.logoUrl == null || _bs.logoUrl!.isEmpty) {
      _tabs.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _bs = _bs.with_(saving: true, clearError: true));

    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final fileName =
          'nursery-${widget.nursery.id}-${DateTime.now().millisecondsSinceEpoch}.$ext';

      final url = await ref
          .read(storageServiceProvider)
          .uploadNurseryLogo(bytes, fileName, contentType);

      if (!mounted) return;
      setState(() => _bs = _bs.with_(
            logoUrl: url,
            clearIcon: true,
            saving: false,
          ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _bs = _bs.with_(
            saving: false,
            error: 'Upload failed. Please try again.',
          ));
    }
  }

  Future<void> _save() async {
    setState(() => _bs = _bs.with_(saving: true, clearError: true));
    try {
      await ref.read(nurseryRepositoryProvider).updateBranding(
            widget.nursery.id,
            logoUrl: _bs.logoUrl,
            brandIconKey: _bs.brandIconKey,
            brandColor: _bs.brandColor,
          );
      if (!mounted) return;
      // Invalidate cache so parent screens reflect new branding
      ref.invalidate(nurseryDetailProvider(widget.nursery.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branding saved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bs = _bs.with_(
            saving: false,
            error: 'Save failed. Please try again.',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PreviewStrip(bs: _bs, nurseryName: widget.nursery.name),
        if (_bs.error != null)
          Container(
            width: double.infinity,
            color: AppColors.errorBg,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Text(_bs.error!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.errorText)),
          ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
          tabs: const [
            Tab(text: 'Upload Logo'),
            Tab(text: 'Pick Icon'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _UploadTab(
                currentLogoUrl: _bs.logoUrl,
                saving: _bs.saving,
                onPick: _pickImage,
                onRemove: () =>
                    setState(() => _bs = _bs.with_(clearLogo: true)),
              ),
              _IconTab(
                selectedKey: _bs.brandIconKey,
                selectedColor: _bs.brandColor ?? _brandColors.first,
                onIconSelected: (key) => setState(() => _bs = _bs.with_(
                      brandIconKey: key,
                      clearLogo: true,
                    )),
                onColorSelected: (color) =>
                    setState(() => _bs = _bs.with_(brandColor: color)),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: AppButton(
              label: 'Save Branding',
              onPressed: _bs.saving ? null : _save,
              isLoading: _bs.saving,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Preview strip ─────────────────────────────────────────────────────────────

class _PreviewStrip extends StatelessWidget {
  final _BS bs;
  final String nurseryName;

  const _PreviewStrip({required this.bs, required this.nurseryName});

  @override
  Widget build(BuildContext context) {
    final subtitle = bs.logoUrl != null
        ? 'Custom logo uploaded'
        : bs.brandIconKey != null
            ? '${_iconLabel(bs.brandIconKey!)} icon${bs.brandColor != null ? ' · color set' : ''}'
            : 'No branding set yet';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.x2l),
      child: Row(
        children: [
          NurseryBrandingBadge(
            logoUrl: bs.logoUrl,
            brandIconKey: bs.brandIconKey,
            brandColor: bs.brandColor,
            nurseryName: nurseryName,
            size: 64,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nurseryName, style: AppTypography.h3),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _iconLabel(String key) =>
      _brandIconDefs
          .where((e) => e.$1 == key)
          .map((e) => e.$2)
          .firstOrNull ??
      key;
}

// ── Upload tab ────────────────────────────────────────────────────────────────

class _UploadTab extends StatelessWidget {
  final String? currentLogoUrl;
  final bool saving;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _UploadTab({
    required this.currentLogoUrl,
    required this.saving,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: GestureDetector(
            onTap: saving ? null : onPick,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.forest100,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                    color: AppColors.primaryMain.withAlpha(76), width: 2),
              ),
              child: currentLogoUrl != null
                  ? ClipRRect(
                      borderRadius: AppRadius.cardRadius,
                      child: Image.network(
                        currentLogoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _PlaceholderLogo(),
                      ),
                    )
                  : const _PlaceholderLogo(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),
        AppButton.outlined(
          label: saving ? 'Uploading…' : 'Choose from Gallery',
          onPressed: saving ? null : onPick,
        ),
        if (currentLogoUrl != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton.danger(
            label: 'Remove Logo',
            onPressed: onRemove,
          ),
        ],
        const SizedBox(height: AppSpacing.x2l),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.infoText),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Square images work best (at least 200×200 px). '
                  'Your logo appears on quotations and order documents.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.infoText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceholderLogo extends StatelessWidget {
  const _PlaceholderLogo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_rounded,
            size: 40, color: AppColors.primaryMain),
        SizedBox(height: AppSpacing.sm),
        Text('Tap to upload', style: AppTypography.caption),
      ],
    );
  }
}

// ── Icon + color tab ──────────────────────────────────────────────────────────

class _IconTab extends StatelessWidget {
  final String? selectedKey;
  final String selectedColor;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<String> onColorSelected;

  const _IconTab({
    required this.selectedKey,
    required this.selectedColor,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Text('Choose an icon', style: AppTypography.label),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          children: _brandIconDefs.map((icon) {
            final isSelected = selectedKey == icon.$1;
            final bg = NurseryBrandingBadge.parseColor(selectedColor) ??
                AppColors.primaryMain;
            final fgLum = bg.computeLuminance() > 0.4;
            return GestureDetector(
              onTap: () => onIconSelected(icon.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected ? bg : AppColors.forest100,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(
                    color: isSelected ? bg : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon.$3,
                      size: 28,
                      color: isSelected
                          ? (fgLum ? Colors.black87 : Colors.white)
                          : AppColors.primaryMain,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      icon.$2,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: isSelected
                            ? (fgLum ? Colors.black87 : Colors.white)
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.x2l),
        Text('Choose a color', style: AppTypography.label),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: _brandColors.map((hex) {
            final color =
                NurseryBrandingBadge.parseColor(hex) ?? AppColors.primaryMain;
            final isSelected = selectedColor == hex;
            return GestureDetector(
              onTap: () => onColorSelected(hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.textPrimary
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: color.withAlpha(102),
                              blurRadius: 8,
                              spreadRadius: 2),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: color.computeLuminance() > 0.4
                            ? Colors.black87
                            : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.x3l),
      ],
    );
  }
}
