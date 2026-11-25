//! `zig build test-ui`: os componentes num ImGui de verdade, sem janela (nada abre na tela):
//! cada quadro passa pelo NewFrame e pelo Render do ImGui, com o mouse que o teste mexe.
const std = @import("std");
const lk = @import("larperkit");
const c = lk.c;
const d = lk.draw;
const comp = lk.components;
const testing = std.testing;

const Harness = struct {
    io: *c.ImGuiIO,
    family: d.Family,
    th: lk.theme.Theme,
    pressed: bool = false,

    fn init(theme_src: []const u8) !Harness {
        comp.register();
        _ = c.ImGui_CreateContext(null);
        const io = c.ImGui_GetIO();
        io.*.DisplaySize = .{ .x = 900, .y = 700 };
        io.*.DeltaTime = 1.0 / 60.0;
        io.*.IniFilename = null;
        // Sem renderer: o atlas das letras fica na memória e ninguém sobe textura.
        io.*.BackendFlags |= c.ImGuiBackendFlags_RendererHasTextures;
        const font = c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
        lk.qa.enable();
        lk.anim.dt = 1.0 / 60.0;
        return .{
            .io = io,
            .family = .{ .name = "padrão", .faces = .{ font, font, font, font, font } },
            .th = try lk.theme.load(testing.allocator, theme_src, null, null),
        };
    }

    fn deinit(h: *Harness) void {
        h.th.deinit();
        c.ImGui_DestroyContext(null);
    }

    fn mouse(h: *Harness, x: f32, y: f32, down: bool) void {
        c.ImGuiIO_AddMousePosEvent(h.io, x, y);
        if (down != h.pressed) c.ImGuiIO_AddMouseButtonEvent(h.io, 0, down);
        h.pressed = down;
    }

    /// Um quadro: `draw` desenha com o contexto pronto. Devolve se algo pediu outro quadro.
    fn frame(h: *Harness, draw: anytype) bool {
        lk.anim.active = false;
        lk.anim.next_wake_ms = std.math.maxInt(i64);
        lk.qa.beginFrame();
        c.ImGui_NewFrame();
        c.ImGui_SetNextWindowPos(.{ .x = 0, .y = 0 }, 0);
        c.ImGui_SetNextWindowSize(.{ .x = 900, .y = 700 }, 0);
        _ = c.ImGui_Begin("##teste", null, c.ImGuiWindowFlags_NoDecoration | c.ImGuiWindowFlags_NoBackground | c.ImGuiWindowFlags_NoMove);
        var ctx: d.Ctx = .{
            .th = &h.th,
            .ui = &h.family,
            .mono = &h.family,
            .dl = c.ImGui_GetWindowDrawList(),
            .fg = c.ImGui_GetForegroundDrawList(),
            .io = h.io,
            .mouse = h.io.*.MousePos,
            .now_ms = 0,
            .win = .{ .x = 0, .y = 0, .w = 900, .h = 700 },
        };
        draw.f(&ctx);
        c.ImGui_End();
        c.ImGui_Render();
        return lk.anim.active or lk.anim.next_wake_ms != std.math.maxInt(i64);
    }
};

const tema = "layout { spacer }";

