import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/auth/presentation/providers/session_provider.dart';
import '../../features/drivers/trip_preview_screen.dart';

// What the result sheet signals back to the scanner
enum _SheetResult { resume, goToTrip, close }

/// Universal QR scanner shown via the bottom-nav centre button.
///
/// Route logic (client-side):
///   UUID  → invite preview card + in-sheet accept
///   non-UUID + driver capability → trip preview card → TripPreviewScreen
///   non-UUID + no driver → "Driver-only QR" explanation
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

  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

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

  Future<void> _processValue(String value) async {
    if (_detected) return;
    _detected = true;
    await _ctrl.stop();
    HapticFeedback.mediumImpact();
    if (!mounted) return;

    final caps = ref.read(sessionProvider).capabilities;
    final isUuid = _uuidRe.hasMatch(value);

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => _QrResultSheet(
        rawValue: value,
        isUuid: isUuid,
        isDriver: caps.hasDriverProfile,
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
          MaterialPageRoute(builder: (_) => TripPreviewScreen(code: value)),
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
                  const Icon(Icons.camera_alt_outlined,
                      color: Colors.white54, size: 64,),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 26,),
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
                      _torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
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
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      'Point your camera at a QR code',
                      style: AppTypography.body
                          .copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12,),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                color: Colors.white, size: 20,),
                            const SizedBox(width: 8),
                            Text(
                              'Choose from Gallery',
                              style: AppTypography.button
                                  .copyWith(color: Colors.white),
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

// ── Result sheet ───────────────────────────────────────────────────────────────

class _QrResultSheet extends ConsumerStatefulWidget {
  final String rawValue;
  final bool isUuid;
  final bool isDriver;
  final WidgetRef ref;

  const _QrResultSheet({
    required this.rawValue,
    required this.isUuid,
    required this.isDriver,
    required this.ref,
  });

  @override
  ConsumerState<_QrResultSheet> createState() => _QrResultSheetState();
}

class _QrResultSheetState extends ConsumerState<_QrResultSheet> {
  _InviteData? _invite;
  bool _loading = false;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isUuid) _loadInvite();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiClient.instance
          .get(ApiConstants.inviteByUUID(widget.rawValue));
      final data = resp.data;
      final inv = (data is Map && data['invite'] is Map)
          ? data['invite'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      setState(() {
        _loading = false;
        _invite = _InviteData(
          uuid: inv['invite_uuid'] as String? ?? widget.rawValue,
          inviteType: inv['invite_type'] as String? ?? '',
          inviterName: inv['inviter_name'] as String?,
          isPending:
              (inv['status'] as String?)?.toUpperCase() == 'PENDING',
        );
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error =
            'Could not load invite. It may have expired or already been used.';
      });
    }
  }

  Future<void> _acceptInvite() async {
    final invite = _invite;
    if (invite == null) return;
    setState(() => _accepting = true);
    try {
      await ApiClient.instance
          .post(ApiConstants.acceptInvite(invite.uuid));
      await widget.ref.read(sessionProvider.notifier).bootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite accepted! Your access has been updated.'),
          backgroundColor: AppColors.primaryMain,
        ),
      );
      Navigator.of(context).pop(_SheetResult.close);
    } catch (_) {
      setState(() => _accepting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to accept invite. Please try again.'),),
        );
      }
    }
  }

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
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (widget.isUuid)
                _buildInviteContent()
              else if (widget.isDriver)
                _buildTripContent()
              else
                _buildUnknownContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child:
                CircularProgressIndicator(color: AppColors.primaryMain),),
      );
    }

    if (_error != null) {
      return _ErrorCard(
        message: _error!,
        onRetry: () => Navigator.of(context).pop(_SheetResult.resume),
      );
    }

    final invite = _invite;
    if (invite == null) return const SizedBox.shrink();

    final typeLabel = switch (invite.inviteType) {
      'CUSTOMER_INVITE' => 'Customer',
      'MANAGER_INVITE' => 'Manager',
      'DRIVER_INVITE' => 'Driver',
      'NURSERY_ONBOARDING_INVITE' => 'Nursery Owner',
      _ => invite.inviteType.replaceAll('_', ' '),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_outline_rounded,
                  size: 26, color: AppColors.primaryMain,),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite from ${invite.inviterName ?? 'GreenRoot'}',
                    style: AppTypography.h4,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You are being invited to GreenRoot',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.forest50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primaryMain.withAlpha(51),),
          ),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined,
                  color: AppColors.primaryMain, size: 20,),
              const SizedBox(width: 10),
              Text(
                'Joining as: ',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              Text(
                typeLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (!invite.isPending) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.amber600, size: 18,),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This invite has already been used or has expired.',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.amber600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (invite.isPending)
          FilledButton(
            onPressed: _accepting ? null : _acceptInvite,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),),
            ),
            child: _accepting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2,),
                  )
                : const Text(
                    'Accept Invite',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,),
                  ),
          ),
        if (invite.isPending) const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(_SheetResult.resume),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),),
          ),
          child: const Text('Scan another code'),
        ),
      ],
    );
  }

  Widget _buildTripContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  size: 26, color: AppColors.primaryMain,),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trip QR Code', style: AppTypography.h4),
                  const SizedBox(height: 2),
                  Text(
                    widget.rawValue,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(_SheetResult.goToTrip),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('View Trip Details'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(_SheetResult.resume),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),),
          ),
          child: const Text('Scan another code'),
        ),
      ],
    );
  }

  Widget _buildUnknownContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.red500.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline_rounded,
                  size: 26, color: AppColors.red500,),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unrecognised QR Code',
                      style: AppTypography.h4,),
                  SizedBox(height: 2),
                  Text(
                    'This QR code cannot be used here.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13,),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(_SheetResult.resume),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),),
          ),
          child: const Text('Scan another code'),
        ),
      ],
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
        const Icon(Icons.error_outline_rounded,
            color: AppColors.red500, size: 48,),
        const SizedBox(height: 12),
        Text(
          message,
          style: AppTypography.body
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),),
          ),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

