import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'mango_api.dart';
import 'mango_audio.dart';
import 'mango_voice.dart';

enum MangoPhase { idle, recording, transcribing, review, thinking }

/// What the orb shows. One at a time, in this priority.
enum OrbState { idle, listening, thinking, speaking, error, limit, micDenied }

class MangoMessage {
  final bool fromUser;
  final String text;
  final MangoProposal? proposal;

  /// What happened to the proposal: null while it waits for the user.
  String? proposalResult;
  bool proposalBusy = false;

  MangoMessage.user(this.text)
      : fromUser = true,
        proposal = null;
  MangoMessage.mango(this.text, {this.proposal}) : fromUser = false;
}

/// One Mango session. Kept in memory only: nothing is saved on the phone,
/// and recordings are deleted as soon as they are sent or dropped.
class MangoChatController extends ChangeNotifier {
  MangoChatController({required this.api, required this.recorder, required this.player, required this.tempDir, this.maxSeconds = 30}) {
    _playerDone = player.onComplete.listen((_) => _finished());
  }

  final MangoApi api;
  final MangoRecorder recorder;
  final MangoPlayer player;
  final Future<Directory> Function() tempDir;
  int maxSeconds;

  /// Below this the recording is treated as silence and never sent: the
  /// provider turns silence into made-up words (seen in testing).
  static const silenceDb = -45.0;

  /// A spoken question is sent after this unless the user taps to edit it.
  static const autoSendAfter = Duration(seconds: 2);

  /// Louder than this counts as the user speaking (hands-free).
  static const speechDb = -40.0;

  /// Hands-free: Mango listens after it speaks and stops when the user
  /// pauses, so a whole conversation needs no taps. Silence is never sent.
  bool handsFree = false;
  Duration pauseToStop = const Duration(milliseconds: 1500);
  Duration waitForSpeech = const Duration(seconds: 8);

  /// The conversation, for context (only the last exchange is shown).
  final messages = <MangoMessage>[];

  /// The text box: typed, or what Mango heard, for the user to correct.
  final input = TextEditingController();
  MangoPhase phase = MangoPhase.idle;
  /// The language the user chose (te, hi, kn, mr, ta, ur or en).
  String language = 'te';
  String? error;
  bool errorRetryable = false;
  bool micDenied = false;
  int recordSeconds = 0;

  /// Microphone loudness while recording, 0 to 1 (drives the orb).
  double level = 0;
  int? speakingIndex;
  bool speechLoading = false;

  /// Today's questions, from the server. Null until loaded.
  MangoQuota? quota;

  /// The greeting or goodbye line on screen (and in the speaker).
  String? greetingText;
  bool greeting = false;

  /// A spoken question waits [autoSendAfter] before going.
  bool autoSendPending = false;

  String? _recording;
  String? _speechFile;
  double _peak = -160;
  String? _failedMessage;
  bool _fromVoice = false;
  Timer? _timer;
  Timer? _autoSend;
  Completer<void>? _byeDone;
  bool _closing = false;
  DateTime _listenStarted = DateTime.now();
  DateTime? _spokeAt;
  DateTime? _lastLoud;
  StreamSubscription<double>? _levels;
  late final StreamSubscription<void> _playerDone;
  bool _disposed = false;

  bool get busy => phase == MangoPhase.transcribing || phase == MangoPhase.thinking;
  bool get limitReached => quota != null && quota!.left == 0;
  MangoMessage? get lastAnswer => messages.isNotEmpty && !messages.last.fromUser ? messages.last : null;
  String? get lastQuestion {
    for (final m in messages.reversed) {
      if (m.fromUser) return m.text;
    }
    return null;
  }

  OrbState get orbState {
    if (phase == MangoPhase.recording) return OrbState.listening;
    if (busy || speechLoading) return OrbState.thinking;
    if (greeting || speakingIndex != null) return OrbState.speaking;
    if (micDenied) return OrbState.micDenied;
    if (limitReached && phase != MangoPhase.review) return OrbState.limit;
    if (error != null) return OrbState.error;
    return OrbState.idle;
  }

