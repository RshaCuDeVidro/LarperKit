//! A vitrine do LarperKit: os componentes em vários temas, desenhados sem janela (o driver
//! offscreen da SDL desenha na memória) e gravados em PNG, para os exemplos da
//! documentação (EXAMPLES.md). Nada aparece na tela.
//!
//!   vitrine --out <pasta> [--fonts <pasta>] [--frames <pasta>] [--lang en|pt]
//!
//! `--fonts`: a pasta com Inter e JetBrains Mono (tools/deps.sh baixa); sem ela, a fonte do
//! próprio ImGui. `--frames`: também os quadros da animação, um PNG por quadro.
const std = @import("std");
const lk = @import("larperkit");
const c = @import("c");
const d = lk.draw;
const comp = lk.components;
const tr = lk.i18n.tr;

const W: f32 = 1280;
const H: f32 = 800;
const dt: f32 = 1.0 / 30.0;

const Tema = struct { src: []const u8, mode: lk.theme.Mode };
const temas = [_]Tema{
    .{ .src = @embedFile("temas/noite.kdl"), .mode = .dark },
    .{ .src = @embedFile("temas/papel.kdl"), .mode = .light },
    .{ .src = @embedFile("temas/terminal.kdl"), .mode = .dark },
    .{ .src = @embedFile("temas/neon.kdl"), .mode = .dark },
};
const noite = 0;
const papel = 1;
const terminal = 2;
const neon = 3;

const App = struct {
    renderer: *c.SDL_Renderer,
    io: *c.ImGuiIO,
    ui: d.Family,
    mono: d.Family,
    themes: [temas.len]lk.theme.Theme,
    now_ms: i64 = 0,
    mouse: [2]f32 = .{ -1000, -1000 },
    down: bool = false,
    was_down: bool = false,
    /// Desenha a seta do mouse (na animação: sem janela, não há seta de verdade).
    cursor: bool = false,
};

const Cena = *const fn (app: *App, ctx: *d.Ctx) void;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var out: ?[]const u8 = null;
    var fonts: ?[]const u8 = null;
    var frames: ?[]const u8 = null;
    var lang: []const u8 = "en";
    var i: usize = 1;
    while (i + 1 < args.len) : (i += 2) {
        const k = args[i];
        if (std.mem.eql(u8, k, "--out")) out = args[i + 1] else if (std.mem.eql(u8, k, "--fonts")) fonts = args[i + 1] else if (std.mem.eql(u8, k, "--frames")) frames = args[i + 1] else if (std.mem.eql(u8, k, "--lang")) lang = args[i + 1] else return error.Uso;
    }
    const dir = out orelse return error.Uso;

    // Sem janela na tela, nunca: a SDL desenha na memória.
    _ = c.SDL_SetHint(c.SDL_HINT_VIDEO_DRIVER, "offscreen");
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SemSdl;
    defer c.SDL_Quit();
    const window = c.SDL_CreateWindow("LarperKit", @intFromFloat(W), @intFromFloat(H), 0) orelse return error.SemJanela;
    defer c.SDL_DestroyWindow(window);
    const renderer = c.SDL_CreateRenderer(window, null) orelse return error.SemRenderer;
    defer c.SDL_DestroyRenderer(renderer);

    _ = c.ImGui_CreateContext(null);
    defer c.ImGui_DestroyContext(null);
    const io = c.ImGui_GetIO();
    io.*.IniFilename = null;
    io.*.DisplaySize = .{ .x = W, .y = H };
    if (!c.cImGui_ImplSDLRenderer3_Init(renderer)) return error.SemImgui;
    defer c.cImGui_ImplSDLRenderer3_Shutdown();

    lk.app.name = "LarperKit";
    comp.register();
    // As marcas do QA dizem à animação onde está cada botão.
    lk.qa.enable();
    lk.i18n.set(lang);
    lk.anim.dt = dt;

    var app: App = .{
        .renderer = renderer,
        .io = io,
        .ui = family(io, fonts, .{ "Inter-Regular.ttf", "Inter-Medium.ttf", "Inter-SemiBold.ttf", "Inter-Bold.ttf", "Inter-Italic.ttf" }),
        .mono = family(io, fonts, .{ "JetBrainsMono-Regular.ttf", "JetBrainsMono-Regular.ttf", "JetBrainsMono-Regular.ttf", "JetBrainsMono-Regular.ttf", "JetBrainsMono-Regular.ttf" }),
        .themes = undefined,
    };
    for (temas, &app.themes) |t, *th| {
        th.* = try lk.theme.loadWith(gpa, t.src, .{ .mode = t.mode }, null);
        for (th.warnings) |w| std.log.warn("tema {s}:{d}:{d}: {s}", .{ th.name, w.line, w.col, w.message });
    }
    defer for (&app.themes) |*th| th.deinit();

    var pb: [1024]u8 = undefined;
    // Cada foto: alguns quadros para as animações chegarem, e o último vai para o PNG.
    const fotos = [_]struct { nome: []const u8, tema: usize, cena: Cena, mouse: [2]f32 }{
        .{ .nome = "settings", .tema = noite, .cena = configuracoes, .mouse = .{ 368, 436 } },
        .{ .nome = "dashboard", .tema = noite, .cena = dashboard, .mouse = .{ -1000, -1000 } },
        .{ .nome = "themes", .tema = noite, .cena = grade, .mouse = .{ -1000, -1000 } },
        .{ .nome = "parts", .tema = neon, .cena = partes, .mouse = .{ 790, 202 } },
        .{ .nome = "settings-paper", .tema = papel, .cena = configuracoes, .mouse = .{ -1000, -1000 } },
        .{ .nome = "dashboard-terminal", .tema = terminal, .cena = dashboard, .mouse = .{ -1000, -1000 } },
    };
    for (fotos) |f| {
        Estado.reset();
        Estado.tema = f.tema;
        app.mouse = f.mouse;
        app.down = false;
        for (0..40) |_| frame(&app, f.cena, null);
        const path = try std.fmt.bufPrintSentinel(&pb, "{s}/{s}-{s}.png", .{ dir, f.nome, lang }, 0);
        frame(&app, f.cena, path);
        std.log.info("{s}", .{path});
    }
    if (frames) |fdir| try animacao(&app, fdir);
}

