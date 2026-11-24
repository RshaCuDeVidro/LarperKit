//! LarperKit: a base comum dos apps (temas, desenho, animação, traduções).
const std = @import("std");

/// O C que o kit usa (SDL3, Dear ImGui, libc), traduzido: os componentes recebem tipos daqui
/// (`*c.ImDrawList`), então o app usa este em vez de traduzir os headers de novo.
pub const c = @import("c");

/// Quem é o app (o nome e a pasta das configurações): ele preenche ao abrir.
pub const app = @import("core/app.zig");

// --- Temas ---------------------------------------------------------------------------
pub const kdl = @import("theme/kdl.zig");
pub const color = @import("theme/color.zig");
pub const path = @import("theme/path.zig");
pub const theme = @import("theme/theme.zig");
pub const schema = @import("theme/schema.zig");
pub const parts = @import("theme/parts.zig");
pub const fx = @import("theme/fx.zig");
pub const layout = @import("theme/layout.zig");
pub const inheritance = @import("theme/heranca.zig");
pub const bases = @import("theme/bases.zig");
pub const custom = @import("theme/custom.zig");
pub const theme_lsp = @import("theme/lsp_tema.zig");
pub const theme_manager = @import("theme/manager.zig");
/// Exemplo de registro: os componentes, as partes e os temas do larperCord.
pub const example_cord = @import("theme/example_cord.zig");

// --- Traduções -----------------------------------------------------------------------
pub const i18n = @import("ui/i18n.zig");
pub const i18n_folder = @import("ui/i18n_pasta.zig");
pub const watcher = @import("platform/vigia.zig");

// --- Desenho ------------------------------------------------------------------------
pub const draw = @import("ui/draw.zig");
pub const family = @import("ui/family.zig");
pub const anim = @import("ui/anim.zig");
pub const procgen = @import("ui/procgen.zig");
/// Os efeitos do tema na tela (gradientes, padrões, sombras, formas: theme/fx.zig resolve).
pub const ui_fx = @import("ui/fx.zig");
pub const backdrop = @import("ui/backdrop.zig");
/// O desenho das partes do tema (theme/parts.zig resolve).
pub const ui_parts = @import("ui/parts.zig");
pub const display_text = @import("ui/display_text.zig");
pub const bidi = @import("ui/bidi.zig");
pub const icons = @import("ui/icons.zig");
pub const tint = @import("ui/tint.zig");
pub const stamp = @import("ui/carimbo.zig");
pub const layer = @import("ui/camada.zig");
pub const frame_stats = @import("ui/quadro.zig");
/// As contas do papel de parede (onde a imagem cai, o vidro dos painéis por cima).
pub const wallpaper_fit = @import("ui/wallpaper_fit.zig");
// --- Janela -------------------------------------------------------------------------
/// A janela e o laço que dorme quando nada muda: `lk.window.run(…)`, `lk.window.wake(…)`.
pub const window = @import("platform/window.zig");

// --- Componentes ---------------------------------------------------------------------
/// Ids por nome para os clicáveis: `lk.ids.id("salvar", 0)`.
pub const ids = @import("ui/ids.zig");
pub const id = ids.id;
pub const components = @import("ui/components.zig");

/// As marcas dos testes visuais, e o que o Inspetor grava de cada quadro.
pub const qa = @import("ui/qa.zig");
pub const inspector = @import("inspect/captura.zig");
pub const jsonx = @import("net/jsonx.zig");
pub const lsp = @import("core/lsp.zig");
pub const embedded = @import("core/embutido.zig");

test {
    // Os testes puros rodam sem a SDL e sem o ImGui: o `c` fica de fora.
    inline for (comptime std.meta.declarations(@This())) |name| {
        if (comptime std.mem.eql(u8, name, "c")) continue;
        _ = &@field(@This(), name);
    }
}
