import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'mango_api.dart';
import 'mango_audio.dart';
import 'mango_chat_controller.dart';
import 'mango_orb.dart';
import 'mango_voice.dart';

const _noticeKey = 'mango_ai_notice_v$mangoNoticeVersion';
const _langKey = 'mango_voice_lang'; // the chosen language (mangoLanguages)
const _muteKey = 'mango_voice_muted';
const _handsFreeKey = 'mango_hands_free'; // on unless the user turns it off

/// The microphone and speaker; tests override them.
final mangoRecorderProvider = Provider<MangoRecorder Function()>((_) => DeviceMangoRecorder.new);
final mangoPlayerProvider = Provider<MangoPlayer Function()>((_) => DeviceMangoPlayer.new);
final mangoTempDirProvider = Provider<Future<Directory> Function()>((_) => getTemporaryDirectory);

/// Shown before first use and from the menu. Says plainly where words go.
Future<bool> showMangoNotice(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Before you use Mango AI'),
      content: const SingleChildScrollView(
        child: Text(
          '• What you say or type to Mango goes to GreenRoot and then to our AI provider, OpenAI, '
          'to turn speech into text, write an answer and read it aloud.\n\n'
          '• GreenRoot does not keep your recordings or the words of your conversation. '
          'We keep only how many questions you asked, for the daily limit and cost.\n\n'
          '• OpenAI does not use this to train its models. It may keep requests for up to 30 days '
          'to check for abuse, then deletes them.\n\n'
          '• Do not tell Mango bank, card or other private details.\n\n'
          '• Mango reads your GreenRoot data only as you can see it, and changes nothing unless you tap Confirm. '
          'Mango can be wrong: check important details on the order screens.',
          style: AppTypography.body,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I agree')),
      ],
    ),
  );
  return ok == true;
}

/// Mango AI: a voice assistant around a glowing orb. Speak (or type), see
/// what Mango heard, hear and read the answer. Greeting and goodbye are
/// clips in the app, never an AI call.
class MangoChatScreen extends ConsumerStatefulWidget {
  const MangoChatScreen({super.key});

  @override
  ConsumerState<MangoChatScreen> createState() => _MangoChatScreenState();
}