/// As cinco faces de uma família, da pasta de fontes; o que faltar usa a fonte do ImGui.
fn family(io: *c.ImGuiIO, dir: ?[]const u8, files: [5][]const u8) d.Family {
    var faces: [5]*c.ImFont = undefined;
    var pb: [1024]u8 = undefined;
    for (files, &faces) |f, *face| {
        face.* = blk: {
            const base = dir orelse break :blk c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
            const path = std.fmt.bufPrintSentinel(&pb, "{s}/{s}", .{ base, f }, 0) catch break :blk c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
            var info: c.SDL_PathInfo = undefined;
            if (!c.SDL_GetPathInfo(path.ptr, &info)) break :blk c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
            break :blk c.ImFontAtlas_AddFontFromFileTTF(io.*.Fonts, path.ptr, 16, null, null) orelse c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
        };
    }
    return .{ .name = files[0], .faces = faces };
}

/// Um quadro inteiro: a cena num ImGui de verdade, desenhada pela SDL na memória. Com
/// `capture`, os pixels vão para esse PNG.
fn frame(app: *App, cena: Cena, capture: ?[:0]const u8) void {
    lk.anim.active = false;
    lk.anim.now_ms = app.now_ms;
    lk.qa.beginFrame();
    lk.ui_fx.beginFrame();
    app.io.*.DeltaTime = dt;
    c.ImGuiIO_AddMousePosEvent(app.io, app.mouse[0], app.mouse[1]);
    if (app.down != app.was_down) c.ImGuiIO_AddMouseButtonEvent(app.io, 0, app.down);
    app.was_down = app.down;
    c.cImGui_ImplSDLRenderer3_NewFrame();
    c.ImGui_NewFrame();
    c.ImGui_SetNextWindowPos(.{ .x = 0, .y = 0 }, 0);
    c.ImGui_SetNextWindowSize(.{ .x = W, .y = H }, 0);
    c.ImGui_PushStyleVarImVec2(c.ImGuiStyleVar_WindowPadding, .{ .x = 0, .y = 0 });
    _ = c.ImGui_Begin("##vitrine", null, c.ImGuiWindowFlags_NoDecoration | c.ImGuiWindowFlags_NoBackground | c.ImGuiWindowFlags_NoMove | c.ImGuiWindowFlags_NoScrollWithMouse);
    var ctx: d.Ctx = .{
        .th = &app.themes[Estado.tema],
        .ui = &app.ui,
        .mono = &app.mono,
        .dl = c.ImGui_GetWindowDrawList(),
        .fg = c.ImGui_GetForegroundDrawList(),
        .io = app.io,
        .renderer = app.renderer,
        .mouse = app.io.*.MousePos,
        .now_ms = app.now_ms,
        .win = .{ .x = 0, .y = 0, .w = W, .h = H },
    };
    d.opt_theme = ctx.th;
    cena(app, &ctx);
    if (app.cursor) seta(ctx.fg, app.mouse[0], app.mouse[1], app.down);
    c.ImGui_End();
    c.ImGui_PopStyleVar();
    c.ImGui_Render();
    _ = c.SDL_SetRenderDrawColor(app.renderer, 0, 0, 0, 255);
    _ = c.SDL_RenderClear(app.renderer);
    c.cImGui_ImplSDLRenderer3_RenderDrawData(c.ImGui_GetDrawData(), app.renderer);
    if (capture) |path| if (c.SDL_RenderReadPixels(app.renderer, null)) |surf| {
        defer c.SDL_DestroySurface(surf);
        if (!c.SDL_SavePNG(surf, path.ptr)) std.log.err("não gravei {s}: {s}", .{ path, c.SDL_GetError() });
    };
    _ = c.SDL_RenderPresent(app.renderer);
    app.now_ms += @intFromFloat(dt * 1000);
}

