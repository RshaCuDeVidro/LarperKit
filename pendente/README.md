# Waiting to be ported

Code that came over in the snapshot (see [ORIGINS.md](../ORIGINS.md)) but doesn't compile in the
kit yet: it still depends on larperCord (its state, its network, its settings) or on a module that
hasn't moved yet. It is not part of the package (`build.zig.zon` doesn't list this folder) and
nothing builds it.

Each file keeps its path under `pendente/`, so it can be compared with larperCord, and moves back to
the same path outside this folder once it compiles and its tests run:

| Path | Waiting for |
| --- | --- |
| `src/plugins/`, `src/ui/plugin_*.zig`, `src/ui/plugins_page.zig`, `third_party/lua/` | the plugin runtime |
| `src/ui/fonts.zig`, `font_blocks.zig`, `font_names.zig`, `font_metrics.cpp`, `src/platform/fc_warm.zig`, `src/core/plain_letters.zig` | the fonts module |
| `src/ui/ime.zig` | the text field |
| `src/ui/widgets.zig`, `src/ui/dropdown.zig`, `src/ui/fuzzy.zig`, `src/ui/syntax.zig` | components |
| `src/ui/wallpaper.zig`, `third_party/stb/` | an image loader without larperCord's media cache |
| `src/woofer/` | reference only (WooferSoundPad's raylib toolkit, MIT): its API shaped the components |
