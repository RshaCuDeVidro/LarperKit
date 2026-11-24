//! Componentes do kit: botão, interruptor, slider e seletor segmentado, e a página de
//! formulário que põe um embaixo do outro (`Page`, a das Configurações do larperCord).
//!
//! A API é a do WooferSoundPad: cada componente recebe o id (de `ids.id("nome", n)`, nunca
//! um número escolhido na mão), o retângulo e as opções, e devolve o que aconteceu. O
//! clique é o de `draw.hit`, a animação a de `anim.zig` (só pede quadro enquanto se mexe:
//! parado, nada), e cada clicável marca o retângulo para o QA ("button:Salvar"), que a
//! varredura de "clicar em tudo" usa.
//!
//! O desenho padrão é o do larperCord, copiado linha por linha: Page.button,
//! Page.buttonSoft, Page.toggleIf, Page.slider e Page.segmented de src/ui/settings.zig,
//! `segments` de src/ui/settings_voz.zig e `button` de src/ui/inbox.zig (b5b3fc2). Ainda
//! não foi comparado por imagem com o larperCord (MIGRATION.md). Um tema com `parts`
//! muda cada pedaço por estado (`part "button:hover" bg="@accent"`): as partes do kit estão
//! em `part_specs`, e o app as registra com `register` ao abrir.
const std = @import("std");
const c = @import("c");
const d = @import("draw.zig");
const anim = @import("anim.zig");
const qa = @import("qa.zig");
const icons = @import("icons.zig");
const ids = @import("ids.zig");
const ui_parts = @import("parts.zig");
const tparts = @import("../theme/parts.zig");
const schema = @import("../theme/schema.zig");

// --- As partes do kit -------------------------------------------------------------------

pub const Part = enum(u4) { button, button_soft, button_pill, toggle, toggle_knob, slider_track, slider_fill, slider_knob, segment };

/// Os estados, na ordem da precedência (o de baixo vence numa combinação).
pub const States = packed struct(u8) {
    on: bool = false,
    selected: bool = false,
    danger: bool = false,
    hover: bool = false,
    pressed: bool = false,
    disabled: bool = false,
    _resto: u2 = 0,
};

pub const state_specs = [_]tparts.StateSpec{
    .{ .name = "on", .desc = "an on/off switch that is on" },
    .{ .name = "selected", .desc = "the chosen option" },
    .{ .name = "danger", .desc = "a button that deletes or leaves" },
    .{ .name = "hover", .desc = "the mouse is over it" },
    .{ .name = "pressed", .desc = "the mouse button is held on it" },
    .{ .name = "disabled", .desc = "it can't be used now" },
};

pub const part_specs = [_]tparts.PartSpec{
    .{ .name = "button", .states = "danger hover pressed", .props = "bg color border border-width radius opacity weight", .desc = "the main button of a page; color is the label's" },
    .{ .name = "button.soft", .states = "hover pressed", .props = "bg color border border-width radius opacity weight", .desc = "a button that isn't the main action" },
    .{ .name = "button.pill", .states = "danger hover pressed", .props = "bg color border border-width radius opacity weight", .desc = "a small rounded text button (panels, lists)" },
    .{ .name = "toggle", .states = "on hover disabled", .props = "bg border border-width radius opacity", .desc = "the track of an on/off switch" },
    .{ .name = "toggle.knob", .states = "on disabled", .props = "bg color", .desc = "the knob of the switch; color is the check mark" },
    .{ .name = "slider.track", .states = "hover pressed", .props = "bg radius", .desc = "the track of a slider" },
    .{ .name = "slider.fill", .states = "hover pressed", .props = "bg radius", .desc = "the part of the track up to the value" },
    .{ .name = "slider.knob", .states = "hover pressed", .props = "bg border border-width radius", .desc = "the handle of a slider" },
    .{ .name = "segment", .states = "selected hover", .props = "bg color border border-width radius opacity weight", .desc = "one option of a segmented control; color is the label's" },
};

