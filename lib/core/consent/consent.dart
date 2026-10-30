import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// What each party confirms at a step (seller at loading, driver before the
// trip, buyer on accepting and at delivery). The wording comes from the API
// (GET /consents/templates), which stores it with each confirmation.

class ConsentStep {
  static const sellerLoading = 'SELLER_LOADING';
  static const driverDispatch = 'DRIVER_DISPATCH';
  static const buyerQuotationAccept = 'BUYER_QUOTATION_ACCEPT';
  static const buyerDelivery = 'BUYER_DELIVERY';
}

class ConsentTemplate {
  final String type;
  final int version;
  final String title;
  final List<String> statements;
  const ConsentTemplate(this.type, this.version, this.title, this.statements);

  factory ConsentTemplate.fromJson(Map<String, dynamic> j) => ConsentTemplate(
        j['consent_type'] as String,
        (j['consent_version'] as num).toInt(),
        j['title'] as String? ?? '',
        (j['statements'] as List<dynamic>).map((e) => '$e').toList(),
      );
}

final consentTemplatesProvider = FutureProvider<Map<String, ConsentTemplate>>((ref) async {
  final list = await ref.read(apiClientProvider).get<List<dynamic>>(
        ApiConstants.consentTemplates,
        fromJson: (d) => (d as Map<String, dynamic>)['templates'] as List<dynamic>,
      );
  return {
    for (final raw in list)
      (raw as Map<String, dynamic>)['consent_type'] as String: ConsentTemplate.fromJson(raw),
  };
});

/// Shows [step]'s statements; every one must be ticked. Returns what the API
/// expects ({consent_version, accepted, evidence}), or null if the person
/// stepped back or the wording could not be loaded (they are told why).
Future<Map<String, dynamic>?> askConsent(
  BuildContext context,
  WidgetRef ref,
  String step, {
  String? intro,
  List<String> evidence = const [],
}) async {
  final messenger = ScaffoldMessenger.of(context);
  ConsentTemplate? template;
  try {
    template = (await ref.read(consentTemplatesProvider.future))[step];
  } catch (_) {
    ref.invalidate(consentTemplatesProvider);
  }
  if (template == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Could not load what to confirm. Check your connection and try again.'),
      backgroundColor: AppColors.red600,
    ),);
    return null;
  }
  if (!context.mounted) return null;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ConsentSheet(template: template!, intro: intro),
  );
  if (ok != true) return null;
  return {'consent_version': template.version, 'accepted': true, if (evidence.isNotEmpty) 'evidence': evidence};
}

/// The statements as checkboxes and a Confirm button enabled when all are ticked.
class ConsentSheet extends StatefulWidget {
  final ConsentTemplate template;
  final String? intro;
  const ConsentSheet({super.key, required this.template, this.intro});

  @override
  State<ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<ConsentSheet> {
  late final List<bool> _ticked = List.filled(widget.template.statements.length, false);

  @override
  Widget build(BuildContext context) {
    final all = _ticked.every((t) => t);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Text(widget.template.title, style: AppTypography.h3),
        if (widget.intro != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.intro!, style: AppTypography.body),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text('Tick each one to confirm. This is saved with your name and the time.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _ticked.length; i++)
          CheckboxListTile(
            value: _ticked[i],
            onChanged: (v) => setState(() => _ticked[i] = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(widget.template.statements[i], style: AppTypography.body),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton(
              onPressed: all ? () => Navigator.pop(context, true) : null,
              child: const Text('Confirm'),
            ),
          ),
        ],),
      ],
    );
  }
}
