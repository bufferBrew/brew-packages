-- core 0001 — the cross-app contract layer every Brew app shares.
--
-- Baseline of the `core` schema as it stands on the shared project in
-- 2026-10, generated from that database's catalog rather than by replaying
-- BREW's migrations 0040–0050, which are tangled up with BREW's own tables
-- (backfills, cutovers, renames). History of how each piece came to be lives
-- in those BREW migrations; this file is what a fresh install needs.
--
-- Idempotent: safe on an empty Supabase database, and safe to re-run. Apps
-- install it through brew-migrate before their own bundle, so it may arrive
-- several times on a shared database; the second run changes nothing.
--
-- Requires Supabase: the auth schema (auth.users, auth.uid()) and the anon /
-- authenticated / service_role roles.
--
-- Secrets: encrypted columns use pgp_sym_encrypt with a key passed in by the
-- caller (the Edge Functions' TOKEN_ENCRYPTION_KEY). The key is never stored
-- in the database, and every function that touches it is service_role only.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists core;

-- ── Types ────────────────────────────────────────────────────────────────────

do $$ begin
  create type core.llm_provider as enum
    ('anthropic', 'openai', 'google', 'deepseek', 'openrouter', 'custom');
exception when duplicate_object then null;
end $$;

-- ── Tables ───────────────────────────────────────────────────────────────────
-- Ordered so every foreign key's target exists first.

create table if not exists core.apps (
  app          text        primary key,
  display_name text        not null,
  icon         text,
  repo_url     text,
  enabled      boolean     not null default true,
  sort_order   integer     not null default 100,
  created_at   timestamptz not null default now(),
  description  text        not null default ''
);
-- Added after the table's first version (BREW 0050); keeps older installs in
-- step.
alter table core.apps add column if not exists description text not null default '';

create table if not exists core.connectors (
  provider     text        primary key,
  display_name text        not null,
  kind         text        not null default 'api_key'
                           check (kind in ('oauth', 'api_key')),
  icon         text        not null default '',
  help_url     text        not null default '',
  fields       jsonb       not null default '[]'::jsonb,
  enabled      boolean     not null default true,
  sort_order   integer     not null default 100,
  created_at   timestamptz not null default now()
);

create table if not exists core.app_api_keys (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users(id) on delete cascade,
  app          text        not null,
  api_key      bytea       not null,
  status       text        not null default 'active'
                           check (status in ('active', 'revoked')),
  last_used_at timestamptz,
  created_at   timestamptz not null default now(),
  constraint app_api_keys_user_id_app_name_key unique (user_id, app)
);

create table if not exists core.app_events (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  app_key_id  uuid        references core.app_api_keys(id) on delete set null,
  app         text        not null
                          references core.apps(app) on update cascade on delete cascade,
  event_type  text        not null,
  payload     jsonb       not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create table if not exists core.app_state (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  app        text        not null
                         references core.apps(app) on update cascade on delete cascade,
  key        text        not null,
  payload    jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, app, key)
);

create table if not exists core.user_prefs (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  app        text        not null
                         references core.apps(app) on update cascade on delete cascade,
  key        text        not null,
  value      text        not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, app, key)
);

create table if not exists core.llm_configs (
  id                uuid              primary key default gen_random_uuid(),
  user_id           uuid              not null references auth.users(id) on delete cascade,
  provider          core.llm_provider not null,
  slug              text              not null default '',
  api_key_encrypted bytea             not null,
  key_hint          text              not null default '',
  base_url          text              not null default '',
  label             text              not null default '',
  is_default        boolean           not null default false,
  created_at        timestamptz       not null default now(),
  updated_at        timestamptz       not null default now(),
  unique (user_id, provider, slug)
);

create table if not exists core.llm_task_models (
  user_id    uuid              not null references auth.users(id) on delete cascade,
  app        text              not null
                               references core.apps(app) on update cascade on delete cascade,
  task       text              not null check (length(task) between 1 and 64),
  provider   core.llm_provider not null,
  slug       text              not null default '',
  model      text              not null default '',
  updated_at timestamptz       not null default now(),
  primary key (user_id, app, task)
);