pub const P = tparts.PartSet(Part, States, &state_specs, &part_specs);

pub const extension: schema.Extension = .{ .parts = &P.definition };

/// As partes dos componentes passam a valer nos temas (ao abrir, antes de carregar temas).
pub fn register() void {
    schema.register(&extension);
}

fn look(ctx: *const d.Ctx, p: Part, s: States) *const tparts.Look {
    return P.get(ctx.th.parts, p, s);
}

fn col(ctx: *const d.Ctx, e: ?*const tparts.Expr, default: d.Rgba) d.Rgba {
    return ui_parts.colorOr(ctx, e, default);
}

// --- Botão ------------------------------------------------------------------------------

pub const ButtonKind = enum {
    /// A ação principal da página: a cor de destaque (Page.button).
    primary,
    /// Sem a cor de destaque, com borda (Page.buttonSoft).
    soft,
    /// Texto em pílula, que acende com o mouse (inbox.button).
    pill,
};

pub const ButtonOpts = struct {
    kind: ButtonKind = .primary,
    /// Apaga ou sai: o vermelho do tema (`danger`) no lugar do destaque.
    danger: bool = false,
    /// A marca do QA: null é "button:<texto>"; "" é nenhuma (quem chama marca).
    mark: ?[]const u8 = null,
};

/// Quanto o botão ocupa de largura (a altura é de quem chama: 36 numa página).
pub fn buttonWidth(ctx: *const d.Ctx, label: []const u8, kind: ButtonKind) f32 {
    return switch (kind) {
        .primary, .soft => d.width(ctx.ui.get(.semibold), 14, label) + 32,
        .pill => d.width(ctx.ui.get(.semibold), 13, label) + 24,
    };
}

/// Um botão de texto em `r`. Devolve se foi clicado.
pub fn button(ctx: *d.Ctx, dl: *c.ImDrawList, id: usize, r: d.Rect, label: []const u8, o: ButtonOpts) bool {
    const hb = d.hit(ctx, id, r);
    if (o.mark) |m| {
        if (m.len > 0) qa.mark(r, "{s}", .{m});
    } else qa.mark(r, "button:{s}", .{label});
    const part: Part = switch (o.kind) {
        .primary => .button,
        .soft => .button_soft,
        .pill => .button_pill,
    };
    const l = look(ctx, part, .{ .danger = o.danger, .hover = hb.hovered, .pressed = hb.held });
    const fade = ui_parts.Fade.begin(dl, l);
    defer fade.end();
    const base = if (o.danger) ctx.col(.danger) else ctx.col(.accent);
    switch (o.kind) {
        .primary => {
            const bg = if (hb.hovered) base.mix(d.Rgba.black, 0.12) else base;
            d.rect(dl, r, col(ctx, l.bg, bg), l.radius orelse ctx.th.radius);
            ui_parts.border(ctx, dl, l, r, ctx.th.radius);
            const fg = if (o.danger) d.Rgba.white else ctx.col(.accent_text);
            d.text(dl, ctx.ui.get(ui_parts.weightOr(l, .semibold)), 14, r.x + 16, d.centerY(r, 14), col(ctx, l.color, fg), label);
        },
        .soft => {
            const radius = l.radius orelse ctx.th.radius;
            d.rect(dl, r, col(ctx, l.bg, ctx.col(.elevated).mix(ctx.col(.text), if (hb.hovered) @as(f32, 0.08) else 0)), radius);
            if (l.border != null) ui_parts.border(ctx, dl, l, r, radius) else d.border(dl, r, ctx.col(.border).mix(ctx.col(.text), 0.08), radius, 1);
            d.text(dl, ctx.ui.get(ui_parts.weightOr(l, .semibold)), 14, r.x + 16, d.centerY(r, 14), col(ctx, l.color, ctx.col(.text)), label);
        },
        .pill => {
            const radius = l.radius orelse r.h / 2;
            d.rect(dl, r, col(ctx, l.bg, if (hb.hovered) base else ctx.col(.hover)), radius);
            ui_parts.border(ctx, dl, l, r, radius);
            const fg = if (hb.hovered) (if (o.danger) d.Rgba.white else ctx.col(.accent_text)) else if (o.danger) ctx.col(.danger) else ctx.col(.text);
            d.text(dl, ctx.ui.get(ui_parts.weightOr(l, .semibold)), 13, r.x + 12, d.centerY(r, 13), col(ctx, l.color, fg), label);
        },
    }
    return hb.clicked;
}

