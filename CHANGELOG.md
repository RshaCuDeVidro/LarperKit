# Changelog

Every version of LarperKit, newest first. The API still changes whenever an app needs it to:
pin a version in your `build.zig.zon` and read the **Breaking** list before moving to the next.

## 0.1.5 (2026-11-25)

- **Fixed:** a drop shadow under a translucent (glass) card left a lighter square in each
  rounded corner, and a light strip under the card when `drop-shadow-y` is larger than the
  corner radius. The light triangle fixed in 0.1.3 really came from the fill between the
  card's rounded corner and the shadow: in two of the four corners it was drawn the wrong
  way around, and ImGui put part of it inside the card. It is now drawn the right way, and
  the corners and the strip are back for every card, glass or not.
- **Breaking:** `fx.dropShadow` no longer takes the `opaco` argument added in 0.1.3. No part
  of the shadow is drawn inside the card any more, so the card's background doesn't matter.

## 0.1.4 (2026-11-25)

- **Fixed:** `draw.tip` crashed when the tip was wider than the window (a panic in Debug and
  ReleaseSafe, undefined behavior in ReleaseFast). A tip now never goes past the window: long
  text breaks into lines (about 28 letters wide, less in a narrow window), a word that doesn't
  fit on a line by itself is cut with "…", and right-to-left text is aligned to the right. A
  short tip looks the same as before.
- **New:** `draw.breakLines` splits a text into lines that fit a width (at spaces; `\n` always
  breaks a line).
- `draw.tip` leaves the QA mark `tip`.

## 0.1.3 (2026-11-24)

- **New:** transparent windows for glass themes. `lk.window.Options.transparent` (on by
  default) creates the window with `SDL_WINDOW_TRANSPARENT`, and each frame is cleared with
  the theme's `bg` including its alpha, premultiplied. On Linux the compositor blurs what is
  behind (Hyprland does it on its own); on Windows the DWM shows the desktop. An opaque theme
  (`bg` with alpha 1) looks the same as before.
- **Fixed:** a drop shadow under a translucent card showed through it, as a light triangle in
  the bottom corners. The pieces of the shadow that fall inside the card are drawn only when
  the card's background is opaque.
- **Breaking:** `fx.dropShadow` takes a new last argument, `opaco`.

## 0.1.2 (2026-11-24)

- **Fixed:** building for Windows still failed in 0.1.1: the SDL3 headers were looked up under
  a folder that the downloaded package doesn't have.

## 0.1.1 (2026-11-24)

- **Fixed:** building for Windows failed with "hash mismatch" on the SDL3 package: 0.1.0 had
  the wrong hash in `build.zig.zon`.
- **Fixed:** `tools/sdl3_linux.sh` now builds SDL3 without X11 and Wayland (only the offscreen
  and dummy drivers), the way a CI machine has it.
- New build option `sdl_mingw`: the `x86_64-w64-mingw32` folder of an already extracted SDL3 for
  MinGW, for Windows builds without network.

## 0.1.0 (2026-11-24)

The first version an app can depend on.

- **Themes:** the theme engine from larperCord (KDL, schema with warnings and suggestions,
  `extends` and `vars`, parts with states, effects, procedural backgrounds, the theme LSP).
  Apps register their own components, parts, thumbnails and built-in themes at startup
  (`lk.schema.register`, `lk.bases.builtins`).
- **Translations:** languages from `.kdl` files, plural forms, live reload and coverage.
  `translations(b, kit.builder, "i18n")` in the app's `build.zig` embeds its files,
  and `lk.i18n.embed(@import("translations"))` hands them over.
- **Drawing:** `lk.draw` (primitives, text with right-to-left support, hit areas), effects,
  backgrounds, the Inspector recording and the QA marks.
- **Components:** button (primary, soft, pill), toggle, slider, segmented control and the
  form page (`lk.components.Page`), with the kit's theme parts and ids from names (`lk.id`).
- **Window:** `lk.window.run`, a loop that sleeps while nothing changes, and `lk.window.wake`
  to wake it from any thread.
- **Build:** the `larperkit` module brings Dear ImGui, the SDL3 backends, libc++ and SDL3
  (downloaded for Windows), and exports its C as `lk.c`. Options: `imgui`, `link_sdl`, `qa`.
