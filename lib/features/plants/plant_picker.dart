import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_colors.dart';
import 'plants.dart';

/// Turns a tapped picker row into a catalog [Plant] (adding a botanical name
/// to the catalog on first use). Shows the API message and returns null on
/// failure, e.g. when an admin removed that plant.
Future<Plant?> resolvePickedPlant(
  BuildContext context,
  WidgetRef ref,
  PlantMatch match,
) async {
  try {
    return await ref.read(plantRepositoryProvider).resolvePlant(match);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppError ? e.message : 'Could not select plant'),
          backgroundColor: AppColors.red600,
        ),
      );
    }
    return null;
  }
}