// --- Interruptor ------------------------------------------------------------------------

/// O interruptor de 40×24 com o canto de cima à esquerda em `sw`, `on` de 0 a 1 (animado
/// por quem chama) e `fade` 1, ou menos quando apagado.
pub fn toggleSwitch(ctx: *const d.Ctx, dl: *c.ImDrawList, sw: d.Rect, on: f32, fade: f32, hovered: bool) void {
    const s: States = .{ .on = on > 0.5, .hover = hovered, .disabled = fade < 1 };
    const lt = look(ctx, .toggle, s);
    const lk = look(ctx, .toggle_knob, s);
    const f = ui_parts.Fade.begin(dl, lt);
    defer f.end();
    const radius = lt.radius orelse 12;
    d.rect(dl, sw, col(ctx, lt.bg, ctx.col(.faint).mix(ctx.col(.accent), on).alpha(fade)), radius);
    ui_parts.border(ctx, dl, lt, sw, radius);
    const kx = sw.x + 12 + on * 16;
    d.circle(dl, kx, sw.y + 12, 9, col(ctx, lk.bg, d.Rgba.white.alpha(fade)));
    const ink = col(ctx, lk.color, ctx.col(.faint).mix(ctx.col(.accent), on).alpha(fade));
    if (on > 0.5) {
        d.line(dl, kx - 4, sw.y + 12, kx - 1, sw.y + 15, ink, 2);
        d.line(dl, kx - 1, sw.y + 15, kx + 4, sw.y + 9, ink, 2);
    } else {
        d.line(dl, kx - 3, sw.y + 9, kx + 3, sw.y + 15, ink, 2);
        d.line(dl, kx + 3, sw.y + 9, kx - 3, sw.y + 15, ink, 2);
    }
}

pub const ToggleOpts = struct {
    /// Falso: aparece apagado e o clique não muda nada (e a varredura do QA não o cobra).
    enabled: bool = true,
    /// O nome na marca do QA ("toggle:<nome>", ou "toggle-off:<nome>" apagado).
    label: []const u8 = "",
};

/// Só o interruptor, em `r` (40×24). Devolve se mudou.
pub fn toggle(ctx: *d.Ctx, dl: *c.ImDrawList, id: usize, r: d.Rect, value: *bool, o: ToggleOpts) bool {
    const hb = d.hit(ctx, id, r);
    if (o.enabled) qa.mark(r, "toggle:{s}", .{o.label}) else qa.mark(r, "toggle-off:{s}", .{o.label});
    const changed = hb.clicked and o.enabled;
    if (changed) value.* = !value.*;
    const on = anim.to(anim.id("sw", id), if (value.*) 1 else 0, 22);
    toggleSwitch(ctx, dl, r, on, if (o.enabled) 1 else 0.45, hb.hovered);
    return changed;
}

// --- Slider -----------------------------------------------------------------------------

pub const SliderOpts = struct {
    /// O nome na marca do QA ("slider:<nome>").
    label: []const u8 = "",
};

