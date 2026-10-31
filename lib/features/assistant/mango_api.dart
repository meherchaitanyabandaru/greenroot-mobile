import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/network_exceptions.dart';

/// The AI notice this app shows before first use (API: assistant.NoticeVersion).
const mangoNoticeVersion = '1';

class MangoTurn {
  final String role; // user | assistant
  final String text;
  const MangoTurn(this.role, this.text);
  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class MangoProposal {
  final int id;
  final String summary;
  const MangoProposal({required this.id, required this.summary});
  factory MangoProposal.fromJson(Map<String, dynamic> j) =>
      MangoProposal(id: (j['id'] as num).toInt(), summary: j['summary'] as String? ?? '');
}

/// Today's questions (counted by the server, India time).
class MangoQuota {
  final int used;
  final int limit;
  final DateTime? resetsAt;
  const MangoQuota({required this.used, required this.limit, this.resetsAt});
  int get left => used >= limit ? 0 : limit - used;
  MangoQuota get usedUp => MangoQuota(used: limit, limit: limit, resetsAt: resetsAt);

  static MangoQuota? fromJson(dynamic j) => j is Map<String, dynamic>
      ? MangoQuota(
          used: (j['questions_used'] as num? ?? 0).toInt(),
          limit: (j['questions_limit'] as num? ?? 0).toInt(),
          resetsAt: DateTime.tryParse(j['resets_at'] as String? ?? '')?.toLocal(),
        )
      : null;
}

class MangoReply {
  final String text;
  final MangoProposal? proposal;
  final List<String> usedTools;
  final MangoQuota? quota;
  const MangoReply(this.text, {this.proposal, this.usedTools = const [], this.quota});
  factory MangoReply.fromJson(Map<String, dynamic> j) => MangoReply(
        j['reply'] as String? ?? '',
        proposal: j['proposal'] is Map<String, dynamic> ? MangoProposal.fromJson(j['proposal']) : null,
        usedTools: [for (final t in (j['used_tools'] as List? ?? const [])) t.toString()],
        quota: MangoQuota.fromJson(j['questions']),
      );
}

class MangoStatus {
  final bool enabled;
  final int maxAudioSeconds;
  final MangoQuota? quota;
  const MangoStatus({required this.enabled, required this.maxAudioSeconds, this.quota});
}

/// A failure with the server's code (ai_slow_down, ai_disabled…) and whether
/// trying again can help. Retries are always the user's choice: each one costs.
class MangoError implements Exception {
  final String message;
  final String? code;
  final bool retryable;
  const MangoError(this.message, {this.code, this.retryable = false});
  @override
  String toString() => message;
}

/// Mango's calls. The app talks only to GreenRoot's API, never to the AI
/// provider, and stores none of the conversation.
class MangoApi {
  final ApiClient client;
  const MangoApi(this.client);

  // Model answers take longer than ordinary requests.
  static final _slow = Options(
    headers: {'X-Mango-Notice': mangoNoticeVersion},
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
  );

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final data = e.response?.data;
      final err = data is Map && data['error'] is Map ? data['error'] as Map : null;
      final code = err?['code'] as String?;
      if (code != null && (code.startsWith('ai_') || code.startsWith('audio_') || code.startsWith('action_') ||
          {'empty_audio', 'corrupt_audio', 'unsupported_audio', 'message_too_long', 'text_too_long', 'assistant_not_for_admins'}.contains(code))) {
        return Future.error(MangoError(err?['message'] as String? ?? 'Mango could not answer.',
            code: code, retryable: {'ai_timeout', 'ai_unavailable', 'ai_provider_error', 'ai_rate_limited'}.contains(code),),);
      }
      final app = NetworkExceptions.fromDioException(e);
      final transient = e.type != DioExceptionType.badResponse || (e.response?.statusCode ?? 0) >= 500;
      return Future.error(MangoError(app.message, retryable: transient));
    }
  }

  Future<MangoStatus> status() => _guard(() async {
        final r = await client.dio.get(ApiConstants.assistantStatus);
        final d = r.data as Map<String, dynamic>;
        return MangoStatus(
          enabled: d['enabled'] == true,
          maxAudioSeconds: (d['max_audio_seconds'] as num? ?? 30).toInt(),
          quota: MangoQuota.fromJson(d['questions']),
        );
      });

  /// [language]: te, en or auto (mixed Telugu and English).
  Future<String> transcribe(File audio, String language) => _guard(() async {
        final form = FormData.fromMap({
          'language': language,
          'audio': await MultipartFile.fromFile(audio.path, filename: 'question.m4a', contentType: DioMediaType('audio', 'mp4')),
        });
        final r = await client.dio.post(ApiConstants.assistantTranscribe, data: form, options: _slow);
        return (r.data['text'] as String? ?? '').trim();
      });

  Future<MangoReply> chat(String message, List<MangoTurn> history) => _guard(() async {
        final r = await client.dio.post(ApiConstants.assistantChat,
            data: {'message': message, 'history': [for (final t in history) t.toJson()]}, options: _slow,);
        return MangoReply.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Uint8List> speak(String text) => _guard(() async {
        final r = await client.dio.post<List<int>>(ApiConstants.assistantSpeech,
            data: {'text': text}, options: _slow.copyWith(responseType: ResponseType.bytes),);
        return Uint8List.fromList(r.data ?? const []);
      });

  Future<String> confirm(int actionId) => _guard(() async {
        final r = await client.dio.post(ApiConstants.assistantConfirm(actionId), data: const {});
        return r.data['message'] as String? ?? 'Done.';
      });

  Future<void> cancel(int actionId) => _guard(() => client.dio.post(ApiConstants.assistantCancel(actionId), data: const {}));

  Future<void> deleteData() => _guard(() => client.dio.delete(ApiConstants.assistantData));
}
