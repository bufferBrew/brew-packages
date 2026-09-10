# brew-packages

Shared Dart/Flutter packages for the **Brew** ecosystem (bufferBrew org).

Every Brew app is its own independently-clonable repository. Anything more than one
app needs lives here and is consumed by **git dependency**, never by a `path:`
dependency — a `path:` dep across sibling repos means a fresh clone of the app
cannot build.

```yaml
dependencies:
  brew_core:
    git:
      url: https://github.com/bufferBrew/brew-packages.git
      path: brew_core
      ref: v0.1.0
```

## Packages

| Package | Purpose |
|---|---|
| [`brew_core`](brew_core) | LLM config/keys and third-party connections against the shared `core.*` Supabase schema. UI-free by design. |

Planned: `brew_data` (Supabase client + schema provider, logging, auth, prefs sync)
and `brew_ui` (theme tokens and shared widget primitives).

## Rules

- **Pin dependencies low.** `brew_core` targets `flutter_riverpod: ^3.3.2` and
  `supabase_flutter: ^2.15.3` deliberately, so adopting it never forces an app to
  upgrade. Apps in the fleet currently span `supabase_flutter` 2.15.3–2.17.2 and
  `flutter_riverpod` 3.3.2–3.4.2.
- **No opinionated widgets in `brew_core`.** See its own README: a widget shipped
  from here can only render against `Theme.of(context)`, which is the lowest common
  denominator that makes an app look borrowed. Tokens and primitives belong in
  `brew_ui`; composition stays in each app.
- **Tag a release for every consumer-visible change**, and bump the `ref` in each
  app deliberately. Apps upgrade on their own schedule.