/// A tela de teste: um de cada componente, e uma página com os de formulário.
const Tela = struct {
    var som = false;
    var volume: f32 = 0.5;
    var modo: usize = 0;
    var salvou: u32 = 0;
    var saiu: u32 = 0;
    var pg_toggle = true;
    var pg_seg: u8 = 1;
    var pg_slider: f32 = 0.25;

    fn f(ctx: *d.Ctx) void {
        const dl = ctx.dl;
        if (comp.button(ctx, dl, lk.ids.id("salvar", 0), .{ .x = 20, .y = 20, .w = comp.buttonWidth(ctx, "Salvar", .primary), .h = 36 }, "Salvar", .{})) salvou += 1;
        _ = comp.button(ctx, dl, lk.ids.id("cancelar", 0), .{ .x = 140, .y = 20, .w = comp.buttonWidth(ctx, "Cancelar", .soft), .h = 36 }, "Cancelar", .{ .kind = .soft });
        if (comp.button(ctx, dl, lk.ids.id("sair", 0), .{ .x = 280, .y = 24, .w = comp.buttonWidth(ctx, "Sair", .pill), .h = 28 }, "Sair", .{ .kind = .pill, .danger = true })) saiu += 1;
        _ = comp.toggle(ctx, dl, lk.ids.id("som", 0), .{ .x = 20, .y = 80, .w = 40, .h = 24 }, &som, .{ .label = "Som" });
        _ = comp.slider(ctx, dl, lk.ids.id("volume", 0), .{ .x = 100, .y = 88, .w = 200, .h = 8 }, &volume, 0, 1, .{ .label = "Volume" });
        if (comp.segmented(ctx, dl, lk.ids.id("modo", 0), .{ .x = 20, .y = 130, .w = 400, .h = 44 }, &.{ "A", "B", "C" }, modo, .{})) |i| modo = i;
        _ = comp.segmented(ctx, dl, lk.ids.id("ruido", 0), .{ .x = 20, .y = 190, .w = 400, .h = 42 }, &.{ "Desligado", "Ligado" }, 0, .{ .style = .plain, .tag = "ruido" });
        var p: comp.Page = .{ .ctx = ctx, .dl = dl, .x = 460, .y = 20, .w = 400, .scope = lk.ids.id("pagina", 0) };
        p.title("Página");
        p.toggle("Avisos", "Mostra um aviso quando algo muda.", &pg_toggle);
        p.slider("Brilho", &pg_slider, 0, 1, "{d:.0}%", 100);
        p.segmented(&.{ "Um", "Dois" }, &pg_seg);
        _ = p.button("Aplicar", false);
        p.sameLine();
        _ = p.buttonSoft("Voltar");
    }
};

test "parado, nenhum componente pede quadro" {
    var h = try Harness.init(tema);
    defer h.deinit();
    h.mouse(-1000, -1000, false);
    // O primeiro quadro guarda os valores; daí em diante, nada se mexe.
    for (0..3) |_| _ = h.frame(Tela);
    for (0..5) |_| try testing.expect(!h.frame(Tela));
}

test "cada clicável deixa a marca do QA" {
    var h = try Harness.init(tema);
    defer h.deinit();
    h.mouse(-1000, -1000, false);
    for (0..2) |_| _ = h.frame(Tela);
    const want = [_][]const u8{ "button:Salvar", "button:Cancelar", "button:Sair", "toggle:Som", "slider:Volume", "seg:A", "seg:B", "seg:C", "ruido:0", "ruido:1", "toggle:Avisos", "slider:Brilho", "seg:Um", "seg:Dois", "button:Aplicar", "button:Voltar" };
    for (want) |k| {
        if (lk.qa.find(k) == null) {
            std.debug.print("sem a marca {s}\n", .{k});
            return error.SemMarca;
        }
    }
    // Lado a lado depois de `sameLine`.
    const a = lk.qa.find("button:Aplicar").?;
    const v = lk.qa.find("button:Voltar").?;
    try testing.expectEqual(a.y, v.y);
    try testing.expect(v.x > a.right());
}

test "clique: o botão responde ao soltar, e o interruptor anima e depois para" {
    var h = try Harness.init(tema);
    defer h.deinit();
    h.mouse(-1000, -1000, false);
    for (0..2) |_| _ = h.frame(Tela);
    const r = lk.qa.find("button:Salvar").?;
    const antes = Tela.salvou;
    h.mouse(r.x + r.w / 2, r.y + r.h / 2, false);
    _ = h.frame(Tela);
    h.mouse(r.x + r.w / 2, r.y + r.h / 2, true);
    _ = h.frame(Tela);
    h.mouse(r.x + r.w / 2, r.y + r.h / 2, false);
    _ = h.frame(Tela);
    try testing.expectEqual(antes + 1, Tela.salvou);

    const t = lk.qa.find("toggle:Som").?;
    const som = Tela.som;
    h.mouse(t.x + 10, t.y + 10, false);
    _ = h.frame(Tela);
    h.mouse(t.x + 10, t.y + 10, true);
    _ = h.frame(Tela);
    h.mouse(t.x + 10, t.y + 10, false);
    _ = h.frame(Tela);
    h.mouse(-1000, -1000, false);
    try testing.expect(Tela.som != som);
    // Mexendo, pede quadro; em menos de um segundo chega e para.
    var parou = false;
    for (0..60) |_| {
        if (!h.frame(Tela)) {
            parou = true;
            break;
        }
    }
    try testing.expect(parou);
}