create table if not exists core.connections (
  id                uuid        primary key default gen_random_uuid(),
  user_id           uuid        not null references auth.users(id) on delete cascade,
  provider          text        not null
                                references core.connectors(provider) on delete cascade,
  account_id        text        not null default '',
  account_label     text        not null default '',
  status            text        not null default 'active'
                                check (status in ('active', 'disconnected', 'error')),
  secrets_encrypted bytea       not null,
  secret_hints      jsonb       not null default '{}'::jsonb,
  metadata          jsonb       not null default '{}'::jsonb,
  scopes            text[]      not null default '{}',
  last_synced_at    timestamptz,
  last_error        text        not null default '',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (user_id, provider, account_id)
);

-- ── Indexes ──────────────────────────────────────────────────────────────────

create index if not exists app_events_app_idx               on core.app_events (app);
create index if not exists app_events_app_key_id_idx        on core.app_events (app_key_id);
create index if not exists app_events_user_app_occurred_idx on core.app_events (user_id, app, occurred_at desc);
create index if not exists app_state_app_idx                on core.app_state (app);
create index if not exists app_state_user_app_idx           on core.app_state (user_id, app);
create index if not exists user_prefs_app_idx               on core.user_prefs (app);
create index if not exists llm_configs_user_idx             on core.llm_configs (user_id);
-- At most one default key per user.
create unique index if not exists llm_configs_one_default_idx on core.llm_configs (user_id) where is_default;
create index if not exists llm_task_models_app_idx          on core.llm_task_models (app);
create index if not exists connections_provider_idx         on core.connections (provider);
create index if not exists connections_user_provider_idx    on core.connections (user_id, provider);

-- ── Row-level security ───────────────────────────────────────────────────────
-- auth.uid() is wrapped in a scalar subquery so Postgres evaluates it once per
-- statement (InitPlan) rather than per row (BREW 0046).

alter table core.apps            enable row level security;
alter table core.connectors      enable row level security;
alter table core.app_api_keys    enable row level security;
alter table core.app_events      enable row level security;
alter table core.app_state       enable row level security;
alter table core.user_prefs      enable row level security;
alter table core.llm_configs     enable row level security;
alter table core.llm_task_models enable row level security;
alter table core.connections     enable row level security;

-- Registries: readable by any signed-in user (anonymous sessions included);
-- only service_role writes them.
drop policy if exists read_all on core.apps;
create policy read_all on core.apps for select to authenticated using (true);
drop policy if exists read_all on core.connectors;
create policy read_all on core.connectors for select to authenticated using (true);

-- app_api_keys: no policy at all. Service role only.

drop policy if exists owner_select on core.app_events;
create policy owner_select on core.app_events for select to authenticated
  using ((select auth.uid()) = user_id);
drop policy if exists owner_insert on core.app_events;
create policy owner_insert on core.app_events for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists owner_all on core.app_state;
create policy owner_all on core.app_state for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists owner_all on core.user_prefs;
create policy owner_all on core.user_prefs for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists owner_all on core.llm_configs;
create policy owner_all on core.llm_configs for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists owner_all on core.llm_task_models;
create policy owner_all on core.llm_task_models for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists owner_all on core.connections;
create policy owner_all on core.connections for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ── Privileges ───────────────────────────────────────────────────────────────
-- Start from nothing and grant exactly what each role needs. Supabase's
-- default privileges otherwise hand anon/authenticated TRUNCATE, TRIGGER and
-- REFERENCES on every new table.

grant usage on schema core to anon, authenticated, service_role;
revoke all on all tables in schema core from anon, authenticated;
grant all on all tables in schema core to service_role;

grant select on core.apps, core.connectors to authenticated;
grant select, insert on core.app_events to authenticated;
grant select, insert, update, delete
  on core.app_state, core.user_prefs, core.llm_task_models to authenticated;

