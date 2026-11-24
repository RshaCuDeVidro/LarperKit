# Migration

What changes for an app that moves its own copy of this code to LarperKit. Each line is a task
for that move; larperCord's move is the reference, since most of the code came from it.

## Themes (`src/theme/`)

| Before (larperCord) | After (LarperKit) |
| --- | --- |
| `@import("builtin_themes")`, a module made by the build | `lk.bases.builtins = &list` at startup, before loading themes (`lk.bases.Builtin`) |
| the component table in `schema.zig` | `lk.schema.register(&ext)` at startup, with `lk.schema.Extension{ .components, .children, .parts, .previews }`; see `src/theme/example_cord.zig` |
| `schema.Preview` (an enum of thumbnails) | `.previews` in the extension; `theme_manager.Preview.kind` is now the string from `preview=` |
| `schema.components` | `lk.schema.allComponents()` (an iterator: the kit's, then each app's) |
| `parts.Part`, `parts.States`, `parts.partes`, `parts.estados` | the app's own types and tables, passed to `lk.parts.PartSet(Part, States, &state_specs, &part_specs)`, registered through `.parts = &P.definition` |
| `theme.parts.?.get(.message, .{ .hover = true })` | `P.get(theme.parts, .message, .{ .hover = true })` |
| `parts.hasState`, `parts.hasProp` | `P.hasState`, `P.hasProp` |
| `theme.has_user_panel`, `theme.has_member_list` | `theme.has("user-panel")`, `theme.has("member-list")` (resolved when the theme loads) |
| `"larpercord"` in paths (themes folder, config folder) | `lk.app.folder = "larpercord"` at startup |
| `"needs a newer larperCord"` | `lk.app.name = "larperCord"` at startup |
| `"larpercord-theme"` and `"larpercord"` in the theme LSP | built from `lk.app.folder` |
| `src/c.h` | the kit's `c` module (`lk.c`) has SDL3, Dear ImGui and the libc headers it uses. An app with more C translates only its own extra headers and takes SDL3 and ImGui types from `lk.c`, so the kit's functions accept them |
| `third_party/imgui` and the SDL3 backends compiled by the app | the `larperkit` module compiles them and links SDL3. larperCord compiles its own ImGui (with FreeType) and links SDL3 its own way (static in releases), so it depends on the kit with `.imgui = false, .link_sdl = false` and keeps passing its ImGui include paths |

## Translations (`src/ui/i18n.zig`, `src/ui/i18n_pasta.zig`)

| Before (larperCord) | After (LarperKit) |
| --- | --- |
| `i18nModule` in `build.zig`, imported as `i18n_embutidos` | `@import("larperkit").translations(b, kit.builder, "i18n")` in the app's `build.zig`, imported under any name, then `lk.i18n.embed(@import("translations"))` at startup |
| `tools/comprimir.zig` in the app | the kit's (the build function uses it) |
| `"larpercord"` in the translations folder | `lk.app.folder` |

## Files (`src/platform/fsutil.zig`, `src/platform/apagar.zig`)

| Before (larperCord) | After (LarperKit) |
| --- | --- |
| `"larpercord"` in `fsutil.configPath` and `ensureDir` | `lk.app.folder` |
| `apagar.comecar` turning off `debug_log` | `apagar.ao_comecar = &desligaRegistro` |
| `apagar` removing the old token (`~/.config/larpercord/token`) | the app does it in `apagar.outros` (with `apagar.permitida`) |
| the keychain entries `larpercord-account`, `larpercord`, `larpercord-plugin` (and `larperCord/account/*`, `larperCord/plugin/*` on Windows) | `apagar.chaves = &.{ "account", "", "plugin" }` with `lk.app.name = "larperCord"` and `lk.app.folder = "larpercord"` |
| `"--apagar-resto"` | `apagar.flag_resto`; the app's command line still calls `apagar.resto(pid)` |

## Before larperCord switches

The kit's components must draw the same as larperCord, checked image to image: draw a page with
the components of a real larperCord screen (Settings → Chat has switches, buttons and a slider)
offscreen in the kit, and compare it with larperCord's QA capture of that screen, in the same
theme and at the same scale. It can't be done yet: the kit doesn't load larperCord's fonts until
the fonts move. larperCord's QA binary runs from a folder outside its worktree (its results go
to the current folder), and nothing is built or written in larperCord's worktree.

The test "os nomes do larperCord saem iguais" in `src/core/app.zig` must pass. With
`lk.app.name = "larperCord"` and `lk.app.folder = "larpercord"`, it checks byte by byte the
keychain entries and the folders the kit builds against the strings in larperCord `b5b3fc2`.
A different name means people lose their login, their plugin secrets and their settings on
update, and "Delete all data" leaves things behind. When the plugin runtime moves (its secrets
are `larpercord-plugin` and `larperCord/plugin/<plugin>/<key>`), its names join that test.

