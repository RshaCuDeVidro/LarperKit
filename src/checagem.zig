//! `zig build check`: analisa cada declaração pública do kit, inclusive o que só roda com a
//! SDL e o ImGui (que os testes não chamam), sem ligar nada.
const std = @import("std");
const lk = @import("larperkit");

/// Cada declaração pública de `T` e dos tipos dentro dele, até `depth` níveis (os arquivos
/// se importam uns aos outros; sem limite, o laço não acaba).
fn refAll(comptime T: type, comptime depth: u8) void {
    inline for (comptime std.meta.declarations(T)) |name| {
        const v = @field(T, name);
        if (@TypeOf(v) == type) {
            if (depth > 0) switch (@typeInfo(v)) {
                .@"struct", .@"enum", .@"union", .@"opaque" => refAll(v, depth - 1),
                else => {},
            };
        } else if (@typeInfo(@TypeOf(v)) == .@"fn" and @typeInfo(@TypeOf(v)).@"fn".is_generic) {
            // Função genérica: só compila com os tipos de quem chama.
        } else _ = &@field(T, name);
    }
}

test {
    @setEvalBranchQuota(1_000_000);
    refAll(lk, 4);
}
