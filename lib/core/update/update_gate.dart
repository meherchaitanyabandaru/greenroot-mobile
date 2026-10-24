// Enforces the API's version policy (GET /app/version-policy, set by
// CLIENT_MIN_VERSION): an app below the minimum shows only an "Update required"
// screen. Checked once per launch; if the check fails (offline, server down)
// the app opens normally, so a network problem never locks anyone out.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';

/// This build's version ("1.0.0"), from the installed package.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// The update URL when this build must update, else null.
final requiredUpdateProvider = FutureProvider<String?>((ref) async {
  try {
    final version = await ref.watch(appVersionProvider.future);
    final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
      ApiConstants.appVersionPolicy,
      queryParameters: {
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'version': version,
      },
      fromJson: (d) => d as Map<String, dynamic>,
    );
    final policy = (data['policy'] ?? data) as Map<String, dynamic>;
    if (policy['update_required'] != true) return null;
    return policy['update_url'] as String? ?? '';
  } catch (_) {
    return null; // fail open
  }
});

class UpdateGate extends ConsumerWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(requiredUpdateProvider).valueOrNull;
    return url == null ? child : _UpdateRequired(url: url);
  }
}

class _UpdateRequired extends StatelessWidget {
  final String url;
  const _UpdateRequired({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_rounded, size: 64, color: AppColors.primaryMain),
                const SizedBox(height: 16),
                Text('Update required', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'This version of GreenRoot is no longer supported. Please update to keep using the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (url.isNotEmpty)
                  FilledButton(
                    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    child: const Text('Update now'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