test "as partes do tema mudam os componentes por estado" {
    var h = try Harness.init(
        \\parts {
        \\    part "button:hover" bg="#ff0000" radius=2
        \\    part "toggle.knob:on" color="@accent"
        \\    part "segment:selected" border="#00ff00" border-width=3
        \\}
        \\layout { spacer }
    );
    defer h.deinit();
    const P = comp.P;
    try testing.expect(P.get(h.th.parts, .button, .{ .hover = true }).bg != null);
    try testing.expectEqual(@as(?f32, 2), P.get(h.th.parts, .button, .{ .hover = true }).radius);
    try testing.expect(P.get(h.th.parts, .button, .{}).bg == null);
    try testing.expect(P.get(h.th.parts, .toggle_knob, .{ .on = true }).color != null);
    try testing.expectEqual(@as(f32, 3), P.get(h.th.parts, .segment, .{ .selected = true }).border_width);
    // E desenha com elas sem tropeçar.
    h.mouse(-1000, -1000, false);
    for (0..2) |_| _ = h.frame(Tela);
}

/// Uma dica sempre visível sobre `alvo`, numa janela de largura `w`.
const Dica = struct {
    var w: f32 = 900;
    var alvo: d.Rect = .{ .x = 400, .y = 300, .w = 24, .h = 24 };
    var label: []const u8 = "";
    var linhas: usize = 0;
    var pedacos: [3][]const u8 = undefined;
    var quebra_de: []const u8 = "";
    var quebra_em: f32 = 0;

    fn f(ctx: *d.Ctx) void {
        ctx.win.w = w;
        d.tip(ctx, alvo, label, true);
        if (quebra_de.len > 0) linhas = d.breakLines(ctx.ui.get(.semibold), 13, quebra_de, quebra_em, &pedacos);
    }

    /// Dois quadros (o QA lê as marcas do anterior) e o retângulo da dica.
    fn rect(h: *Harness) !d.Rect {
        for (0..2) |_| _ = h.frame(Dica);
        return lk.qa.find("tip") orelse error.SemDica;
    }

    fn quebra(h: *Harness, s: []const u8, max_w: f32) []const []const u8 {
        quebra_de = s;
        quebra_em = max_w;
        _ = h.frame(Dica);
        quebra_de = "";
        return pedacos[0..linhas];
    }
};

test "a dica cabe na janela: quebra em linhas e não derruba o app numa janela menor que ela" {
    var h = try Harness.init(tema);
    defer h.deinit();
    h.mouse(-1000, -1000, false);
    const font = h.family.get(.semibold);

    // Curta: o retângulo de sempre, centrado 8 acima do botão.
    Dica.w = 900;
    Dica.label = "Copiar";
    var r = try Dica.rect(&h);
    const tw = d.width(font, 13, "Copiar");
    try testing.expectEqual(@as(f32, 26), r.h);
    try testing.expectEqual(tw + 20, r.w);
    try testing.expectEqual(Dica.alvo.y - 34, r.y);
    try testing.expectEqual(Dica.alvo.x + Dica.alvo.w / 2 - r.w / 2, r.x);

    // Longa numa janela estreita, com o botão encostado na direita: várias linhas, dentro.
    Dica.w = 200;
    Dica.alvo.x = 170;
    Dica.label = "Rede virtual desligada: ligue o adaptador nas configurações para ver os outros computadores";
    r = try Dica.rect(&h);
    try testing.expect(r.h > 26);
    try testing.expect(r.x >= 4 and r.right() <= Dica.w - 4);

    // Janela menor que qualquer dica: a borda da esquerda ganha, sem o panic do clamp.
    Dica.w = 20;
    r = try Dica.rect(&h);
    try testing.expectEqual(@as(f32, 4), r.x);
}