class _MangoChatScreenState extends ConsumerState<MangoChatScreen> {
  late final MangoChatController c;
  final _scroll = ScrollController();
  int _seen = 0; // messages shown so far: a new answer scrolls into view
  bool _ready = false;
  bool _typing = false;
  bool _closing = false;
  String? _offline;
  String _lang = 'te';
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    c = MangoChatController(
      api: MangoApi(ref.read(apiClientProvider)),
      recorder: ref.read(mangoRecorderProvider)(),
      player: ref.read(mangoPlayerProvider)(),
      tempDir: ref.read(mangoTempDirProvider),
    )..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = mangoLanguage(prefs.getString(_langKey) ?? 'te').code;
    c.setLanguage(_lang);
    _muted = prefs.getBool(_muteKey) ?? false;
    c.handsFree = prefs.getBool(_handsFreeKey) ?? true;
    if (prefs.getBool(_noticeKey) != true) {
      if (!mounted) return;
      if (!await showMangoNotice(context)) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      await prefs.setBool(_noticeKey, true);
    }
    try {
      final s = await c.load();
      if (!s.enabled) _offline = 'Mango AI is switched off right now. The 🥭 guides still work.';
    } on MangoError catch (e) {
      _offline = e.message;
    }
    if (!mounted) return;
    setState(() => _ready = true);
    if (_offline == null) await c.greet(_lang, muted: _muted);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (c.messages.length != _seen || c.phase == MangoPhase.review) {
      _seen = c.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Goodbye first (from the app's clip), then close; a second tap closes now.
  Future<void> _close() async {
    if (_closing || !_ready || _offline != null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _closing = true);
    await c.sayBye(_lang, muted: _muted);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _menu(String choice) async {
    final prefs = await SharedPreferences.getInstance();
    switch (choice) {
      case 'mute':
        _muted = !_muted;
        await prefs.setBool(_muteKey, _muted);
      case 'handsfree':
        c.handsFree = !c.handsFree;
        await prefs.setBool(_handsFreeKey, c.handsFree);
      case 'about':
        if (mounted) await showMangoNotice(context);
      case 'delete':
        try {
          await c.api.deleteData();
          await prefs.remove(_noticeKey);
          _snack('Your Mango data is deleted.');
        } on MangoError catch (e) {
          _snack(e.message);
        }
    }
    if (mounted) setState(() {});
  }

  /// Choose Mango's language; Mango greets in it at once (from its clip).
  Future<void> _pickLanguage() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // as tall as the list needs, scrolling on small phones
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text("Mango's language", style: AppTypography.h4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('You can always ask in English too.', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            ),
            for (final l in mangoLanguages)
              ListTile(
                title: Text(l.native, style: AppTypography.bodyLarge),
                subtitle: l.code == 'en' ? null : Text(l.english),
                trailing: l.code == _lang ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryMain) : null,
                selected: l.code == _lang,
                onTap: () => Navigator.pop(ctx, l.code),
              ),
          ],
        ),
      ),
    );
    if (code == null || code == _lang || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, code);
    setState(() => _lang = code);
    c.setLanguage(code);
    if (c.phase == MangoPhase.idle && c.speakingIndex == null && !_closing) await c.greet(code, muted: _muted);
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _ask(String text) {
    c.input.text = text;
    setState(() => _typing = false);
    c.send();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4FBEF), Colors.white, Color(0xFFEAF6E4)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: _close, onMenu: _menu, onLanguage: _pickLanguage, lang: _lang, muted: _muted, handsFree: c.handsFree),
                Expanded(
                  child: !_ready
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(builder: (_, box) => _body(box)),
                ),
                if (_ready && _offline == null) _controls(),
                if (_ready) _PrivacyRow(onTap: () => showMangoNotice(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BoxConstraints box) {
    final compact = box.maxHeight < 560;
    // With an answer or a transcript on screen the orb steps back for it.
    final focus = c.phase == MangoPhase.review || (c.lastAnswer != null && c.phase == MangoPhase.idle);
    final orb = (box.maxHeight * (focus ? 0.17 : (compact ? 0.28 : 0.3))).clamp(80.0, 240.0);
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (!compact) ...[
            const SizedBox(height: 4),
            Text('Mango AI', style: AppTypography.h1.copyWith(color: AppColors.forest800)),
            const SizedBox(height: 2),
            Text('Ask about your orders, quotations and deliveries',
                textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: AppColors.textSecondary),),
          ],
          if (c.quota != null) ...[const SizedBox(height: 10), _QuotaPill(quota: c.quota!)],
          if (_offline != null) ...[
            const SizedBox(height: 24),
            _Notice(text: _offline!),
          ] else ...[
            MangoOrb(state: c.orbState, level: c.level, size: orb),
            _Status(c: c, closing: _closing),
            const SizedBox(height: 10),
            if (c.phase == MangoPhase.review)
              _TranscriptCard(c: c)
            else if (c.messages.isEmpty && c.phase == MangoPhase.idle && !c.limitReached && !_typing)
              _Suggestions(onPick: _ask, lang: _lang)
            else if (c.lastAnswer != null && c.phase == MangoPhase.idle)
              _AnswerCard(c: c),
            if (_typing && c.phase == MangoPhase.idle && !c.limitReached) _TypeBox(c: c, onSend: () => _ask(c.input.text)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _controls() {
    final s = c.orbState;
    final recording = c.phase == MangoPhase.recording;
    final speaking = c.speakingIndex != null || c.greeting;
    final canCancel = recording || c.phase == MangoPhase.review;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _Pill(
                icon: Icons.keyboard_alt_outlined,
                label: 'Type',
                onTap: c.busy || recording || c.limitReached ? null : () => setState(() => _typing = !_typing),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _BigButton(
            state: s,
            recording: recording,
            speaking: speaking,
            onTap: switch (s) {
              OrbState.thinking => null,
              OrbState.limit => null,
              _ when recording => c.stopRecording,
              _ when speaking => c.stopVoice,
              _ => () {
                  setState(() => _typing = false);
                  c.startRecording();
                },
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Visibility(
                visible: canCancel,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _Pill(icon: Icons.close_rounded, label: 'Cancel', onTap: canCancel ? c.cancelRecording : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(String) onMenu;
  final VoidCallback onLanguage;
  final String lang;
  final bool muted;
  final bool handsFree;
  const _TopBar({required this.onClose, required this.onMenu, required this.onLanguage, required this.lang, required this.muted, required this.handsFree});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(
          children: [
            const Icon(Icons.eco_rounded, color: AppColors.primaryMain, size: 28),
            const SizedBox(width: 6),
            // The language chip needs the room on narrow phones.
            if (MediaQuery.sizeOf(context).width >= 400)
              Flexible(child: Text('GreenRoot', style: AppTypography.h3.copyWith(color: AppColors.forest800), overflow: TextOverflow.ellipsis)),
            const Spacer(),
            Semantics(
              button: true,
              label: "Mango's language: ${mangoLanguage(lang).english}. Change",
              excludeSemantics: true,
              child: ActionChip(
                avatar: const Icon(Icons.translate_rounded, size: 18, color: AppColors.forest700),
                label: Text('${mangoLanguage(lang).native} ▾'),
                backgroundColor: Colors.white,
                shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
                onPressed: onLanguage,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, semanticLabel: 'Mango options'),
              onSelected: onMenu,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'handsfree', child: Text(handsFree ? 'Hands-free: on (tap to turn off)' : 'Hands-free: off (tap to turn on)')),
                PopupMenuItem(value: 'mute', child: Text(muted ? "Turn on Mango's greeting voice" : "Mute Mango's greeting voice")),
                const PopupMenuItem(value: 'about', child: Text('About Mango AI and privacy')),
                const PopupMenuItem(value: 'delete', child: Text('Delete my Mango data')),
              ],
            ),
            IconButton.filledTonal(
              iconSize: 26,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, semanticLabel: 'Close Mango'),
            ),
          ],
        ),
      );
}

class _QuotaPill extends StatelessWidget {
  final MangoQuota quota;
  const _QuotaPill({required this.quota});

  @override
  Widget build(BuildContext context) {
    final out = quota.left == 0;
    return Semantics(
      label: '${quota.left} of ${quota.limit} questions left today',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: out ? AppColors.amber50 : AppColors.lime100,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 22, color: out ? AppColors.amber700 : AppColors.forest700),
            const SizedBox(width: 8),
            Text('${quota.left}/${quota.limit}', style: AppTypography.h4.copyWith(color: AppColors.forest800)),
            const SizedBox(width: 8),
            Flexible(child: Text('questions left today', style: AppTypography.bodySmall.copyWith(color: AppColors.forest800))),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final MangoChatController c;
  final bool closing;
  const _Status({required this.c, required this.closing});

  String _resets() {
    final at = c.quota?.resetsAt;
    if (at == null) return 'Mango is back after midnight.';
    final h = at.hour == 0 ? 12 : (at.hour > 12 ? at.hour - 12 : at.hour);
    return 'Mango is back at $h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}.';
  }

  @override
  Widget build(BuildContext context) {
    final (title, sub) = switch (c.orbState) {
      _ when closing || (c.greeting && c.greetingText != null) => (c.greetingText ?? '', ''),
      OrbState.listening => ('Listening…', c.handsFree ? "Just speak. I'll stop when you pause." : '0:${c.recordSeconds.toString().padLeft(2, '0')} of 0:${c.maxSeconds} · tap ■ to stop'),
      OrbState.thinking when c.phase == MangoPhase.transcribing => ('Getting your words…', ''),
      OrbState.thinking when c.speechLoading => ('Getting ready to speak…', ''),
      OrbState.thinking => ('Mango is thinking…', ''),
      OrbState.speaking => ('Mango is speaking', 'Tap ■ to stop'),
      OrbState.limit => (c.quota?.limit == 1 ? "You have asked today's question" : 'You have asked all ${c.quota?.limit ?? ''} questions today', _resets()),
      OrbState.micDenied => ('Mango needs the microphone', 'Allow it in Settings → Apps → GreenRoot → Permissions, or tap Type.'),
      OrbState.error => ('Something went wrong', c.error ?? ''),
      OrbState.idle when c.phase == MangoPhase.review => ('Is this right?', 'Tap the words to fix them'),
      OrbState.idle => (c.greetingText ?? 'Tap the mic and ask', c.greetingText == null ? '${c.language == 'en' ? 'English' : '${mangoLanguage(c.language).native} or English'}, up to ${c.maxSeconds} seconds' : ''),
    };
    return Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: AppTypography.h3.copyWith(color: AppColors.forest800)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        ],
        if (c.orbState == OrbState.error && c.errorRetryable)
          TextButton.icon(onPressed: c.retry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

class _TranscriptCard extends StatelessWidget {
  final MangoChatController c;
  const _TranscriptCard({required this.c});

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You said', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            TextField(
              controller: c.input,
              onTap: c.holdReview,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(border: InputBorder.none, counterText: '', isDense: true),
            ),
            if (c.autoSendPending)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MangoChatController.autoSendAfter,
                builder: (_, v, __) => Semantics(
                  label: 'Sending in a moment. Tap the words to edit.',
                  child: LinearProgressIndicator(value: v, minHeight: 3, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(onPressed: c.send, icon: const Icon(Icons.send_rounded), label: const Text('Send')),
            ),
          ],
        ),
      );
}

class _AnswerCard extends StatelessWidget {
  final MangoChatController c;
  const _AnswerCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final index = c.messages.length - 1;
    final m = c.messages[index];
    final speaking = c.speakingIndex == index;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.lastQuestion != null)
            Text(c.lastQuestion!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          SelectableText(m.text, style: AppTypography.bodyLarge),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => c.speak(index),
              icon: Icon(speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded),
              label: Text(speaking ? 'Stop' : 'Read aloud'),
            ),
          ),
          if (m.proposal != null) _Proposal(c: c, index: index),
        ],
      ),
    );
  }
}