/// A seta do mouse e, apertado, um anel em volta da ponta.
fn seta(dl: *c.ImDrawList, x: f32, y: f32, down: bool) void {
    const pts = [_][2]f32{ .{ 0, 0 }, .{ 0, 18 }, .{ 4.6, 13.8 }, .{ 7.8, 20.6 }, .{ 10.6, 19.4 }, .{ 7.4, 12.8 }, .{ 13, 12.8 } };
    var v: [pts.len]c.ImVec2 = undefined;
    for (pts, &v) |p, *o| o.* = .{ .x = x + p[0], .y = y + p[1] };
    if (down) c.ImDrawList_AddCircleEx(dl, d.v(x, y), 14, d.Rgba.white.alpha(0.8).u(), 0, 2.5, 0);
    c.ImDrawList_AddConcavePolyFilled(dl, &v, v.len, d.Rgba.white.u());
    c.ImDrawList_AddPolyline(dl, &v, v.len, d.Rgba.black.u(), 1.4, c.ImDrawFlags_Closed);
}

// --- O estado das telas -----------------------------------------------------------------

const Estado = struct {
    var tema: usize = noite;
    var previas = true;
    var compacto = false;
    var emoji = false;
    var texto: f32 = 1.0;
    var densidade: u8 = 0;
    var aviso: u8 = 1;
    var secao: usize = 1;
    var intervalo: usize = 1;
    var servicos = [_]bool{ true, true, false, true };
    var grade_toggle = [_]bool{ true, false, true, true };
    var grade_slider = [_]f32{ 0.62, 0.35, 0.8, 0.5 };
    var grade_seg = [_]u8{ 0, 1, 2, 1 };
    var neon_on = true;
    var neon_off = false;
    var neon_slider: f32 = 0.68;
    var neon_seg: usize = 1;

    fn reset() void {
        previas = true;
        compacto = false;
        emoji = false;
        texto = 1.0;
        densidade = 0;
        aviso = 1;
        secao = 1;
        intervalo = 1;
    }
};

// --- Peças comuns -----------------------------------------------------------------------

/// O fundo do tema: o degradê e os fundos procedurais do `layout`, na tela toda.
fn fundo(ctx: *d.Ctx, r: d.Rect) void {
    d.rect(ctx.dl, r, ctx.col(.bg), 0);
    const root = ctx.th.layout orelse return;
    for (root.children, 0..) |*n, i| no(ctx, n, r, i);
}

fn no(ctx: *d.Ctx, n: *const lk.kdl.Node, r: d.Rect, key: usize) void {
    if (ctx.th.nodeFx(n)) |x| lk.ui_fx.node(ctx, x, n, r, key);
    if (lk.backdrop.isBackdrop(n.name)) lk.backdrop.draw(ctx, n, r);
    for (n.children, 0..) |*ch, i| no(ctx, ch, r, key * 31 + i + 1);
}

/// Um cartão: sombra, fundo um pouco translúcido e borda.
fn cartao(ctx: *d.Ctx, r: d.Rect) void {
    const radius = ctx.th.radius + 4;
    d.shadow(ctx.dl, r, radius, 18, ctx.col(.shadow));
    d.rect(ctx.dl, r, ctx.col(.surface).alpha(0.86), radius);
    d.border(ctx.dl, r, ctx.col(.border), radius, 1);
}

fn font(ctx: *d.Ctx, w: d.Weight) *c.ImFont {
    return ctx.ui.get(w);
}

// --- Configurações ----------------------------------------------------------------------

