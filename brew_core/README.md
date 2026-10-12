# brew_core

The **backend** every Brew app shares — models, repositories and controllers.
No widgets.

That is deliberate. Each Brew app has its own design language: BrewVoyage has
`AppCard`/`AppButton`/`AnimatedEntrance` and semantic colour tokens, WealthBrew
is plainer Material over its own palette, BREW is different again. A widget
shipped from here could only render against `Theme.of(context)`, which is the
lowest common denominator that makes a screen look borrowed rather than native.

So the apps share the data layer and each builds its own screens. They should
look *similar*, not identical — see "The shape to build" below.

## AI provider settings

Keys and model choices have different natural scopes, and conflating them is why
the four previous implementations (newsbrew, BREW, NeuroBrew, BrewWise) could
not be merged:

| | Scope | Where |
|---|---|---|
| **API keys** | Ecosystem-wide | `core.llm_configs` |
| **Model per task** | Per app | `core.llm_task_models` |

A user pastes their Anthropic key once and every Brew app can use it. newsbrew
still picks a cheap model for `classify` and an expensive one for `research`
without disturbing anyone else.

**Keys are encrypted at rest and never returned to any client.** There is no
endpoint that hands one back; `key_hint` (last four characters) is all the UI
gets. Apps therefore cannot call providers directly — they name a *task* and
`core-llm-call` resolves the key server-side.

## Connectors

Notion, Todoist and the rest are configured once in `core.connections`,
encrypted the same way. `core.connectors` is a registry whose `fields` column
describes the form, so a connector added to the registry after an app shipped
still renders its own fields in that app with no client release.

Secrets are stored as one encrypted blob per connection, so **there is no
partial update**: every secret field must be sent on every save. Tell the user
that on the field rather than letting a blank input silently wipe a token.

## Wiring an app up

```yaml
# pubspec.yaml
dependencies:
  brew_core:
    git:
      url: https://github.com/bufferBrew/brew-packages.git
      path: brew_core
      ref: 9102a5b4101a92621e7005c2f20445a5d180d3df # v0.2.2
```

```dart
// main.dart — resolve the backend, boot Supabase, then run.
final config = await loadBrewConfig();          // null → show a setup screen
if (config == null) return runApp(const SetupApp());
await BrewSupabase.init(config, schema: 'brewwire'); // the app's own schema

// Riverpod must be above the app. If the app uses `provider` for
// its own state (WealthBrew does), ProviderScope wraps MultiProvider; the two
// coexist fine.
runApp(ProviderScope(
  overrides: [brewAppIdProvider.overrideWithValue('voyage')],
  child: const MyApp(),
));
```

Then watch what you need:

```dart
final settings   = ref.watch(llmSettingsProvider);   // AsyncValue<LlmSettings>
final hasAnyKey  = ref.watch(hasLlmKeyProvider);     // gate AI features on this
final connectors = ref.watch(connectionsProvider);   // AsyncValue<ConnectionsState>

// At runtime, name a task — never a provider or a key.
final result = await ref.read(llmClientProvider).complete(
  task: 'summarize',
  prompt: '…',
);
```

## Config and bootstrap

`loadBrewConfig()` decides which Supabase backend the app uses, first hit wins:

| Source | When | How |
|---|---|---|
| `--dart-define` | development, CI | `--dart-define-from-file=env/dev.json` |
| hosted `/config.json` | web, Docker, static hosting | the container writes it from `SUPABASE_URL` / `SUPABASE_ANON_KEY` at start-up |
| saved on device | prebuilt releases | the app's setup screen calls `SharedPrefsConfigStore().save(...)` |

`null` means first run — show a setup screen. A half-set or malformed config
throws `BrewConfigException`, because that is a mistake to fix.

`BrewSupabase.init(config, schema:)` boots the global client with the app's own
schema as the default and a timeout that surfaces as `BrewInitException`.
brew_core's repositories read `brewClientProvider`, so tests override one
provider instead of needing `Supabase.instance`.

## Which apps are installed

`core.apps` is the registry. On the shared project every app has a row; on a
standalone install only the apps whose migrations ran do. Gate cross-app links
on it so a missing app hides the link instead of opening a dead end:

```dart
if (ref.watch(appAvailableProvider('neurobrew'))) LearnThisButton(...)
```

It is false while loading and on error, and a PostgREST error (e.g. `core` not
exposed) is not retried.

## The shape to build

Apps stay recognisably one family by sharing structure, not code. An AI-provider
or connections screen should:

* **list one collapsed card per provider/connector**, expanding to its form.
  Six expanded key forms is a wall of fields on a screen most people visit once;
* **show a configured credential as a masked hint** (`••••1234`) and never offer
  to reveal it — the plaintext genuinely cannot be read back;
* **put a Test action next to Save.** A key that authenticates but lacks access
  (a valid Notion token that cannot see the database) fails silently hours
  later otherwise;
* **say that these credentials are shared across Brew apps.** The user is
  editing ecosystem-wide state from inside one app, and removing a key here
  removes it everywhere — confirm destructive actions on that basis;
* **not offer a form for OAuth connectors.** `ConnectorKind.oauth` means tokens
  arrive from a provider redirect; accepting a pasted one would mean trusting a
  client-supplied credential, which is the thing this backend exists to prevent.
  Either wire the app's own redirect handler or say where to connect it.

Working references: `BrewVoyage/lib/features/settings/presentation/`
(`ai_providers_screen.dart`, `connections_screen.dart`) in the token-rich style,
and the WealthBrew pair of the same names in the plainer Material style.

## Layout

```
lib/src/config/
  brew_config.dart        BrewConfig, BrewConfigSource, validation
  brew_config_loader.dart loadBrewConfig, BrewConfigStore, fetchHostedConfig
lib/src/supabase/
  brew_supabase.dart      BrewSupabase.init, brewClientProvider, requireUserId
lib/src/apps/
  app_registry.dart       core.apps → brewAppsProvider, appAvailableProvider
lib/src/llm/
  llm_provider.dart     LlmProvider enum, curated model lists, defaults
  llm_config.dart       LlmConfigEntry, LlmTaskModel, LlmTaskSpec, LlmSettings
  llm_repository.dart   core-llm-config calls + LlmSettingsException
  llm_controller.dart   llmSettingsProvider, hasLlmKeyProvider
  llm_client.dart       core-llm-call — the runtime path
lib/src/connections/
  connector.dart              Connector, ConnectorField, Connection, state
  connections_repository.dart core-connections calls + connectionsProvider
```

## Backing migrations

* `brew/BREW/supabase/migrations/0040_core_schema.sql` (`core.apps`)
* `brew/BREW/supabase/migrations/0041_core_llm.sql`
* `brew/BREW/supabase/migrations/0042_core_connections.sql`
