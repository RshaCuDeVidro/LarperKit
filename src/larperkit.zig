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

// --- Traduções -----------------------------------------------------------------------
pub const i18n = @import("ui/i18n.zig");
pub const i18n_pasta = @import("ui/i18n_pasta.zig");
pub const vigia = @import("platform/vigia.zig");

pub const anim = @import("ui/anim.zig");
pub const procgen = @import("ui/procgen.zig");
pub const jsonx = @import("net/jsonx.zig");
pub const lsp = @import("core/lsp.zig");
pub const embutido = @import("core/embutido.zig");

test {
    std.testing.refAllDecls(@This());
}