fn configuracoes(app: *App, ctx: *d.Ctx) void {
    _ = app;
    const dl = ctx.dl;
    fundo(ctx, ctx.win);
    // A lista das seções, à esquerda.
    const side: d.Rect = .{ .x = 24, .y = 24, .w = 252, .h = H - 48 };
    cartao(ctx, side);
    d.text(dl, font(ctx, .bold), 20, side.x + 24, side.y + 24, ctx.col(.text), "LarperKit");
    d.text(dl, font(ctx, .regular), 13, side.x + 24, side.y + 52, ctx.col(.muted), tr("Configurações", "Settings"));
    const secoes = [_][]const u8{ tr("Minha conta", "My account"), tr("Chat", "Chat"), tr("Aparência", "Appearance"), tr("Voz e vídeo", "Voice & video"), tr("Plugins", "Plugins"), tr("Idioma", "Language"), tr("Atalhos", "Shortcuts") };
    for (secoes, 0..) |s, i| {
        const r: d.Rect = .{ .x = side.x + 12, .y = side.y + 92 + @as(f32, @floatFromInt(i)) * 42, .w = side.w - 24, .h = 36 };
        const hb = d.hit(ctx, lk.id("secao", i), r);
        lk.qa.mark(r, "secao:{d}", .{i});
        if (hb.clicked) Estado.secao = i;
        const sel = Estado.secao == i;
        if (sel or hb.hovered) d.rect(dl, r, if (sel) ctx.col(.selected) else ctx.col(.hover), ctx.th.radius);
        d.text(dl, font(ctx, if (sel) .semibold else .medium), 15, r.x + 14, d.centerY(r, 15), if (sel) ctx.col(.text) else ctx.col(.muted), s);
    }
    // A página.
    const main_r: d.Rect = .{ .x = 300, .y = 24, .w = W - 324, .h = H - 48 };
    cartao(ctx, main_r);
    var p: comp.Page = .{ .ctx = ctx, .dl = dl, .x = main_r.x + 40, .y = main_r.y + 36, .w = 470, .scope = lk.id("pagina-chat", 0) };
    p.title(tr("Chat", "Chat"));
    p.heading(tr("Mensagens", "Messages"));
    p.toggle(tr("Prévias de links", "Link previews"), tr("Mostra o título e a imagem dos links enviados.", "Shows the title and picture of links people send."), &Estado.previas);
    p.toggle(tr("Modo compacto", "Compact mode"), "", &Estado.compacto);
    p.toggleIf(tr("Emoji animado", "Animated emoji"), tr("Desligado enquanto \"Reduzir movimento\" estiver ligado.", "Off while \"Reduce motion\" is on."), &Estado.emoji, false);
    p.slider(tr("Tamanho do texto", "Text size"), &Estado.texto, 0.8, 1.4, "{d:.0}%", 100);
    p.heading(tr("Ações", "Actions"));
    _ = p.button(tr("Salvar", "Save"), false);
    p.sameLine();
    _ = p.buttonSoft(tr("Restaurar", "Reset"));
    // A segunda coluna: o tema, escolhido ao vivo.
    var q: comp.Page = .{ .ctx = ctx, .dl = dl, .x = main_r.x + 560, .y = main_r.y + 80, .w = main_r.w - 600, .scope = lk.id("pagina-tema", 0) };
    q.heading(tr("Tema", "Theme"));
    var tema: u8 = @intCast(Estado.tema % 3);
    q.segmented(&.{ "Noite", "Papel", "Terminal" }, &tema);
    Estado.tema = tema;
    q.select(tr("Densidade", "Density"), &.{ tr("Confortável", "Comfortable"), tr("Compacta", "Compact") }, &Estado.densidade);
    q.radio(&.{ tr("Avisar sempre", "Always notify"), tr("Só menções", "Mentions only") }, &.{ tr("Um aviso para cada mensagem.", "A notice for every message."), tr("Quando alguém chama você.", "When someone pings you.") }, &Estado.aviso);
    const bx = q.x;
    const by = q.y + 4;
    const w1 = comp.buttonWidth(ctx, tr("Exportar", "Export"), .pill);
    _ = comp.button(ctx, dl, lk.id("exportar", 0), .{ .x = bx, .y = by, .w = w1, .h = 30 }, tr("Exportar", "Export"), .{ .kind = .pill });
    _ = comp.button(ctx, dl, lk.id("apagar", 0), .{ .x = bx + w1 + 8, .y = by, .w = comp.buttonWidth(ctx, tr("Apagar dados", "Delete data"), .pill), .h = 30 }, tr("Apagar dados", "Delete data"), .{ .kind = .pill, .danger = true });
}

// --- Dashboard --------------------------------------------------------------------------

/// Uma série de números que parece de verdade, sempre a mesma.
fn serie(seed: f32, i: usize) f32 {
    const x: f32 = @floatFromInt(i);
    return 0.5 + 0.24 * @sin(x * 0.32 + seed) + 0.1 * @sin(x * 0.85 + seed * 2.1) + 0.035 * @sin(x * 2.2 + seed * 0.7);
}

fn linha(ctx: *d.Ctx, r: d.Rect, seed: f32, n: usize, cor: d.Rgba, area: bool, grossura: f32) void {
    var pts: [64]c.ImVec2 = undefined;
    const count = @min(n, pts.len);
    for (0..count) |i| {
        const k = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(count - 1));
        pts[i] = .{ .x = r.x + k * r.w, .y = r.y + r.h - serie(seed, i) * r.h };
    }
    if (area) for (0..count - 1) |i| {
        const q = [_]c.ImVec2{ pts[i], pts[i + 1], .{ .x = pts[i + 1].x, .y = r.bottom() }, .{ .x = pts[i].x, .y = r.bottom() } };
        c.ImDrawList_AddConvexPolyFilled(ctx.dl, &q, 4, cor.alpha(0.13).u(), 0);
    };
    c.ImDrawList_AddPolyline(ctx.dl, &pts, @intCast(count), cor.u(), grossura, 0);
}