-- Credential tables: clients may list and delete their own rows but never
-- read the encrypted column. Writes go through the service-role functions
-- below, called by the core-* Edge Functions.
grant select (id, user_id, provider, slug, key_hint, base_url, label,
              is_default, created_at, updated_at)
  on core.llm_configs to authenticated;
grant delete on core.llm_configs to authenticated;
grant select (id, user_id, provider, account_id, account_label, status,
              secret_hints, metadata, scopes, last_synced_at, last_error,
              created_at, updated_at)
  on core.connections to authenticated;
grant delete on core.connections to authenticated;

-- ── Functions ────────────────────────────────────────────────────────────────
-- All SECURITY DEFINER with a pinned search_path, all service_role only.

create or replace function core.create_app_api_key(p_app text, p_user_id uuid, p_enc_key text)
returns text
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
declare
  v_key text;
begin
  v_key := p_app || '_' || encode(extensions.gen_random_bytes(32), 'hex');

  insert into core.app_api_keys (user_id, app, api_key)
  values (p_user_id, p_app, extensions.pgp_sym_encrypt(v_key, p_enc_key))
  on conflict (user_id, app) do update set
    api_key    = extensions.pgp_sym_encrypt(v_key, p_enc_key),
    status     = 'active',
    created_at = now();

  return v_key;
end;
$function$;

create or replace function core.authenticate_app_api_key(p_app text, p_key text, p_enc_key text)
returns table(user_id uuid, key_id uuid)
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
declare
  v_rec       record;
  v_decrypted text;
begin
  for v_rec in
    select k.id, k.user_id, k.api_key
    from   core.app_api_keys k
    where  k.app    = p_app
      and  k.status = 'active'
  loop
    begin
      v_decrypted := extensions.pgp_sym_decrypt(v_rec.api_key, p_enc_key);
    exception when others then
      v_decrypted := null;
    end;

    if v_decrypted = p_key then
      update core.app_api_keys set last_used_at = now() where id = v_rec.id;
      return query select v_rec.user_id, v_rec.id;
      return;
    end if;
  end loop;

  return;
end;
$function$;

create or replace function core.upsert_llm_config(
  p_user_id uuid, p_enc_key text, p_provider core.llm_provider, p_api_key text,
  p_slug text default '', p_label text default '', p_base_url text default '',
  p_make_default boolean default false)
returns void
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
declare
  v_first boolean;
begin
  select count(*) = 0 into v_first
  from core.llm_configs where user_id = p_user_id;

  if p_make_default or v_first then
    update core.llm_configs set is_default = false, updated_at = now()
    where user_id = p_user_id and is_default;
  end if;

  insert into core.llm_configs as c (
    user_id, provider, slug, api_key_encrypted, key_hint,
    base_url, label, is_default
  )
  values (
    p_user_id,
    p_provider,
    coalesce(p_slug, ''),
    pgp_sym_encrypt(p_api_key, p_enc_key),
    right(p_api_key, 4),
    coalesce(p_base_url, ''),
    coalesce(p_label, ''),
    p_make_default or v_first
  )
  on conflict (user_id, provider, slug) do update set
    api_key_encrypted = excluded.api_key_encrypted,
    key_hint          = excluded.key_hint,
    base_url          = excluded.base_url,
    label             = excluded.label,
    is_default        = excluded.is_default or c.is_default,
    updated_at        = now();
end;
$function$;

create or replace function core.set_default_llm_config(
  p_user_id uuid, p_provider core.llm_provider, p_slug text default '')
returns void
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
begin
  update core.llm_configs set is_default = false, updated_at = now()
  where user_id = p_user_id
    and is_default
    and not (provider = p_provider and slug = coalesce(p_slug, ''));

  update core.llm_configs set is_default = true, updated_at = now()
  where user_id = p_user_id
    and provider = p_provider
    and slug = coalesce(p_slug, '');

  if not found then
    raise exception 'no core.llm_configs row for provider % slug %',
      p_provider, coalesce(p_slug, '');
  end if;
