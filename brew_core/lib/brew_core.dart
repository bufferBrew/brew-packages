/// Shared cross-app data layer for the Brew ecosystem.
///
/// This package is deliberately **UI-free**. Every Brew app has its own design
/// language — its own tokens, its own card and button vocabulary — and a widget
/// shipped from here would have to render against `Theme.of(context)` alone,
/// which is exactly the lowest common denominator that makes an app look
/// borrowed. So the apps share the backend and the models, and each one builds
/// its own screens.
///
/// What is shared, and why:
///
/// **LLM provider settings.** API keys are stored once in `core.llm_configs`,
/// encrypted, and are never returned to any client. Per-app model choices live
/// separately in `core.llm_task_models` — see
/// `apps/BREW/supabase/migrations/0041_core_llm.sql` for why the two are split.
///
/// **Third-party connectors.** Notion, Todoist and friends are configured once
/// in `core.connections`, encrypted the same way. `core.connectors` is a
/// registry whose `fields` drive the form, so a connector added after an app
/// ships still renders correctly in that app.
///
/// ## The shape apps should build
///
/// Apps are meant to look *similar*, not identical. To keep them recognisable
/// as one family, an AI-provider or connections screen should:
///
///   * list one collapsed card per provider/connector, expanding to a form;
///   * show a configured credential as a masked hint (`••••1234`) and never
///     offer to reveal it — the plaintext genuinely cannot be read back;
///   * put a **Test** action next to Save, because a key that authenticates but
///     lacks access fails later and silently otherwise;
///   * say plainly that these credentials are shared across Brew apps, since
///     the user is editing ecosystem-wide state from inside one app;
///   * disable OAuth connectors unless the app passes its own redirect starter.
library;

export 'src/connections/connections_repository.dart';
export 'src/connections/connector.dart';
export 'src/llm/llm_client.dart';
export 'src/llm/llm_config.dart';
export 'src/llm/llm_controller.dart';
export 'src/llm/llm_provider.dart';
export 'src/llm/llm_repository.dart'
    show LlmRepository, LlmSettingsException, llmRepositoryProvider;