/// O trilho em `tr` (8 de altura numa página), com o botão e a área de arrastar em volta.
/// Devolve se o valor mudou.
pub fn slider(ctx: *d.Ctx, dl: *c.ImDrawList, id: usize, tr: d.Rect, value: *f32, min: f32, max: f32, o: SliderOpts) bool {
    const k = (value.* - min) / (max - min);
    const hr: d.Rect = .{ .x = tr.x - 8, .y = tr.y - 10, .w = tr.w + 16, .h = 28 };
    const hb = d.hit(ctx, id, hr);
    qa.mark(hr, "slider:{s}", .{o.label});
    const before = value.*;
    if (hb.held) {
        const t = std.math.clamp((ctx.mouse.x - tr.x) / tr.w, 0, 1);
        value.* = min + t * (max - min);
    }
    const s: States = .{ .hover = hb.hovered, .pressed = hb.held };
    const lt = look(ctx, .slider_track, s);
    const lf = look(ctx, .slider_fill, s);
    const lk = look(ctx, .slider_knob, s);
    d.rect(dl, tr, col(ctx, lt.bg, ctx.col(.elevated).mix(ctx.col(.text), 0.08)), lt.radius orelse 4);
    d.rect(dl, .{ .x = tr.x, .y = tr.y, .w = tr.w * k, .h = tr.h }, col(ctx, lf.bg, ctx.col(.accent)), lf.radius orelse 4);
    const kx = tr.x + tr.w * k;
    const knob: d.Rect = .{ .x = kx - 6, .y = tr.y - 8, .w = 12, .h = 24 };
    d.shadow(dl, .{ .x = kx - 7, .y = tr.y - 7, .w = 14, .h = 22 }, 4, 4, ctx.col(.shadow));
    d.rect(dl, knob, col(ctx, lk.bg, d.Rgba.white), lk.radius orelse 3);
    ui_parts.border(ctx, dl, lk, knob, 3);
    return value.* != before;
}

// --- Seletor segmentado -----------------------------------------------------------------

pub const SegmentedOpts = struct {
    /// `suave`: a escolha acende com animação e um texto longo diminui a fonte
    /// (Page.segmented). `simples`: sem animação, fonte fixa (os de settings_voz.zig).
    style: enum { smooth, plain } = .smooth,
    /// A marca do QA de cada opção: null é "seg:<texto>"; senão "<tag>:<índice>".
    tag: ?[]const u8 = null,
};

/// Opções lado a lado em `r` (a altura é a de cada botão), uma escolhida. Devolve a que
/// foi clicada.
pub fn segmented(ctx: *d.Ctx, dl: *c.ImDrawList, id: usize, r: d.Rect, options: []const []const u8, selected: usize, o: SegmentedOpts) ?usize {
    const gap: f32 = 8;
    const count: f32 = @floatFromInt(options.len);
    const bw = (r.w - gap * (count - 1)) / count;
    var clicked: ?usize = null;
    for (options, 0..) |opt, i| {
        const br: d.Rect = .{ .x = r.x + @as(f32, @floatFromInt(i)) * (bw + gap), .y = r.y, .w = bw, .h = r.h };
        const hb = d.hit(ctx, ids.sub(id, i), br);
        if (o.tag) |t| qa.mark(br, "{s}:{d}", .{ t, i }) else qa.mark(br, "seg:{s}", .{opt});
        if (hb.clicked) clicked = i;
        const sel = selected == i;
        const l = look(ctx, .segment, .{ .selected = sel, .hover = hb.hovered });
        const fade = ui_parts.Fade.begin(dl, l);
        defer fade.end();
        const radius = l.radius orelse ctx.th.radius + 2;
        const font = ctx.ui.get(ui_parts.weightOr(l, .semibold));
        const bg = switch (o.style) {
            .smooth => blk: {
                const k = anim.to(anim.id("seg", ids.sub(id, i)), if (sel) 1 else if (hb.hovered) 0.4 else 0, 20);
                break :blk ctx.col(.rail).alpha(0.6).mix(ctx.col(.accent).alpha(0.22), k);
            },
            .plain => if (sel) ctx.col(.accent).alpha(0.22) else if (hb.hovered) ctx.col(.hover) else ctx.col(.rail).alpha(0.6),
        };
        d.rect(dl, br, col(ctx, l.bg, bg), radius);
        if (l.border != null) ui_parts.border(ctx, dl, l, br, radius) else d.border(dl, br, if (sel) ctx.col(.accent) else ctx.col(.border), radius, if (sel) 2 else 1);
        // Uma opção longa (russo, alemão) diminui a fonte em vez de passar da borda.
        const fs = if (o.style == .smooth) fitSize(font, 15, 11, opt, br.w - 12) else 15;
        const tw = d.width(font, fs, opt);
        d.text(dl, font, fs, br.x + (br.w - tw) / 2, d.centerY(br, fs), col(ctx, l.color, if (sel) ctx.col(.text) else ctx.col(.muted)), opt);
    }
    return clicked;
}

