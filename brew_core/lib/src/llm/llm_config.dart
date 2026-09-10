import 'llm_provider.dart';

/// One provider the user has configured.
///
/// There is no key field and there cannot be one. The column grants in
/// `0041_core_llm.sql` exclude the ciphertext, so no client session can select
/// it, and `core-llm-config` has no action that returns key material.
/// [keyHint] is the last four characters — enough to answer "which key is
/// this?" and nothing more.
class LlmConfigEntry {
  const LlmConfigEntry({
    required this.provider,
    required this.slug,
    required this.keyHint,
    required this.baseUrl,
    required this.label,
    required this.isDefault,
    required this.updatedAt,
  });

  final LlmProvider provider;

  /// Empty for the built-in providers; a user-chosen id for each custom
  /// endpoint, so several can coexist.
  final String slug;

  final String keyHint;

  /// Populated for custom endpoints only.
  final String baseUrl;

  /// User-supplied display name for a custom endpoint. Empty for built-ins,
  /// which use [LlmProvider.label].
  final String label;

  final bool isDefault;
  final DateTime updatedAt;

  /// Identifies this config in the (provider, slug) key space.
  String get id => slug.isEmpty ? provider.name : '${provider.name}/$slug';

  String get displayName =>
      label.isNotEmpty ? label : provider.label;

  String get maskedKey => keyHint.isEmpty ? '••••' : '••••$keyHint';

  static LlmConfigEntry fromJson(Map<String, dynamic> json) => LlmConfigEntry(
        provider: LlmProvider.parse(json['provider'] as String?),
        slug: (json['slug'] as String?) ?? '',
        keyHint: (json['key_hint'] as String?) ?? '',
        baseUrl: (json['base_url'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        isDefault: (json['is_default'] as bool?) ?? false,
        updatedAt: DateTime.tryParse(
              (json['updated_at'] ?? json['created_at']) as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Which provider+model one app uses for one of its own tasks.
///
/// Carries no key material: the key is looked up from the matching
/// [LlmConfigEntry] by (provider, slug), which is what lets a single Anthropic
/// key serve every app in the ecosystem.
class LlmTaskModel {
  const LlmTaskModel({
    required this.app,
    required this.task,
    required this.provider,
    required this.slug,
    required this.model,
  });

  final String app;
  final String task;
  final LlmProvider provider;
  final String slug;

  /// Empty means "this provider's own default", resolved at call time rather
  /// than pinned here — model names churn faster than stored settings do.
  final String model;

  String get configId => slug.isEmpty ? provider.name : '${provider.name}/$slug';

  static LlmTaskModel fromJson(Map<String, dynamic> json) => LlmTaskModel(
        app: (json['app'] as String?) ?? '',
        task: (json['task'] as String?) ?? '',
        provider: LlmProvider.parse(json['provider'] as String?),
        slug: (json['slug'] as String?) ?? '',
        model: (json['model'] as String?) ?? '',
      );
}

/// A task one app can assign a model to.
///
/// Apps declare their own list — newsbrew has summarize/classify/research,
/// NeuroBrew has generate — and pass it to [AiProviderSettings]. `task` is free
/// text in the database precisely so adding one needs no migration.
class LlmTaskSpec {
  const LlmTaskSpec({
    required this.task,
    required this.label,
    required this.description,
  });

  final String task;
  final String label;

  /// Shown under the picker. Say what the model is used FOR, so the user can
  /// judge whether it warrants an expensive model.
  final String description;
}

/// Everything the settings screen needs, in one snapshot.
class LlmSettings {
  const LlmSettings({
    required this.configs,
    required this.taskModels,
  });

  const LlmSettings.empty()
      : configs = const [],
        taskModels = const [];

  final List<LlmConfigEntry> configs;
  final List<LlmTaskModel> taskModels;

  bool get hasAnyKey => configs.isNotEmpty;

  LlmConfigEntry? get defaultConfig {
    for (final c in configs) {
      if (c.isDefault) return c;
    }
    return configs.isEmpty ? null : configs.first;
  }

  /// The config stored for [provider]/[slug], or null if the user has no key
  /// for it.
  LlmConfigEntry? configFor(LlmProvider provider, {String slug = ''}) {
    for (final c in configs) {
      if (c.provider == provider && c.slug == slug) return c;
    }
    return null;
  }

  /// Every custom endpoint the user has added.
  List<LlmConfigEntry> get customConfigs =>
      configs.where((c) => c.provider == LlmProvider.custom).toList();

  /// The assignment for one app/task, or null when the app falls back to the
  /// user's default provider.
  LlmTaskModel? taskModel(String app, String task) {
    for (final t in taskModels) {
      if (t.app == app && t.task == task) return t;
    }
    return null;
  }
}
