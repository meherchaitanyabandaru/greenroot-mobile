// Delivery is confirmed by the customer: the driver or nursery enters the
// customer's 4-digit code, the customer taps "I received the plants", or the
// nursery marks it delivered with a reason the customer can dispute for 48 h.
import '../../core/consent/consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import 'dispatches.dart';
import '../../core/feedback/app_haptics.dart';

/// Driver / nursery: asks for the customer's code (or, when allowed, a reason
/// to deliver without it). Returns the delivered trip, or null if closed.
Future<Dispatch?> showDeliverSheet(
  BuildContext context,
  WidgetRef ref,
  Dispatch dispatch,
) {
  return showModalBottomSheet<Dispatch>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DeliverSheet(dispatch: dispatch),
  );
}

class _DeliverSheet extends ConsumerStatefulWidget {
  final Dispatch dispatch;
  const _DeliverSheet({required this.dispatch});

  @override
  ConsumerState<_DeliverSheet> createState() => _DeliverSheetState();
}

class _DeliverSheetState extends ConsumerState<_DeliverSheet> {
  final _code = TextEditingController();
  final _reason = TextEditingController();
  bool _override = false;
  bool _busy = false;
  String? _error;

  bool get _canOverride =>
      widget.dispatch.capabilities?.canOverrideDelivery == true;

  @override
  void dispose() {
    _code.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(dispatchRepositoryProvider);
      final done = _override
          ? await repo.deliver(widget.dispatch.id,
              overrideReason: _reason.text.trim(),)
          : await repo.deliver(widget.dispatch.id, code: _code.text.trim());
      AppHaptics.success();
      if (mounted) Navigator.of(context).pop(done);
    } on AppError catch (e) {
      AppHaptics.error();
      if (mounted) {
        setState(() {
          _error = e.message;
          _code.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _override
        ? _reason.text.trim().length >= 10
        : _code.text.trim().length == 4;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _override ? 'Deliver without the code' : 'Confirm delivery',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _override
                  ? "Say why the customer can't give the code. They will be told, and can report a problem for 48 hours."
                  : 'Ask the customer for the 4-digit delivery code in their GreenRoot app, after they have checked the plants.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (!_override)
              TextField(
                key: const Key('deliveryCodeField'),
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                // The 4th digit sends it: no extra Confirm tap.
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 4 && !_busy) _submit();
                },
                onSubmitted: (_) => ready && !_busy ? _submit() : null,
              )
            else
              TextField(
                key: const Key('overrideReasonField'),
                controller: _reason,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: "e.g. Customer's phone switched off; plants handed to his son",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.red600)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: ready && !_busy ? _submit : null,
              style: _override
                  ? FilledButton.styleFrom(backgroundColor: AppColors.amber600)
                  : null,
              child: Text(
                _busy
                    ? 'Saving...'
                    : _override
                        ? 'Mark delivered without the code'
                        : 'Confirm delivery',
              ),
            ),
            if (_canOverride) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _override = !_override;
                            _error = null;
                          }),
                  child: Text(
                    _override
                        ? 'Enter the code instead'
                        : "Customer can't give the code?",
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The customer's card while the trip is on its way: their code, and
/// "I received the plants". After delivery: confirm an unconfirmed one or
/// report a problem (48 h). Shows nothing when there is nothing to do.
class CustomerDeliveryCard extends ConsumerStatefulWidget {
  final Dispatch dispatch;
  final ValueChanged<Dispatch> onChanged;
  const CustomerDeliveryCard({
    super.key,
    required this.dispatch,
    required this.onChanged,
  });

  @override
  ConsumerState<CustomerDeliveryCard> createState() =>
      _CustomerDeliveryCardState();
}

class _CustomerDeliveryCardState extends ConsumerState<CustomerDeliveryCard> {
  bool _busy = false;

  Future<void> _send({String? issue}) async {
    // Confirming is acknowledged in words; reporting a problem is not.
    Map<String, dynamic>? consent;
    if (issue == null) {
      consent = await askConsent(context, ref, ConsentStep.buyerDelivery);
      if (consent == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final d = await ref
          .read(dispatchRepositoryProvider)
          .confirmReceipt(widget.dispatch.id, issue: issue, consent: consent);
      widget.onChanged(d);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              issue != null
                  ? 'Problem reported to the nursery.'
                  : 'Thanks! Delivery confirmed.',
            ),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Received your plants?'),
        content: const Text(
          'Confirm only after the plants are with you and you have checked them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Yes, received'),
          ),
        ],
      ),
    );
    if (ok == true) await _send();
  }

  Future<void> _report() async {
    final ctrl = TextEditingController();
    final issue = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report a problem'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'e.g. Not received, or 5 plants damaged',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(ctrl.text.trim()),
            child: const Text('Send to nursery'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (issue != null && issue.isNotEmpty) await _send(issue: issue);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispatch;
    final caps = d.capabilities;
    final code = d.deliveryCode;
    final canConfirm = caps?.canConfirmReceipt == true;
    final canReport = caps?.canReportIssue == true;
    if (code == null && !canConfirm && !canReport && d.deliveryIssue == null) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (code != null) ...[
              const Text(
                'Your delivery code',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                code.split('').join(' '),
                key: const Key('deliveryCode'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Share it with the driver only after you have received and checked your plants.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
            ],
            if (d.deliveryUnconfirmed && d.status == 'DELIVERED') ...[
              Text(
                'The nursery marked this delivered without your code'
                '${d.deliveryOverrideReason != null ? ': ${d.deliveryOverrideReason}' : '.'}',
                style: const TextStyle(color: AppColors.amber600),
              ),
              const SizedBox(height: 12),
            ],
            if (canConfirm)
              FilledButton(
                onPressed: _busy ? null : _confirm,
                child: const Text('I received the plants'),
              ),
            if (canReport)
              TextButton(
                onPressed: _busy ? null : _report,
                child: const Text('Report a problem'),
              ),
            if (d.deliveryIssue != null)
              Text(
                'You reported: ${d.deliveryIssue}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// One line on a delivered trip saying how it was confirmed.
String? deliveryConfirmationLabel(Dispatch d) {
  if (d.status != 'DELIVERED') return null;
  return switch (d.deliveryConfirmation) {
    'CUSTOMER_CODE' => "Delivered · confirmed with the customer's code",
    'CUSTOMER_APP' => 'Delivered · confirmed by the customer in the app',
    'UNCONFIRMED' =>
      'Delivered without customer confirmation${d.deliveryOverrideReason != null ? ': ${d.deliveryOverrideReason}' : ''}',
    _ => null,
  };
}