// --- Texto ------------------------------------------------------------------------------

/// Textos que não couberam onde deviam: só os builds de debug contam (o QA confere que
/// nenhuma tela corta nada, em cada idioma).
const count_overflows = @import("builtin").mode == .debug;
pub var overflows: std.atomic.Value(u32) = .init(0);
pub var last_overflow: [96]u8 = undefined;
pub var last_overflow_len: usize = 0;

pub fn noteOverflow(text: []const u8) void {
    if (comptime !count_overflows) return;
    _ = overflows.fetchAdd(1, .monotonic);
    const n = d.utf8Prefix(text, last_overflow.len).len;
    @memcpy(last_overflow[0..n], text[0..n]);
    last_overflow_len = n;
}

/// O tamanho de fonte que faz `text` caber em `avail`, de `size` até `min` (abaixo disso o
/// texto fica ilegível, e conta como estouro).
pub fn fitSize(font: *c.ImFont, size: f32, min: f32, text: []const u8, avail: f32) f32 {
    const tw = d.width(font, size, text);
    if (tw <= avail) return size;
    const k = @max(min, @floor(size * avail / tw * 2) / 2);
    if (d.width(font, k, text) > avail) noteOverflow(text);
    return k;
}

/// Texto quebrado por palavra em até `max_lines` linhas (a última corta com
/// "…"). Com `dl` null só mede. Retorna a altura usada.
pub fn wrapText(dl: ?*c.ImDrawList, font: *c.ImFont, size: f32, x: f32, y: f32, max_w: f32, text: []const u8, max_lines: usize, color: d.Rgba) f32 {
    const lh = d.fontPx(size) * 1.38;
    const space = d.width(font, size, " ");
    var lines: usize = 0;
    var start: ?usize = null;
    var end: usize = 0;
    var cur: f32 = 0;
    var it = std.mem.tokenizeAny(u8, text, " \n");
    while (it.next()) |word| {
        const off = @intFromPtr(word.ptr) - @intFromPtr(text.ptr);
        const ww = d.width(font, size, word);
        if (start == null) {
            start = off;
            end = off + word.len;
            cur = ww;
            continue;
        }
        if (cur + space + ww <= max_w) {
            end = off + word.len;
            cur += space + ww;
            continue;
        }
        // Última linha permitida: o resto vai nela, cortado.
        if (lines + 1 == max_lines) {
            if (dl) |l| _ = d.textClipped(l, font, size, x, y + @as(f32, @floatFromInt(lines)) * lh, color, text[start.?..], max_w);
            return @as(f32, @floatFromInt(lines + 1)) * lh;
        }
        if (dl) |l| _ = d.textClipped(l, font, size, x, y + @as(f32, @floatFromInt(lines)) * lh, color, text[start.?..end], max_w);
        lines += 1;
        start = off;
        end = off + word.len;
        cur = ww;
    }
    if (start) |s| {
        if (dl) |l| _ = d.textClipped(l, font, size, x, y + @as(f32, @floatFromInt(lines)) * lh, color, text[s..end], max_w);
        lines += 1;
    }
    return @as(f32, @floatFromInt(lines)) * lh;
}

