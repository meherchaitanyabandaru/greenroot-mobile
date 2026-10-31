import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Quick-action tiles two per row. Each row is as tall as its tallest label:
/// a fixed tile shape (GridView childAspectRatio) cut labels off on narrow
/// phones and with larger system font.
class ActionTileGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ActionTileGrid(
      {super.key, required this.children, this.spacing = AppSpacing.md,});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) SizedBox(height: spacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                SizedBox(width: spacing),
                Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox(),),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