  void _set(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void _fail(Object e) {
    if (e is MangoError && e.code == 'ai_daily_questions_used') {
      quota = (quota ?? const MangoQuota(used: 0, limit: 0)).usedUp;
      error = null; // the limit state says it
      return;
    }
    error = e is MangoError ? e.message : 'Something went wrong. Please try again.';
    errorRetryable = e is MangoError && e.retryable;
  }

  void setLanguage(String value) => _set(() => language = value);
  void clearError() => _set(() => error = null);

  /// Status on open: whether Mango is on, and today's questions.
  Future<MangoStatus> load() async {
    final s = await api.status();
    _set(() {
      maxSeconds = s.maxAudioSeconds;
      quota = s.quota;
    });
    return s;
  }

  /// Say hello from the app's own clip (no AI call).
  Future<void> greet(String lang, {required bool muted, DateTime? now}) async {
    final clip = greetingClip(now ?? DateTime.now(), lang);
    _set(() {
      greetingText = mangoLines[clip];
      greeting = !muted;
    });
    if (muted) {
      _listenAgain();
    } else {
      await _playClip(clip);
    }
  }

  /// Say goodbye (no AI call); completes when the clip ends, at most 4 s.
  Future<void> sayBye(String lang, {required bool muted}) async {
    _closing = true;
    _autoSend?.cancel();
    if (phase == MangoPhase.recording) await cancelRecording();
    if (speakingIndex != null || greeting) {
      await stopVoice();
      // The stopped answer can still report "finished" a moment later (seen
      // on Android), which would end the goodbye at once.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    final clip = byeClip(lang);
    _set(() {
      greetingText = mangoLines[clip];
      greeting = !muted;
    });
    if (muted) return;
    _byeDone = Completer<void>();
    await _playClip(clip);
    await _byeDone?.future.timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  Future<void> _playClip(String clip) async {
    try {
      await player.playAsset(clipAsset(clip));
    } catch (_) {
      _finished(); // a missing speaker is not an error worth showing
    }
  }

  /// [natural]: the clip or answer played to the end (not stopped).
  void _finished({bool natural = true}) {
    if (_byeDone != null && !_byeDone!.isCompleted) _byeDone!.complete();
    if (greeting) _set(() => greeting = false);
    if (speakingIndex != null) _stopped();
    if (natural) _listenAgain();
  }

  /// Hands-free: when Mango has finished speaking, listen for the reply.
  void _listenAgain() {
    if (!handsFree || _closing || _disposed) return;
    // A moment for the speaker to release the audio before the mic opens.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (_disposed || _closing || phase != MangoPhase.idle || limitReached || micDenied || error != null) return;
      if (greeting || speakingIndex != null) return;
      startRecording();
    });
  }

  Future<void> startRecording() async {
    if (phase == MangoPhase.recording || busy) return;
    if (limitReached) return;
    _autoSend?.cancel();
    _set(() {
      error = null;
      autoSendPending = false;
    });
    if (!await recorder.hasPermission()) {
      _set(() => micDenied = true);
      return;
    }
    await stopSpeaking();
    if (greeting) {
      await player.stop();
      _set(() => greeting = false);
    }
    try {
      final dir = await tempDir();
      _recording = '${dir.path}/mango_${DateTime.now().microsecondsSinceEpoch}.m4a';
      _peak = -160;
      await recorder.start(_recording!);
    } catch (_) {
      // e.g. another app is using the microphone
      _recording = null;
      _set(() {
        error = 'The microphone could not start. Close other apps using it, or type.';
        errorRetryable = false;
      });
      return;
    }
    _listenStarted = DateTime.now();
    _spokeAt = _lastLoud = null;
    _levels = recorder.levels().listen((db) {
      if (db > _peak) _peak = db;
      _set(() => level = ((db + 50) / 50).clamp(0.0, 1.0));
      if (!handsFree || phase != MangoPhase.recording) return;
      final now = DateTime.now();
      if (db > speechDb) {
        _spokeAt ??= now;
        _lastLoud = now;
      }
      if (_spokeAt != null && now.difference(_lastLoud!) >= pauseToStop) {
        stopRecording(); // the user paused: their question is done
      } else if (_spokeAt == null && now.difference(_listenStarted) >= waitForSpeech) {
        cancelRecording(); // nobody spoke: stop quietly, nothing is sent
      }
    });
    _set(() {
      micDenied = false;
      phase = MangoPhase.recording;
      recordSeconds = 0;
      greetingText = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _set(() => recordSeconds++);
      if (recordSeconds >= maxSeconds) stopRecording();
    });
  }

  Future<void> stopRecording() async {
    if (phase != MangoPhase.recording) return;
    _timer?.cancel();
    await _levels?.cancel();
    final path = await recorder.stop() ?? _recording;
    _recording = null;
    _set(() => level = 0);
    if (path == null || _peak < silenceDb) {
      _delete(path);
      _set(() {
        phase = MangoPhase.idle;
        error = "I didn't hear anything. Hold the phone closer and try again, or type.";
        errorRetryable = false;
      });
      return;
    }
    _set(() => phase = MangoPhase.transcribing);
    try {
      // Speech-to-text detects the language: forcing the choice turned spoken
      // English into Telugu letters and hurt mixed speech (seen in testing).
      final text = await api.transcribe(File(path), 'auto');
      _set(() {
        if (text.isEmpty) {
          phase = MangoPhase.idle;
          error = "I couldn't make out the words. Please try again, or type.";
          errorRetryable = false;
        } else {
          input.text = text;
          phase = MangoPhase.review;
          autoSendPending = true;
          _fromVoice = true;
        }
      });
      if (autoSendPending) _autoSend = Timer(autoSendAfter, send);
    } catch (e) {
      _set(() {
        phase = MangoPhase.idle;
        _fail(e);
      });
    } finally {
      _delete(path);
    }
  }

  /// The user taps the transcript to correct it: it waits for Send.
  void holdReview() {
    _autoSend?.cancel();
    _set(() => autoSendPending = false);
  }

  /// Drop the recording, or the transcript waiting to be sent.
  Future<void> cancelRecording() async {
    if (phase == MangoPhase.review) {
      _autoSend?.cancel();
      input.clear();
      _fromVoice = false;
      _set(() {
        autoSendPending = false;
        phase = MangoPhase.idle;
      });
      return;
    }
    if (phase != MangoPhase.recording) return;
    _timer?.cancel();
    await _levels?.cancel();
    await recorder.cancel();
    _delete(_recording);
    _recording = null;
    _set(() {
      phase = MangoPhase.idle;
      level = 0;
    });
  }

  List<MangoTurn> _history() {
    final past = messages.where((m) => m.text.isNotEmpty).toList();
    return [
      for (final m in past.skip(past.length > 6 ? past.length - 6 : 0)) MangoTurn(m.fromUser ? 'user' : 'assistant', m.text),
    ];
  }

  Future<void> send() async {
    _autoSend?.cancel();
    final text = input.text.trim();
    if (text.isEmpty || busy || phase == MangoPhase.recording) return;
    final speak = _fromVoice;
    _fromVoice = false;
    final history = _history();
    _set(() {
      messages.add(MangoMessage.user(text));
      input.clear();
      error = null;
      micDenied = false;
      autoSendPending = false;
      greetingText = null;
      phase = MangoPhase.thinking;
    });
    await _ask(text, history, speak: speak);
  }

  /// Ask again after a failure, without adding the question twice.
  Future<void> retry() async {
    final text = _failedMessage;
    if (text == null || busy) return;
    _set(() {
      error = null;
      phase = MangoPhase.thinking;
    });
    await _ask(text, _history()..removeLast());
  }

  Future<void> _ask(String text, List<MangoTurn> history, {bool speak = false}) async {
    try {
      final reply = await api.chat(text, history, language: language);
      _failedMessage = null;
      _set(() {
        messages.add(MangoMessage.mango(reply.text, proposal: reply.proposal));
        quota = reply.quota ?? quota;
      });
    } catch (e) {
      _failedMessage = text;
      _set(() => _fail(e));
    } finally {
      _set(() => phase = MangoPhase.idle);
    }
    // A spoken question gets a spoken answer, like a voice assistant.
    if (speak && lastAnswer != null) await this.speak(messages.length - 1);
  }

  /// Read a reply aloud; tapping again (or another reply) stops it.
  Future<void> speak(int index) async {
    if (speakingIndex == index) return stopSpeaking();
    await stopSpeaking();
    _set(() {
      speakingIndex = index;
      speechLoading = true;
      error = null;
    });
    try {
      final audio = await api.speak(messages[index].text, language: language);
      if (speakingIndex != index) return; // stopped while loading
      final dir = await tempDir();
      final file = File('${dir.path}/mango_reply_${DateTime.now().microsecondsSinceEpoch}.mp3');
      await file.writeAsBytes(audio, flush: true);
      _speechFile = file.path;
      await player.playFile(file.path);
      _set(() => speechLoading = false);
    } catch (e) {
      _stopped();
      _set(() => _fail(e));
    }
  }

  /// Stop whatever Mango is saying: an answer or the greeting.
  Future<void> stopVoice() async {
    await player.stop();
    _finished(natural: false);
  }

  Future<void> stopSpeaking() async {
    if (speakingIndex == null) return;
    await player.stop();
    _stopped();
  }

  void _stopped() {
    _delete(_speechFile);
    _speechFile = null;
    _set(() {
      speakingIndex = null;
      speechLoading = false;
    });
  }

  Future<void> decide(int index, {required bool confirm}) async {
    final m = messages[index];
    final p = m.proposal;
    if (p == null || m.proposalResult != null || m.proposalBusy) return;
    _set(() => m.proposalBusy = true);
    try {
      if (confirm) {
        final done = await api.confirm(p.id);
        _set(() => m.proposalResult = done);
      } else {
        await api.cancel(p.id);
        _set(() => m.proposalResult = 'Cancelled. Nothing was changed.');
      }
    } catch (e) {
      _set(() => m.proposalResult = e is MangoError ? e.message : 'Could not do this. Nothing was changed.');
    } finally {
      _set(() => m.proposalBusy = false);
    }
  }

  void _delete(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _autoSend?.cancel();
    _levels?.cancel();
    _playerDone.cancel();
    if (_recording != null) recorder.cancel();
    _delete(_recording);
    _delete(_speechFile);
    player.stop();
    recorder.dispose();
    player.dispose();
    input.dispose();
    super.dispose();
  }
}
