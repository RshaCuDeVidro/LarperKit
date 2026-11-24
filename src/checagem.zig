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

// As funções genéricas, com os tipos de um app de verdade (o exemplo do larperCord).
test "genéricas com o exemplo do larperCord" {
    const P = lk.exemplo_cord.Partes;
    _ = &struct {
        fn f(ctx: *const lk.draw.Ctx, r: lk.draw.Rect) void {
            _ = lk.ui_parts.look(ctx, P, .message, .{ .hover = true });
            lk.ui_parts.mark(r, P, .channel_item, .{ .selected = true });
        }
    }.f;
}

// O exemplo do README (a seção API), como está lá: se a API mudar, este teste lembra de
// mudar o README junto.
test "o exemplo do README compila" {
    const Settings = struct {
        compact: bool = false,
        text_size: f32 = 1,
        accounts: []const u8 = &.{},
        fn save(_: *@This()) void {}
        fn remove(_: *@This(), _: usize) void {}
    };
    const lk_ = lk;
    _ = &struct {
        const comp = lk_.componentes;
        fn settingsPage(ctx: *lk_.draw.Ctx, s: *Settings) void {
            var p: comp.Page = .{ .ctx = ctx, .dl = ctx.dl, .x = 40, .y = 40, .w = 480, .escopo = lk_.id("settings", 0) };
            p.title("Chat");
            p.toggle("Compact mode", "", &s.compact);
            p.slider("Text size", &s.text_size, 0.8, 1.4, "{d:.0}%", 100);
            if (p.button("Save", false)) s.save();
            for (s.accounts, 0..) |_, i| {
                const r: lk_.draw.Rect = .{ .x = 40, .y = p.y + @as(f32, @floatFromInt(i)) * 40, .w = 120, .h = 32 };
                if (comp.button(ctx, ctx.dl, lk_.id("remove-account", i), r, "Remove", .{ .kind = .pill, .danger = true })) s.remove(i);
            }
        }
    }.settingsPage;
}
