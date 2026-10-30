import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import 'quotations.dart';

/// A customer's request on the quotation screen: their message, how long the
/// nursery has to answer, why it was declined, and the actions each side
/// has (nursery: price lines, decline; customer: cancel). [onChanged] reloads.
class QuotationRequestPanel extends ConsumerWidget {
  final Quotation quotation;
  final VoidCallback onChanged;
  const QuotationRequestPanel({super.key, required this.quotation, required this.onChanged});

  Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      onChanged();
    } on AppError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
    }
  }

  Future<String?> _askReason(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline this request?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (the customer sees it)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quotation;
    final caps = q.capabilities;
    final repo = ref.read(quotationRepositoryProvider);
    final until = q.requestExpiresAt;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.forest100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Customer's request", style: AppTypography.label),
          if (q.requestNote != null) ...[
            const SizedBox(height: 6),
            Text('"${q.requestNote!}"', style: AppTypography.body),
          ],
          if (q.status == 'CUSTOMER_REQUESTED' && until != null) ...[
            const SizedBox(height: 6),
            Text(
              until.isAfter(DateTime.now())
                  ? 'Prices due by ${DateFormat('d MMM, h:mm a').format(until)}'
                  : 'The time to answer this request is over.',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (q.declineReason != null) ...[
            const SizedBox(height: 6),
            Text('Declined: ${q.declineReason!}', style: AppTypography.body.copyWith(color: AppColors.red600)),
          ],
          if (caps?.canPrice ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: q.items.every((i) => i.isPriced) ? 'Change prices' : 'Price the lines',
              leadingIcon: Icons.currency_rupee_rounded,
              onPressed: () async {
                final saved = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => PriceRequestSheet(quotation: q),
                );
                if (saved == true) onChanged();
              },
            ),
          ],
          if (caps?.canDecline ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                final reason = await _askReason(context);
                if (reason == null || !context.mounted) return;
                if (reason.length < 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Say why in a few words (at least 5 characters).')),
                  );
                  return;
                }
                await _run(context, () => repo.declineRequest(q.id, reason), 'Request declined. The customer was told.');
              },
              child: const Text('Decline request'),
            ),
          ],
          if (caps?.canCancelRequest ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _run(context, () => repo.cancelRequest(q.id), 'Request cancelled.'),
              child: const Text('Cancel my request'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The nursery prices each line (and may change the quantity it can supply).
/// The plant of a line cannot be changed here: a custom plant stays the
/// customer's plant.
class PriceRequestSheet extends ConsumerStatefulWidget {
  final Quotation quotation;
  const PriceRequestSheet({super.key, required this.quotation});

  @override
  ConsumerState<PriceRequestSheet> createState() => _PriceRequestSheetState();
}

class _PriceRequestSheetState extends ConsumerState<PriceRequestSheet> {
  late final _price = {
    for (final it in widget.quotation.items)
      it.id: TextEditingController(text: it.isPriced ? _num(it.unitPrice) : ''),
  };
  late final _qty = {
    for (final it in widget.quotation.items) it.id: TextEditingController(text: _num(it.quantity)),
  };
  bool _saving = false;
  String? _error;

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [..._price.values, ..._qty.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final prices = <LinePrice>[];
    for (final it in widget.quotation.items) {
      final p = double.tryParse(_price[it.id]!.text.trim());
      if (p == null) continue; // left for later
      final q = double.tryParse(_qty[it.id]!.text.trim());
      if (p < 0 || q == null || q <= 0) {
        setState(() => _error = 'Check the price and quantity of ${it.displayName}');
        return;
      }
      prices.add(LinePrice(it.id, p, quantity: q == it.quantity ? null : q));
    }
    if (prices.isEmpty) {
      setState(() => _error = 'Enter at least one price');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(quotationRepositoryProvider).priceRequest(widget.quotation.id, prices);
      if (mounted) Navigator.of(context).pop(true);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const Text('Price the request', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text('Leave a price empty to come back to it. Send the quotation when every line has a price.',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),),
          const SizedBox(height: AppSpacing.md),
          for (final it in widget.quotation.items) ...[
            Text(it.displayName, style: AppTypography.label),
            if (it.isCustom)
              Text(
                "Customer's own name — not in the plant list${it.linkedPlantName != null ? ' (GreenRoot: ${it.linkedPlantName})' : ''}",
                style: AppTypography.caption.copyWith(color: AppColors.amber600),
              ),
            if (it.specs != null)
              Text(it.specs!, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _qty[it.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Quantity you can supply'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _price[it.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Price each (₹)'),
                ),
              ),
            ],),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_error != null) ...[
            Text(_error!, style: AppTypography.body.copyWith(color: AppColors.red600)),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(label: 'Save prices', isLoading: _saving, onPressed: _saving ? null : _save),
        ],
      ),
    );
  }
}
