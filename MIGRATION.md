# Migration

What changes for an app that moves its own copy of this code to LarperKit. Each line is a task
for that move; larperCord's move is the reference, since most of the code came from it.

## Themes (`src/theme/`)

| Before (larperCord) | After (LarperKit) |
| --- | --- |
| `@import("builtin_themes")`, a module made by the build | `lk.bases.embutidos = &list` at startup, before loading themes (`lk.bases.Builtin`) |
| the component table in `schema.zig` | `lk.schema.registrar(&ext)` at startup, with `lk.schema.Extensao{ .componentes, .filhos, .partes, .previews }`; see `src/theme/exemplo_cord.zig` |
| `schema.Preview` (an enum of thumbnails) | `.previews` in the extension; `theme_manager.Preview.kind` is now the string from `preview=` |
| `schema.components` | `lk.schema.componentes()` (an iterator: the kit's, then each app's) |
| `parts.Part`, `parts.States`, `parts.partes`, `parts.estados` | the app's own types and tables, passed to `lk.parts.Partes(Part, States, &estados, &partes)`, registered through `.partes = &P.conjunto` |
| `theme.parts.?.get(.message, .{ .hover = true })` | `P.get(theme.parts, .message, .{ .hover = true })` |
| `parts.hasState`, `parts.hasProp` | `P.hasState`, `P.hasProp` |
| `theme.has_user_panel`, `theme.has_member_list` | `theme.has("user-panel")`, `theme.has("member-list")` (resolved when the theme loads) |
| `"larpercord"` in paths (themes folder, config folder) | `lk.app.pasta = "larpercord"` at startup |
| `"needs a newer larperCord"` | `lk.app.nome = "larperCord"` at startup |
| `"larpercord-theme"` and `"larpercord"` in the theme LSP | built from `lk.app.pasta` |
| `src/c.h` | the kit's `c` module has SDL3, Dear ImGui and the libc headers it uses; an app with more C keeps its own and replaces the kit's with `addImport("c", …)` on the `larperkit` module |
