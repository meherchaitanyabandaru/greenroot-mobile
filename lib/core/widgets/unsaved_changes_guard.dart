import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Asks before Back throws away a form the user has started filling in.
/// Saving closes the screen with Navigator.pop, which this does not block.
class UnsavedChangesGuard extends StatelessWidget {
  final bool hasChanges;
  final String what; // "quotation", "order"
  final Widget child;

  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.what,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !hasChanges,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final discard = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Discard this $what?'),
              content: const Text('What you entered here will be lost.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Discard',
                    style: TextStyle(color: AppColors.red600),
                  ),
                ),
              ],
            ),
          );
          if (discard == true && context.mounted) Navigator.of(context).pop();
        },
        child: child,
      );
}
