import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'owner_members_screen.dart' show NurseryCustomer;

/// Bottom sheet that lists connected customers for a nursery and returns the
/// selected [NurseryCustomer]. Used by both quotation and order creation.
class CustomerPickerSheet extends StatefulWidget {
  final int nurseryId;
  const CustomerPickerSheet({super.key, required this.nurseryId});

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  List<NurseryCustomer>? _customers;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customers = await ApiClient.instance.get<List<NurseryCustomer>>(
        ApiConstants.nurseryCustomers(widget.nurseryId),
        fromJson: (json) {
          final list =
              (json as Map<String, dynamic>)['customers'] as List<dynamic>? ??
                  [];
          return list
              .cast<Map<String, dynamic>>()
              .map(NurseryCustomer.fromJson)
              .toList();
        },
      );
      if (mounted) {
        setState(() {
          _customers = customers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, ctrl) => SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 8),
              child: Row(children: [
                Expanded(
                    child: Text('Select Customer', style: AppTypography.h3)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryMain))
                  : _error != null
                      ? Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Text('Failed to load customers',
                                style: AppTypography.body
                                    .copyWith(color: AppColors.red600)),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ]))
                      : _customers == null || _customers!.isEmpty
                          ? Center(
                              child: Text(
                                'No connected customers',
                                style: AppTypography.body
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.separated(
                              controller: ctrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screenPadding,
                                  vertical: AppSpacing.md),
                              itemCount: _customers!.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.border),
                              itemBuilder: (_, i) {
                                final c = _customers![i];
                                return ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.forest100,
                                    child: Text(
                                      c.displayName[0].toUpperCase(),
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.primaryMain,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    c.displayName,
                                    style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    c.identityLabel,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      size: 18, color: AppColors.textMuted),
                                  onTap: () => Navigator.pop(context, c),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
