import 'package:flutter/material.dart';

/// Manager home section — rendered inside HomeScreen for managers (Gumastha).
/// Unique to MANAGER role: work queue, assigned orders, loading tasks,
/// dispatch creation, quotation approval. Cannot be a nursery owner simultaneously.
class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
