<div align="center">

# LarperKit

**The shared base of my native apps: themes, components, plugins and translations, written once.**

Zig 0.17 · SDL3 · Dear ImGui · KDL · Lua 5.4

**English** · [Português](README.pt-BR.md)

</div>

> [!NOTE]
> Early days: nothing has moved here yet. The code still lives in [larperCord](https://github.com/RshaCuDeVidro/larperCord) and larperNotes, and comes over one piece at a time (see [Roadmap](#roadmap)). This is a kit for my own programs, so the API changes whenever one of them needs it to.

## Why

larperCord and larperNotes are built the same way. SDL3 opens the window, and Dear ImGui handles input, fonts and text fields. Each app draws its own interface on top, styled by a KDL theme file.

larperNotes started from a copy of larperCord's base, and the two copies have drifted apart. Notes' theme engine is 2,400 lines, and larperCord's is 8,100: schema, parts, a language server, vector shapes and wallpaper are all missing on the Notes side. Every fix has to be carried over by hand, and most never are.

LarperKit keeps that base in one place. An app imports it and gets themes, components and plugins. The app writes only what is its own: its screens, the components its themes can style, and what its plugins are allowed to do.

## What goes in

- **Themes.** KDL theme files described by one schema. That schema checks a theme on load (warnings with line and column, and suggestions for typos) and powers `--theme-check` and a language server for editors. Themes get `extends` and `vars`, parts with states (`part "button:hover"`), vector shapes, procedural backgrounds and a local wallpaper. Each app registers its own components in the schema.
- **Components.** Button, icon button, toggle, slider, segmented control, dropdown, tooltip, toast, modal, menu, scroll area and text field.
  - Each one takes its look from the theme, follows the single UI scale factor and works right to left.
  - Each one gets its id from a name (`id("save", i)`) instead of a hand-picked number, in the style of [WooferSoundPad](https://github.com/RshaCuDeVidro/WooferSoundPad).
  - Each one reports itself to the Inspector and leaves a mark for the visual tests, so a new screen is testable from day one.
- **Idle by default.** Nothing is drawn while nothing changes, and an animation asks for frames only while it moves.
- **Plugins.** The Lua 5.4 runtime: the sandbox, manifests, permissions, HTTP with per-host rules, secrets in the system keychain, translated labels and the plugin panel. The app decides which functions its plugins get.
- **Translations.** Languages come from `.kdl` files, with plural forms, live reload and a coverage count per language.
- **Text.** Fonts with per-script fallback to the system's fonts, plus the patched Dear ImGui (right-to-left text, input methods and the font changes) that both apps build on.
- **Gallery.** A small app that draws every component in every theme: light and dark, at other scales, and right to left. It is both the demo and the target of the visual tests, so the kit tests itself without opening an app.

## Planned API

A sketch of where this is going. None of it compiles yet.

```zig
const lk = @import("larperkit");

fn settingsPage(ui: *lk.Ui, s: *Settings) void {
    if (ui.button(lk.id("save", 0), "Save", .{ .kind = .primary })) s.save();
    ui.toggle(lk.id("compact", 0), "Compact mode", &s.compact);
    for (s.accounts, 0..) |_, i| {
        if (ui.iconButton(lk.id("remove-account", i), .trash, .{ .kind = .danger })) s.remove(i);
    }
}
```

The same components in a theme:

```kdl
parts {
    part "button:hover" bg="@accent" radius=6
    part "toggle.knob:on" color="@accent"
}
```

## Roadmap

- [ ] **Core:** the theme engine, ids, animation, drawing and translations, taken from larperCord's current code.
- [ ] **larperNotes** switches to the core and drops its own copies.
- [ ] **Components** and the gallery.
- [ ] **Plugin runtime.**
- [ ] **Fonts** and the patched Dear ImGui.
- [ ] **larperCord** switches over one module at a time, after its 0.7 release.

## License

GPL-3.0, the same as larperCord, since most of the code comes from it.