fn dashboard(app: *App, ctx: *d.Ctx) void {
    _ = app;
    const dl = ctx.dl;
    fundo(ctx, ctx.win);
    d.text(dl, font(ctx, .bold), 28, 40, 34, ctx.col(.text), tr("Visão geral", "Overview"));
    d.text(dl, font(ctx, .regular), 14, 40, 72, ctx.col(.muted), tr("Servidor de exemplo · atualizado agora", "Example server · updated just now"));
    const intervalos = [_][]const u8{ "24h", "7d", "30d" };
    if (comp.segmented(ctx, dl, lk.id("intervalo", 0), .{ .x = W - 460, .y = 36, .w = 240, .h = 38 }, &intervalos, Estado.intervalo, .{ .tag = "intervalo" })) |i| Estado.intervalo = i;
    const novo = tr("Novo relatório", "New report");
    const nw = comp.buttonWidth(ctx, novo, .primary);
    _ = comp.button(ctx, dl, lk.id("relatorio", 0), .{ .x = W - 40 - nw, .y = 37, .w = nw, .h = 36 }, novo, .{});

    const stats = [_]struct { rotulo: []const u8, valor: []const u8, delta: []const u8, bom: bool }{
        .{ .rotulo = tr("MENSAGENS", "MESSAGES"), .valor = "48.2k", .delta = "+12.4%", .bom = true },
        .{ .rotulo = tr("PESSOAS ATIVAS", "ACTIVE PEOPLE"), .valor = "1,284", .delta = "+3.1%", .bom = true },
        .{ .rotulo = tr("LATÊNCIA", "LATENCY"), .valor = "38 ms", .delta = "-6 ms", .bom = true },
        .{ .rotulo = tr("ERROS", "ERRORS"), .valor = "0.4%", .delta = "+0.1%", .bom = false },
    };
    const cw = (W - 80 - 3 * 20) / 4;
    for (stats, 0..) |s, i| {
        const r: d.Rect = .{ .x = 40 + @as(f32, @floatFromInt(i)) * (cw + 20), .y = 110, .w = cw, .h = 132 };
        cartao(ctx, r);
        d.text(dl, font(ctx, .semibold), 12, r.x + 20, r.y + 18, ctx.col(.muted), s.rotulo);
        d.text(dl, font(ctx, .bold), 30, r.x + 20, r.y + 40, ctx.col(.text), s.valor);
        const dc = if (s.bom) ctx.col(.online) else ctx.col(.danger);
        const dw = d.width(font(ctx, .semibold), 13, s.delta);
        d.rect(dl, .{ .x = r.right() - dw - 36, .y = r.y + 16, .w = dw + 16, .h = 22 }, dc.alpha(0.16), 11);
        d.text(dl, font(ctx, .semibold), 13, r.right() - dw - 28, r.y + 19, dc, s.delta);
        linha(ctx, .{ .x = r.x + 20, .y = r.y + 90, .w = r.w - 40, .h = 28 }, @as(f32, @floatFromInt(i)) * 1.7 + 0.4, 24, ctx.col(.accent), true, 2);
    }

    // O gráfico grande.
    const g: d.Rect = .{ .x = 40, .y = 264, .w = 780, .h = H - 304 };
    cartao(ctx, g);
    d.text(dl, font(ctx, .semibold), 17, g.x + 24, g.y + 22, ctx.col(.text), tr("Mensagens por hora", "Messages per hour"));
    d.text(dl, font(ctx, .regular), 13, g.x + 24, g.y + 46, ctx.col(.muted), tr("Hoje, comparado com ontem", "Today, compared with yesterday"));
    const area: d.Rect = .{ .x = g.x + 56, .y = g.y + 84, .w = g.w - 84, .h = g.h - 132 };
    for (0..5) |k| {
        const y = area.y + @as(f32, @floatFromInt(k)) * area.h / 4;
        d.line(dl, area.x, y, area.right(), y, ctx.col(.border), 1);
        var nb: [8]u8 = undefined;
        const lab = std.fmt.bufPrint(&nb, "{d}k", .{(4 - k) * 2}) catch "";
        d.text(dl, ctx.mono.get(.regular), 12, g.x + 22, y - 8, ctx.col(.faint), lab);
    }
    for (0..7) |k| {
        var nb: [8]u8 = undefined;
        const lab = std.fmt.bufPrint(&nb, "{d:0>2}h", .{k * 4}) catch "";
        const x = area.x + @as(f32, @floatFromInt(k)) * area.w / 6;
        d.text(dl, ctx.mono.get(.regular), 12, x - 10, area.bottom() + 12, ctx.col(.faint), lab);
    }
    linha(ctx, area, 5.2, 40, ctx.col(.muted).alpha(0.6), false, 1.5);
    linha(ctx, area, 1.3, 40, ctx.col(.accent), true, 2.6);

    // Os serviços.
    const sv: d.Rect = .{ .x = 840, .y = 264, .w = W - 880, .h = H - 304 };
    cartao(ctx, sv);
    d.text(dl, font(ctx, .semibold), 17, sv.x + 24, sv.y + 22, ctx.col(.text), tr("Serviços", "Services"));
    const nomes = [_][]const u8{ "Gateway", tr("Mídia", "Media"), tr("Busca", "Search"), "Plugins" };
    const estados = [_]d.Token{ .online, .online, .idle, .online };
    for (nomes, 0..) |nome, i| {
        const y = sv.y + 64 + @as(f32, @floatFromInt(i)) * 46;
        d.circle(dl, sv.x + 30, y + 12, 5, if (Estado.servicos[i]) ctx.col(estados[i]) else ctx.col(.faint));
        d.text(dl, font(ctx, .medium), 15, sv.x + 46, y + 3, ctx.col(.text), nome);
        _ = comp.toggle(ctx, dl, lk.id("servico", i), .{ .x = sv.right() - 64, .y = y, .w = 40, .h = 24 }, &Estado.servicos[i], .{ .label = nome });
    }
    const usos = [_]struct { nome: []const u8, k: f32 }{ .{ .nome = "CPU", .k = 0.42 }, .{ .nome = tr("Memória", "Memory"), .k = 0.67 }, .{ .nome = tr("Disco", "Disk"), .k = 0.23 } };
    for (usos, 0..) |u, i| {
        const y = sv.y + 260 + @as(f32, @floatFromInt(i)) * 44;
        d.text(dl, font(ctx, .medium), 13, sv.x + 24, y, ctx.col(.muted), u.nome);
        var nb: [8]u8 = undefined;
        const pct = std.fmt.bufPrint(&nb, "{d}%", .{@as(u32, @intFromFloat(u.k * 100))}) catch "";
        d.text(dl, ctx.mono.get(.regular), 13, sv.right() - 24 - d.width(ctx.mono.get(.regular), 13, pct), y, ctx.col(.text), pct);
        const tr_r: d.Rect = .{ .x = sv.x + 24, .y = y + 22, .w = sv.w - 48, .h = 6 };
        d.rect(dl, tr_r, ctx.col(.elevated).mix(ctx.col(.text), 0.08), 3);
        d.rect(dl, .{ .x = tr_r.x, .y = tr_r.y, .w = tr_r.w * u.k, .h = tr_r.h }, ctx.col(.accent), 3);
    }
    const ver = tr("Ver registros", "View logs");
    _ = comp.button(ctx, dl, lk.id("registros", 0), .{ .x = sv.x + 24, .y = sv.bottom() - 54, .w = comp.buttonWidth(ctx, ver, .soft), .h = 36 }, ver, .{ .kind = .soft });
}

