import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/brew_supabase.dart';
import 'llm_config.dart';
import 'llm_provider.dart';

/// A failure the user can act on, with the provider's own words where the
/// provider is the one objecting.
class LlmSettingsException implements Exception {
  const LlmSettingsException(this.message, {this.code});

  final String message;
  final String? code;

  /// True when the provider rejected the key, as opposed to a transport or
  /// server problem. The settings UI keeps the field open in that case rather
  /// than reporting a generic failure.
  bool get isKeyRejected => code == 'llm_key_rejected';

  @override
  String toString() => message;
}

/// Reads and writes LLM provider settings for the whole ecosystem.
///
/// Everything goes through the `core-llm-config` Edge Function rather than
/// PostgREST, because saving a key means encrypting it and the encryption
/// secret only exists inside an Edge Function. A plaintext key is in this
/// process for exactly as long as the save call takes and is never read back —
/// not even by the client that wrote it.
class LlmRepository {
  const LlmRepository(this._client);

  final SupabaseClient _client;

  static const _function = 'core-llm-config';

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(_function, body: body);
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    } on FunctionException catch (e) {
      // The function returns { error, detail }; `detail` is written for a human
      // and is the half worth showing. Falling back to the raw payload only
      // when it is missing keeps unexpected shapes debuggable.
      final details = e.details;
      String? message;
      String? code;
      if (details is Map) {
        message = details['detail'] as String?;
        code = details['error'] as String?;
      }
      throw LlmSettingsException(
        message ?? 'The server rejected that request (HTTP ${e.status}).',
        code: code,
      );
    } catch (e) {
      throw LlmSettingsException('Could not reach the server: $e');
    }
  }

  /// Every stored key (metadata only) plus every per-app task assignment.
  Future<LlmSettings> load() async {
    final data = await _invoke({'action': 'list'});
    final configs = (data['configs'] as List<dynamic>? ?? const [])
        .map((e) => LlmConfigEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final tasks = (data['task_models'] as List<dynamic>? ?? const [])
        .map((e) => LlmTaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return LlmSettings(configs: configs, taskModels: tasks);
  }

  /// Stores a key. The function verifies it against the provider first, so a
  /// rejected key surfaces on the field the user is looking at rather than
  /// during whatever they were about to do next.
  Future<void> saveKey({
    required LlmProvider provider,
    required String apiKey,
    String slug = '',
    String label = '',
    String baseUrl = '',
    String model = '',
    bool makeDefault = false,
  }) async {
    await _invoke({
      'action': 'set',
      'provider': provider.wireName,
      'api_key': apiKey,
      'slug': slug,
      'label': label,
      'base_url': baseUrl,
      'model': model,
      'make_default': makeDefault,
    });
  }

  /// Re-verifies an already-stored key without the client ever seeing it.
  Future<void> testKey({
    required LlmProvider provider,
    String slug = '',
    String model = '',
  }) async {
    await _invoke({
      'action': 'test',
      'provider': provider.wireName,
      'slug': slug,
      'model': model,
    });
  }

  Future<void> setDefault({
    required LlmProvider provider,
    String slug = '',
  }) async {
    await _invoke({
      'action': 'set_default',
      'provider': provider.wireName,
      'slug': slug,
    });
  }

  Future<void> deleteKey({
    required LlmProvider provider,
    String slug = '',
  }) async {
    await _invoke({
      'action': 'delete',
      'provider': provider.wireName,
      'slug': slug,
    });
  }

  /// Assigns a provider+model to one app's task.
  Future<void> setTaskModel({
    required String app,
    required String task,
    required LlmProvider provider,
    String slug = '',
    String model = '',
  }) async {
    await _invoke({
      'action': 'set_task_model',
      'app': app,
      'task': task,
      'provider': provider.wireName,
      'slug': slug,
      'model': model,
    });
  }
}

final llmRepositoryProvider = Provider<LlmRepository>(
  (ref) => LlmRepository(ref.watch(brewClientProvider)),
);
