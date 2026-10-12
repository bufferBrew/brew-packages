# Brew database bundles

How a Brew app's database gets installed on a Supabase of your own, alone or
next to other Brew apps.

```
supabase/
  core/0001_core.sql    the shared `core` schema every Brew app uses
  migrate/brew-migrate  installs bundles and tracks what's applied
  migrate/Dockerfile    the same, as an image (bundles core inside)
```

Each app ships its own bundle in its repo at `supabase/bundle/` (for
example BrewWire's `0001_brewwire.sql`). A bundle creates the app's schema,
adds its signup trigger on `auth.users`, seeds its reference data, and
registers the app in `core.apps`.

## Install an app

```bash
DATABASE_URL=postgres://postgres:…@db.<ref>.supabase.co:5432/postgres \
  supabase/migrate/brew-migrate \
    core=<brew-packages>/supabase/core \
    wire=<BrewWire>/supabase/bundle
```

or, with nothing but Docker:

```bash
docker run --rm -e DATABASE_URL=postgres://… \
  -v "$PWD/supabase/bundle:/bundles/app" \
  ghcr.io/bufferbrew/brew-migrate core=/bundles/core wire=/bundles/app
```

Then expose the app's schema (and `core`) to the API, or every request fails
with `PGRST106`:

- **Hosted Supabase:** Project Settings → Data API → Exposed schemas.
- **Self-hosted / local:** add them to PostgREST's `db-schemas`
  (`PGRST_DB_SCHEMAS`, or `[api] schemas` in `supabase/config.toml`).
  PostgREST won't start if a listed schema doesn't exist yet, so install the
  bundles **before** adding the schemas, or run brew-migrate before the REST
  container starts.

## One database or several

Both work, and the choice is made by configuration only:

- **Shared:** point every app at the same Supabase. Each app has its own
  schema; `core` is shared; one `auth.users` account works in all of them
  (each bundle adds its own signup trigger and backfills existing users).
  Install apps in any order; core is installed once and skipped after.
- **Separate:** give each app its own Supabase. `core.apps` then lists only
  that app, so links to apps that aren't there hide themselves
  (`appAvailableProvider` in brew_core).

Apps never read each other's schema. Cross-app data goes through `core.*` or
over HTTP (e.g. a collector posting to BREW's `app-event-ingest`), which works
across databases too.

## How brew-migrate works

- Applies each `*.sql` in a directory in filename order, components in the
  order given. Core goes first; app bundles check for it.
- Records every file with its SHA-256 in `brew_meta.applied` (a schema no API
  role can see), keyed by (component, file). A file already applied is
  skipped; a file **changed** after it was applied is an error. Change a
  schema by adding `0002_….sql`, never by editing `0001`.
- Each file runs in one transaction with its ledger row. A session advisory
  lock stops two installs racing.
- Not the Supabase CLI ledger: that one is per-database, so on a shared
  database every app's `db push` fails on the other apps' versions.
- `--dry-run` lists what would run. `--baseline` records files as applied
  without running them: use it once on a database whose schemas already
  exist (the shared hosted project, built by each app's own migrations).

Bundle files must be idempotent (`if not exists`, guarded constraints,
`create or replace`, `on conflict do nothing`) and must not contain their own
`BEGIN`/`COMMIT`.

## Where `core` comes from

`core/0001_core.sql` was generated from the shared project's catalog on
2026-10-12, not replayed from BREW's migrations 0040–0050, which are tangled
up with BREW's own tables. It was checked against production by fingerprint:
columns, constraints, indexes and RLS are identical (136 entries, same hash),
and all 12 function bodies hash the same. The only differences are
deliberate:

- no `TRUNCATE`/`TRIGGER`/`REFERENCES` grants for `anon`/`authenticated`
  (Supabase's default privileges add them; nothing needs them);
- three owner policies say `to authenticated` instead of `to public`. That's
  equivalent in effect, because `anon` has no grants and `auth.uid()` is null
  for it.

The connector catalogue is seeded as BREW's repo intends it (YouTube in,
Google Maps out). Note that BREW's `0052_youtube` and the two migrations after
it hadn't been applied to the shared project when this was generated.

## Verified

On a local Supabase (CLI v2.115, Postgres 17), from empty:

- core, then BrewWire's bundle, install cleanly. Re-running is a no-op, both
  through brew-migrate and as raw SQL. An edited file is refused.
- Through the real Auth and REST APIs, with two users:
  - signup creates the `brewwire.users` row;
  - each user reads and writes only their own `brewwire.user_prefs`;
  - `rate_limits` is 403;
  - `core.apps` lists `wire`;
  - the 27 brief feeds are seeded.