// --- Temas ------------------------------------------------------------------------------

fn grade(app: *App, ctx: *d.Ctx) void {
    const dl = ctx.dl;
    for (0..4) |i| {
        const q: d.Rect = .{ .x = @as(f32, @floatFromInt(i % 2)) * W / 2, .y = @as(f32, @floatFromInt(i / 2)) * H / 2, .w = W / 2, .h = H / 2 };
        ctx.th = &app.themes[i];
        d.opt_theme = ctx.th;
        c.ImDrawList_PushClipRect(dl, d.v(q.x, q.y), d.v(q.right(), q.bottom()), false);
        defer c.ImDrawList_PopClipRect(dl);
        fundo(ctx, q);
        d.text(dl, ctx.mono.get(.regular), 13, q.x + 20, q.y + 16, ctx.col(.faint), ctx.th.name);
        const card: d.Rect = .{ .x = q.x + 60, .y = q.y + 46, .w = q.w - 120, .h = q.h - 86 };
        cartao(ctx, card);
        var p: comp.Page = .{ .ctx = ctx, .dl = dl, .x = card.x + 28, .y = card.y + 22, .w = card.w - 56, .scope = lk.id("grade", i) };
        p.line(.bold, 18, ctx.col(.text), if (lk.i18n.en()) ctx.th.description_en else ctx.th.description, 34);
        p.toggle(tr("Notificações", "Notifications"), "", &Estado.grade_toggle[i]);
        p.slider(tr("Volume", "Volume"), &Estado.grade_slider[i], 0, 1, "{d:.0}%", 100);
        var seg = Estado.grade_seg[i];
        const r: d.Rect = .{ .x = p.x, .y = p.y, .w = p.w - 150, .h = 38 };
        if (comp.segmented(ctx, dl, lk.id("grade-seg", i), r, &.{ "A", "B", "C" }, seg, .{ .tag = "grade-seg" })) |k| seg = @intCast(k);
        Estado.grade_seg[i] = seg;
        p.y += 56;
        p.note(tr("Os quatro cantos são o mesmo código: só o arquivo do tema muda.", "All four corners are the same code: only the theme file changes."));
        const ok = tr("Aplicar", "Apply");
        const okw = comp.buttonWidth(ctx, ok, .primary);
        _ = comp.button(ctx, dl, lk.id("grade-ok", i), .{ .x = card.right() - 28 - okw, .y = p.y + 1, .w = okw, .h = 36 }, ok, .{});
    }
    // As linhas entre os quatro.
    ctx.th = &app.themes[noite];
    d.line(dl, W / 2, 0, W / 2, H, d.Rgba.black.alpha(0.5), 2);
    d.line(dl, 0, H / 2, W, H / 2, d.Rgba.black.alpha(0.5), 2);
}

