# Serves a Brew app's Flutter web bundle with nginx, pointed at any Supabase
# backend at container start.
#
# The bundle is built outside this image, on purpose: Flutter publishes no
# linux-arm64 SDK, so building inside a Linux image on Apple Silicon means
# emulating x86 for tens of minutes. Build it with Flutter (CI does this for
# releases), then this image is a ~25 MB static server for amd64 and arm64:
#
#   flutter build web --release            # no --dart-define: see below
#   docker build -f deploy/web/Dockerfile -t <app>-web .
#
# This directory is copied into every Brew app repo (deploy/web/) by
# brew/sync-deploy.sh from brew-packages; edit it there, not in an app.
#
# Backend: build WITHOUT --dart-define and pass SUPABASE_URL and
# SUPABASE_ANON_KEY to the container. 40-brew-config.sh writes them to
# /config.json on start, and brew_core's loadBrewConfig() reads it, so one
# image serves any backend. (A bundle built with dart-defines ignores
# config.json: build-time values win.)
#
# BUNDLE is the bundle's path inside the build context.

FROM nginx:1.27-alpine

ARG BUNDLE=build/web

COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY deploy/web/40-brew-config.sh /docker-entrypoint.d/40-brew-config.sh
RUN chmod 755 /docker-entrypoint.d/40-brew-config.sh
COPY ${BUNDLE} /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz >/dev/null || exit 1