## Drawing (`src/ui/draw.zig` and friends)

| Before (larperCord) | After (LarperKit) |
| --- | --- |
| `d.Ctx` with `store`, `st`, `actions`, `stats`, `images`, `theme_name`, `theme_names`, `theme_index` | `lk.draw.Ctx` keeps only what drawing needs (`th`, `fonts`, `ui`, `mono`, `dl`, `fg`, `io`, `renderer`, `mouse`, `now_ms`, `win`, `hot`, `pip`); the app's context holds a `lk.draw.Ctx` and its own state, and gets back to itself with `@fieldParentPtr` |
| `ctx.act(…)`, `ctx.popup(…)`, `d.Stats` | stay in the app's context |
| `ctx.images.renderer` (in `ui/fx.zig`) | `ctx.renderer` |
| `ctx.fonts` (a `*fonts.Fonts`) | `ctx.fonts`, an optional `lk.draw.Fontes` (`ptr` + `findFn`) until the fonts move |
| `fonts.Weight`, `fonts.Family` | `lk.family.Weight`, `lk.family.Family` (also `lk.draw.Weight`, `lk.draw.Family`) |
| `ui/parts.zig`: `look(ctx, .message, s)`, `mark(r, .message, s)` | `look(ctx, P, .message, s)`, `mark(r, P, .message, s)` with the app's `P = lk.parts.PartSet(…)` |
| `-Dqa` (the `qa` build option of the app) | the app passes its own value on: `b.dependency("larperkit", .{ .qa = qa, … })`. The kit's default is the same as larperCord's (on in Debug only), but an app that changes its own must pass it, or its robot runs without the kit's marks, or a release ships with them |
| the Inspector recording in `inspect/captura.zig` (`kind`, rectangle, QA mark, part) | unchanged: the kit's drawing calls it exactly as before, so `ctl inspect el` and the Inspector card see the same elements |
| `third_party/fribidi` compiled by the app | compiled by the kit's module |

## Components (`src/ui/components.zig`, `src/ui/ids.zig`)

The default drawing of each component is copied line by line from larperCord; a theme with
`parts` changes it per state. It has not been compared image to image yet (see below). The app registers the kit's parts at startup: `lk.components.register()`.

| Before (larperCord) | After (LarperKit) |
| --- | --- |
| a number picked by hand in `d.hit(ctx, 27, r)` | `d.hit(ctx, lk.id("mic", 0), r)`: same signature (`usize`), the number comes from a name |
| `Page` in `ui/settings.zig` (`id`, `markText`, `font`, `title`, `line`, `heading`, `note`, `divider`, `toggle`, `toggleIf`, `slider`, `select`, `radio`, `segmented`, `button`, `buttonSoft`, `sameLine`) | `lk.components.Page`, with `.scope = lk.id("settings-voz", 0)` (one per page) instead of counting from 1 on every page; the toggle animation key no longer mixes in `ctx.st.settings.page` |
| `Page.swatches`, `Page.keyRow`, `Page.keyRowEditable`, `languageRows` | stay in the app (they know the app's colors, shortcuts and languages) |
| `noteOverflow`, `fitSize` in `ui/settings.zig` | `lk.components.noteOverflow`, `lk.components.fitSize` (the overflow counter moves with them) |
| `inbox.button`, `inbox.buttonWidth` | `lk.components.button(…, .{ .kind = .pill, .danger = … })`, `buttonWidth(ctx, label, .pill)`. It now leaves the QA mark `button:<label>` unless the caller passes `.mark = ""` (or its own key) |
| `inbox.wrapText` | `lk.components.wrapText` |
| `segments` in `ui/settings_voz.zig` | `lk.components.segmented(…, .{ .style = .plain, .tag = "voz-ruido" })`; `Page.segmented` is `.style = .smooth` (the two looks differ: animation, height, font fitting) |

Still to survey: the other button and switch variants spread through larperCord (about 50),
to tell the ones that differ on purpose (the mascot pill, the forum tag, the reminder chip stay
in the app) from the plain copies that can use these components.

## Names

The kit's public API is in English. The files that came from larperCord keep their names
(`heranca.zig`, `lsp_tema.zig`, `vigia.zig`…), so `git diff` between the two repositories keeps
working, but they are exported under English names: `lk.inheritance`, `lk.theme_lsp`,
`lk.i18n_folder`, `lk.watcher`, `lk.stamp` (`carimbo.zig`), `lk.layer` (`camada.zig`),
`lk.frame_stats` (`quadro.zig`), `lk.inspector` (`inspect/captura.zig`), `lk.embedded`
(`core/embutido.zig`). Comments stay in Portuguese.