// --- Partes -----------------------------------------------------------------------------

fn partes(app: *App, ctx: *d.Ctx) void {
    _ = app;
    const dl = ctx.dl;
    fundo(ctx, ctx.win);
    d.text(dl, font(ctx, .bold), 26, 40, 34, ctx.col(.text), tr("Os mesmos componentes, outro visual", "The same components, another look"));
    d.text(dl, font(ctx, .regular), 15, 40, 72, ctx.col(.muted), tr("Só o bloco `parts` do tema mudou: cada pedaço tem um visual por estado.", "Only the theme's `parts` block changed: each piece has a look per state."));
    // O trecho do tema, como está no arquivo.
    const code: d.Rect = .{ .x = 40, .y = 120, .w = 660, .h = H - 160 };
    cartao(ctx, code);
    const src = temas[neon].src;
    const ini = std.mem.indexOf(u8, src, "parts {") orelse 0;
    const fim = (std.mem.indexOfPos(u8, src, ini, "\n}") orelse src.len) + 2;
    var it = std.mem.splitScalar(u8, src[ini..@min(fim, src.len)], '\n');
    var y = code.y + 24;
    while (it.next()) |l| : (y += 21) {
        const t = std.mem.trimEnd(u8, l, " ");
        const cor = if (std.mem.startsWith(u8, std.mem.trimStart(u8, t, " "), "part")) ctx.col(.text) else ctx.col(.accent);
        _ = d.textClipped(dl, ctx.mono.get(.regular), 12.5, code.x + 22, y, cor, t, code.w - 44);
    }
    // Os componentes com essas partes.
    const demo: d.Rect = .{ .x = 724, .y = 120, .w = W - 764, .h = H - 160 };
    cartao(ctx, demo);
    const x = demo.x + 36;
    d.text(dl, font(ctx, .semibold), 13, x, demo.y + 30, ctx.col(.muted), tr("BOTÕES (o primeiro com o mouse em cima)", "BUTTONS (the mouse is over the first)"));
    const b1 = tr("Continuar", "Continue");
    const b1w = comp.buttonWidth(ctx, b1, .primary);
    _ = comp.button(ctx, dl, lk.id("neon-b1", 0), .{ .x = x, .y = demo.y + 62, .w = b1w, .h = 40 }, b1, .{});
    const b2 = tr("Publicar", "Publish");
    const b2w = comp.buttonWidth(ctx, b2, .primary);
    _ = comp.button(ctx, dl, lk.id("neon-b2", 0), .{ .x = x + b1w + 14, .y = demo.y + 62, .w = b2w, .h = 40 }, b2, .{});
    const b3 = tr("Cancelar", "Cancel");
    _ = comp.button(ctx, dl, lk.id("neon-b3", 0), .{ .x = x + b1w + b2w + 28, .y = demo.y + 62, .w = comp.buttonWidth(ctx, b3, .soft), .h = 40 }, b3, .{ .kind = .soft });
    d.text(dl, font(ctx, .semibold), 13, x, demo.y + 140, ctx.col(.muted), tr("INTERRUPTORES", "SWITCHES"));
    _ = comp.toggle(ctx, dl, lk.id("neon-t1", 0), .{ .x = x, .y = demo.y + 170, .w = 40, .h = 24 }, &Estado.neon_on, .{ .label = "on" });
    _ = comp.toggle(ctx, dl, lk.id("neon-t2", 0), .{ .x = x + 64, .y = demo.y + 170, .w = 40, .h = 24 }, &Estado.neon_off, .{ .label = "off" });
    d.text(dl, font(ctx, .semibold), 13, x, demo.y + 232, ctx.col(.muted), "SLIDER");
    _ = comp.slider(ctx, dl, lk.id("neon-s", 0), .{ .x = x + 6, .y = demo.y + 272, .w = demo.w - 90, .h = 8 }, &Estado.neon_slider, 0, 1, .{ .label = "neon" });
    d.text(dl, font(ctx, .semibold), 13, x, demo.y + 326, ctx.col(.muted), tr("SELETOR", "SEGMENTED"));
    if (comp.segmented(ctx, dl, lk.id("neon-seg", 0), .{ .x = x, .y = demo.y + 356, .w = demo.w - 72, .h = 42 }, &.{ tr("Dia", "Day"), tr("Semana", "Week"), tr("Mês", "Month") }, Estado.neon_seg, .{})) |k| Estado.neon_seg = k;
}