class _Proposal extends StatelessWidget {
  final MangoChatController c;
  final int index;
  const _Proposal({required this.c, required this.index});

  @override
  Widget build(BuildContext context) {
    final m = c.messages[index];
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.proposal!.summary, style: AppTypography.label),
          const SizedBox(height: 8),
          if (m.proposalResult != null)
            Text(m.proposalResult!, style: AppTypography.body)
          else if (m.proposalBusy)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: () => c.decide(index, confirm: true), child: const Text('Confirm')),
                OutlinedButton(onPressed: () => c.decide(index, confirm: false), child: const Text('Cancel')),
              ],
            ),
        ],
      ),
    );
  }
}

class _TypeBox extends StatelessWidget {
  final MangoChatController c;
  final VoidCallback onSend;
  const _TypeBox({required this.c, required this.onSend});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: c.input,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type your question',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(iconSize: 26, onPressed: onSend, icon: const Icon(Icons.send_rounded, semanticLabel: 'Send')),
          ],
        ),
      );
}

class _Suggestions extends StatelessWidget {
  final void Function(String) onPick;
  final String lang;
  const _Suggestions({required this.onPick, required this.lang});

  List<String> get examples => [if (mangoSampleQuestion[lang] != null) mangoSampleQuestion[lang]!, "Today's pending orders", 'Where is my delivery?'];

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in examples)
            // Not a Chip: a chip keeps its label on one line, and long
            // questions (Tamil, Kannada) were cut off.
            Material(
              color: Colors.white,
              shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onPick(e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(e, textAlign: TextAlign.center, style: AppTypography.label.copyWith(color: AppColors.forest800)),
                ),
              ),
            ),
        ],
      );
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});
  @override
  Widget build(BuildContext context) => _Card(child: Text(text, textAlign: TextAlign.center, style: AppTypography.bodyLarge));
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Pill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
}

class _BigButton extends StatelessWidget {
  final OrbState state;
  final bool recording;
  final bool speaking;
  final VoidCallback? onTap;
  const _BigButton({required this.state, required this.recording, required this.speaking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stop = recording || speaking;
    final label = recording ? 'Stop recording' : (speaking ? 'Stop speaking' : 'Start speaking');
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null ? AppColors.slate300 : AppColors.forest700,
            boxShadow: [
              BoxShadow(color: (onTap == null ? AppColors.slate300 : AppColors.lime400).withValues(alpha: 0.6), blurRadius: 18, spreadRadius: 4),
            ],
          ),
          child: state == OrbState.thinking
              ? const Padding(padding: EdgeInsets.all(26), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Icon(stop ? Icons.stop_rounded : Icons.mic_rounded, size: 44, color: Colors.white),
        ),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  final VoidCallback onTap;
  const _PrivacyRow({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 18, color: AppColors.forest700),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Private: GreenRoot doesn't keep your questions",
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
}