// ── Invite data model ──────────────────────────────────────────────────────────

class _InviteData {
  final String uuid;
  final String inviteType;
  final String? inviterName;
  final bool isPending;

  const _InviteData({
    required this.uuid,
    required this.inviteType,
    this.inviterName,
    required this.isPending,
  });
}

// ── Scan frame overlay ─────────────────────────────────────────────────────────

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
            painter: _OverlayPainter(
              cutoutRect: Rect.fromLTWH(left, top, cutout, cutout),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _ScanCorners(size: cutout),
          ),
          Positioned(
            left: left + 4,
            top: top + 4,
            child: AnimatedBuilder(
              animation: lineAnimation,
              builder: (_, __) {
                return SizedBox(
                  width: cutout - 8,
                  height: cutout - 8,
                  child: Align(
                    alignment:
                        Alignment(0, (lineAnimation.value * 2) - 1),
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
                );
              },
            ),
          ),
        ],
      );
    },);
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;

  const _OverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final rounded = RRect.fromRectAndRadius(
        cutoutRect, const Radius.circular(16),);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(rounded),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      cutoutRect != old.cutoutRect;
}

class _ScanCorners extends StatelessWidget {
  final double size;

  const _ScanCorners({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _CornerPainter()),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 24.0;
    const thick = 3.5;
    const r = 14.0;
    final paint = Paint()
      ..color = AppColors.primaryMain
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.drawPath(
        Path()
          ..moveTo(r, 0)
          ..lineTo(arm, 0)
          ..moveTo(0, r)
          ..lineTo(0, arm)
          ..moveTo(0, r)
          ..arcToPoint(const Offset(r, 0),
              radius: const Radius.circular(r), clockwise: false,),
        paint,);

    canvas.drawPath(
        Path()
          ..moveTo(w - arm, 0)
          ..lineTo(w - r, 0)
          ..arcToPoint(Offset(w, r),
              radius: const Radius.circular(r), clockwise: true,)
          ..lineTo(w, arm),
        paint,);

    canvas.drawPath(
        Path()
          ..moveTo(0, h - arm)
          ..lineTo(0, h - r)
          ..arcToPoint(Offset(r, h),
              radius: const Radius.circular(r), clockwise: true,)
          ..lineTo(arm, h),
        paint,);

    canvas.drawPath(
        Path()
          ..moveTo(w - arm, h)
          ..lineTo(w - r, h)
          ..arcToPoint(Offset(w, h - r),
              radius: const Radius.circular(r), clockwise: false,)
          ..lineTo(w, h - arm),
        paint,);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
