import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'llm_repository.dart';

/// The result of one completion.
class LlmCompletion {
  const LlmCompletion({
    required this.text,
    required this.provider,
    required this.model,
  });

  final String text;

  /// Which provider actually answered. Worth surfacing in debug UI: the task
  /// may have fallen back to the user's default provider rather than the one
  /// its settings name — see the resolution tiers in `core.get_task_llm`.
  final String provider;
  final String model;
}

/// Calls an LLM on the user's behalf through `core-llm-call`.
///
/// Apps do not hold API keys and cannot call providers directly — the key is
/// encrypted server-side and never returned. They name a *task* instead
/// ('summarize', 'classify', 'generate', …) and the server resolves which
/// provider and model that task is configured to use.
///
/// One synchronous completion per call. Anything long enough to outlive an Edge
/// Function's wall clock needs a job table, not a longer timeout here.
class LlmClient {
  const LlmClient(this._client, {required this.app});

  final SupabaseClient _client;

  /// This app's id in `core.apps`.
  final String app;

  static const _function = 'core-llm-call';

  Future<LlmCompletion> complete({
    required String task,
    required String prompt,
    String? system,
    int? maxTokens,
    bool json = false,
  }) async {
    try {
      final res = await _client.functions.invoke(_function, body: {
        'app': app,
        'task': task,
        'prompt': prompt,
        'system': ?system,
        'maxTokens': ?maxTokens,
        'json': json,
      });
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw const LlmSettingsException('The server returned an unexpected response.');
      }
      return LlmCompletion(
        text: (data['text'] as String?) ?? '',
        provider: (data['provider'] as String?) ?? '',
        model: (data['model'] as String?) ?? '',
      );
    } on FunctionException catch (e) {
      final details = e.details;
      String? message;
      String? code;
      if (details is Map) {
        message = details['detail'] as String?;
        code = details['error'] as String?;
      }
      throw LlmSettingsException(
        message ?? 'The AI request failed (HTTP ${e.status}).',
        code: code,
      );
    }
  }
}

/// Apps override this in their own ProviderScope with their `core.apps` id:
///
/// ```dart
/// ProviderScope(
///   overrides: [brewAppIdProvider.overrideWithValue('newsbrew')],
///   child: const NewsBrewApp(),
/// )
/// ```
final brewAppIdProvider = Provider<String>(
  (ref) => throw UnimplementedError(
    'Override brewAppIdProvider with this app\'s id from core.apps.',
  ),
);

final llmClientProvider = Provider<LlmClient>(
  (ref) => LlmClient(Supabase.instance.client, app: ref.watch(brewAppIdProvider)),
);
