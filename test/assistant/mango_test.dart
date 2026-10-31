// Mango AI: voice and text questions, the transcript the user corrects,
// silence and permission handling, errors and retry, read aloud, confirm,
// the privacy notice, and no AI key in the app.
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/assistant/mango_api.dart';
import 'package:greenroot_mobile/features/assistant/mango_audio.dart';
import 'package:greenroot_mobile/features/assistant/mango_chat_controller.dart';
import 'package:greenroot_mobile/features/assistant/mango_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api_client.dart';

class FakeRecorder implements MangoRecorder {
  bool allowed = true;
  List<double> loudness = [-20];
  String? path;
  bool cancelled = false;

  @override
  Future<bool> hasPermission() async => allowed;
  @override
  Future<void> start(String p) async {
    path = p;
    File(p).writeAsBytesSync(List.filled(4000, 1)); // what the recorder would write
  }

  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async => cancelled = true;
  @override
  Stream<double> levels() => Stream.fromIterable(loudness);
  @override
  Future<void> dispose() async {}
}

class FakePlayer implements MangoPlayer {
  final played = <String>[];
  final assets = <String>[];
  int stops = 0;
  final _done = StreamController<void>.broadcast();
  void finish() => _done.add(null);

  @override
  Future<void> playFile(String path) async => played.add(path);
  @override
  Future<void> playAsset(String path) async => assets.add(path);
  @override
  Future<void> stop() async => stops++;
  @override
  Stream<void> get onComplete => _done.stream;
  @override
  Future<void> dispose() async {}
}

