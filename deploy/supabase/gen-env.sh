#!/usr/bin/env bash
# Prints fresh secrets for the self-hosted Supabase stack, as .env lines:
#
#   deploy/supabase/gen-env.sh >> .env
#
# ANON_KEY and SERVICE_ROLE_KEY are HS256 JWTs signed with JWT_SECRET, which
# is what Supabase clients and PostgREST expect. The anon key is public (it
# goes to every browser via config.json); keep the rest secret.
set -euo pipefail

rand() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$1"; }
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

jwt() {
  local role=$1 secret=$2 now exp header payload sig
  now=$(date +%s)
  exp=$((now + 10 * 365 * 24 * 3600))   # ten years; rotate by re-running
  header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '{"role":"%s","iss":"supabase","iat":%d,"exp":%d}' "$role" "$now" "$exp" | b64url)
  sig=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -hmac "$secret" -binary | b64url)
  printf '%s.%s.%s' "$header" "$payload" "$sig"
}

secret=$(rand 48)
echo "POSTGRES_PASSWORD=$(rand 32)"
echo "JWT_SECRET=$secret"
echo "ANON_KEY=$(jwt anon "$secret")"
echo "SERVICE_ROLE_KEY=$(jwt service_role "$secret")"
echo "TOKEN_ENCRYPTION_KEY=$(rand 48)"