test "breakLines: espaços, \\n, palavra que não cabe e o limite de linhas" {
    var h = try Harness.init(tema);
    defer h.deinit();
    h.mouse(-1000, -1000, false);
    Dica.w = 900;
    Dica.label = "";
    const font = h.family.get(.semibold);
    const eq = testing.expectEqualDeep;

    try eq(@as([]const []const u8, &.{"um  dois"}), Dica.quebra(&h, "  um  dois ", 1000));
    try eq(@as([]const []const u8, &.{ "um", "dois" }), Dica.quebra(&h, "um dois", d.width(font, 13, "um dois") - 1));
    try eq(@as([]const []const u8, &.{ "um", "dois" }), Dica.quebra(&h, "um\ndois", 1000));
    // A palavra que sozinha não cabe fica numa linha só dela.
    try eq(@as([]const []const u8, &.{ "a", "enormeenormeenorme", "b" }), Dica.quebra(&h, "a enormeenormeenorme b", d.width(font, 13, "a b")));
    // Três linhas no máximo: o resto vai na última.
    try eq(@as([]const []const u8, &.{ "a", "b", "c d e" }), Dica.quebra(&h, "a b c d e", 1));
    try eq(@as([]const []const u8, &.{""}), Dica.quebra(&h, "   ", 100));
}

test "ids de páginas diferentes não se cruzam" {
    var a: comp.Page = undefined;
    a.scope = lk.ids.id("pagina", 0);
    a.ids = 0;
    var b = a;
    b.scope = lk.ids.id("pagina", 1);
    for (0..50) |_| try testing.expect(a.id() != b.id());
}

test "o laço da janela dorme parado e acorda com wake de outra thread" {
    // Sem janela na tela: o driver offscreen da SDL desenha na memória.
    _ = c.SDL_SetHint(c.SDL_HINT_VIDEO_DRIVER, "offscreen");
    comp.register();
    var th = try lk.theme.load(testing.allocator, tema, null, null);
    defer th.deinit();
    const S = struct {
        var acordou: std.atomic.Value(i32) = .init(0);
        var sair: std.atomic.Value(bool) = .init(false);
        var quadros: std.atomic.Value(u32) = .init(0);
        var parado: u32 = 0;
        fn onWake(code: i32) void {
            _ = acordou.fetchAdd(code, .monotonic);
        }
        fn quit() bool {
            return sair.load(.acquire);
        }
        fn draw(_: void, ctx: *d.Ctx) void {
            _ = quadros.fetchAdd(1, .monotonic);
            Tela.f(ctx);
        }
        // Espera a janela abrir e assentar (no wine leva mais de meio segundo), conta os
        // quadros de meio segundo parado, acorda com um wake, e sai.
        fn outra() void {
            var n: u32 = 0;
            while (quadros.load(.monotonic) < 3 and n < 1000) : (n += 1) c.SDL_Delay(10);
            c.SDL_Delay(100);
            const inicio = quadros.load(.monotonic);
            c.SDL_Delay(500);
            parado = quadros.load(.monotonic) - inicio;
            lk.window.wake(5);
            c.SDL_Delay(300);
            sair.store(true, .release);
            lk.window.wake(0);
        }
    };
    const t = try std.Thread.spawn(.{}, S.outra, .{});
    try lk.window.run(.{ .title = "teste", .width = 900, .height = 700, .theme = &th, .on_wake = S.onWake, .should_quit = S.quit }, {}, S.draw);
    t.join();
    try testing.expectEqual(@as(i32, 5), S.acordou.load(.acquire));
    // Meio segundo parado: nenhum quadro (a 60 por segundo seriam uns 30).
    if (S.parado > 1) {
        std.debug.print("{d} quadros em meio segundo parado\n", .{S.parado});
        return error.DesenhouParado;
    }
}
