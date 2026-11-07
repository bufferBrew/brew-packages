# Brew launcher icons

Every Brew app gets its own one-word name. The family resemblance comes from
the shared pieces instead, and the launcher icon is the one people see most.
So all Brew icons are built the same way, from the template here.

**The style:** a dark square (Brew ink `#060811`), a soft glow in the
app's accent colour, and the app's glyph in the middle. The glyph is white
line art with a few neon accents. Synapse's icon
(`Synapse/assets/branding/app_icon.png`, a brain opening into a book) is the
reference.

**What an app supplies:** a glyph and an accent. The template supplies the
canvas, background, glow, safe-zone placement and rounding.

## Making an app's icon

1. Draw the glyph: square, transparent background, white strokes about 5% of
   the width, two or three neon accent colours at most. Prefer SVG; a PNG
   needs to be at least 640px. Keep it in the app at
   `assets/branding/glyph.svg`. `example/glyph.svg` shows the expected shape.
2. From the app's root, with brew-packages checked out next to it:

   ```bash
   ../packages/branding/make-icon.sh --glyph assets/branding/glyph.svg \
     --accent '#A78BFA' > flutter_launcher_icons.yaml
   ```

   That writes `assets/branding/app_icon.png` (full bleed),
   `app_icon_foreground.png` (the glyph alone, for Android adaptive icons) and
   `app_icon_rounded.png` (for `BrewAppMark` and docs). The config it prints
   goes to `flutter_launcher_icons.yaml`, which is where the icon config lives.
   It doesn't go in `pubspec.yaml`.
3. `dart run flutter_launcher_icons`, then check the launcher on a device.
4. Use the same accent in the app's `BrewAppIdentity`.

Needs `rsvg-convert` (`brew install librsvg`).

## Why it's built this way

- **Full bleed.** `app_icon.png` is a plain square. Android, iOS and the
  web's maskable icons apply their own shape, so pre-rounding would give
  black corners inside the mask.
- **Glyph in the middle 62%.** Android's adaptive icon keeps only the central
  66% for sure. The foreground is the glyph alone on a transparent
  background, over a flat background colour, with
  `adaptive_icon_foreground_inset: 0`. A circle or squircle mask then cuts
  the background and never the glyph.
- **Accent as a glow, not a fill.** On a dark ground, the accent glow and the
  glyph's neon colours are what tell the apps apart.

## Accent backgrounds

Some apps use their accent as the whole background instead of the ink. Codex's
`codex/distinct-icon-backgrounds` branches do this: BREW `#7920D7`, BrewWire
`#064FDD`. The script supports it:

```bash
make-icon.sh --glyph … --accent '#7920D7' --background '#7920D7'
```

Ink or accent background is decided per app. Whichever you pick, keep the
glyph white, and keep the accents distinct across the family:

| App | Accent | Background |
|---|---|---|
| Synapse | `#A78BFA` (violet) | ink `#060811` |
| BREW | `#7920D7` | accent (Codex branch) |
| BrewWire | `#064FDD` | accent (Codex branch) |

Add a row when an app adopts the template.
