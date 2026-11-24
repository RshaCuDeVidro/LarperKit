//! A janela e o laço de um app do kit: a SDL3, o renderizador, o Dear ImGui com os backends,
//! as fontes, e a espera quando nada muda. Parado, o laço dorme em `SDL_WaitEvent`: só acorda
//! com entrada, com `wake` (de qualquer thread: a rede avisou algo) ou com o prazo de uma
//! animação lenta (`anim.at`), e desenha enquanto algo se mexe (`anim.active`).
//!
//!     try lk.window.run(.{ .title = "Meu app", .theme = &tema }, &estado, desenha);
//!
//! A janela, a escala e o acordar vêm de src/platform/window.zig do larperCord (b5b3fc2); o
//! laço é o mesmo jeito de dormir do src/app.zig dele, sem o que é só do larperCord.
const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const d = @import("../ui/draw.zig");
const anim = @import("../ui/anim.zig");
const qa = @import("../ui/qa.zig");
const fx = @import("../ui/fx.zig");
const theme = @import("../theme/theme.zig");

/// O tipo do evento de `wake` (registrado em `run`); 0 antes disso.
var wake_type: std.atomic.Value(u32) = .init(0);

/// Acorda o laço para mais um quadro, com `code` para `Options.on_wake`. Pode ser chamado de
/// qualquer thread (a rede, um vigia de arquivos). Antes de `run`, não faz nada.
pub fn wake(code: i32) void {
    const t = wake_type.load(.acquire);
    if (t == 0) return;
    var ev = std.mem.zeroes(c.SDL_Event);
    ev.type = t;
    ev.user.code = code;
    _ = c.SDL_PushEvent(&ev);
}

/// Os arquivos TTF das famílias `ui` e `mono`, numa pasta. Sem pasta (ou sem um arquivo), a
/// fonte do próprio ImGui.
pub const Fonts = struct {
    dir: ?[]const u8 = null,
    ui: [5][]const u8 = .{ "Inter-Regular.ttf", "Inter-Medium.ttf", "Inter-SemiBold.ttf", "Inter-Bold.ttf", "Inter-Italic.ttf" },
    mono: [5][]const u8 = @splat("JetBrainsMono-Regular.ttf"),
    /// O tamanho base em que o ImGui gera as letras (o desenho pede o tamanho de cada texto).
    size: f32 = 16,
};

pub const Options = struct {
    title: [:0]const u8 = "LarperKit",
    /// O tamanho ao abrir, em pontos (com 150% no Windows, a janela abre 1,5 vez maior).
    width: c_int = 1280,
    height: c_int = 800,
    /// O renderizador da SDL (opengl, vulkan, gpu, software); null = o automático.
    renderer: ?[*:0]const u8 = null,
    theme: *const theme.Theme,
    fonts: Fonts = .{},
    /// Chamado quando chega um `wake(code)`, antes do quadro.
    on_wake: ?*const fn (code: i32) void = null,
    /// Para os testes: sai depois de tantos quadros (null = só quando a janela fecha).
    max_frames: ?u64 = null,
    /// Para os testes: sai quando a função disser.
    should_quit: ?*const fn () bool = null,
    /// A janela deixa ver o que está atrás onde o fundo do tema tem alfa (os temas de vidro;
    /// no Linux o compositor desfoca, no Windows o DWM mostra a área de trabalho). Ligada por
    /// padrão: a flag só vale ao criar a janela, e o tema pode virar vidro com o app aberto.
    /// Num tema opaco (fundo com alfa 1) não muda nada.
    transparent: bool = true,
};

/// O que o laço guarda entre um quadro e outro (o app lê pelo `Frame`).
pub const Window = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    io: *c.ImGuiIO,
    ui: d.Family,
    mono: d.Family,
    /// A escala que o sistema pede além do que a SDL já aplica (125% no Windows: 1,25).
    scale: f32 = 1,
    /// Quadros desenhados desde a abertura (os testes conferem que parado não desenha).
    frames: u64 = 0,
};

/// Abre a janela, roda o laço e fecha tudo quando a janela fecha. `draw(user, ctx)` desenha
/// cada quadro, com o contexto pronto (o tema, as fontes, as listas do ImGui, o mouse).
pub fn run(opts: Options, user: anytype, comptime draw: fn (@TypeOf(user), *d.Ctx) void) !void {
    var w = try open(opts);
    defer close(&w);
    loop(&w, opts, user, draw);
}

