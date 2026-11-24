//! LarperKit: a base comum dos apps (temas, desenho, animação, traduções).
const std = @import("std");

pub const kdl = @import("theme/kdl.zig");
pub const color = @import("theme/color.zig");
pub const path = @import("theme/path.zig");
pub const anim = @import("ui/anim.zig");
pub const procgen = @import("ui/procgen.zig");
pub const jsonx = @import("net/jsonx.zig");
pub const lsp = @import("core/lsp.zig");
pub const embutido = @import("core/embutido.zig");

test {
    std.testing.refAllDecls(@This());
}
