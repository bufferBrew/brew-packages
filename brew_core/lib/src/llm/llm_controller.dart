import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'llm_config.dart';
import 'llm_provider.dart';
import 'llm_repository.dart';

/// The ecosystem's LLM settings.
///
/// Deliberately app-agnostic: the keys are shared, so this notifier is the same
/// in every Brew app and there is one cache of them per process rather than one
/// per feature. Per-app task assignments live in the same snapshot because they
/// arrive on the same round trip.
class LlmSettingsController extends AsyncNotifier<LlmSettings> {
  @override
  Future<LlmSettings> build() => ref.read(llmRepositoryProvider).load();

  /// Re-reads from the server. Mutations below call this rather than patching
  /// state locally: `is_default` moves between rows inside one SQL statement,
  /// so a local guess at the new state would be wrong exactly when it matters.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(llmRepositoryProvider).load(),
    );
  }

  Future<void> saveKey({
    required LlmProvider provider,
    required String apiKey,
    String slug = '',
    String label = '',
    String baseUrl = '',
    String model = '',
    bool makeDefault = false,
  }) async {
    await ref
        .read(llmRepositoryProvider)
        .saveKey(
          provider: provider,
          apiKey: apiKey,
          slug: slug,
          label: label,
          baseUrl: baseUrl,
          model: model,
          makeDefault: makeDefault,
        );
    await reload();
  }

  Future<void> testKey({
    required LlmProvider provider,
    String slug = '',
    String model = '',
  }) => ref
      .read(llmRepositoryProvider)
      .testKey(provider: provider, slug: slug, model: model);

  Future<void> setDefault({
    required LlmProvider provider,
    String slug = '',
  }) async {
    await ref
        .read(llmRepositoryProvider)
        .setDefault(provider: provider, slug: slug);
    await reload();
  }

  Future<void> deleteKey({
    required LlmProvider provider,
    String slug = '',
  }) async {
    await ref
        .read(llmRepositoryProvider)
        .deleteKey(provider: provider, slug: slug);
    await reload();
  }

  Future<void> setTaskModel({
    required String app,
    required String task,
    required LlmProvider provider,
    String slug = '',
    String model = '',
  }) async {
    await ref
        .read(llmRepositoryProvider)
        .setTaskModel(
          app: app,
          task: task,
          provider: provider,
          slug: slug,
          model: model,
        );
    await reload();
  }
}

final llmSettingsProvider =
    AsyncNotifierProvider<LlmSettingsController, LlmSettings>(
      LlmSettingsController.new,
    );

/// Whether the user has configured any provider at all.
///
/// Apps gate their AI features on this so a missing key reads as "AI is off"
/// rather than as a failure at the moment the feature is used.
final hasLlmKeyProvider = Provider<bool>((ref) {
  return ref.watch(llmSettingsProvider).value?.hasAnyKey ?? false;
});
