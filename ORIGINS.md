# Origins

Where every file in this repository came from, so fixes can be ported in both directions.
Files not listed here were written for LarperKit.

To see what changed upstream since a file was copied, run `git diff <commit>..<newer> -- <path>`
in the source repository.

## larperCord

[larperCord](https://github.com/RshaCuDeVidro/larperCord), branch `int/0.7`. Paths are the same
in both repositories.

### `ac44662` (2026-11-24)

`ac446623500de1b10f0882804a2af7cd76a20504`. These files are identical in `b5b3fc2`.

| Path | Notes |
| --- | --- |
| `src/theme/bases.zig` | |
| `src/theme/color.zig` | |
| `src/theme/custom.zig` | |
| `src/theme/fx.zig` | |
| `src/theme/heranca.zig` | |
| `src/theme/kdl.zig` | |
| `src/theme/layout.zig` | |
| `src/theme/lsp_tema.zig` | |
| `src/theme/manager.zig` | |
| `src/theme/parts.zig` | |
| `src/theme/path.zig` | |
| `src/theme/schema.zig` | |
| `src/theme/theme.zig` | |
| `src/ui/anim.zig` | |
| `src/ui/backdrop.zig` | |
| `src/ui/bidi.zig` | |
| `src/ui/draw.zig` | |
| `src/ui/fx.zig` | |
| `src/ui/i18n.zig` | |
| `src/ui/i18n_pasta.zig` | |
| `src/ui/procgen.zig` | |
| `src/platform/vigia.zig` | |
| `src/core/embutido.zig` | |
| `src/core/i18n_cabecalho.zig` | |
| `src/core/lsp.zig` | |
| `src/net/jsonx.zig` | |
| `tools/comprimir.zig` | |
| `third_party/fribidi/` | GNU FriBidi, as vendored by larperCord |

### `b5b3fc2` (2026-11-24)

`b5b3fc20cd13ab2ab0ad252c2688bf219168cf2d`. Includes the merges of larperCord PRs #48 and #31
(`src/ui/fonts.zig`).

| Path | Notes |
| --- | --- |
| `src/ui/camada.zig` | |
| `src/ui/carimbo.zig` | |
| `src/ui/display_text.zig` | |
| `src/ui/dropdown.zig` | |
| `src/ui/font_blocks.zig` | |
| `src/ui/font_metrics.cpp` | |
| `src/ui/font_names.zig` | |
| `src/ui/fonts.zig` | |
| `src/ui/fuzzy.zig` | |
| `src/ui/i18n_xx.kdl` | |
| `src/ui/icons.zig` | |
| `src/ui/ime.zig` | |
| `src/ui/parts.zig` | |
| `src/ui/plugin_confirm.zig` | |
| `src/ui/plugin_panel.zig` | |
| `src/ui/plugins_page.zig` | |
| `src/ui/qa.zig` | |
| `src/ui/quadro.zig` | |
| `src/ui/syntax.zig` | |
| `src/ui/tint.zig` | |
| `src/ui/wallpaper.zig` | |
| `src/ui/wallpaper_fit.zig` | |
| `src/ui/widgets.zig` | |
| `src/inspect/captura.zig` | |
| `src/inspect/ganchos.cpp` | the ImGui item hooks `captura.zig` reads |
| `src/platform/apagar.zig` | |
| `src/platform/fc_warm.zig` | |
| `src/platform/fsutil.zig` | |
| `src/platform/sys.zig` | |
| `src/core/plain_letters.zig` | |
| `src/core/sort.zig` | |
| `src/plugins/engine.zig` | |
| `src/plugins/host.zig` | |
| `src/plugins/http_curl.zig` | |
| `src/plugins/http_policy.zig` | |
| `src/plugins/json.zig` | |
| `src/plugins/loc.zig` | |
| `src/plugins/lua.zig` | |
| `src/plugins/manifest.zig` | |
| `src/plugins/panel.zig` | |
| `src/plugins/runtime.zig` | |
| `src/plugins/sync.zig` | |
| `src/plugins/wire.zig` | |
| `src/plugins/testdata/` | |
| `third_party/imgui/` | Dear ImGui with the changes marked `[larperCord]` |
| `third_party/dcimgui/` | Dear Bindings (C API of Dear ImGui) |
| `third_party/lua/` | Lua 5.4 |
| `third_party/stb/` | stb_image and friends |

### Test fixtures

`src/theme/example_cord.zig` registers larperCord's components, parts and thumbnails the way
an app does, so the theme tests run against a real app. Its tables were moved out of
`src/theme/schema.zig` and `src/theme/parts.zig` (`ac44662`). `src/theme/example_cord/classico.kdl`
and `zen.kdl` are `themes/classico.kdl` and `themes/zen.kdl` from `b5b3fc2`.

`src/ui/example_i18n/ja.kdl` and `ru.kdl` hold the entries of larperCord's `i18n/ja.kdl` and
`i18n/ru.kdl` (`b5b3fc2`) that the tests in `src/ui/i18n.zig` use, plus some more Japanese ones;
`keys.txt` lists the keys of `ja.kdl`.

## WooferSoundPad

[WooferSoundPad](https://github.com/RshaCuDeVidro/WooferSoundPad), branch `main`.

### `c0cb5b3` (2026-10-24)

`c0cb5b305f8a7f28112ca29ef3545b7f8eb69658`.

| Path here | Path there | Notes |
| --- | --- | --- |
| `src/woofer/ui.zig` | `src/ui.zig` | Component API and behavior; the raylib drawing stays behind |
| `src/woofer/LICENSE` | `LICENSE` | MIT, Copyright (c) 2026 RshaCuDeVidro |

`src/woofer/ui.zig` is MIT-licensed (see `src/woofer/LICENSE`). It is reference material and is
not part of the build while it depends on raylib.
