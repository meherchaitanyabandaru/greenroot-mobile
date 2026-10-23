// What keeps the QR scanners from getting stuck on "Camera unavailable":
// the camera is released when the app goes to the background (or a gallery /
// another app takes over) and started again on return, the torch is only
// touched while the camera runs, and a failure shows what to do next.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Stops the scanner when the app leaves the foreground and starts it again
/// when it returns. [scannerPaused] is true while the screen paused it on
/// purpose (e.g. a result sheet is open), so resuming the app leaves it off.
mixin ScannerLifecycle<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  MobileScannerController get scanner;
  bool get scannerPaused => false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!scannerPaused) unawaited(startScanner());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(stopScanner());
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Starts the camera; never throws (the error view shows the problem).
  Future<void> startScanner() async {
    try {
      if (!scanner.value.isRunning) await scanner.start();
    } catch (_) {}
  }

  Future<void> stopScanner() async {
    try {
      if (scanner.value.isRunning) await scanner.stop();
    } catch (_) {}
  }

  /// "Try again" on the error view: release the camera and start fresh.
  Future<void> restartScanner() async {
    await stopScanner();
    await startScanner();
  }

  /// Toggles the torch only when the camera runs and has one; returns
  /// whether the torch is now on.
  Future<bool> toggleTorchSafely() async {
    final v = scanner.value;
    if (!v.isRunning || v.torchState == TorchState.unavailable) return false;
    try {
      await scanner.toggleTorch();
    } catch (_) {
      return false;
    }
    return scanner.value.torchState == TorchState.on;
  }
}

/// Shown instead of the camera when it can't start: says why in plain words
/// and offers a retry (the screen keeps its gallery button).
class ScannerErrorView extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;

  const ScannerErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (title, hint) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
          'Camera permission is off',
          'Allow camera access for GreenRoot in your phone Settings, then tap Try again.',
        ),
      MobileScannerErrorCode.unsupported => (
          "This phone can't scan with its camera",
          'Pick a photo of the QR code from your gallery instead.',
        ),
      _ => (
          "The camera didn't start",
          'Another app may be using it. Close that app and tap Try again, or pick a photo of the QR code.',
        ),
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 46)),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              const SizedBox(height: 14),
              // For support: which error the phone reported.
              Text(
                'Code: ${[
                  error.errorCode.name,
                  error.errorDetails?.code,
                  error.errorDetails?.message,
                ].whereType<String>().join(' · ')}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
