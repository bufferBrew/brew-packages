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
      ref: 9102a5b4101a92621e7005c2f20445a5d180d3df # v0.2.2
```

## Packages

| Package | Purpose |
|---|---|
| [`brew_core`](brew_core) | Backend config, Supabase bootstrap, the `core.apps` registry, LLM config/keys and third-party connections against the shared `core.*` schema. UI-free by design. |
| [`brew_auth`](brew_auth) | Sign-in (email, Google, GitHub, anonymous) on web, Android, iOS and desktop; router redirect and auth gate. Logic only. |
| [`brew_ui`](brew_ui) | Design tokens, `buildBrewTheme`, and primitives for buttons, cards, states, auth and settings. Each app supplies its own palette. |

## Also here

| | |
|---|---|
| [`supabase/`](supabase) | The shared `core` schema bundle and `brew-migrate`, which installs it and an app's own bundle into any Supabase |
| [`deploy/`](deploy) | Docker: the web image and a self-hosted Supabase stack, synced into every app; the reusable release workflow |

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
- **Pin `ref` to the tag's commit SHA, not the tag name** (keep the tag in a
  comment). `brew_auth` and `brew_ui` reach `brew_core` through an in-repo
  path, which pub records as the commit SHA; an app that names the tag instead
  has "two sources" for `brew_core` and fails to resolve. Get the SHA with
  `git ls-remote https://github.com/bufferBrew/brew-packages.git 'refs/tags/vX.Y.Z^{}'`.
