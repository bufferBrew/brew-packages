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
| [`brew_core`](brew_core) | Backend config, Supabase bootstrap, the `core.apps` registry, LLM config/keys and third-party connections against the shared `core.*` schema. UI-free by design. |
| [`brew_auth`](brew_auth) | Sign-in (email, Google, GitHub, anonymous) on web, Android, iOS and desktop; router redirect and auth gate. Logic only. |
| [`brew_ui`](brew_ui) | Design tokens, `buildBrewTheme`, and primitives for buttons, cards, states, auth and settings. Each app supplies its own palette. |

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