void main() {
  late FakeApiClient fake;
  late FakeRecorder recorder;
  late FakePlayer player;
  late Directory tmp;

  setUp(() {
    fake = FakeApiClient()..reset();
    recorder = FakeRecorder();
    player = FakePlayer();
    tmp = Directory.systemTemp.createTempSync('mango_test');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  final made = <MangoChatController>[];
  tearDown(() {
    for (final c in made) {
      c.dispose();
    }
    made.clear();
  });
  MangoChatController controller() {
    final c = MangoChatController(api: MangoApi(fake.apiClient), recorder: recorder, player: player, tempDir: () async => tmp);
    made.add(c);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('a typed question is answered; the notice header and earlier turns go with it', () async {
    final c = controller();
    fake.enqueue(response: {'reply': 'You have 2 pending orders today.', 'used_tools': ['list_orders']});
    c.input.text = "Today's pending orders";
    await c.send();
    fake.enqueue(response: {'reply': 'ORD-1 is PENDING.'});
    c.input.text = 'And ORD-1?';
    await c.send();

    expect(c.messages.map((m) => m.text), ["Today's pending orders", 'You have 2 pending orders today.', 'And ORD-1?', 'ORD-1 is PENDING.']);
    final second = fake.calls[1];
    expect(second.path, endsWith('/assistant/chat'));
    expect(second.headers['X-Mango-Notice'], mangoNoticeVersion);
    expect(second.data['message'], 'And ORD-1?');
    expect(second.data['history'], [
      {'role': 'user', 'text': "Today's pending orders"},
      {'role': 'assistant', 'text': 'You have 2 pending orders today.'},
    ]);
    expect(c.input.text, isEmpty);
    expect(c.phase, MangoPhase.idle);
  });

  test('only the last 6 turns are sent', () async {
    final c = controller();
    for (var i = 0; i < 5; i++) {
      fake.enqueue(response: {'reply': 'a$i'});
      c.input.text = 'q$i';
      await c.send();
    }
    expect((fake.calls.last.data['history'] as List).length, 6);
  });

  test('voice: the transcript shows for checking, the recording is deleted, editing holds it for Send', () async {
    final c = controller()..setLanguage('te');
    fake.enqueue(response: {'text': 'ఈరోజు పెండింగ్ ఆర్డర్లు ఎన్ని?'});
    await c.startRecording();
    await settle();
    expect(c.phase, MangoPhase.recording);
    final path = recorder.path!;
    await c.stopRecording();

    expect(c.phase, MangoPhase.review);
    expect(c.input.text, 'ఈరోజు పెండింగ్ ఆర్డర్లు ఎన్ని?');
    expect(File(path).existsSync(), isFalse, reason: 'audio must not stay on the phone');
    expect(fake.calls.single.path, endsWith('/assistant/transcribe'));
    final form = fake.calls.single.data as FormData;
    expect(form.fields.map((f) => '${f.key}=${f.value}'), contains('language=te'));
    expect(form.files.single.value.contentType.toString(), 'audio/mp4');
    expect(c.messages, isEmpty);
    expect(c.autoSendPending, isTrue);

    c.holdReview(); // the user taps the words to fix one
    c.input.text = 'ఈరోజు పెండింగ్ ఆర్డర్లు ఎన్ని ఉన్నాయి?';
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    expect(fake.calls.length, 1, reason: 'editing stops the automatic send');
    fake.enqueue(response: {'reply': 'ఈరోజు 2 పెండింగ్ ఆర్డర్లు ఉన్నాయి.'});
    fake.enqueue(response: [73, 68, 51]);
    await c.send();
    expect(fake.calls[1].data['message'], 'ఈరోజు పెండింగ్ ఆర్డర్లు ఎన్ని ఉన్నాయి?');
    expect(fake.calls[2].path, endsWith('/assistant/speech'), reason: 'a spoken question gets a spoken answer');
  });

  test('silence is never sent (the AI would invent words) and its file is deleted', () async {
    final c = controller();
    recorder.loudness = [-70, -62, -58];
    await c.startRecording();
    await settle();
    final path = recorder.path!;
    await c.stopRecording();
    expect(fake.calls, isEmpty);
    expect(c.error, contains("didn't hear"));
    expect(File(path).existsSync(), isFalse);
  });

  test('no microphone permission: a clear message, no recording', () async {
    final c = controller();
    recorder.allowed = false;
    await c.startRecording();
    expect(c.phase, MangoPhase.idle);
    expect(c.micDenied, isTrue);
    expect(c.orbState, OrbState.micDenied);
    expect(recorder.path, isNull);
  });

  test('discarding a recording deletes it and sends nothing', () async {
    final c = controller();
    await c.startRecording();
    final path = recorder.path!;
    await c.cancelRecording();
    expect(recorder.cancelled, isTrue);
    expect(File(path).existsSync(), isFalse);
    expect(fake.calls, isEmpty);
  });

  test('a microphone that cannot start says so', () async {
    final c = MangoChatController(api: MangoApi(fake.apiClient), recorder: recorder, player: player, tempDir: () async => throw const FileSystemException('busy'));
    made.add(c);
    await c.startRecording();
    expect(c.phase, MangoPhase.idle);
    expect(c.error, contains('microphone could not start'));
  });

  test('recording stops by itself at the time limit', () async {
    final c = controller()..maxSeconds = 1;
    fake.enqueue(response: {'text': 'hello'});
    await c.startRecording();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(c.phase, MangoPhase.review);
    expect(fake.calls.single.path, endsWith('/assistant/transcribe'));
  });

  test('an empty transcript asks the user to try again', () async {
    final c = controller();
    fake.enqueue(response: {'text': ''});
    await c.startRecording();
    await settle();
    await c.stopRecording();
    expect(c.phase, MangoPhase.idle);
    expect(c.error, contains("couldn't make out"));
  });

  test('network failure: no automatic retry; Try again asks once more without repeating the question', () async {
    final c = controller();
    fake.enqueue(type: FakeResponseType.networkError);
    c.input.text = 'pending orders?';
    await c.send();
    expect(fake.calls.length, 1, reason: 'a retry is a second charge: only the user starts one');
    expect(c.errorRetryable, isTrue);
    expect(c.messages.length, 1);

    fake.enqueue(response: {'reply': 'You have 1 pending order.'});
    await c.retry();
    expect(fake.calls.length, 2);
    expect(fake.calls.last.data['message'], 'pending orders?');
    expect(fake.calls.last.data['history'], isEmpty);
    expect(c.messages.map((m) => m.text), ['pending orders?', 'You have 1 pending order.']);
    expect(c.error, isNull);
  });

  test("the server's own words are shown for Mango's limits; those are not retried", () async {
    final c = controller();
    fake.enqueue(type: FakeResponseType.serviceUnavailable, errorData: {'error': {'code': 'ai_disabled', 'message': 'Mango AI is switched off for now'}});
    c.input.text = 'hi';
    await c.send();
    expect(c.error, 'Mango AI is switched off for now');
    expect(c.errorRetryable, isFalse);
    fake.enqueue(type: FakeResponseType.validationError, errorData: {'error': {'code': 'audio_too_long', 'message': 'keep the question under 30 seconds'}});
    await c.startRecording();
    await settle();
    await c.stopRecording();
    expect(c.error, 'keep the question under 30 seconds');
  });

  test('read aloud plays an MP3 and deletes it after; tapping again stops', () async {
    final c = controller();
    fake.enqueue(response: {'reply': 'మీకు 2 ఆర్డర్లు ఉన్నాయి.'});
    c.input.text = 'orders?';
    await c.send();
    fake.enqueue(response: [73, 68, 51, 1, 2, 3]);
    await c.speak(1);
    expect(fake.calls.last.path, endsWith('/assistant/speech'));
    expect(fake.calls.last.data, {'text': 'మీకు 2 ఆర్డర్లు ఉన్నాయి.'});
    final mp3 = player.played.single;
    expect(File(mp3).existsSync(), isTrue);
    expect(c.speakingIndex, 1);
    await c.speak(1); // stop
    expect(player.stops, 1);
    expect(c.speakingIndex, isNull);
    expect(File(mp3).existsSync(), isFalse);

    fake.enqueue(response: [73, 68, 51]);
    await c.speak(1);
    final again = player.played.last;
    player.finish();
    await settle();
    expect(File(again).existsSync(), isFalse);
    expect(c.speakingIndex, isNull);
  });

  test('read aloud failure is shown and nothing plays', () async {
    final c = controller();
    fake.enqueue(response: {'reply': 'ok'});
    c.input.text = 'x';
    await c.send();
    fake.enqueue(type: FakeResponseType.networkError);
    await c.speak(1);
    expect(player.played, isEmpty);
    expect(c.error, isNotNull);
    expect(c.speakingIndex, isNull);
  });

  test('a proposal runs only when the user taps Confirm, once', () async {
    final c = controller();
    fake.enqueue(response: {'reply': 'Tap Confirm to confirm ORD-1.', 'proposal': {'id': 42, 'summary': 'Confirm order ORD-1 from Ravi (₹6000)'}});
    c.input.text = 'confirm ORD-1';
    await c.send();
    expect(c.messages.last.proposal!.id, 42);
    expect(fake.calls.length, 1, reason: 'nothing is changed by the answer itself');

    fake.enqueue(response: {'status': 'DONE', 'message': 'Done: the order is confirmed.'});
    await c.decide(1, confirm: true);
    expect(fake.calls.last.path, endsWith('/assistant/actions/42/confirm'));
    expect(c.messages.last.proposalResult, 'Done: the order is confirmed.');
    await c.decide(1, confirm: true);
    expect(fake.calls.length, 2, reason: 'a decided proposal is not sent again');
  });

  test('cancelling a proposal, and a refused confirm, change nothing', () async {
    final c = controller();
    fake.enqueue(response: {'reply': 'r', 'proposal': {'id': 7, 'summary': 's'}});
    c.input.text = 'q';
    await c.send();
    fake.enqueue(response: {'status': 'CANCELLED'});
    await c.decide(1, confirm: false);
    expect(fake.calls.last.path, endsWith('/assistant/actions/7/cancel'));
    expect(c.messages.last.proposalResult, contains('Nothing was changed'));

    fake.enqueue(response: {'reply': 'r', 'proposal': {'id': 8, 'summary': 's'}});
    c.input.text = 'q2';
    await c.send();
    fake.enqueue(type: FakeResponseType.conflict, errorData: {'error': {'code': 'action_failed', 'message': 'order cannot be confirmed now'}});
    await c.decide(3, confirm: true);
    expect(c.messages.last.proposalResult, 'order cannot be confirmed now');
  });

  group('orb states, greeting and daily questions', () {
    test('each state shows on the orb, in priority order', () async {
      final c = controller();
      expect(c.orbState, OrbState.idle);
      await c.greet('te', muted: false);
      expect(c.orbState, OrbState.speaking);
      player.finish();
      await settle();
      expect(c.orbState, OrbState.idle);
      await c.startRecording();
      expect(c.orbState, OrbState.listening);
      await c.cancelRecording();
      recorder.allowed = false;
      await c.startRecording();
      expect(c.orbState, OrbState.micDenied);
      recorder.allowed = true;
      fake.enqueue(type: FakeResponseType.networkError);
      c.input.text = 'q';
      final sending = c.send();
      expect(c.orbState, OrbState.thinking);
      await sending;
      expect(c.orbState, OrbState.error);
      fake.enqueue(type: FakeResponseType.validationError, errorData: {'error': {'code': 'ai_daily_questions_used', 'message': 'You have asked your 5 questions for today.'}});
      c.input.text = 'q2';
      await c.send();
      expect(c.orbState, OrbState.limit);
      expect(c.error, isNull, reason: 'the limit state says it');
    });

    test('greeting and goodbye play the app\'s own clips and call no API', () async {
      final c = controller();
      await c.greet('te', muted: false, now: DateTime(2026, 10, 31, 9));
      expect(player.assets, ['audio/mango/greet_morning_te.mp3']);
      expect(c.greetingText, 'శుభోదయం! నేను మ్యాంగో. మీకు ఏం సహాయం కావాలి?');
      await c.greet('en', muted: false, now: DateTime(2026, 10, 31, 19));
      expect(player.assets.last, 'audio/mango/greet_evening_en.mp3');
      final bye = c.sayBye('te', muted: false); // the greeting is still playing: it stops first
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(player.stops, 1);
      expect(player.assets.last, 'audio/mango/bye_te.mp3');
      player.finish();
      await bye; // closes once the goodbye has been said
      expect(c.greetingText, 'సరే, మళ్లీ కలుద్దాం!');
      expect(fake.calls, isEmpty);
      for (final clip in player.assets) {
        expect(File('assets/$clip').existsSync(), isTrue, reason: '$clip is shipped');
      }
    });

    test('muted: the words show, nothing plays', () async {
      final c = controller();
      await c.greet('te', muted: true, now: DateTime(2026, 10, 31, 14));
      await c.sayBye('te', muted: true);
      expect(player.assets, isEmpty);
      expect(c.greetingText, 'సరే, మళ్లీ కలుద్దాం!');
    });

    test('a spoken question is sent by itself after 2 s and answered aloud; a typed one is not read aloud', () async {
      final c = controller();
      fake.enqueue(response: {'text': 'pending orders?'});
      await c.startRecording();
      await settle();
      await c.stopRecording();
      fake.enqueue(response: {'reply': 'You have 2.', 'questions': {'questions_used': 1, 'questions_limit': 5, 'resets_at': '2026-11-01T00:00:00+05:30'}});
      fake.enqueue(response: [73, 68, 51]);
      await Future<void>.delayed(const Duration(milliseconds: 2400));
      expect(fake.calls.map((x) => x.path.split('/').last), ['transcribe', 'chat', 'speech']);
      expect(c.quota!.left, 4);
      expect(player.played, hasLength(1));

      fake.enqueue(response: {'reply': 'Typed answer.'});
      c.input.text = 'typed';
      await c.send();
      expect(fake.calls.last.path, endsWith('/assistant/chat'), reason: 'no read-aloud for typed questions');
    });

    test('cancel drops a transcript waiting to be sent', () async {
      final c = controller();
      fake.enqueue(response: {'text': 'hello'});
      await c.startRecording();
      await settle();
      await c.stopRecording();
      await c.cancelRecording();
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(fake.calls.length, 1);
      expect(c.phase, MangoPhase.idle);
      expect(c.input.text, isEmpty);
    });

    test('today\'s questions come from the server; at 0 the mic does nothing', () async {
      final c = controller();
      fake.enqueue(response: {'enabled': true, 'max_audio_seconds': 30, 'questions': {'questions_used': 5, 'questions_limit': 5, 'resets_at': '2026-11-01T00:00:00+05:30'}});
      await c.load();
      expect(c.quota!.left, 0);
      expect(c.limitReached, isTrue);
      expect(c.orbState, OrbState.limit);
      await c.startRecording();
      expect(recorder.path, isNull);
      fake.enqueue(response: [73, 68, 51]);
      c.messages.add(MangoMessage.mango('earlier answer'));
      await c.speak(0);
      expect(player.played, hasLength(1), reason: 'an earlier answer can still be read aloud');
    });
  });

  group('screen', () {
    // The orb animates forever; pump through instead of settling.
    Future<void> pumpFor(WidgetTester tester, [int ms = 1000]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Map<String, dynamic> status({int used = 2, int limit = 5, bool enabled = true}) => {
          'enabled': enabled, 'notice_version': '1', 'max_audio_seconds': 30,
          'questions': {'questions_used': used, 'questions_limit': limit, 'resets_at': '2026-11-01T00:00:00+05:30'},
        };

    Widget host() => ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fake.apiClient),
            mangoRecorderProvider.overrideWithValue(() => recorder),
            mangoPlayerProvider.overrideWithValue(() => player),
            mangoTempDirProvider.overrideWithValue(() async => tmp),
          ],
          child: MaterialApp(home: Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(
            onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const MangoChatScreen())),
            child: const Text('open'),
          ),),),),),
        );

    Future<void> open(WidgetTester tester, {Map<String, Object> prefs = const {'mango_ai_notice_v1': true}}) async {
      SharedPreferences.setMockInitialValues(prefs);
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await pumpFor(tester);
    }

    testWidgets('first use shows the AI notice; Not now leaves without any AI call', (tester) async {
      await open(tester, prefs: {});
      expect(find.text('Before you use Mango AI'), findsOneWidget);
      expect(find.textContaining('OpenAI'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await pumpFor(tester);
      expect(find.text('open'), findsOneWidget);
      expect(fake.calls, isEmpty);
      expect(player.assets, isEmpty);
    });

    testWidgets('opening: Mango greets from its own clip, shows 3/5, and offers the mic', (tester) async {
      fake.route('/assistant/status', status());
      await open(tester);
      expect(player.assets.single, startsWith('audio/mango/greet_'));
      expect(find.textContaining('నేను మ్యాంగో'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
      expect(find.bySemanticsLabel('3 of 5 questions left today'), findsOneWidget);
      expect(find.bySemanticsLabel('Mango is speaking'), findsWidgets);
      player.finish();
      await pumpFor(tester, 300);
      expect(find.bySemanticsLabel('Mango is ready'), findsOneWidget);
      expect(find.bySemanticsLabel('Start speaking'), findsOneWidget);
      expect(fake.calls.map((x) => x.path.split('/').last), ['status'], reason: 'the greeting is not an AI call');
    });

    testWidgets('listening, then the transcript to check, then the answer with read aloud', (tester) async {
      fake.route('/assistant/status', status());
      await open(tester);
      player.finish();
      await pumpFor(tester, 200);
      await tester.tap(find.bySemanticsLabel('Start speaking'));
      await pumpFor(tester, 300);
      expect(find.text('Listening…'), findsOneWidget);
      expect(find.bySemanticsLabel('Mango is listening'), findsOneWidget);
      expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      fake.enqueue(response: {'text': 'pending orders?'});
      // Uploading reads the recording from disk: real I/O runs only in runAsync.
      await tester.runAsync(() async {
        await tester.tap(find.bySemanticsLabel('Stop recording'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await pumpFor(tester, 300);
      expect(find.text('Is this right?'), findsOneWidget);
      expect(find.text('pending orders?'), findsOneWidget);
      await tester.tap(find.text('pending orders?')); // edit: no automatic send
      fake.enqueue(response: {'reply': 'You have 2 pending orders today.', 'questions': {'questions_used': 3, 'questions_limit': 5}});
      fake.enqueue(response: [73, 68, 51]);
      await tester.runAsync(() async {
        await tester.tap(find.text('Send'));
        await Future<void>.delayed(const Duration(milliseconds: 300)); // the spoken answer is written to a temp file
      });
      await pumpFor(tester, 500);
      expect(find.text('You have 2 pending orders today.'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.bySemanticsLabel('Mango is speaking'), findsWidgets);
    });

    testWidgets('daily limit reached: friendly state, reset time, mic off', (tester) async {
      fake.route('/assistant/status', status(used: 5));
      await open(tester);
      player.finish();
      await pumpFor(tester, 300);
      expect(find.text('You have asked all 5 questions today'), findsOneWidget);
      expect(find.textContaining('Mango is back at 12:00 AM'), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Start speaking')), isSemantics(isButton: true, isEnabled: false));
    });

    testWidgets('microphone not allowed: says how to allow it', (tester) async {
      fake.route('/assistant/status', status());
      await open(tester);
      player.finish();
      await pumpFor(tester, 200);
      recorder.allowed = false;
      await tester.tap(find.bySemanticsLabel('Start speaking'));
      await pumpFor(tester, 300);
      expect(find.text('Mango needs the microphone'), findsOneWidget);
      expect(find.bySemanticsLabel('Microphone not allowed'), findsOneWidget);
    });

    testWidgets('error with Try again; typing is the fallback', (tester) async {
      fake.route('/assistant/status', status());
      await open(tester);
      player.finish();
      await pumpFor(tester, 200);
      await tester.tap(find.text('Type'));
      await pumpFor(tester, 300);
      fake.enqueue(type: FakeResponseType.networkError);
      await tester.enterText(find.byType(TextField), 'pending orders?');
      await tester.tap(find.bySemanticsLabel('Send'));
      await pumpFor(tester, 300);
      expect(find.text('Something went wrong'), findsOneWidget);
      fake.enqueue(response: {'reply': 'Now it works.'});
      await tester.tap(find.text('Try again'));
      await pumpFor(tester, 300);
      expect(find.text('Now it works.'), findsOneWidget);
    });

    testWidgets('close: Mango says goodbye from its clip, then the screen closes', (tester) async {
      fake.route('/assistant/status', status());
      await open(tester);
      player.finish();
      await pumpFor(tester, 200);
      await tester.tap(find.bySemanticsLabel('Close Mango'));
      await pumpFor(tester, 300);
      expect(player.assets.last, 'audio/mango/bye_te.mp3');
      expect(find.text('సరే, మళ్లీ కలుద్దాం!'), findsOneWidget);
      player.finish();
      await pumpFor(tester, 500);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('switched off by the admin: says so, no greeting, no mic', (tester) async {
      fake.route('/assistant/status', status(enabled: false));
      await open(tester);
      expect(find.textContaining('switched off'), findsOneWidget);
      expect(find.bySemanticsLabel('Start speaking'), findsNothing);
      expect(player.assets, isEmpty);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final used in [2, 5]) {
        testWidgets('fits a 360×640 phone at 130% text (${platform.name}, $used/5 used)', (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          fake.route('/assistant/status', status(used: used));
          tester.view.physicalSize = const Size(360 * 2, 640 * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({'mango_ai_notice_v1': true});
          await tester.pumpWidget(MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.3)), child: host()));
          await tester.tap(find.text('open'));
          await pumpFor(tester);
          player.finish();
          await pumpFor(tester, 300);
          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel('Start speaking'), findsOneWidget);
          debugDefaultTargetPlatformOverride = null;
        });
      }
    }

    testWidgets('reduce motion: the orb stands still and nothing breaks', (tester) async {
      fake.route('/assistant/status', status());
      SharedPreferences.setMockInitialValues({'mango_ai_notice_v1': true});
      await tester.pumpWidget(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: host()));
      await tester.tap(find.text('open'));
      await pumpFor(tester);
      player.finish();
      await tester.pumpAndSettle(); // settles: no endless animation
      expect(find.bySemanticsLabel('Mango is ready'), findsOneWidget);
    });
  });

  test('no AI provider key or address is in the app', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      expect(text.contains('api.openai.com') || RegExp(r'sk-[A-Za-z0-9_-]{20,}').hasMatch(text) || text.contains('OPENAI_API_KEY'), isFalse, reason: f.path);
    }
  });
}