end;
$function$;

create or replace function core.get_llm_config(
  p_user_id uuid, p_enc_key text,
  p_provider core.llm_provider default null, p_slug text default '')
returns table(provider core.llm_provider, slug text, api_key text, base_url text)
language sql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
  select
    c.provider,
    c.slug,
    pgp_sym_decrypt(c.api_key_encrypted, p_enc_key)::text,
    c.base_url
  from core.llm_configs c
  where c.user_id = p_user_id
    and (
      (p_provider is null and c.is_default)
      or (c.provider = p_provider and c.slug = coalesce(p_slug, ''))
    )
  order by c.is_default desc
  limit 1;
$function$;

create or replace function core.get_task_llm(
  p_user_id uuid, p_enc_key text, p_app text, p_task text)
returns table(provider core.llm_provider, slug text, model text, api_key text, base_url text)
language sql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
  with wanted as (
    select t.provider, t.slug, t.model
    from core.llm_task_models t
    where t.user_id = p_user_id and t.app = p_app and t.task = p_task
  ),
  picked as (
    select c.provider, c.slug, w.model, c.api_key_encrypted, c.base_url, 1 as tier
    from core.llm_configs c
    join wanted w on w.provider = c.provider and w.slug = c.slug
    where c.user_id = p_user_id

    union all

    select c.provider, c.slug, '', c.api_key_encrypted, c.base_url, 2 as tier
    from core.llm_configs c
    where c.user_id = p_user_id and c.is_default
  )
  select
    p.provider,
    p.slug,
    p.model,
    pgp_sym_decrypt(p.api_key_encrypted, p_enc_key)::text,
    p.base_url
  from picked p
  order by p.tier
  limit 1;
$function$;

create or replace function core.upsert_connection(
  p_user_id uuid, p_enc_key text, p_provider text, p_secrets jsonb,
  p_secret_hints jsonb default '{}'::jsonb, p_account_id text default '',
  p_account_label text default '', p_metadata jsonb default '{}'::jsonb,
  p_scopes text[] default '{}'::text[])
returns void
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
begin
  insert into core.connections as c (
    user_id, provider, account_id, account_label, status,
    secrets_encrypted, secret_hints, metadata, scopes
  )
  values (
    p_user_id,
    p_provider,
    coalesce(p_account_id, ''),
    coalesce(p_account_label, ''),
    'active',
    pgp_sym_encrypt(p_secrets::text, p_enc_key),
    coalesce(p_secret_hints, '{}'::jsonb),
    coalesce(p_metadata, '{}'::jsonb),
    coalesce(p_scopes, '{}')
  )
  on conflict (user_id, provider, account_id) do update set
    account_label     = case when excluded.account_label <> ''
                             then excluded.account_label else c.account_label end,
    status            = 'active',
    secrets_encrypted = excluded.secrets_encrypted,
    secret_hints      = excluded.secret_hints,
    metadata          = c.metadata || excluded.metadata,
    scopes            = excluded.scopes,
    last_error        = '',
    updated_at        = now();
end;
$function$;

create or replace function core.upsert_oauth_connection(
  p_user_id uuid, p_provider text, p_access_token text, p_refresh_token text,
  p_enc_key text, p_scopes text default null, p_account_id text default null,
  p_account_label text default null)
returns void
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
declare
  v_secrets jsonb;
  v_hints   jsonb;
  v_scopes  text[];