pub fn open(opts: Options) !Window {
    preferWayland();
    // O IME, por padrão, fica com a janela nativa dele e a SDL nunca manda o texto em
    // conversão: dizendo que o app desenha a composição, a SDL repassa o texto e a lista de
    // candidatos continua nativa.
    _ = c.SDL_SetHint(c.SDL_HINT_IME_IMPLEMENTED_UI, "composition");
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("SDL video: {s}", .{c.SDL_GetError()});
        return error.SdlInit;
    }
    errdefer c.SDL_Quit();
    const flags = c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY | (if (opts.transparent) c.SDL_WINDOW_TRANSPARENT else 0);
    const window = c.SDL_CreateWindow(opts.title.ptr, opts.width, opts.height, flags) orelse {
        const driver: [*:0]const u8 = c.SDL_GetCurrentVideoDriver() orelse "?";
        std.log.err("janela ({s}): {s}", .{ driver, c.SDL_GetError() });
        return error.SdlWindow;
    };
    errdefer c.SDL_DestroyWindow(window);
    // No Windows o tamanho pedido é em pixels: em 150% a janela abriria com 2/3 do tamanho.
    const s = contentScale(window);
    if (s != 1) openScaled(window, opts.width, opts.height, s);
    const renderer = c.SDL_CreateRenderer(window, opts.renderer) orelse c.SDL_CreateRenderer(window, null) orelse {
        std.log.err("renderizador: {s}", .{c.SDL_GetError()});
        return error.SdlRenderer;
    };
    errdefer c.SDL_DestroyRenderer(renderer);
    _ = c.SDL_SetRenderVSync(renderer, 1);
    // A limpeza troca os pixels, alfa incluído, em vez de misturar com o que já estava lá.
    _ = c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_NONE);
    wake_type.store(c.SDL_RegisterEvents(1), .release);

    _ = c.ImGui_CreateContext(null);
    errdefer c.ImGui_DestroyContext(null);
    const io = c.ImGui_GetIO();
    io.*.IniFilename = null;
    if (!c.cImGui_ImplSDL3_InitForSDLRenderer(window, renderer)) return error.ImguiSdl;
    if (!c.cImGui_ImplSDLRenderer3_Init(renderer)) return error.ImguiRenderer;
    return .{
        .window = window,
        .renderer = renderer,
        .io = io,
        .ui = loadFamily(io, opts.fonts.dir, opts.fonts.ui, opts.fonts.size),
        .mono = loadFamily(io, opts.fonts.dir, opts.fonts.mono, opts.fonts.size),
        .scale = s,
    };
}

pub fn close(w: *Window) void {
    wake_type.store(0, .release);
    fx.dropAll();
    c.cImGui_ImplSDLRenderer3_Shutdown();
    c.cImGui_ImplSDL3_Shutdown();
    c.ImGui_DestroyContext(null);
    c.SDL_DestroyRenderer(w.renderer);
    c.SDL_DestroyWindow(w.window);
    c.SDL_Quit();
}

/// Quantos quadros desenhar depois de um evento: o ImGui decide o hover e o clique um quadro
/// depois da entrada, e uma animação que começa nele só aparece no seguinte.
const settle_frames = 2;

