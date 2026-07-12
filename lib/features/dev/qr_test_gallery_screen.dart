import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/universal_qr_screen.dart';

// Debug-only screen that shows all QR test scenarios as scannable QrImageView
// cards. Accessed via Profile → Dev Tools (only visible in debug builds).
// Tap "Scan" on any card to open UniversalQrScreen with that code
// pre-loaded via gallery simulation, or just point a second device at the screen.
class QrTestGalleryScreen extends StatelessWidget {
  const QrTestGalleryScreen({super.key});

  // Test scenarios: (label, content, expected outcome, category)
  static const _scenarios = [
    _Scenario(
      id: '01',
      label: 'Valid Manager Invite (PENDING)',
      category: 'INVITE',
      hint: '→ Invite sheet, Accept button visible, manager role granted on accept',
      content: '7c8fbc7d-3e1f-4456-bf2c-f57679d67399',
    ),
    _Scenario(
      id: '02',
      label: 'Valid Customer Invite (PENDING)',
      category: 'INVITE',
      hint: '→ Invite sheet, Accept button, customer linked to nursery',
      content: 'd2a3aa76-8c8b-40d6-ac9c-03ea3b1dcf2b',
    ),
    _Scenario(
      id: '03',
      label: 'Already-Used Invite',
      category: 'INVITE',
      hint: '→ Sheet with "already used or expired" state, no Accept button',
      content: '8d81d921-0223-430d-bb31-128a992778f7',
    ),
    _Scenario(
      id: '04',
      label: 'Non-existent UUID',
      category: 'INVITE',
      hint: '→ Error card "may have expired or already been used"',
      content: '00000000-0000-0000-0000-000000000000',
    ),
    _Scenario(
      id: '05',
      label: 'Valid Trip Code (PENDING)',
      category: 'TRIP',
      hint: 'Driver → TripPreviewScreen → Accept → ACCEPTED\nOwner/Manager → "Only drivers can join trips"',
      content: 'DSP-20260712-0005',
    ),
    _Scenario(
      id: '06',
      label: 'Already-Accepted Trip Code',
      category: 'TRIP',
      hint: 'Driver → TripPreviewScreen → dispatch already ACCEPTED (driver rejoins own trip)',
      content: 'DSP-20260712-0004',
    ),
    _Scenario(
      id: '07',
      label: 'Non-existent Dispatch Code',
      category: 'TRIP',
      hint: '→ TripPreviewScreen → 404 "Trip not found"',
      content: 'DSP-00000000-9999',
    ),
    _Scenario(
      id: '08',
      label: 'Valid Verify Token (hex)',
      category: 'VERIFY',
      hint: '→ VERIFIED sheet: quotation code, status, issued/expiry dates',
      content: 'e0f26dbd5743d2582b97c964d7847a9f72c73179654f3c869a83add7d43ba0f9',
    ),
    _Scenario(
      id: '09',
      label: 'Invalid Verify Token (random hex)',
      category: 'VERIFY',
      hint: '→ INVALID sheet — token not found in DB',
      content: 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
    ),
    _Scenario(
      id: '10',
      label: 'Verify Token (alternate — same token)',
      category: 'VERIFY',
      hint: '→ Same as 08, confirms 64-hex token is recognised regardless of source',
      content: 'e0f26dbd5743d2582b97c964d7847a9f72c73179654f3c869a83add7d43ba0f9',
    ),
    _Scenario(
      id: '11',
      label: 'Foreign / Non-GreenRoot QR',
      category: 'UNKNOWN',
      hint: '→ "Not a GreenRoot QR" screen with type list',
      content: 'https://amazon.com/product/12345',
    ),
    _Scenario(
      id: '12',
      label: 'Wrong-Target Invite (sent to different person)',
      category: 'INVITE',
      hint: 'Buyer scans invite addressed to 9800000099 → "This invite was sent to someone else"',
      content: 'a433ea4d-bbd3-4e34-9a8c-c801df22d5b8',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode, 'QrTestGalleryScreen must only be mounted in debug mode');

    final usable = _scenarios.where((s) => s.content.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('QR Test Gallery'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const UniversalQrScreen(),
              ),
            ),
            child: const Text('Open Scanner'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoBanner(count: usable.length, total: _scenarios.length),
          const SizedBox(height: 16),
          ...usable.map((s) => _ScenarioCard(scenario: s)),
        ],
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final int count;
  final int total;
  const _InfoBanner({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryMain.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug QR Test Gallery ($count/$total scenarios with content)',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live codes from dev API (2026-07-12). '
            'Tap "Scan" to open the scanner. '
            'Tap the code chip to copy it to clipboard for manual entry.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Scenario card ─────────────────────────────────────────────────────────────

class _ScenarioCard extends StatelessWidget {
  final _Scenario scenario;
  const _ScenarioCard({super.key, required this.scenario});

  Color get _categoryColor => switch (scenario.category) {
        'INVITE'  => AppColors.blue600,
        'TRIP'    => AppColors.primaryMain,
        'VERIFY'  => const Color(0xFF7C3AED),
        _         => AppColors.red500,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _categoryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    scenario.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _categoryColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${scenario.id}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(scenario.label, style: AppTypography.h4),
            const SizedBox(height: 4),
            Text(
              scenario.hint,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // QR code + actions row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QR image
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: scenario.content,
                    version: QrVersions.auto,
                    size: 120,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _categoryColor.withAlpha(220),
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _categoryColor.withAlpha(220),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Code chip
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: scenario.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            scenario.content.length > 40
                                ? '${scenario.content.substring(0, 40)}…'
                                : scenario.content,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Open scanner button
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const UniversalQrScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('Open Scanner'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _categoryColor,
                          minimumSize: const Size(double.infinity, 38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Copy hint
                      Text(
                        'Copy code above → paste in "Enter Trip Code" field, or scan via gallery',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _Scenario {
  final String id;
  final String label;
  final String category;
  final String hint;
  final String content;
  final bool isPlaceholder;

  const _Scenario({
    required this.id,
    required this.label,
    required this.category,
    required this.hint,
    required this.content,
    this.isPlaceholder = false,
  });
}