begin
  v_secrets := jsonb_strip_nulls(jsonb_build_object(
    'access_token',  p_access_token,
    'refresh_token', p_refresh_token
  ));
  v_hints := jsonb_strip_nulls(jsonb_build_object(
    'access_token',  case when p_access_token  is not null then right(p_access_token, 4)  end,
    'refresh_token', case when p_refresh_token is not null then right(p_refresh_token, 4) end
  ));
  v_scopes := case
    when p_scopes is null or btrim(p_scopes) = '' then '{}'::text[]
    else regexp_split_to_array(btrim(p_scopes), '\s+')
  end;

  insert into core.connections as c (
    user_id, provider, account_id, account_label, status,
    secrets_encrypted, secret_hints, scopes, last_synced_at
  )
  values (
    p_user_id,
    p_provider,
    coalesce(p_account_id, ''),
    coalesce(p_account_label, ''),
    'active',
    extensions.pgp_sym_encrypt(v_secrets::text, p_enc_key),
    v_hints,
    v_scopes,
    null
  )
  on conflict (user_id, provider, account_id) do update set
    status            = 'active',
    secrets_encrypted = excluded.secrets_encrypted,
    secret_hints      = excluded.secret_hints,
    scopes            = case
                          when excluded.scopes = '{}'::text[] then c.scopes
                          else excluded.scopes
                        end,
    account_label     = case
                          when coalesce(excluded.account_label, '') = '' then c.account_label
                          else excluded.account_label
                        end,
    last_error        = '',
    last_synced_at    = null,
    updated_at        = now();
end;
$function$;

create or replace function core.get_connection_secrets(
  p_user_id uuid, p_enc_key text, p_provider text, p_account_id text default null)
returns table(provider text, account_id text, account_label text,
              secrets jsonb, metadata jsonb, scopes text[])
language sql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
  select
    c.provider,
    c.account_id,
    c.account_label,
    pgp_sym_decrypt(c.secrets_encrypted, p_enc_key)::jsonb,
    c.metadata,
    c.scopes
  from core.connections c
  where c.user_id = p_user_id
    and c.provider = p_provider
    and c.status = 'active'
    and (p_account_id is null or c.account_id = p_account_id)
  order by (c.account_id = '') desc, c.updated_at desc
  limit 1;
$function$;

create or replace function core.get_connection_oauth(p_connection_id uuid, p_enc_key text)
returns table(provider text, access_token text, refresh_token text)
language sql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
  select
    c.provider,
    (extensions.pgp_sym_decrypt(c.secrets_encrypted, p_enc_key)::jsonb ->> 'access_token'),
    (extensions.pgp_sym_decrypt(c.secrets_encrypted, p_enc_key)::jsonb ->> 'refresh_token')
  from core.connections c
  where c.id = p_connection_id;
$function$;

create or replace function core.update_connection_tokens(
  p_connection_id uuid, p_access_token text, p_refresh_token text, p_enc_key text)
returns void
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
declare
  v_secrets jsonb;
begin
  select extensions.pgp_sym_decrypt(c.secrets_encrypted, p_enc_key)::jsonb
    into v_secrets
  from core.connections c
  where c.id = p_connection_id;

  if v_secrets is null then
    raise exception 'no core.connections row for %', p_connection_id;
  end if;

  v_secrets := v_secrets || jsonb_build_object('access_token', p_access_token);
  if p_refresh_token is not null then
    v_secrets := v_secrets || jsonb_build_object('refresh_token', p_refresh_token);
  end if;

  update core.connections set
    secrets_encrypted = extensions.pgp_sym_encrypt(v_secrets::text, p_enc_key),
    secret_hints      = secret_hints
                        || jsonb_build_object('access_token', right(p_access_token, 4))
                        || case
                             when p_refresh_token is not null
                             then jsonb_build_object('refresh_token', right(p_refresh_token, 4))
                             else '{}'::jsonb
                           end,
    updated_at        = now()
  where id = p_connection_id;
end;
$function$;

create or replace function core.set_connection_status(
  p_user_id uuid, p_provider text, p_account_id text, p_status text,
  p_error text default '')
returns void
language plpgsql security definer
set search_path to 'core', 'public', 'extensions'
as $function$
begin
  update core.connections set
    status     = p_status,
    last_error = coalesce(p_error, ''),
    updated_at = now()
  where user_id = p_user_id
    and provider = p_provider
    and (p_account_id is null or account_id = p_account_id);
end;
$function$;

revoke all on all functions in schema core from public, anon, authenticated;
grant execute on all functions in schema core to service_role;