// --- A animação -------------------------------------------------------------------------

/// O mouse passeando pelas Configurações: passa pelo botão, liga o modo compacto, arrasta
/// o tamanho do texto e troca o tema duas vezes. Um PNG por quadro em `dir`.
fn animacao(app: *App, dir: []const u8) !void {
    Estado.reset();
    Estado.tema = noite;
    app.cursor = true;
    defer app.cursor = false;
    var n: usize = 0;
    var pb: [1024]u8 = undefined;
    const Passo = struct { x: f32, y: f32, down: bool, quadros: usize };
    // As posições vêm das marcas do QA do quadro anterior.
    for (0..3) |_| frame(app, configuracoes, null);
    const salvar = lk.qa.find("button:Save") orelse lk.qa.find("button:Salvar") orelse return error.SemMarca;
    const compacto = lk.qa.find("toggle:Compact mode") orelse lk.qa.find("toggle:Modo compacto") orelse return error.SemMarca;
    const texto = lk.qa.find("slider:Text size") orelse lk.qa.find("slider:Tamanho do texto") orelse return error.SemMarca;
    const papel_r = lk.qa.find("seg:Papel") orelse return error.SemMarca;
    const terminal_r = lk.qa.find("seg:Terminal") orelse return error.SemMarca;
    const noite_r = lk.qa.find("seg:Noite") orelse return error.SemMarca;
    const knob_x = texto.x + 8 + (texto.w - 16) * (Estado.texto - 0.8) / 0.6;
    const passos = [_]Passo{
        .{ .x = 1180, .y = 760, .down = false, .quadros = 1 },
        .{ .x = salvar.x + salvar.w / 2, .y = salvar.y + salvar.h / 2, .down = false, .quadros = 18 },
        .{ .x = salvar.x + salvar.w / 2, .y = salvar.y + salvar.h / 2, .down = false, .quadros = 10 },
        .{ .x = compacto.right() - 24, .y = compacto.y + 16, .down = false, .quadros = 16 },
        .{ .x = compacto.right() - 24, .y = compacto.y + 16, .down = true, .quadros = 3 },
        .{ .x = compacto.right() - 24, .y = compacto.y + 16, .down = false, .quadros = 14 },
        .{ .x = knob_x, .y = texto.y + texto.h / 2, .down = false, .quadros = 14 },
        .{ .x = knob_x, .y = texto.y + texto.h / 2, .down = true, .quadros = 3 },
        .{ .x = knob_x + 120, .y = texto.y + texto.h / 2, .down = true, .quadros = 18 },
        .{ .x = knob_x + 120, .y = texto.y + texto.h / 2, .down = false, .quadros = 6 },
        .{ .x = papel_r.x + papel_r.w / 2, .y = papel_r.y + papel_r.h / 2, .down = false, .quadros = 16 },
        .{ .x = papel_r.x + papel_r.w / 2, .y = papel_r.y + papel_r.h / 2, .down = true, .quadros = 3 },
        .{ .x = papel_r.x + papel_r.w / 2, .y = papel_r.y + papel_r.h / 2, .down = false, .quadros = 20 },
        .{ .x = terminal_r.x + terminal_r.w / 2, .y = terminal_r.y + terminal_r.h / 2, .down = false, .quadros = 12 },
        .{ .x = terminal_r.x + terminal_r.w / 2, .y = terminal_r.y + terminal_r.h / 2, .down = true, .quadros = 3 },
        .{ .x = terminal_r.x + terminal_r.w / 2, .y = terminal_r.y + terminal_r.h / 2, .down = false, .quadros = 20 },
        .{ .x = noite_r.x + noite_r.w / 2, .y = noite_r.y + noite_r.h / 2, .down = false, .quadros = 12 },
        .{ .x = noite_r.x + noite_r.w / 2, .y = noite_r.y + noite_r.h / 2, .down = true, .quadros = 3 },
        .{ .x = noite_r.x + noite_r.w / 2, .y = noite_r.y + noite_r.h / 2, .down = false, .quadros = 24 },
    };
    var from: [2]f32 = .{ passos[0].x, passos[0].y };
    for (passos) |p| {
        for (0..p.quadros) |k| {
            // Anda com uma curva suave do ponto de antes até este.
            const t = d.easeOut(@as(f32, @floatFromInt(k + 1)) / @as(f32, @floatFromInt(p.quadros)));
            app.mouse = .{ from[0] + (p.x - from[0]) * t, from[1] + (p.y - from[1]) * t };
            app.down = p.down;
            const path = try std.fmt.bufPrintSentinel(&pb, "{s}/f{d:0>4}.png", .{ dir, n }, 0);
            frame(app, configuracoes, path);
            n += 1;
        }
        from = .{ p.x, p.y };
    }
    std.log.info("{d} quadros em {s}", .{ n, dir });
}
