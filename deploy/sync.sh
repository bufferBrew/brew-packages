#!/usr/bin/env bash
# Copies brew-packages' deployment files into a Brew app repo:
#
#   deploy/sync.sh ../../brew/BrewWire            # write
#   deploy/sync.sh --check ../../brew/BrewWire    # exit 1 if out of date
#
# Writes <app>/deploy/web/ and <app>/deploy/supabase/ (the web image and the
# self-hosted Supabase stack). The app's own compose.yml, .env.example and
# supabase/bundle/ stay the app's. Edit the files here, never in an app.
set -euo pipefail

CHECK=0
[[ "${1:-}" == "--check" ]] && { CHECK=1; shift; }
app="${1:?usage: deploy/sync.sh [--check] <app-repo>}"
src="$(cd "$(dirname "$0")" && pwd)"
[[ -d "$app/.git" ]] || { echo "not a git repo: $app" >&2; exit 2; }

stale=0
for part in web supabase; do
  if ! diff -rq "$src/$part" "$app/deploy/$part" >/dev/null 2>&1; then
    stale=1
    if (( CHECK )); then
      echo "stale: $app/deploy/$part"
    else
      rm -rf "$app/deploy/$part"
      mkdir -p "$app/deploy"
      cp -R "$src/$part" "$app/deploy/$part"
      echo "updated: $app/deploy/$part"
    fi
  fi
done
(( CHECK )) && exit $stale
exit 0
