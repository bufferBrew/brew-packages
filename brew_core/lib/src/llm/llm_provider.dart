/// The LLM providers every Brew app can be configured with.
///
/// **This list mirrors `PROVIDER_SPECS` in
/// `brew/BREW/supabase/functions/_shared/core_llm.ts` and the `core.llm_provider`
/// enum in `brew/BREW/supabase/migrations/0041_core_llm.sql`.** There is no
/// generator; the TypeScript file is the source of truth and all three must
/// agree. Adding a provider means touching all three deliberately, because a
/// provider the settings screen offers but the Edge Function cannot speak to is
/// a failure the user only discovers mid-request.
library;

enum LlmProvider {
  anthropic,
  openai,
  google,
  deepseek,
  openrouter,

  /// Any OpenAI-compatible endpoint the user adds themselves. Distinguished
  /// from other custom endpoints by [LlmConfigEntry.slug], and the only
  /// provider whose base URL is user data rather than a constant below.
  custom;

  /// The value stored in `core.llm_configs.provider`.
  String get wireName => name;

  String get label => switch (this) {
        anthropic => 'Anthropic',
        openai => 'OpenAI',
        google => 'Google Gemini',
        deepseek => 'DeepSeek',
        openrouter => 'OpenRouter',
        custom => 'Custom endpoint',
      };

  String get blurb => switch (this) {
        anthropic => 'Claude models',
        openai => 'GPT models',
        google => 'Gemini models',
        deepseek => 'Low-cost reasoning models',
        openrouter => 'One key, many vendors',
        custom => 'Any OpenAI-compatible API',
      };

  /// Where the user gets a key. Empty for [custom], which has no single home.
  String get keyHelpUrl => switch (this) {
        anthropic => 'https://console.anthropic.com/settings/keys',
        openai => 'https://platform.openai.com/api-keys',
        google => 'https://aistudio.google.com/apikey',
        deepseek => 'https://platform.deepseek.com/api_keys',
        openrouter => 'https://openrouter.ai/keys',
        custom => '',
      };

  /// Whether the user must supply a base URL. True only for [custom].
  bool get requiresBaseUrl => this == custom;

  /// Models offered in the picker.
  ///
  /// Advisory, not exhaustive: the model field accepts free text everywhere, so
  /// a model released after this list was written is still reachable. Curating
  /// it is what stops the common case being a text box the user has to know the
  /// answer for.
  List<LlmModelOption> get models => switch (this) {
        anthropic => const [
            LlmModelOption('claude-opus-5', 'Claude Opus 5', 'Most capable'),
            LlmModelOption('claude-sonnet-5', 'Claude Sonnet 5', 'Balanced'),
            LlmModelOption('claude-haiku-4-5', 'Claude Haiku 4.5', 'Fastest, cheapest'),
          ],
        openai => const [
            LlmModelOption('gpt-4o', 'GPT-4o', 'Balanced'),
            LlmModelOption('gpt-4o-mini', 'GPT-4o mini', 'Fastest, cheapest'),
          ],
        google => const [
            LlmModelOption('gemini-2.5-pro', 'Gemini 2.5 Pro', 'Most capable'),
            LlmModelOption('gemini-2.5-flash', 'Gemini 2.5 Flash', 'Fastest, cheapest'),
          ],
        deepseek => const [
            LlmModelOption('deepseek-chat', 'DeepSeek Chat', 'General purpose'),
            LlmModelOption('deepseek-reasoner', 'DeepSeek Reasoner', 'Slower, better at analysis'),
          ],
        openrouter => const [
            LlmModelOption('anthropic/claude-opus-4', 'Claude Opus 4', 'via OpenRouter'),
            LlmModelOption('openai/gpt-4o', 'GPT-4o', 'via OpenRouter'),
          ],
        custom => const [],
      };

  /// The model used when the user has not chosen one. Empty where no name is
  /// stable enough to hardcode — those providers make the model field required
  /// rather than guessing and failing later as a confusing 404.
  String get defaultModel => switch (this) {
        anthropic => 'claude-opus-5',
        deepseek => 'deepseek-chat',
        openai || google || openrouter || custom => '',
      };

  bool get requiresModel => defaultModel.isEmpty && this != custom;

  static LlmProvider? tryParse(String? value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return null;
  }

  static LlmProvider parse(String? value) => tryParse(value) ?? anthropic;
}

/// One entry in a provider's model picker.
class LlmModelOption {
  const LlmModelOption(this.id, this.label, this.note);

  final String id;
  final String label;

  /// One-line "why you'd pick this" — cost/speed/capability.
  final String note;
}
