import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/auth/presentation/providers/session_provider.dart';
import '../../features/drivers/trip_preview_screen.dart';

// ── QR type taxonomy ──────────────────────────────────────────────────────────
//
// Every GreenRoot QR maps to exactly one of these types, determined by content:
//
//   invite           → UUID  (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
//   quotationVerify  → 64-char hex token OR URL containing /verify/<64-hex>
//   tripCode         → anything else (alphanumeric trip code from API)
//   unknown          → unrecognised content
//
// RBAC gating:
//   invite          → any registered user; server enforces role conflicts
//   quotationVerify → any user; public endpoint, no auth required
//   tripCode        → drivers only; non-drivers see role-gate screen
//   unknown         → error screen
//
enum _QrType { invite, quotationVerify, tripCode, unknown }

class _QrDetection {
  final _QrType type;
  final String? verifyToken; // only set when type == quotationVerify

  const _QrDetection({required this.type, this.verifyToken});
}

// What the result sheet signals back to the scanner
enum _SheetResult { resume, goToTrip, close }

// ── Detection logic ───────────────────────────────────────────────────────────

final _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _hexTokenRe = RegExp(r'^[0-9a-f]{64}$', caseSensitive: false);
final _verifyUrlRe = RegExp(r'/verify/([0-9a-f]{64})', caseSensitive: false);

_QrDetection _detect(String raw) {
  final v = raw.trim();
  // 1. UUID → invite
  if (_uuidRe.hasMatch(v)) return const _QrDetection(type: _QrType.invite);
  // 2. 64-hex raw token → quotation verify
  if (_hexTokenRe.hasMatch(v)) {
    return _QrDetection(type: _QrType.quotationVerify, verifyToken: v.toLowerCase());
  }
  // 3. URL containing /verify/<token> → quotation verify
  final m = _verifyUrlRe.firstMatch(v);
  if (m != null) {
    return _QrDetection(type: _QrType.quotationVerify, verifyToken: m.group(1)!.toLowerCase());
  }
  // 4. Non-empty string → trip code (driver gating in UI)
  if (v.isNotEmpty) return const _QrDetection(type: _QrType.tripCode);
  return const _QrDetection(type: _QrType.unknown);
}

// ── Invite error mapping ──────────────────────────────────────────────────────

String _inviteErrorMessage(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('conflicting_role')) {
    return 'Role conflict: nursery owners cannot join as managers, and managers cannot become nursery owners.';
  }
  if (s.contains('already_member')) {
    return 'You are already a manager at another nursery. Leave your current nursery first, then accept this invite.';
  }
  if (s.contains('forbidden')) {
    return "You don't have permission to accept this invite.";
  }
  if (s.contains('not_found') || s.contains('404')) {
    return 'This invite no longer exists. It may have been cancelled.';
  }
  return 'Failed to accept invite. Please try again.';
}

// ── Scanner screen ────────────────────────────────────────────────────────────

class UniversalQrScreen extends ConsumerStatefulWidget {
  const UniversalQrScreen({super.key});

  @override
  ConsumerState<UniversalQrScreen> createState() => _UniversalQrScreenState();
}

