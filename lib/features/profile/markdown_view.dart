import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Renders the small markdown subset our legal documents use: `#`, `##`,
/// `###` headings, `-` and `1.` lists, `---` rules, paragraphs and `**bold**`.
/// shortcut: no links, tables or nesting; use a markdown package if a
/// document ever needs them.
class MarkdownView extends StatelessWidget {
  final String source;
  const MarkdownView({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      final numbered = RegExp(r'^(\d+)\. (.*)$').firstMatch(line);
      if (line.startsWith('### ')) {
        children.add(_pad(Text(line.substring(4), style: AppTypography.h4),
            top: AppSpacing.md,),);
      } else if (line.startsWith('## ')) {
        children.add(
          _pad(
            Text(line.substring(3),
                style: AppTypography.h3.copyWith(color: AppColors.primaryMain),),
            top: AppSpacing.x2l,
          ),
        );
      } else if (line.startsWith('# ')) {
        children.add(_pad(Text(line.substring(2), style: AppTypography.h2),
            top: AppSpacing.xs,),);
      } else if (line == '---') {
        children.add(const Divider(height: AppSpacing.x2l));
      } else if (line.startsWith('- ')) {
        children.add(_listItem(
            const Icon(Icons.circle, size: 6, color: AppColors.primaryMain),
            line.substring(2),),);
      } else if (numbered != null) {
        children.add(
          _listItem(
            Text('${numbered.group(1)}.',
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryMain, fontWeight: FontWeight.w700,),),
            numbered.group(2)!,
          ),
        );
      } else {
        children.add(_pad(_rich(line), top: AppSpacing.sm));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children,);
  }

  static Widget _pad(Widget child, {double top = 0}) =>
      Padding(padding: EdgeInsets.only(top: top), child: child);

  static Widget _listItem(Widget marker, String text) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 22,
                child: Padding(
                    padding: const EdgeInsets.only(top: 6), child: marker,),),
            Expanded(child: _rich(text)),
          ],
        ),
      );

  /// A line with `**bold**` spans.
  static Widget _rich(String text) {
    final base = AppTypography.bodySmall
        .copyWith(color: AppColors.textSecondary, height: 1.55);
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? base.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary,)
                  : base,
            ),
        ],
      ),
    );
  }
}
