import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

/// Microphone for Mango; tests use a fake.
abstract class MangoRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();

  /// Loudness while recording, in dBFS (0 is the loudest).
  Stream<double> levels();
  Future<void> dispose();
}

class DeviceMangoRecorder implements MangoRecorder {
  final _r = AudioRecorder();

  @override
  Future<bool> hasPermission() => _r.hasPermission();

  // Speech needs little: 16 kHz mono AAC at 32 kb/s is about 4 KB a second.
  @override
  Future<void> start(String path) => _r.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 32000, noiseSuppress: true),
        path: path,
      );

  @override
  Future<String?> stop() => _r.stop();

  @override
  Future<void> cancel() => _r.cancel();

  @override
  Stream<double> levels() => _r.onAmplitudeChanged(const Duration(milliseconds: 200)).map((a) => a.current);

  @override
  Future<void> dispose() => _r.dispose();
}

/// Plays Mango's spoken answers; tests use a fake.
abstract class MangoPlayer {
  Future<void> playFile(String path);

  /// A clip shipped with the app, e.g. `audio/mango/bye_te.mp3`.
  Future<void> playAsset(String path);
  Future<void> stop();
  Stream<void> get onComplete;
  Future<void> dispose();
}

class DeviceMangoPlayer implements MangoPlayer {
  final _p = AudioPlayer();

  @override
  Future<void> playFile(String path) => _p.play(DeviceFileSource(path));

  @override
  Future<void> playAsset(String path) => _p.play(AssetSource(path));

  @override
  Future<void> stop() => _p.stop();

  @override
  Stream<void> get onComplete => _p.onPlayerComplete;

  @override
  Future<void> dispose() => _p.dispose();
}
