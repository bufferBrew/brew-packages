# Running Brew apps in Docker

Everything an app needs to run in containers, shared by all Brew apps.
`deploy/sync.sh <app>` copies `web/` and `supabase/` into an app's
`deploy/`; the app adds its own `compose.yml` (see BrewWire's).

```
deploy/
  web/        nginx image for the Flutter web bundle; config.json at start
  supabase/   minimal self-hosted Supabase: db, auth, rest, functions, gateway
  sync.sh     copies web/ and supabase/ into an app
```

## For someone installing one app

```bash
git clone https://github.com/bufferBrew/BrewWire && cd BrewWire
cp .env.example .env
deploy/supabase/gen-env.sh >> .env       # database password, JWT secret, keys
docker compose --profile supabase up -d
```

App on http://localhost:3000, Supabase API on http://localhost:8000. That's
the whole thing: no Flutter, no Supabase account. The web image is pulled
from `ghcr.io/bufferbrew/<app>-web`; `brew-migrate` installs the database
before the API starts.

**Against an existing Supabase** (hosted, or a stack shared by several apps):
put `SUPABASE_URL`, `ANON_KEY` and `DATABASE_URL` in `.env`, then

```bash
docker compose run --rm migrate      # install core + the app's schema, once
docker compose up -d                 # just the web app
```

and expose `core` plus the app's schema in the API settings.

### Several apps on one database

Run the `supabase` profile from one app, then point the others at it
(Option B in their `.env.example`) and run their `migrate` once. `core` is
installed by whichever app goes first and skipped after; each app adds its
own schema and signup trigger. Each app's `APP_SCHEMAS` must then be added to
the shared stack's PostgREST (`APP_SCHEMAS=brewwire,brewfeed` in the stack's
`.env`).

## What's in the self-hosted stack

| Service | Image | Notes |
|---|---|---|
| db | `supabase/postgres:17.6.1.159` | Same image and version the Supabase CLI runs |
| auth | `supabase/gotrue:v2.195.0` | Email sign-up auto-confirmed unless SMTP is set; anonymous sign-in on; Google/GitHub optional |
| rest | `supabase/postgrest:v16.1` | Starts only after `migrate` succeeds: it refuses to start if an exposed schema doesn't exist |
| functions | `supabase/edge-runtime:v1.74.3` | Serves the app's `supabase/functions/` at `/functions/v1/<name>`, verifying JWTs like the platform |
| gateway | `nginx` | One port, laid out like a Supabase URL. Adds CORS for `/auth/v1` and `/functions/v1` |

Not included: Studio, Storage, Realtime. No Brew app needs them to run.

Things learned getting this to work, kept in the files:

- **CORS.** GoTrue doesn't answer browser preflights (on the platform, Kong
  does), so a web app on another origin fails every sign-in with "Failed to
  fetch" until the gateway adds the headers.
- **Content-Security-Policy.** An app whose `web/index.html` sets
  `connect-src 'self' https:` can't reach a plain-http backend.
  `http://localhost:*` and `http://127.0.0.1:*` must be allowed for local
  stacks; real servers should use https.
- **Function dependencies** resolve through a `deno.json` with an `imports`
  map in `supabase/functions/` (the runtime walks up from each function). A
  legacy `import_map.json` alone is ignored.
- **Docker bind mounts of single files** keep the old file when it's
  replaced. After `sync.sh`, recreate the containers
  (`docker compose up -d --force-recreate`).

## The web image

Built from an already-built bundle (`flutter build web --release`, no
`--dart-define`), because Flutter has no linux-arm64 SDK and building inside
Docker on Apple Silicon means emulating x86 for tens of minutes. CI builds the
bundle on x86 and publishes the image for amd64 and arm64.

At start, `40-brew-config.sh` writes `/config.json` from `SUPABASE_URL` and
`SUPABASE_ANON_KEY`; brew_core's `loadBrewConfig()` reads it. With neither
set there's no config.json (a real 404), and the app asks for a backend.

## Releases

`.github/workflows/flutter-release.yml` is reusable. An app calls it with its
name and platforms; on a `v*` tag it publishes a GitHub Release (APK,
Windows/Linux zip or tarball, unsigned macOS app, web zip) and pushes
`ghcr.io/bufferbrew/<app>-web`. On a pull request it only builds. Native
builds bake in a default backend when the app repo has the
`RELEASE_SUPABASE_URL` / `RELEASE_SUPABASE_ANON_KEY` secrets.

`images.yml` publishes `ghcr.io/bufferbrew/brew-migrate:<tag>` the same way.