class _UniversalQrScreenState extends ConsumerState<UniversalQrScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _ctrl;
  bool _torchOn = false;
  bool _detected = false;

  late final AnimationController _lineCtrl;
  late final Animation<double> _lineAnim;
  Timer? _autoTorchTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut),
    );
    _autoTorchTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!_detected && mounted && !_torchOn) {
        _ctrl.toggleTorch();
        setState(() => _torchOn = true);
      }
    });
  }

  @override
  void dispose() {
    _autoTorchTimer?.cancel();
    _lineCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _processValue(value.trim());
  }

  Future<void> _processValue(String raw) async {
    if (_detected) return;
    _detected = true;
    await _ctrl.stop();
    HapticFeedback.mediumImpact();
    if (!mounted) return;

    final detection = _detect(raw);
    final isDriver = ref.read(sessionProvider).capabilities.hasDriverProfile;

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => _QrResultSheet(
        rawValue: raw,
        detection: detection,
        isDriver: isDriver,
        ref: ref,
      ),
    );

    if (!mounted) return;

    switch (result ?? _SheetResult.resume) {
      case _SheetResult.resume:
        setState(() => _detected = false);
        await _ctrl.start();
      case _SheetResult.goToTrip:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripPreviewScreen(code: raw)),
        );
        if (mounted) Navigator.of(context).pop();
      case _SheetResult.close:
        Navigator.of(context).pop();
    }
  }

  Future<void> _toggleTorch() async {
    await _ctrl.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final result = await _ctrl.analyzeImage(file.path);
    if (!mounted) return;

    final value = result?.barcodes.firstOrNull?.rawValue;
    if (value != null && value.isNotEmpty) {
      _processValue(value.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code found in the selected image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Camera unavailable\n${error.errorCode.name}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          _QrScanFrame(lineAnimation: _lineAnim),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                  ),
                  Expanded(
                    child: Text(
                      'Scan QR Code',
                      style: AppTypography.h3.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _torchOn ? Colors.yellow : Colors.white,
                      size: 26,
                    ),
                    tooltip: _torchOn ? 'Turn off flash' : 'Turn on flash',
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      'Point your camera at a QR code',
                      style: AppTypography.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Choose from Gallery',
                              style: AppTypography.button.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result sheet ──────────────────────────────────────────────────────────────

class _QrResultSheet extends ConsumerStatefulWidget {
  final String rawValue;
  final _QrDetection detection;
  final bool isDriver;
  final WidgetRef ref;

  const _QrResultSheet({
    required this.rawValue,
    required this.detection,
    required this.isDriver,
    required this.ref,
  });

  @override
  ConsumerState<_QrResultSheet> createState() => _QrResultSheetState();
}

class _QrResultSheetState extends ConsumerState<_QrResultSheet> {
  _InviteData? _invite;
  _VerifyData? _verify;
  bool _loading = false;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    switch (widget.detection.type) {
      case _QrType.invite:
        _loadInvite();
      case _QrType.quotationVerify:
        _loadVerify();
      case _QrType.tripCode:
      case _QrType.unknown:
        break;
    }
  }

  // ── Data loaders ────────────────────────────────────────────────────────────

  Future<void> _loadInvite() async {
    setState(() { _loading = true; _error = null; });
    try {
      final body = await ApiClient.instance.get<Map<String, dynamic>>(ApiConstants.inviteByUUID(widget.rawValue));
      final inv = (body['invite'] is Map)
          ? body['invite'] as Map<String, dynamic>
          : body;
      setState(() {
        _loading = false;
        _invite = _InviteData(
          uuid: (inv['invite_uuid'] ?? widget.rawValue) as String,
          inviteType: (inv['invite_type'] ?? '') as String,
          inviterName: inv['inviter_name'] as String?,
          nurseryName: inv['nursery_name'] as String?,
          isPending: ((inv['status'] as String?) ?? '').toUpperCase() == 'PENDING',
        );
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load invite. It may have expired or already been used.';
      });
    }
  }

  Future<void> _loadVerify() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = widget.detection.verifyToken!;
      final data = await ApiClient.instance.get<Map<String, dynamic>>(ApiConstants.publicVerify(token));
      setState(() {
        _loading = false;
        _verify = _VerifyData(
          authenticity: (data['authenticity'] ?? 'INVALID') as String,
          quotationCode: (data['quotation_code'] ?? '') as String,
          quotationStatus: (data['quotation_status'] ?? 'UNKNOWN') as String,
          documentIntegrity: (data['document_integrity'] ?? 'UNVERIFIED') as String,
          issuedAt: data['issued_at'] != null
              ? DateTime.tryParse(data['issued_at'] as String)
              : null,
          validUntil: data['valid_until'] != null
              ? DateTime.tryParse(data['valid_until'] as String)
              : null,
        );
      });
    } catch (_) {
      setState(() { _loading = false; _error = 'Could not verify this document.'; });
    }
  }

  Future<void> _acceptInvite() async {
    final invite = _invite;
    if (invite == null) return;
    setState(() => _accepting = true);
    try {
      await ApiClient.instance.post(ApiConstants.acceptInvite(invite.uuid));
      await widget.ref.read(sessionProvider.notifier).bootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite accepted! Your access has been updated.'),
          backgroundColor: AppColors.primaryMain,
        ),
      );
      Navigator.of(context).pop(_SheetResult.close);
    } catch (e) {
      setState(() => _accepting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_inviteErrorMessage(e)),
            backgroundColor: AppColors.red500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Shell ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              switch (widget.detection.type) {
                _QrType.invite         => _buildInviteContent(),
                _QrType.quotationVerify => _buildVerifyContent(),
                _QrType.tripCode       => widget.isDriver
                    ? _buildTripContent()
                    : _buildDriverOnlyContent(),
                _QrType.unknown        => _buildUnknownContent(),
              },
            ],
          ),
        ),
      ),
    );
  }

  // ── Content builders ────────────────────────────────────────────────────────

  Widget _buildInviteContent() {
    if (_loading) return _loadingSpinner();
    if (_error != null) {
      return _ErrorCard(message: _error!, onRetry: () => Navigator.of(context).pop(_SheetResult.resume));
    }

    final invite = _invite;
    if (invite == null) return const SizedBox.shrink();

    final typeLabel = switch (invite.inviteType) {
      'CUSTOMER_INVITE'           => 'Customer',
      'MANAGER_INVITE'            => 'Manager (Gumastha)',
      'DRIVER_INVITE'             => 'Driver',
      'NURSERY_ONBOARDING_INVITE' => 'Nursery Owner',
      'TRIP_SHARE_INVITE'         => 'Trip Assignment',
      _ => invite.inviteType.replaceAll('_', ' '),
    };

    final subtitle = invite.nurseryName != null
        ? 'Invited by ${invite.inviterName ?? 'GreenRoot'} · ${invite.nurseryName}'
        : 'Invited by ${invite.inviterName ?? 'GreenRoot'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(
          icon: Icons.mail_outline_rounded,
          iconColor: AppColors.primaryMain,
          iconBg: AppColors.forest100,
          title: 'You have an invite',
          subtitle: subtitle,
        ),
        const SizedBox(height: 16),
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Joining as',
              value: typeLabel,
              valueColor: AppColors.primaryMain,
            ),
          ],
        ),
        if (!invite.isPending) ...[
          const SizedBox(height: 12),
          _WarningBanner('This invite has already been used or has expired.'),
        ],
        const SizedBox(height: 24),
        if (invite.isPending)
          FilledButton(
            onPressed: _accepting ? null : _acceptInvite,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _accepting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Accept Invite', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        if (invite.isPending) const SizedBox(height: 10),
        _scanAnotherButton(),
      ],
    );
  }

  Widget _buildTripContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.primaryMain,
          iconBg: AppColors.forest100,
          title: 'Trip QR Code',
          subtitle: widget.rawValue,
          subtitleClip: true,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_SheetResult.goToTrip),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('View Trip Details'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        _scanAnotherButton(),
      ],
    );
  }

  Widget _buildDriverOnlyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.amber600,
          iconBg: const Color(0xFFFFF3E0),
          title: 'Trip QR Code',
          subtitle: 'Only drivers can join trips',
        ),
        const SizedBox(height: 16),
        _WarningBanner(
          'This QR code assigns a driver to a trip. '
          'Your account does not have a driver profile, so you cannot join this trip.',
        ),
        const SizedBox(height: 24),
        _scanAnotherButton(),
      ],
    );
  }

  Widget _buildVerifyContent() {
    if (_loading) return _loadingSpinner();
    if (_error != null) {
      return _ErrorCard(message: _error!, onRetry: () => Navigator.of(context).pop(_SheetResult.resume));
    }

    final v = _verify;
    if (v == null) return const SizedBox.shrink();

    final isVerified = v.authenticity == 'VERIFIED';
    final accent = isVerified ? AppColors.primaryMain : AppColors.red500;
    final lightBg = isVerified ? AppColors.forest100 : AppColors.red500.withAlpha(26);
    final statusLabel = switch (v.quotationStatus) {
      'ACTIVE'    => 'Active — Offer Open',
      'EXPIRED'   => 'Expired',
      'CONVERTED' => 'Converted to Order',
      'CANCELLED' => 'Cancelled',
      _           => v.quotationStatus,
    };
    final fmt = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(
          icon: isVerified ? Icons.verified_outlined : Icons.dangerous_outlined,
          iconColor: accent,
          iconBg: lightBg,
          title: isVerified ? 'Quotation Verified' : 'Invalid QR Code',
          subtitle: isVerified
              ? 'This document is authentic and issued by GreenRoot'
              : 'This QR code is not recognised or has been revoked',
        ),
        if (isVerified && v.quotationCode.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
            children: [
              _InfoRow(icon: Icons.receipt_long_outlined, label: 'Quotation ID', value: v.quotationCode),
              _InfoRow(
                icon: Icons.circle,
                iconSize: 8,
                label: 'Offer Status',
                value: statusLabel,
                valueColor: v.quotationStatus == 'ACTIVE' ? AppColors.primaryMain : null,
              ),
              if (v.issuedAt != null)
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Issued On',
                  value: fmt.format(v.issuedAt!.toLocal()),
                ),
              if (v.validUntil != null)
                _InfoRow(
                  icon: Icons.event_outlined,
                  label: 'Valid Until',
                  value: fmt.format(v.validUntil!.toLocal()),
                ),
              _InfoRow(
                icon: v.documentIntegrity == 'UNMODIFIED'
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_outlined,
                label: 'Document Integrity',
                value: v.documentIntegrity == 'UNMODIFIED' ? 'Unmodified ✓' : 'Unverified',
                valueColor: v.documentIntegrity == 'UNMODIFIED' ? AppColors.primaryMain : null,
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(_SheetResult.resume),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildUnknownContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(
          icon: Icons.qr_code_scanner_rounded,
          iconColor: AppColors.red500,
          iconBg: AppColors.red500.withAlpha(26),
          title: 'Not a GreenRoot QR',
          subtitle: 'This QR code was not issued by GreenRoot and cannot be processed here.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GreenRoot QR codes are used for:',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              for (final item in const [
                '• Invitations (customer, manager, driver)',
                '• Trip assignments for drivers',
                '• Quotation document verification',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(item,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _scanAnotherButton(),
      ],
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Widget _loadingSpinner() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryMain)),
      );

  Widget _scanAnotherButton() => OutlinedButton(
        onPressed: () => Navigator.of(context).pop(_SheetResult.resume),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Scan another code'),
      );
}

// ── Shared UI components ──────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool subtitleClip;

  const _HeaderRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.subtitleClip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, size: 26, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h4),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                maxLines: subtitleClip ? 1 : 2,
                overflow: subtitleClip ? TextOverflow.ellipsis : TextOverflow.visible,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryMain.withAlpha(51)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) ...[
              const SizedBox(height: 4),
              Divider(height: 1, color: AppColors.border.withAlpha(120)),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    this.iconSize = 16,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.amber600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTypography.caption.copyWith(color: AppColors.amber600)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.red500, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _InviteData {
  final String uuid;
  final String inviteType;
  final String? inviterName;
  final String? nurseryName;
  final bool isPending;

  const _InviteData({
    required this.uuid,
    required this.inviteType,
    this.inviterName,
    this.nurseryName,
    required this.isPending,
  });
}

class _VerifyData {
  final String authenticity;
  final String quotationCode;
  final String quotationStatus;
  final String documentIntegrity;
  final DateTime? issuedAt;
  final DateTime? validUntil;

  const _VerifyData({
    required this.authenticity,
    required this.quotationCode,
    required this.quotationStatus,
    required this.documentIntegrity,
    this.issuedAt,
    this.validUntil,
  });
}

// ── Scan frame overlay ────────────────────────────────────────────────────────

class _QrScanFrame extends StatelessWidget {
  final Animation<double> lineAnimation;
  const _QrScanFrame({required this.lineAnimation});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final cutout = size.width * 0.72;
      final left = (size.width - cutout) / 2;
      final top = (size.height - cutout) / 2 - 40;

      return Stack(
        children: [
          CustomPaint(
            size: size,
            painter: _OverlayPainter(cutoutRect: Rect.fromLTWH(left, top, cutout, cutout)),
          ),
          Positioned(left: left, top: top, child: _ScanCorners(size: cutout)),
          Positioned(
            left: left + 4, top: top + 4,
            child: AnimatedBuilder(
              animation: lineAnimation,
              builder: (_, __) => SizedBox(
                width: cutout - 8, height: cutout - 8,
                child: Align(
                  alignment: Alignment(0, (lineAnimation.value * 2) - 1),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primaryMain.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;
  const _OverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => cutoutRect != old.cutoutRect;
}

class _ScanCorners extends StatelessWidget {
  final double size;
  const _ScanCorners({required this.size});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: const CustomPaint(painter: _CornerPainter()));
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 24.0, thick = 3.5, r = 14.0;
    final paint = Paint()
      ..color = AppColors.primaryMain
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;

    canvas
      ..drawPath(Path()
        ..moveTo(r, 0)..lineTo(arm, 0)
        ..moveTo(0, r)..lineTo(0, arm)
        ..moveTo(0, r)..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r), clockwise: false), paint)
      ..drawPath(Path()
        ..moveTo(w - arm, 0)..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r), clockwise: true)
        ..lineTo(w, arm), paint)
      ..drawPath(Path()
        ..moveTo(0, h - arm)..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h), radius: const Radius.circular(r), clockwise: true)
        ..lineTo(arm, h), paint)
      ..drawPath(Path()
        ..moveTo(w - arm, h)..lineTo(w - r, h)
        ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r), clockwise: false)
        ..lineTo(w, h - arm), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
