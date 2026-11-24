//! Uma família de fonte já carregada: as cinco faces que o desenho pede pelo peso. Quem
//! carrega (ui/fonts.zig) monta; o desenho (ui/draw.zig) só lê.
//! Tirado de src/ui/fonts.zig do larperCord.
const c = @import("c");

pub const Weight = enum(u3) { regular, medium, semibold, bold, italic };

pub const Family = struct {
    name: []const u8,
    faces: [5]*c.ImFont,
    /// Veio de `installedFamily` (no Windows, da lista das pastas de fontes).
    installed: bool = false,

    pub fn get(f: *const Family, w: Weight) *c.ImFont {
        return f.faces[@intFromEnum(w)];
    }
};