pub fn loop(w: *Window, opts: Options, user: anytype, comptime draw: fn (@TypeOf(user), *d.Ctx) void) void {
    var pending: u32 = settle_frames;
    var last_ms: i64 = @intCast(c.SDL_GetTicks());
    var running = true;
    var e: c.SDL_Event = undefined;
    while (running) {
        if (opts.should_quit) |q| if (q()) break;
        if (opts.max_frames) |m| if (w.frames >= m) break;
        // Dorme até a entrada, um `wake` ou o prazo de uma animação lenta (o que vier
        // primeiro). Algo se mexendo, ou um evento que ainda está assentando: não dorme.
        const busy = pending > 0 or anim.active;
        const now_ms: i64 = @intCast(c.SDL_GetTicks());
        const due = anim.next_wake_ms;
        const clock_due = anim.clock_wake_ms;
        const nap = anim.napFor(if (due == std.math.maxInt(i64)) null else due -| now_ms, if (clock_due == std.math.maxInt(i64)) null else clock_due -| now_ms);
        const wait = @min(due, clock_due) -| now_ms;
        var got = if (busy or wait <= 0)
            c.SDL_PollEvent(&e)
        else if (nap) |ms|
            c.SDL_WaitEventTimeout(&e, @intCast(@max(ms, 1)))
        else
            c.SDL_WaitEvent(&e);
        // Acordou só porque o teto da espera venceu (ver anim.sleepFor) e o prazo não chegou.
        if (!got and !busy and wait > 0 and @as(i64, @intCast(c.SDL_GetTicks())) < @min(due, clock_due)) continue;
        while (got) {
            if (e.type == wake_type.load(.acquire)) {
                if (opts.on_wake) |f| f(e.user.code);
            } else {
                if (e.type == c.SDL_EVENT_QUIT or e.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) running = false;
                if (e.type == c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) w.scale = contentScale(w.window);
                // O mouse no lugar das coordenadas do app (com a escala, menores que os pixels).
                _ = c.SDL_ConvertEventToRenderCoordinates(w.renderer, &e);
                _ = c.cImGui_ImplSDL3_ProcessEvent(&e);
            }
            pending = settle_frames;
            got = c.SDL_PollEvent(&e);
        }
        if (!running) break;
        // Minimizada ou coberta: ninguém vê. Os eventos foram tratados; ao voltar, a SDL
        // avisa e o quadro sai certo.
        if (c.SDL_GetWindowFlags(w.window) & (c.SDL_WINDOW_MINIMIZED | c.SDL_WINDOW_OCCLUDED) != 0) {
            pending = 0;
            anim.active = false;
            continue;
        }
        const t: i64 = @intCast(c.SDL_GetTicks());
        anim.dt = std.math.clamp(@as(f32, @floatFromInt(t - last_ms)) / 1000, 1.0 / 240.0, 0.25);
        last_ms = t;
        frame(w, opts, user, draw, t);
        if (pending > 0) pending -= 1;
    }
}

fn frame(w: *Window, opts: Options, user: anytype, comptime draw: fn (@TypeOf(user), *d.Ctx) void, now_ms: i64) void {
    anim.active = false;
    anim.next_wake_ms = std.math.maxInt(i64);
    anim.clock_wake_ms = std.math.maxInt(i64);
    anim.now_ms = now_ms;
    qa.beginFrame();
    fx.beginFrame();
    c.cImGui_ImplSDLRenderer3_NewFrame();
    c.cImGui_ImplSDL3_NewFrame();
    // O fator único de escala: o app desenha em coordenadas lógicas e o backend multiplica
    // tudo pela escala do sistema (125% no Windows), com as letras geradas nela.
    if (w.scale != 1) {
        w.io.*.DisplaySize.x /= w.scale;
        w.io.*.DisplaySize.y /= w.scale;
        w.io.*.DisplayFramebufferScale.x *= w.scale;
        w.io.*.DisplayFramebufferScale.y *= w.scale;
    }
    c.ImGui_NewFrame();
    const size = w.io.*.DisplaySize;
    c.ImGui_SetNextWindowPos(.{ .x = 0, .y = 0 }, 0);
    c.ImGui_SetNextWindowSize(size, 0);
    c.ImGui_PushStyleVarImVec2(c.ImGuiStyleVar_WindowPadding, .{ .x = 0, .y = 0 });
    _ = c.ImGui_Begin("##app", null, c.ImGuiWindowFlags_NoDecoration | c.ImGuiWindowFlags_NoBackground | c.ImGuiWindowFlags_NoMove | c.ImGuiWindowFlags_NoBringToFrontOnFocus | c.ImGuiWindowFlags_NoScrollWithMouse);
    var ctx: d.Ctx = .{
        .th = opts.theme,
        .ui = &w.ui,
        .mono = &w.mono,
        .dl = c.ImGui_GetWindowDrawList(),
        .fg = c.ImGui_GetForegroundDrawList(),
        .io = w.io,
        .renderer = w.renderer,
        .mouse = w.io.*.MousePos,
        .now_ms = now_ms,
        .win = .{ .x = 0, .y = 0, .w = size.x, .h = size.y },
    };
    d.opt_theme = ctx.th;
    draw(user, &ctx);
    c.ImGui_End();
    c.ImGui_PopStyleVar();
    c.ImGui_Render();
    // O fundo do tema com o alfa dele, pré-multiplicado: no vidro, a janela fica translúcida.
    const bg = opts.theme.c(.bg);
    _ = c.SDL_SetRenderDrawColorFloat(w.renderer, bg.r * bg.a, bg.g * bg.a, bg.b * bg.a, bg.a);
    _ = c.SDL_RenderClear(w.renderer);
    c.cImGui_ImplSDLRenderer3_RenderDrawData(c.ImGui_GetDrawData(), w.renderer);
    _ = c.SDL_RenderPresent(w.renderer);
    w.frames += 1;
}

