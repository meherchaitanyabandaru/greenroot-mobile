import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(sessionProvider).capabilities;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Help & Support', style: AppTypography.h3),
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(AppSpacing.x2l),
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 40,),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'We\'re here to help',
                        style: AppTypography.h3.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mon – Sat, 9 AM – 6 PM',
                        style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Contact options
          const _SectionHeader(title: 'Contact Us'),
          const SizedBox(height: AppSpacing.sm),
          _ContactTile(
            icon: Icons.chat_rounded,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF25D366),
            title: 'WhatsApp Support',
            subtitle: '+91 90000 00000',
            copyValue: '+91 90000 00000',
            onTap: () => _launch(
              'https://wa.me/919000000000'
              '?text=Hi%20GreenRoot%20Support%2C%20I%20need%20help%20with...',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ContactTile(
            icon: Icons.email_outlined,
            iconBg: const Color(0xFFE3F2FD),
            iconColor: AppColors.blue600,
            title: 'Email Support',
            subtitle: 'support@greenroot.in',
            copyValue: 'support@greenroot.in',
            onTap: () => _launch(
              'mailto:support@greenroot.in'
              '?subject=GreenRoot%20Support%20Request',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ContactTile(
            icon: Icons.phone_outlined,
            iconBg: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF7B1FA2),
            title: 'Call Us',
            subtitle: '+91 90000 00000',
            copyValue: '+91 90000 00000',
            onTap: () => _launch('tel:+919000000000'),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // FAQs — role-aware
          const _SectionHeader(title: 'Frequently Asked Questions'),
          const SizedBox(height: AppSpacing.sm),

          // Common to all roles
          const _FaqSection(
            title: 'Getting Started',
            icon: Icons.rocket_launch_outlined,
            items: [
              _FaqItem(
                question: 'How do I complete my profile?',
                answer:
                    'Go to Profile → Edit Profile. Fill in your first name, last name, '
                    'and gender. Once all fields are saved, you won\'t be prompted again.',
              ),
              _FaqItem(
                question: 'Can I change my mobile number?',
                answer:
                    'No. Your mobile number is your login identity and is verified via OTP. '
                    'It cannot be changed after registration. Please contact support if you '
                    'need assistance.',
              ),
              _FaqItem(
                question: 'Can I change my email once it\'s verified?',
                answer:
                    'Once your email is verified it is locked for security. '
                    'Contact support at support@greenroot.in to request a change.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Buyer + Owner/Manager: orders and quotations
          if (!caps.isDriverOnly) ...[
            const _FaqSection(
              title: 'Orders & Quotations',
              icon: Icons.shopping_bag_outlined,
              items: [
                _FaqItem(
                  question: 'How do I receive a quotation from a nursery?',
                  answer:
                      'Nurseries send quotations directly to your account. '
                      'You\'ll see them under Buying → Quotations. '
                      'You can accept or reject each quotation from there.',
                ),
                _FaqItem(
                  question: 'Can I cancel an order?',
                  answer:
                      'Orders can only be cancelled while they are in PENDING status. '
                      'Once a nursery confirms the order, cancellation is not allowed. '
                      'Contact the nursery directly for any changes.',
                ),
                _FaqItem(
                  question: 'How do I track my delivery?',
                  answer:
                      'Go to Buying → Deliveries. You\'ll see live delivery status '
                      'and driver location once the dispatch is created by the nursery.',
                ),
                _FaqItem(
                  question: 'Why can\'t I place an order directly?',
                  answer:
                      'GreenRoot is a B2B platform. Nurseries send you a price quotation '
                      'first. You accept it, and the nursery creates the order. '
                      'This ensures pricing accuracy for bulk plant purchases.',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Nursery Owners and Managers only
          if (caps.canSell) ...[
            const _FaqSection(
              title: 'Nursery Owners & Managers',
              icon: Icons.storefront_outlined,
              items: [
                _FaqItem(
                  question: 'How do I register my nursery?',
                  answer:
                      'Go to Profile → Register Nursery. Fill in your nursery details '
                      'and submit for approval. The GreenRoot admin team reviews applications '
                      'within 2–3 business days.',
                ),
                _FaqItem(
                  question: 'Why is my nursery still showing as Pending?',
                  answer:
                      'Nursery approval is a manual review process. If it has been more than '
                      '3 business days, please contact support with your nursery name and '
                      'registered mobile number.',
                ),
                _FaqItem(
                  question: 'How do I add a manager to my nursery?',
                  answer:
                      'Go to your nursery dashboard → Members → Invite Manager. '
                      'Enter their mobile number to send an invite. They will need to '
                      'accept the invite from their app.',
                ),
                _FaqItem(
                  question: 'Can a manager create orders and quotations?',
                  answer:
                      'Yes. Managers have full work access — they can create quotations, '
                      'manage orders, and handle dispatches on behalf of the nursery owner.',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Drivers (driver profile, including drivers who are also other roles)
          if (caps.hasDriverProfile) ...[
            const _FaqSection(
              title: 'Drivers',
              icon: Icons.local_shipping_outlined,
              items: [
                _FaqItem(
                  question: 'How do I start a trip?',
                  answer:
                      'Scan the QR code on the dispatch sheet using the scanner button '
                      'in the Driver tab. Review the trip details and tap Accept to begin.',
                ),
                _FaqItem(
                  question: 'What do I do if I can\'t deliver to the address?',
                  answer:
                      'Add a trip event from the active trip screen. Select the appropriate '
                      'event type (e.g., Address Not Found) and add a note. '
                      'The nursery manager will be notified.',
                ),
                _FaqItem(
                  question: 'How do I mark a delivery as complete?',
                  answer:
                      'From the active trip screen, tap "Complete Delivery". '
                      'You\'ll be asked to upload a proof photo (optional) before confirming.',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // App info
          _AppInfoTile(),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(title, style: AppTypography.h4);
}

// ── Contact tile ───────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String copyValue;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.copyValue,
    required this.onTap,
  });

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: copyValue));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $copyValue'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md,),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Copy icon
              IconButton(
                onPressed: () => _copy(context),
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Copy',
                splashRadius: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FAQ section ────────────────────────────────────────────────────────────────

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

class _FaqSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_FaqItem> items;

  const _FaqSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.primaryMain, size: 22),
          title: Text(
            title,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
          iconColor: AppColors.primaryMain,
          collapsedIconColor: AppColors.textMuted,
          childrenPadding: EdgeInsets.zero,
          children: [
            const Divider(height: 1, color: AppColors.border),
            ...items.map((item) => _FaqTile(item: item)),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 0,),
        title: Text(
          item.question,
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        ),
        iconColor: AppColors.primaryMain,
        collapsedIconColor: AppColors.textMuted,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,),
        children: [
          Text(
            item.answer,
            style: AppTypography.body
                .copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ── App info ───────────────────────────────────────────────────────────────────

class _AppInfoTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco_rounded,
                color: AppColors.primaryMain, size: 24,),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GreenRoot', style: AppTypography.label),
                Text(
                  'Version 1.0.0 · Platform B2B',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
