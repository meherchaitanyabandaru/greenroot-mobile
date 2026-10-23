import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'owner_members_screen.dart' show NurseryCustomer;

/// Name, email or any part of the mobile number ("98111", "kiran").
bool customerMatches(NurseryCustomer c, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (c.displayName.toLowerCase().contains(q)) return true;
  if ((c.email ?? '').toLowerCase().contains(q)) return true;
  final digits = q.replaceAll(RegExp(r'\D'), '');
  return digits.isNotEmpty && c.mobile.contains(digits);
}

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
  String _query = '';

  List<NurseryCustomer> get _shown => (_customers ?? const <NurseryCustomer>[])
      .where((c) => customerMatches(c, _query))
      .toList();

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
      initialChildSize: 0.85,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, ctrl) => SafeArea(
        child: Padding(
          // Keep the last results above the keyboard while searching.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
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
                  AppSpacing.screenPadding,
                  16,
                  AppSpacing.screenPadding,
                  8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Select Customer', style: AppTypography.h3),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // A nursery can have hundreds of customers: search, don't scroll.
              if ((_customers?.length ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    0,
                    AppSpacing.screenPadding,
                    8,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search name or mobile',
                      prefixIcon: const Icon(Icons.search_rounded),
                      helperText: _query.trim().isEmpty
                          ? '${_customers!.length} customers · newest first'
                          : '${_shown.length} of ${_customers!.length}',
                    ),
                  ),
                ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryMain,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Failed to load customers',
                                  style: AppTypography.body
                                      .copyWith(color: AppColors.red600),
                                ),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _customers == null || _customers!.isEmpty
                            ? Center(
                                child: Text(
                                  'No connected customers',
                                  style: AppTypography.body
                                      .copyWith(color: AppColors.textMuted),
                                ),
                              )
                            : _shown.isEmpty
                                ? Center(
                                    child: Text(
                                      'No customer matches "${_query.trim()}"',
                                      style: AppTypography.body
                                          .copyWith(color: AppColors.textMuted),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: ctrl,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.screenPadding,
                                      vertical: AppSpacing.md,
                                    ),
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    itemCount: _shown.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                    itemBuilder: (_, i) {
                                      final c = _shown[i];
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
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
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          c.identityLabel,
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: AppColors.textMuted,
                                        ),
                                        onTap: () => Navigator.pop(context, c),
                                      );
                                    },
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
