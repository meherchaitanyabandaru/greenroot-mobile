import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_loader.dart';
import 'markdown_view.dart';

enum LegalDocumentType { privacyPolicy, termsOfService }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  /// The Terms & Conditions as published (also in greenroot-infra/docs/legal).
  static const termsAsset = 'assets/legal/terms-and-conditions.md';

  @override
  Widget build(BuildContext context) {
    if (type == LegalDocumentType.termsOfService) return const _TermsScreen();
    final document = _documentFor(type);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(document.title, style: AppTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.title, style: AppTypography.h2),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Last updated: 12 Jul 2026',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  document.summary,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final section in document.sections) ...[
            _LegalSection(section: section),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  static _LegalDocument _documentFor(LegalDocumentType type) => _privacyPolicy;
}

class _TermsScreen extends StatelessWidget {
  const _TermsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Terms & Conditions', style: AppTypography.h3),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(LegalDocumentScreen.termsAsset),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: AppLoader());
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: MarkdownView(source: snap.data!),
            ),
          );
        },
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final _LegalSectionData section;

  const _LegalSection({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),
          for (final item in section.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.primaryMain,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (item != section.items.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _LegalDocument {
  final String title;
  final String summary;
  final List<_LegalSectionData> sections;

  const _LegalDocument({
    required this.title,
    required this.summary,
    required this.sections,
  });
}

class _LegalSectionData {
  final String title;
  final List<String> items;

  const _LegalSectionData({required this.title, required this.items});
}

const _privacyPolicy = _LegalDocument(
  title: 'Privacy Policy',
  summary:
      'GreenRoot protects user, nursery, order, quotation, dispatch, payment, and profile information while keeping business records available for operational and compliance needs.',
  sections: [
    _LegalSectionData(
      title: 'Information We Collect',
      items: [
        'Account details such as name, mobile number, email, profile photo, role, and verification status.',
        'Nursery details such as business name, address, branding, top items, members, quotations, orders, dispatches, and payments.',
        'Operational data such as device, login, audit, notification, and usage information required to run the platform securely.',
      ],
    ),
    _LegalSectionData(
      title: 'How We Use Information',
      items: [
        'To create and manage user accounts, nursery profiles, quotations, orders, dispatches, and delivery workflows.',
        'To enforce role-based access, privacy rules, security controls, audit logs, and business-rule validations.',
        'To send service notifications, improve app reliability, and support customer or nursery requests.',
      ],
    ),
    _LegalSectionData(
      title: 'Data Sharing',
      items: [
        'We show only the information needed for each role and workflow.',
        'Customers, owners, managers, and drivers see different data according to GreenRoot privacy and RBAC rules.',
        'We do not sell personal information.',
      ],
    ),
    _LegalSectionData(
      title: 'Retention & Security',
      items: [
        'Business records may be retained for operational history, legal requirements, audit purposes, and compliance.',
        'Access is protected with authentication, role checks, and audit logging where applicable.',
        'When accounts are deleted or deactivated, access is blocked while required business history is preserved.',
      ],
    ),
    _LegalSectionData(
      title: 'Contact',
      items: [
        'For privacy questions, contact GreenRoot support from the Help & Support screen.',
      ],
    ),
  ],
);
