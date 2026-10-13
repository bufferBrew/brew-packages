#!/bin/sh
# Writes /config.json for brew_core's loadBrewConfig() from the container's
# SUPABASE_URL and SUPABASE_ANON_KEY. Runs on every start (nginx image's
# /docker-entrypoint.d hook), so changing the env and restarting repoints the
# app without a rebuild.
#
# The anon key is public by design (RLS protects the data). Never pass the
# service-role key here: this file is served to every visitor.
set -eu

out=/usr/share/nginx/html/config.json

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  rm -f "$out"
  echo "brew-config: SUPABASE_URL/SUPABASE_ANON_KEY not set; no config.json (the app will ask for a backend)"
  exit 0
fi

case "$SUPABASE_URL" in
  http://*|https://*) ;;
  *) echo "brew-config: SUPABASE_URL must start with http:// or https://" >&2; exit 1 ;;
esac

# JSON-escape backslashes and double quotes.
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

printf '{"SUPABASE_URL":"%s","SUPABASE_ANON_KEY":"%s"}\n' \
  "$(esc "$SUPABASE_URL")" "$(esc "$SUPABASE_ANON_KEY")" > "$out"
echo "brew-config: serving backend $SUPABASE_URL"