-- ── Comments ─────────────────────────────────────────────────────────────────

comment on table core.apps is
  'Registry of Brew apps on this backend. Each app inserts its own row when it installs; apps read it to decide whether a cross-app link has a target.';
comment on column core.apps.description is
  'One-line card description for the Ecosystem screen. Blank is a valid, tolerated state.';
comment on table core.connectors is
  'Registry of connectable third-party services. Adding a connector is an INSERT here plus whatever Edge Function consumes it — never a migration.';
comment on table core.app_api_keys is
  'Encrypted API keys for apps that push events without a user session (e.g. a collector). No client surface — service role only.';
comment on column core.app_api_keys.api_key is
  'pgp_sym_encrypt encrypted API key; never returned to clients or via PostgREST.';
comment on table core.app_events is
  'Append-only cross-app event log. Written by apps under RLS, or by app-event-ingest via an app API key.';
comment on table core.app_state is
  'Latest snapshot per (user, app, key). Upserted by each app; read by dashboard widgets.';
comment on table core.user_prefs is
  'Per-user, per-app preference sync. Keyed by (user_id, app, key) so apps cannot overwrite each other.';
comment on table core.llm_configs is
  'Per-user LLM provider API keys, shared by every Brew app on this backend. Encrypted at rest; never returned to any client. Model choice lives in core.llm_task_models.';
comment on table core.llm_task_models is
  'Which provider+model each app uses for each of its own tasks. Carries no key material — the key is looked up from core.llm_configs by (provider, slug).';
comment on table core.connections is
  'Per-user third-party credentials, shared by every Brew app on this backend. Encrypted at rest; never returned to any client.';

-- ── Seed: connector catalogue ────────────────────────────────────────────────
-- The services the Brew apps know how to talk to. Existing rows are left
-- alone, so an operator's edits survive a re-run.

insert into core.connectors (provider, display_name, kind, icon, help_url, fields, sort_order) values
  ('notion', 'Notion', 'api_key', 'description', 'https://www.notion.so/my-integrations',
   '[{"key": "api_key", "hint": "ntn_…", "label": "Internal integration token", "secret": true, "required": true},
     {"key": "database_id", "help": "The 32-character id in your database URL", "label": "Database ID", "secret": false, "required": true}]', 10),
  ('todoist', 'Todoist', 'api_key', 'checklist', 'https://app.todoist.com/app/settings/integrations/developer',
   '[{"key": "api_key", "label": "API token", "secret": true, "required": true}]', 20),
  ('gmail', 'Gmail', 'oauth', 'mail', '', '[]', 30),
  ('github', 'GitHub', 'oauth', 'code', '', '[]', 40),
  ('google_calendar', 'Google Calendar', 'oauth', 'event', '', '[]', 50),
  ('youtube', 'YouTube', 'oauth', 'video', '', '[]', 55),
  ('google_drive', 'Google Drive', 'oauth', 'folder', '', '[]', 60),
  ('sports_api', 'API-Sports', 'api_key', 'sports', 'https://dashboard.api-sports.io/profile',
   '[{"key": "api_key", "help": "From your API-Sports dashboard under Profile. The same key works for every sport.", "hint": "32-character key", "label": "API key", "secret": true, "required": true}]', 70),
  ('news_api', 'News API', 'api_key', 'news', 'https://newsapi.org/account',
   '[{"key": "api_key", "label": "API key", "secret": true, "required": true}]', 80),
  ('bring', 'Bring!', 'api_key', 'shopping_cart', '',
   '[{"key": "email", "label": "Email", "secret": false, "required": true},
     {"key": "password", "label": "Password", "secret": true, "required": true}]', 90),
  ('strava', 'Strava', 'oauth', 'directions_run', '', '[]', 100),
  ('samsung_health', 'Samsung Health', 'oauth', 'activity', '', '[]', 115),
  ('myfitnesspal', 'MyFitnessPal', 'api_key', 'nutrition', '', '[]', 120)
on conflict (provider) do nothing;
