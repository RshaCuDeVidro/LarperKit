//! Um app mínimo com o LarperKit: uma janela que só desenha quando algo muda, um tema, uma
//! página de formulário e um relógio que uma outra thread atualiza com `lk.window.wake`.
//!   zig build && zig-out/bin/hello
//! LARPERKIT_FONTS=<pasta>: as fontes Inter e JetBrains Mono (tools/deps.sh do kit baixa).
//! HELLO_FRAMES=<n>: sai depois de n quadros (o CI usa, com SDL_VIDEO_DRIVER=offscreen).
const std = @import("std");
const lk = @import("larperkit");
const tr = lk.i18n.tr;

const tema =
    \\theme "hello"
    \\colors {
    \\    bg "#101218"; surface "#171a23"; elevated "#1f2330"; text "#e8eaf2"
    \\    muted "#9aa3b8"; faint "#6b7389"; accent "#5fb3ff"; accent-text "#04121f"
    \\}
    \\metrics radius=8
    \\layout { stack { aurora color="alpha(@accent, 0.25)" color2="alpha(#b388ff, 0.2)" seed=3; spacer } }
;

const Estado = struct {
    avisos: bool = true,
    compacto: bool = false,
    volume: f32 = 0.6,
    tema: u8 = 0,
    cliques: u32 = 0,
};

/// Os segundos desde a abertura, contados por outra thread (como a rede avisaria algo).
var segundos: std.atomic.Value(u32) = .init(0);

fn relogio() void {
    while (true) {
        lk.c.SDL_Delay(1000);
        _ = segundos.fetchAdd(1, .monotonic);
        // A thread não desenha: só acorda o laço, que desenha um quadro e volta a dormir.
        lk.window.wake(1);
    }
}

fn desenha(s: *Estado, ctx: *lk.draw.Ctx) void {
    const dl = ctx.dl;
    // O fundo do tema (a aurora do `layout`).
    lk.draw.rect(dl, ctx.win, ctx.col(.bg), 0);
    if (ctx.th.layout) |root| for (root.children) |*n| for (n.children) |*ch| {
        if (lk.backdrop.isBackdrop(ch.name)) lk.backdrop.draw(ctx, ch, ctx.win);
    };
    const card: lk.draw.Rect = .{ .x = 40, .y = 40, .w = @min(560, ctx.win.w - 80), .h = ctx.win.h - 80 };
    lk.draw.shadow(dl, card, 12, 18, ctx.col(.shadow));
    lk.draw.rect(dl, card, ctx.col(.surface).alpha(0.9), 12);
    var p: lk.components.Page = .{ .ctx = ctx, .dl = dl, .x = card.x + 32, .y = card.y + 28, .w = card.w - 64, .scope = lk.id("hello", 0) };
    p.title(tr("Olá, LarperKit", "Hello, LarperKit"));
    var buf: [64]u8 = undefined;
    p.line(.regular, 14, ctx.col(.muted), lk.i18n.fmt(&buf, "Aberto há {d} s (uma outra thread acorda o laço)", "Open for {d} s (another thread wakes the loop)", .{segundos.load(.monotonic)}), 30);
    p.toggle(tr("Avisos", "Notifications"), tr("Um aviso quando algo muda.", "A notice when something changes."), &s.avisos);
    p.toggle(tr("Modo compacto", "Compact mode"), "", &s.compacto);
    p.slider(tr("Volume", "Volume"), &s.volume, 0, 1, "{d:.0}%", 100);
    p.segmented(&.{ tr("Escuro", "Dark"), tr("Claro", "Light"), tr("Sistema", "System") }, &s.tema);
    if (p.button(tr("Clique aqui", "Click me"), false)) s.cliques += 1;
    p.line(.regular, 14, ctx.col(.faint), lk.i18n.fmt(&buf, "{d} cliques", "{d} clicks", .{s.cliques}), 30);
}

var max_frames: ?u64 = null;

pub fn main(init: std.process.Init) !void {
    lk.app.name = "Hello";
    lk.app.folder = "larperkit-hello";
    lk.components.register();
    var th = try lk.theme.load(init.gpa, tema, null, null);
    defer th.deinit();
    if (init.environ_map.get("HELLO_FRAMES")) |n| max_frames = std.fmt.parseInt(u64, n, 10) catch null;
    const t = try std.Thread.spawn(.{}, relogio, .{});
    t.detach();
    var s: Estado = .{};
    try lk.window.run(.{
        .title = "Hello, LarperKit",
        .width = 720,
        .height = 640,
        .theme = &th,
        .fonts = .{ .dir = init.environ_map.get("LARPERKIT_FONTS") },
        .max_frames = max_frames,
    }, &s, desenha);
}
