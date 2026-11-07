#!/usr/bin/env bash
# Builds a Brew app's launcher icons from its glyph and accent.
#
#   make-icon.sh --glyph assets/branding/glyph.svg --accent '#7DD3FC' \
#                [--background '#060811'] [--out assets/branding]
#
# The glyph is the app's own artwork: white line art with neon accents on a
# transparent background, square (SVG preferred, or PNG >= 640px). Everything
# else — canvas, ink background, accent glow, safe-zone placement, rounding —
# comes from template.svg, so every Brew icon is built the same way.
#
# Writes into --out:
#   app_icon.png             1024 full bleed: Android legacy, iOS, web, desktop
#   app_icon_foreground.png  1024 glyph only, transparent: Android adaptive
#   app_icon_rounded.png     512 rounded square: in-app BrewAppMark, docs
# and prints the flutter_launcher_icons.yaml to drop into the app root.
#
# Needs rsvg-convert (brew install librsvg).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
glyph="" accent="" background="#060811" out="assets/branding"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --glyph) glyph="$2"; shift 2 ;;
    --accent) accent="$2"; shift 2 ;;
    --background) background="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

hex='^#[0-9A-Fa-f]{6}$'
[[ -f "$glyph" ]] || { echo "--glyph: no such file: $glyph" >&2; exit 2; }
[[ "$accent" =~ $hex ]] || { echo "--accent must be #RRGGBB" >&2; exit 2; }
[[ "$background" =~ $hex ]] || { echo "--background must be #RRGGBB" >&2; exit 2; }
command -v rsvg-convert >/dev/null || {
  echo "rsvg-convert not found: brew install librsvg" >&2; exit 1; }

case "$glyph" in
  *.svg|*.SVG) mime="image/svg+xml" ;;
  *.png|*.PNG) mime="image/png" ;;
  *) echo "--glyph must be .svg or .png" >&2; exit 2 ;;
esac
href="data:$mime;base64,$(base64 < "$glyph" | tr -d '\n')"

mkdir -p "$out"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# render NAME RADIUS BG_OPACITY RIM SIZE
render() {
  local rim=""
  if [[ "$4" == rim ]]; then
    rim="<rect x=\"8\" y=\"8\" width=\"1008\" height=\"1008\" rx=\"$(( $2 - 8 ))\" fill=\"none\" stroke=\"$accent\" stroke-opacity=\"0.35\" stroke-width=\"16\"/>"
  fi
  sed -e "s|{{BACKGROUND}}|$background|g" \
      -e "s|{{ACCENT}}|$accent|g" \
      -e "s|{{GLOW}}|0.22|g" \
      -e "s|{{RADIUS}}|$2|g" \
      -e "s|{{BG_OPACITY}}|$3|g" \
      -e "s|{{GLYPH_SIZE}}|636|g" \
      -e "s|{{GLYPH_X}}|194|g" \
      -e "s|{{RIM}}|$rim|" \
      "$here/template.svg" > "$tmp/$1.svg"
  # The glyph data URI is too long for sed's command line; splice it last.
  local svg; svg="$(cat "$tmp/$1.svg")"
  printf '%s' "${svg//\{\{GLYPH_HREF\}\}/$href}" > "$tmp/$1.svg"
  rsvg-convert -w "$5" -h "$5" "$tmp/$1.svg" -o "$out/$1.png"
}

render app_icon 0 1 none 1024
render app_icon_foreground 0 0 none 1024
render app_icon_rounded 230 1 rim 512

echo "Wrote $out/app_icon.png, app_icon_foreground.png, app_icon_rounded.png" >&2
sed -e "s|{{BACKGROUND}}|$background|g" -e "s|{{OUT}}|$out|g" \
  "$here/flutter_launcher_icons.yaml.template"
