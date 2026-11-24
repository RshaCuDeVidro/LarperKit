# Changelog

Every version of LarperKit, newest first. The API still changes whenever an app needs it to:
pin a version in your `build.zig.zon` and read the **Breaking** list before moving to the next.

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