/// As cinco faces de uma família, da pasta de fontes; o que faltar usa a fonte do ImGui.
pub fn loadFamily(io: *c.ImGuiIO, dir: ?[]const u8, files: [5][]const u8, size: f32) d.Family {
    var faces: [5]*c.ImFont = undefined;
    var pb: [1024]u8 = undefined;
    for (files, &faces) |f, *face| {
        face.* = blk: {
            const base = dir orelse break :blk c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
            const path = std.fmt.bufPrintSentinel(&pb, "{s}/{s}", .{ base, f }, 0) catch break :blk c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
            var info: c.SDL_PathInfo = undefined;
            if (!c.SDL_GetPathInfo(path.ptr, &info)) break :blk c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
            break :blk c.ImFontAtlas_AddFontFromFileTTF(io.*.Fonts, path.ptr, size, null, null) orelse c.ImFontAtlas_AddFontDefault(io.*.Fonts, null);
        };
    }
    return .{ .name = files[0], .faces = faces };
}

/// How much the display scale asks for beyond what SDL already applies. On macOS
/// and Wayland the window is already in points (1); on Windows and X11 it is in
/// pixels, and the scale (125%, 150%…) is up to the app.
pub fn contentScale(window: *c.SDL_Window) f32 {
    const display = c.SDL_GetWindowDisplayScale(window);
    const density = c.SDL_GetWindowPixelDensity(window);
    if (display <= 0 or density <= 0) return 1;
    return display / density;
}

/// The opening size at this scale, up to what fits the display: 1280x800 at 150% is 1920x1200,
/// taller than a 1080p laptop. SDL centered the window for the old size, so it is centered again.
fn openScaled(window: *c.SDL_Window, w: c_int, h: c_int, s: f32) void {
    var sw: c_int = @intFromFloat(@as(f32, @floatFromInt(w)) * s);
    var sh: c_int = @intFromFloat(@as(f32, @floatFromInt(h)) * s);
    const display = c.SDL_GetDisplayForWindow(window);
    var area: c.SDL_Rect = undefined;
    if (c.SDL_GetDisplayUsableBounds(display, &area)) {
        var top: c_int = 0;
        var left: c_int = 0;
        var bottom: c_int = 0;
        var right: c_int = 0;
        _ = c.SDL_GetWindowBordersSize(window, &top, &left, &bottom, &right);
        sw = @min(sw, area.w - left - right);
        sh = @min(sh, area.h - top - bottom);
    }
    _ = c.SDL_SetWindowSize(window, sw, sh);
    const centered: c_int = @intCast(@as(u32, c.SDL_WINDOWPOS_CENTERED_MASK) | display);
    _ = c.SDL_SetWindowPosition(window, centered, centered);
}

/// Uma sessão Wayland usa a conexão nativa, mesmo em compositores onde a SDL prefere
/// XWayland. Se ela não estiver disponível, tenta X11. A prioridade mínima preserva
/// SDL_VIDEO_DRIVER (inclusive o offscreen dos testes) e outros hints.
fn preferWayland() void {
    if (builtin.os.tag != .linux) return;
    const display = c.SDL_getenv("WAYLAND_DISPLAY");
    const socket = c.SDL_getenv("WAYLAND_SOCKET");
    const session = c.SDL_getenv("XDG_SESSION_TYPE");
    const wayland = (display != null and display[0] != 0) or
        (socket != null and socket[0] != 0) or
        (session != null and std.mem.eql(u8, std.mem.span(session), "wayland"));
    if (wayland) _ = c.SDL_SetHintWithPriority(c.SDL_HINT_VIDEO_DRIVER, "wayland,x11", c.SDL_HINT_DEFAULT);
}
