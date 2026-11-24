//! LarperKit: a base comum dos apps (temas, desenho, animação, traduções).
const std = @import("std");

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
pub const heranca = @import("theme/heranca.zig");
pub const bases = @import("theme/bases.zig");
pub const custom = @import("theme/custom.zig");
pub const lsp_tema = @import("theme/lsp_tema.zig");
pub const theme_manager = @import("theme/manager.zig");
/// Exemplo de registro: os componentes, as partes e os temas do larperCord.
pub const exemplo_cord = @import("theme/exemplo_cord.zig");

// --- Traduções -----------------------------------------------------------------------
pub const i18n = @import("ui/i18n.zig");
pub const i18n_pasta = @import("ui/i18n_pasta.zig");
pub const vigia = @import("platform/vigia.zig");

// --- Desenho ------------------------------------------------------------------------
pub const draw = @import("ui/draw.zig");
pub const familia = @import("ui/familia.zig");
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
pub const carimbo = @import("ui/carimbo.zig");
pub const camada = @import("ui/camada.zig");
pub const quadro = @import("ui/quadro.zig");
/// As contas do papel de parede (onde a imagem cai, o vidro dos painéis por cima).
pub const wallpaper_fit = @import("ui/wallpaper_fit.zig");
/// As marcas dos testes visuais, e o que o Inspetor grava de cada quadro.
pub const qa = @import("ui/qa.zig");
pub const captura = @import("inspect/captura.zig");
pub const jsonx = @import("net/jsonx.zig");
pub const lsp = @import("core/lsp.zig");
pub const embutido = @import("core/embutido.zig");

test {
    std.testing.refAllDecls(@This());
}
