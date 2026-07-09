import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../dispatches/dispatches.dart';

/// Driver-only: add a trip event (checkpoint) to an active IN_TRANSIT dispatch.
class TripEventScreen extends ConsumerStatefulWidget {
  final int dispatchId;
  const TripEventScreen({super.key, required this.dispatchId});

  @override
  ConsumerState<TripEventScreen> createState() => _TripEventScreenState();
}

class _TripEventScreenState extends ConsumerState<TripEventScreen> {
  static const _eventTypes = [
    ('CHECKPOINT', 'Checkpoint', 'Route checkpoint reached', Icons.location_on_rounded),
    ('DELAY', 'Delay', 'Unexpected delay encountered', Icons.access_time_outlined),
    ('VEHICLE_ISSUE', 'Vehicle Issue', 'Vehicle problem or breakdown', Icons.car_crash_outlined),
    ('CUSTOMS', 'Customs / Checkpoint', 'Border or customs check', Icons.policy_outlined),
    ('OTHER', 'Other', 'Other event', Icons.more_horiz_rounded),
  ];

  String _selectedType = 'CHECKPOINT';
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(dispatchRepositoryProvider).addTripEvent(
            widget.dispatchId,
            _selectedType,
            note: _noteController.text.trim().isNotEmpty
                ? _noteController.text.trim()
                : null,
          );
      ref.invalidate(dispatchDetailProvider(widget.dispatchId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip event recorded'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
        Navigator.of(context).pop();
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Trip Event'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.md),

          Text('Event Type', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),

          // Event type selector
          ...(_eventTypes.map((entry) {
            final (type, label, desc, icon) = entry;
            final selected = _selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InkWell(
                onTap: () => setState(() => _selectedType = type),
                borderRadius: AppRadius.cardRadius,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryMain.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryMain
                          : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryMain
                              : AppColors.forest100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: selected
                              ? Colors.white
                              : AppColors.primaryMain,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: AppTypography.label.copyWith(
                                color: selected
                                    ? AppColors.primaryMain
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              desc,
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primaryMain),
                    ],
                  ),
                ),
              ),
            );
          })),

          const SizedBox(height: AppSpacing.x2l),

          Text('Note (Optional)', style: AppTypography.h4),
          const SizedBox(height: AppSpacing.sm),

          TextField(
            controller: _noteController,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add a note about this event…',
              hintStyle:
                  AppTypography.body.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputRadius,
                borderSide: const BorderSide(
                    color: AppColors.primaryMain, width: 2),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.x2l),

          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.primaryMain),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_circle_outline_rounded),
              label: Text(
                _submitting ? 'Saving…' : 'Save Event',
                style: AppTypography.label,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}