// --- Página de formulário ---------------------------------------------------------------

/// Estado de desenho de uma página (posição corrente, largura útil): cada peça desenha em
/// `y` e desce. `scope` separa os ids de uma página dos de outra (`ids.id("pagina", n)`).
pub const Page = struct {
    ctx: *d.Ctx,
    dl: *c.ImDrawList,
    x: f32,
    y: f32,
    w: f32,
    scope: usize,
    ids: usize = 0,
    /// Marcações do QA para o que é só texto (o QA confere que nada se sobrepõe).
    marks: usize = 0,
    /// Fim do último botão e, depois de `sameLine`, onde vem o próximo.
    button_end: f32 = 0,
    line_x: ?f32 = null,

    pub fn id(p: *Page) usize {
        p.ids += 1;
        return ids.sub(p.scope, p.ids);
    }

    pub fn markText(p: *Page, r: d.Rect) void {
        qa.mark(r, "pg:{d}", .{p.marks});
        p.marks += 1;
    }

    pub fn font(p: *Page, wt: d.Weight) *c.ImFont {
        return p.ctx.ui.get(wt);
    }

    pub fn title(p: *Page, t: []const u8) void {
        d.text(p.dl, p.font(.bold), 22, p.x, p.y, p.ctx.col(.text), t);
        p.markText(.{ .x = p.x, .y = p.y, .w = d.width(p.font(.bold), 22, t), .h = 28 });
        p.y += 44;
    }

    /// Uma linha de texto solta, que ocupa `advance` de altura.
    pub fn line(p: *Page, wt: d.Weight, size: f32, color: d.Rgba, t: []const u8, advance: f32) void {
        if (d.width(p.font(wt), size, t) > p.w) noteOverflow(t);
        const tw = d.textClipped(p.dl, p.font(wt), size, p.x, p.y, color, t, p.w);
        p.markText(.{ .x = p.x, .y = p.y, .w = tw, .h = advance - 4 });
        p.y += advance;
    }

    pub fn heading(p: *Page, t: []const u8) void {
        p.y += 8;
        var buf: [96]u8 = undefined;
        const up = d.upper(&buf, t);
        d.text(p.dl, p.font(.bold), 12, p.x, p.y, p.ctx.col(.muted), up);
        p.markText(.{ .x = p.x, .y = p.y, .w = d.width(p.font(.bold), 12, up), .h = 16 });
        p.y += 26;
    }

    /// Texto de apoio: quebra a linha em vez de passar da página.
    pub fn note(p: *Page, t: []const u8) void {
        const h = wrapText(p.dl, p.font(.regular), 13.5, p.x, p.y, p.w, t, 8, p.ctx.col(.faint));
        p.markText(.{ .x = p.x, .y = p.y, .w = @min(d.width(p.font(.regular), 13.5, t), p.w), .h = h });
        p.y += @round(h + 7.4);
    }

    pub fn divider(p: *Page) void {
        p.y += 10;
        d.line(p.dl, p.x, p.y, p.x + p.w, p.y, p.ctx.col(.border).mix(p.ctx.col(.text), 0.03), 1);
        p.y += 20;
    }

    /// Linha com título, descrição e um interruptor à direita.
    pub fn toggle(p: *Page, label: []const u8, desc: []const u8, value: *bool) void {
        p.toggleIf(label, desc, value, true);
    }

    /// `enabled` falso: a opção aparece apagada e o clique não muda nada (quem
    /// chama explica o motivo logo abaixo, com `note`).
    pub fn toggleIf(p: *Page, label: []const u8, desc: []const u8, value: *bool, enabled: bool) void {
        const ctx = p.ctx;
        // A descrição quebra a linha (numa janela estreita, cortar perderia o que
        // a opção faz), e a linha cresce junto.
        const desc_w = p.w - 80;
        const desc_h = if (desc.len > 0) wrapText(null, p.font(.regular), 13.5, 0, 0, desc_w, desc, 6, ctx.col(.muted)) else 0;
        const row_h: f32 = if (desc.len > 0) 58 + @round(@max(desc_h - 19, 0)) else 40;
        const r: d.Rect = .{ .x = p.x, .y = p.y, .w = p.w, .h = row_h };
        const k_id = p.id();
        const hb = d.hit(ctx, k_id, r);
        // Apagada não é um botão: a varredura do QA ("clicar em tudo") não a cobra.
        if (enabled) qa.mark(r, "toggle:{s}", .{label}) else qa.mark(r, "toggle-off:{s}", .{label});
        if (hb.clicked and enabled) value.* = !value.*;
        const fade: f32 = if (enabled) 1 else 0.45;
        // O rótulo não pode passar por baixo do interruptor.
        if (d.width(p.font(.medium), 16, label) > desc_w) noteOverflow(label);
        d.text(p.dl, p.font(.medium), 16, r.x, r.y + 4, ctx.col(.text).alpha(fade), label);
        if (desc.len > 0) _ = wrapText(p.dl, p.font(.regular), 13.5, r.x, r.y + 28, desc_w, desc, 6, ctx.col(.muted).alpha(fade));
        const sw: d.Rect = .{ .x = r.right() - 44, .y = r.y + 4, .w = 40, .h = 24 };
        const on = anim.to(anim.id("sw", k_id), if (value.*) 1 else 0, 22);
        toggleSwitch(ctx, p.dl, sw, on, fade, hb.hovered);
        p.y += row_h;
        d.line(p.dl, r.x, p.y - 8, r.right(), p.y - 8, ctx.col(.border), 1);
        p.y += 6;
    }

    /// Controle deslizante com valor em texto.
    pub fn slider(p: *Page, label: []const u8, value: *f32, min: f32, max: f32, comptime fmt: []const u8, scale: f32) void {
        const ctx = p.ctx;
        d.text(p.dl, p.font(.medium), 16, p.x, p.y, ctx.col(.text), label);
        p.y += 30;
        const tr: d.Rect = .{ .x = p.x + 6, .y = p.y + 6, .w = p.w - 80, .h = 8 };
        _ = sliderTrack(ctx, p.dl, p.id(), tr, value, min, max, .{ .label = label });
        var buf: [32]u8 = undefined;
        const txt = std.fmt.bufPrint(&buf, fmt, .{value.* * scale}) catch "";
        d.text(p.dl, p.font(.semibold), 14, tr.right() + 22, tr.y - 5, ctx.col(.muted), txt);
        p.y += 40;
    }

    /// Escolha entre opções (clique alterna, como um menu compacto).
    pub fn select(p: *Page, label: []const u8, options: []const []const u8, value: *u8) void {
        const ctx = p.ctx;
        d.text(p.dl, p.font(.bold), 12, p.x, p.y, ctx.col(.muted), label);
        p.y += 22;
        const r: d.Rect = .{ .x = p.x, .y = p.y, .w = p.w, .h = 42 };
        const hb = d.hit(ctx, p.id(), r);
        qa.mark(r, "select:{s}", .{label});
        if (hb.clicked) value.* = @intCast((@as(usize, value.*) + 1) % options.len);
        d.rect(p.dl, r, ctx.col(.rail).mix(ctx.col(.elevated), if (hb.hovered) 0.4 else 0.2), ctx.th.radius);
        d.border(p.dl, r, if (hb.hovered) ctx.col(.accent).alpha(0.6) else ctx.col(.border), ctx.th.radius, 1);
        d.text(p.dl, p.font(.medium), 15, r.x + 12, d.centerY(r, 15), ctx.col(.text), options[@min(value.*, options.len - 1)]);
        icons.chevron(p.dl, r.right() - 20, r.y + 21, ctx.col(.muted).u(), 1);
        p.y += 54;
    }

    pub fn radio(p: *Page, options: []const []const u8, descs: []const []const u8, value: *u8) void {
        const ctx = p.ctx;
        for (options, 0..) |o, i| {
            const r: d.Rect = .{ .x = p.x, .y = p.y, .w = p.w, .h = if (descs.len > i) @as(f32, 60) else 44 };
            const hb = d.hit(ctx, p.id(), r);
            qa.mark(r, "radio:{s}", .{o});
            if (hb.clicked) value.* = @intCast(i);
            const sel = value.* == i;
            d.rect(p.dl, r, if (sel) ctx.col(.selected) else if (hb.hovered) ctx.col(.hover) else ctx.col(.rail).alpha(0.5), ctx.th.radius);
            const cx = r.x + 22;
            const cy = r.y + 22;
            c.ImDrawList_AddCircleEx(p.dl, d.v(cx, cy), 9, (if (sel) ctx.col(.accent) else ctx.col(.muted)).u(), 0, 2, 0);
            if (sel) d.circle(p.dl, cx, cy, 5, ctx.col(.accent));
            if (d.width(p.font(.medium), 15, o) > r.w - 56) noteOverflow(o);
            d.text(p.dl, p.font(.medium), 15, r.x + 44, r.y + 12, ctx.col(.text), o);
            if (descs.len > i) {
                if (d.width(p.font(.regular), 13, descs[i]) > r.w - 56) noteOverflow(descs[i]);
                d.text(p.dl, p.font(.regular), 13, r.x + 44, r.y + 34, ctx.col(.muted), descs[i]);
            }
            p.y += r.h + 8;
        }
        p.y += 8;
    }

    /// Botões lado a lado, um selecionado.
    pub fn segmented(p: *Page, options: []const []const u8, value: *u8) void {
        const r: d.Rect = .{ .x = p.x, .y = p.y, .w = p.w, .h = 44 };
        if (segmentedRow(p.ctx, p.dl, p.id(), r, options, value.*, .{})) |i| value.* = @intCast(i);
        p.y += 60;
    }

    /// Quanto um botão ocupa na página.
    const button_step: f32 = 44;

    /// O botão anda com o cursor da página, como tudo aqui: quem vem depois nunca
    /// cai em cima dele. Dois na mesma linha: `sameLine` entre eles.
    pub fn button(p: *Page, label: []const u8, danger: bool) bool {
        const r = p.buttonRect(label);
        return buttonAt(p.ctx, p.dl, p.id(), r, label, .{ .danger = danger });
    }

    /// Um botão que não é a ação principal da página: sem a cor de destaque.
    pub fn buttonSoft(p: *Page, label: []const u8) bool {
        const r = p.buttonRect(label);
        return buttonAt(p.ctx, p.dl, p.id(), r, label, .{ .kind = .soft });
    }

    /// Onde vai o próximo botão; o cursor da página já anda.
    fn buttonRect(p: *Page, label: []const u8) d.Rect {
        const r: d.Rect = .{ .x = p.line_x orelse p.x, .y = p.y, .w = d.width(p.font(.semibold), 14, label) + 32, .h = 36 };
        if (r.right() > p.x + p.w + 0.5) noteOverflow(label);
        p.line_x = null;
        p.button_end = r.right();
        p.y += button_step;
        return r;
    }

    /// O próximo botão fica ao lado do último, em vez de embaixo.
    pub fn sameLine(p: *Page) void {
        p.y -= button_step;
        p.line_x = p.button_end + 8;
    }
};

// Os nomes de fora da página, para os métodos dela chamarem sem confundir com os seus.
const buttonAt = button;
const sliderTrack = slider;
const segmentedRow = segmented;
