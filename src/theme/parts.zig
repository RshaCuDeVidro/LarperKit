//! Partes de dentro dos componentes, com estados: o bloco `parts` do tema.
//!
//!     parts {
//!         part "message.author" color="@accent" weight=bold
//!         part "message:hover" bg="@hover" radius=6
//!         part "channel.item:selected" bg="@selected" color="@text"
//!         part "channel.item:selected:hover" bg="mix(@selected, @text, 0.05)"
//!     }
//!
//! Quais partes existem é de cada app (e de cada componente do kit): cada um monta um
//! conjunto com `Partes` (as partes, os estados que valem em cada uma e as propriedades,
//! com uma linha em inglês) e registra com `registrar` (ou `schema.registrar`). A tabela
//! `props` abaixo é a mesma para todos.
//!
//! Tudo é resolvido ao carregar o tema: para cada parte e cada combinação de estados, a
//! cascata vira um `Look` numa tabela, e quem desenha só indexa (`Partes(…).get`), sem
//! comparar nome nem alocar. As cores são expressões guardadas (`color.Expr`), avaliadas
//! no quadro com os tokens do momento, como as de `fx.zig`: seguem a cor de destaque
//! escolhida, a do servidor e o `c-…` do pedaço do layout. Tema sem `parts` não tem
//! tabela (null) e os componentes desenham como sempre.
const std = @import("std");
const kdl = @import("kdl.zig");
const color = @import("color.zig");
const fx = @import("fx.zig");
pub const Expr = color.Expr;
pub const Weight = fx.Weight;

// --- O que existe -----------------------------------------------------------------------

/// Um estado de um conjunto. Na lista do conjunto, a ordem é a da precedência: numa
/// combinação, o de baixo vence o de cima. No máximo 8 por conjunto.
pub const StateSpec = struct { name: []const u8, desc: []const u8 };

pub const Kind = enum { color, number, weight };

pub const Prop = enum(u4) { bg, color, border, border_width, radius, bar, bar_width, opacity, weight };

pub const PropSpec = struct { name: []const u8, kind: Kind, min: f32 = 0, max: f32 = 0, desc: []const u8 };

/// Números fora da faixa são trazidos para dentro dela, como no resto do tema.
pub const props = [_]PropSpec{
    .{ .name = "bg", .kind = .color, .desc = "background" },
    .{ .name = "color", .kind = .color, .desc = "text color" },
    .{ .name = "border", .kind = .color, .desc = "border all around" },
    .{ .name = "border-width", .kind = .number, .min = 0.5, .max = 8, .desc = "border thickness in pixels (1 when not set)" },
    .{ .name = "radius", .kind = .number, .min = 0, .max = 64, .desc = "rounding of the background and the border" },
    .{ .name = "bar", .kind = .color, .desc = "a stripe along the side where the text starts" },
    .{ .name = "bar-width", .kind = .number, .min = 1, .max = 16, .desc = "stripe thickness in pixels (3 when not set)" },
    .{ .name = "opacity", .kind = .number, .min = 0, .max = 1, .desc = "opacity of everything drawn in the part, from 0 to 1" },
    .{ .name = "weight", .kind = .weight, .desc = "font weight: regular, medium, semibold, bold or italic" },
};

/// `states` e `props`: nomes separados por espaço (uma entrada por linha, para quem gera
/// a documentação ler a lista).
pub const PartSpec = struct { name: []const u8, states: []const u8, props: []const u8, desc: []const u8 };

/// As partes de um app, com os estados delas: o que `registrar` recebe. Montado em tempo
/// de compilação por `Partes`, que confere a tabela.
pub const Conjunto = struct {
    estados: []const StateSpec,
    partes: []const PartSpec,
    /// Os estados e as propriedades de cada parte, como bits (lidos das strings da tabela).
    valid_states: []const u8,
    valid_props: []const u16,

    fn stateIndex(c: *const Conjunto, name: []const u8) ?u3 {
        for (c.estados, 0..) |s, i| if (std.mem.eql(u8, s.name, name)) return @intCast(i);
        return null;
    }

    fn propIndex(name: []const u8) ?Prop {
        inline for (props, 0..) |p, i| if (std.mem.eql(u8, p.name, name)) return @enumFromInt(i);
        return null;
    }

    fn partIndex(c: *const Conjunto, name: []const u8) ?u16 {
        for (c.partes, 0..) |p, i| if (std.mem.eql(u8, p.name, name)) return @intCast(i);
        return null;
    }

    fn hasState(c: *const Conjunto, p: usize, s: u3) bool {
        return c.valid_states[p] & (@as(u8, 1) << s) != 0;
    }

    fn hasProp(c: *const Conjunto, p: usize, pr: Prop) bool {
        return c.valid_props[p] & (@as(u16, 1) << @intFromEnum(pr)) != 0;
    }
};

/// O conjunto de um app com os tipos dele: `Part` é um enum com uma entrada por parte, na
/// ordem de `partes` (`channel.voice-member` é `channel_voice_member`), e `States` um
/// `packed struct(u8)` com um bool por estado, na ordem de `estados`. O app registra
/// `&conjunto` e desenha com `get`.
pub fn Partes(comptime TPart: type, comptime TStates: type, comptime estados: []const StateSpec, comptime partes: []const PartSpec) type {
    comptime {
        std.debug.assert(estados.len <= 8);
        std.debug.assert(@typeInfo(TPart).@"enum".field_names.len == partes.len);
        std.debug.assert(@bitSizeOf(TStates) == 8);
        for (partes, 0..) |p, i| std.debug.assert(sameName(p.name, @tagName(@as(TPart, @enumFromInt(i)))));
        for (estados, 0..) |s, i| std.debug.assert(std.mem.eql(u8, s.name, @typeInfo(TStates).@"struct".field_names[i]));
    }
    return struct {
        pub const Part = TPart;
        pub const States = TStates;

        const valid_states: [partes.len]u8 = blk: {
            @setEvalBranchQuota(20_000);
            var out: [partes.len]u8 = @splat(0);
            for (partes, 0..) |p, i| {
                var it = std.mem.tokenizeScalar(u8, p.states, ' ');
                next: while (it.next()) |s| {
                    for (estados, 0..) |e, k| if (std.mem.eql(u8, e.name, s)) {
                        out[i] |= @as(u8, 1) << k;
                        continue :next;
                    };
                    @compileError("estado desconhecido na tabela: " ++ s);
                }
            }
            break :blk out;
        };

        const valid_props: [partes.len]u16 = blk: {
            @setEvalBranchQuota(20_000);
            var out: [partes.len]u16 = @splat(0);
            for (partes, 0..) |p, i| {
                var it = std.mem.tokenizeScalar(u8, p.props, ' ');
                while (it.next()) |s| out[i] |= @as(u16, 1) << @intFromEnum(Conjunto.propIndex(s) orelse @compileError("propriedade desconhecida na tabela: " ++ s));
            }
            break :blk out;
        };

        pub const conjunto: Conjunto = .{ .estados = estados, .partes = partes, .valid_states = &valid_states, .valid_props = &valid_props };

        /// Como a parte fica nessa combinação de estados, no tema `t` (`theme.parts`).
        pub fn get(t: ?*const Table, p: TPart, s: TStates) *const Look {
            const tb = t orelse return &none;
            const index = tb.indexOf(&conjunto) orelse return &none;
            return &tb.looks[index[@intFromEnum(p)][@as(u8, @bitCast(s))]];
        }

        pub fn hasState(p: TPart, s: std.meta.FieldEnum(TStates)) bool {
            return conjunto.hasState(@intFromEnum(p), @intCast(@intFromEnum(s)));
        }

        pub fn hasProp(p: TPart, pr: Prop) bool {
            return conjunto.hasProp(@intFromEnum(p), pr);
        }
    };
}

/// `channel.voice-member` é `channel_voice_member`.
fn sameName(name: []const u8, tag: []const u8) bool {
    if (name.len != tag.len) return false;
    for (name, tag) |a, b| {
        const x: u8 = if (a == '.' or a == '-') '_' else a;
        if (x != b) return false;
    }
    return true;
}

// --- Registro ---------------------------------------------------------------------------

var registrados: [8]*const Conjunto = undefined;
var n_registrados: usize = 0;

/// Junta um conjunto aos que os temas entendem (uma vez basta; repetir não faz nada). Só
/// na thread da interface, antes de carregar temas: os temas já carregados não veem o novo.
pub fn registrar(c: *const Conjunto) void {
    for (conjuntos()) |old| if (old == c) return;
    std.debug.assert(n_registrados < registrados.len);
    registrados[n_registrados] = c;
    n_registrados += 1;
}

pub fn conjuntos() []const *const Conjunto {
    return registrados[0..n_registrados];
}

/// A parte com esse nome, em algum conjunto registrado.
fn find(name: []const u8) ?struct { set: u8, part: u16 } {
    for (conjuntos(), 0..) |c, i| if (c.partIndex(name)) |p| return .{ .set = @intCast(i), .part = p };
    return null;
}

// --- O resultado ------------------------------------------------------------------------

/// Como uma parte fica numa combinação de estados. null = o desenho de sempre do app.
pub const Look = struct {
    bg: ?*const Expr = null,
    color: ?*const Expr = null,
    border: ?*const Expr = null,
    bar: ?*const Expr = null,
    border_width: f32 = 1,
    bar_width: f32 = 3,
    radius: ?f32 = null,
    opacity: f32 = 1,
    weight: ?Weight = null,
    /// Alguma regra mexeu nesta parte nesta combinação (false = tudo como sempre).
    any: bool = false,
};

/// A parte sem regra nenhuma (e a de todo tema sem `parts`).
pub const none: Look = .{};

pub const Table = struct {
    /// Um índice por conjunto registrado quando o tema carregou: para cada parte e cada
    /// combinação dos 8 estados, o índice em `looks`. Os bits que não valem para a parte
    /// dão no mesmo que sem eles.
    sets: []const SetIndex,
    /// `looks[0]` é `none`.
    looks: []const Look,

    pub const SetIndex = struct { conjunto: *const Conjunto, index: []const [256]u16 };

    fn indexOf(t: *const Table, c: *const Conjunto) ?[]const [256]u16 {
        for (t.sets) |s| if (s.conjunto == c) return s.index;
        return null;
    }
};

// --- Leitura e cascata ------------------------------------------------------------------

/// O que uma regra diz (null = não fala disso).
const Set = struct {
    bg: ?*const Expr = null,
    color: ?*const Expr = null,
    border: ?*const Expr = null,
    bar: ?*const Expr = null,
    border_width: ?f32 = null,
    bar_width: ?f32 = null,
    radius: ?f32 = null,
    opacity: ?f32 = null,
    weight: ?Weight = null,

    /// Por cima de `l`, propriedade por propriedade.
    fn onto(s: Set, l: *Look) void {
        inline for (@typeInfo(Set).@"struct".field_names) |f| if (@field(s, f)) |v| {
            @field(l, f) = v;
            l.any = true;
        };
    }
};

const Rule = struct {
    set_index: u8,
    part: u16,
    mask: u8,
    set: Set,
    /// Ordem no arquivo (o de baixo vence um empate).
    order: u32,

    /// Ordem da cascata: o estado mais forte da regra, depois quantos estados, depois a linha.
    fn before(_: void, a: Rule, b: Rule) bool {
        const ta = top(a.mask);
        const tb = top(b.mask);
        if (ta != tb) return ta < tb;
        const ca = @popCount(a.mask);
        const cb = @popCount(b.mask);
        if (ca != cb) return ca < cb;
        return a.order < b.order;
    }

    fn top(mask: u8) i8 {
        return if (mask == 0) -1 else 7 - @as(i8, @clz(mask));
    }
};

/// As mensagens de erro de cada propriedade, prontas (o diagnóstico guarda só o ponteiro).
const bad_value = blk: {
    var out: [props.len][]const u8 = undefined;
    for (props, 0..) |p, i| out[i] = switch (p.kind) {
        .color => "cor inválida em " ++ p.name,
        .number => p.name ++ " precisa de um número",
        .weight => "weight: regular, medium, semibold, bold ou italic",
    };
    break :blk out;
};

/// Junta as regras dos blocos `parts` (pode haver vários, com `mode=` e `when=`) e monta a
/// tabela no fim.
pub const Builder = struct {
    rules: std.ArrayList(Rule) = .empty,

    fn fail(cx: *fx.Cx, n: *const kdl.Node, msg: []const u8) fx.Error {
        cx.problem = .{ .node = n, .message = msg };
        return error.Invalid;
    }

    /// Um bloco `parts { part "…" … }`. Erro com o nó em `cx.problem`.
    pub fn add(b: *Builder, cx: *fx.Cx, block: *const kdl.Node) fx.Error!void {
        for (block.children) |*n| {
            if (!std.mem.eql(u8, n.name, "part")) return fail(cx, n, "dentro de `parts` só vai `part \"nome:estado\"`");
            const sel = (n.arg(0) orelse return fail(cx, n, "part sem nome (part \"message:hover\" …)")).asString() orelse return fail(cx, n, "o nome da parte deve ser uma string");
            var it = std.mem.splitScalar(u8, sel, ':');
            const found = find(it.first()) orelse return fail(cx, n, "parte desconhecida (a lista está na documentação dos temas do app, \"Parts and states\")");
            const conj = conjuntos()[found.set];
            var mask: u8 = 0;
            while (it.next()) |s| {
                const i = conj.stateIndex(s) orelse return fail(cx, n, "estado desconhecido (os estados de cada parte estão na documentação dos temas do app)");
                if (!conj.hasState(found.part, i)) return fail(cx, n, "esse estado não existe nessa parte (a lista está na documentação dos temas do app)");
                mask |= @as(u8, 1) << i;
            }
            var set: Set = .{};
            for (n.props) |p| {
                const pr = Conjunto.propIndex(p.key) orelse return fail(cx, n, "propriedade desconhecida numa parte");
                if (!conj.hasProp(found.part, pr)) return fail(cx, n, "essa propriedade não existe nessa parte (a lista está na documentação dos temas do app)");
                const spec = props[@intFromEnum(pr)];
                const msg = bad_value[@intFromEnum(pr)];
                switch (spec.kind) {
                    .color => {
                        const src = p.value.asString() orelse return fail(cx, n, msg);
                        const e = try cx.expr(n, src, msg);
                        switch (pr) {
                            .bg => set.bg = e,
                            .color => set.color = e,
                            .border => set.border = e,
                            .bar => set.bar = e,
                            else => unreachable,
                        }
                    },
                    .number => {
                        const v: f32 = @floatCast(p.value.asNumber() orelse return fail(cx, n, msg));
                        const x = std.math.clamp(v, spec.min, spec.max);
                        switch (pr) {
                            .border_width => set.border_width = x,
                            .bar_width => set.bar_width = x,
                            .radius => set.radius = x,
                            .opacity => set.opacity = x,
                            else => unreachable,
                        }
                    },
                    .weight => {
                        const s = p.value.asString() orelse return fail(cx, n, msg);
                        set.weight = std.meta.stringToEnum(Weight, s) orelse return fail(cx, n, msg);
                    },
                }
            }
            try b.rules.append(cx.a, .{ .set_index = found.set, .part = found.part, .mask = mask, .set = set, .order = @intCast(b.rules.items.len) });
        }
    }

    /// A tabela de todas as combinações. null = o tema não tem regra nenhuma.
    pub fn finish(b: *Builder, a: std.mem.Allocator) error{OutOfMemory}!?*const Table {
        if (b.rules.items.len == 0) return null;
        std.mem.sort(Rule, b.rules.items, {}, Rule.before);
        var looks: std.ArrayList(Look) = .empty;
        try looks.append(a, none);
        const regs = conjuntos();
        const sets = try a.alloc(Table.SetIndex, regs.len);
        for (regs, sets, 0..) |conj, *out, si| {
            const index = try a.alloc([256]u16, conj.partes.len);
            for (index, 0..) |*row, pi| {
                const valid = conj.valid_states[pi];
                for (0..256) |m| {
                    const mask: u8 = @intCast(m);
                    if (mask & ~valid != 0) continue;
                    var l: Look = .{};
                    for (b.rules.items) |r| {
                        if (r.set_index == si and r.part == pi and r.mask & ~mask == 0) r.set.onto(&l);
                    }
                    row[m] = try intern(a, &looks, l);
                }
                // As combinações com estados que a parte não tem: como sem eles.
                for (0..256) |m| row[m] = row[m & valid];
            }
            out.* = .{ .conjunto = conj, .index = index };
        }
        const t = try a.create(Table);
        t.* = .{ .sets = sets, .looks = try looks.toOwnedSlice(a) };
        return t;
    }

    fn intern(a: std.mem.Allocator, looks: *std.ArrayList(Look), l: Look) error{OutOfMemory}!u16 {
        if (!l.any) return 0;
        for (looks.items, 0..) |x, i| if (std.meta.eql(x, l)) return @intCast(i);
        try looks.append(a, l);
        return @intCast(looks.items.len - 1);
    }
};

// --- Testes ---------------------------------------------------------------------------

const testing = std.testing;
const theme = @import("theme.zig");
/// As partes do larperCord, registradas como um app faria.
const cord = @import("exemplo_cord.zig");
const P = cord.Partes;

fn loadSrc(src: []const u8, d: ?*theme.Diagnostic) !theme.Theme {
    cord.registrar();
    return theme.load(testing.allocator, src, null, d);
}

/// 0xRRGGBB da cor da parte com os tokens do tema.
fn rgb(t: *const theme.Theme, e: ?*const Expr) u32 {
    const k = e.?.eval(t.tokenValues());
    const q = struct {
        fn f(x: f32) u32 {
            return @intFromFloat(std.math.clamp(x, 0, 1) * 255.0 + 0.5);
        }
    }.f;
    return (q(k.r) << 16) | (q(k.g) << 8) | q(k.b);
}

test "lê as partes, com estados combinados e propriedades de cada tipo" {
    var t = try loadSrc(
        \\colors { accent "#ff0000"; hover "#00ff00" }
        \\parts {
        \\    part "message.author" color="@accent" weight=bold
        \\    part "message:hover" bg="@hover" radius=6 bar="#0000ff" bar-width=4 opacity=0.5
        \\    part "channel.item:selected:hover" bg="mix(@accent, white, 0.5)" border="@accent" border-width=2
        \\    part "composer.box" bg=accent radius=99
        \\}
        \\layout { messages }
    , null);
    defer t.deinit();
    const tb = t.parts.?;
    const author = P.get(tb, .message_author, .{});
    try testing.expect(author.any);
    try testing.expectEqual(Weight.bold, author.weight.?);
    try testing.expectEqual(@as(u32, 0xff0000), rgb(&t, author.color));
    // Sem o hover, a mensagem não muda; com ele, tudo o que a regra disse.
    try testing.expect(!P.get(tb, .message, .{}).any);
    const hov = P.get(tb, .message, .{ .hover = true });
    try testing.expectEqual(@as(?f32, 6), hov.radius);
    try testing.expectEqual(@as(f32, 4), hov.bar_width);
    try testing.expectEqual(@as(f32, 0.5), hov.opacity);
    try testing.expectEqual(@as(f32, 1), hov.border_width);
    try testing.expect(hov.border == null);
    // A regra de dois estados só vale com os dois.
    try testing.expect(!P.get(tb, .channel_item, .{ .selected = true }).any);
    const both = P.get(tb, .channel_item, .{ .selected = true, .hover = true, .unread = true });
    try testing.expectEqual(@as(f32, 2), both.border_width);
    try testing.expectEqual(@as(u32, 0xff8080), rgb(&t, both.bg));
    // Números fora da faixa ficam na borda dela.
    try testing.expectEqual(@as(?f32, 64), P.get(tb, .composer_box, .{}).radius);
    // Estado que a parte não tem não muda nada (o composer não tem hover).
    try testing.expectEqual(P.get(tb, .composer_box, .{}), P.get(tb, .composer_box, .{ .hover = true, .speaking = true }));
}

test "cascata: estado mais forte vence, propriedade por propriedade" {
    var t = try loadSrc(
        \\parts {
        \\    part "channel.item:selected" bg="#000003" color="#000013"
        \\    part "channel.item" bg="#000001" color="#000011" radius=2 weight=medium
        \\    part "channel.item:hover" bg="#000002" border="#000022"
        \\    part "channel.item:unread" color="#000014" weight=bold
        \\    part "channel.item:mention" bg="#000005"
        \\    part "channel.item:selected:hover" bar="#000033"
        \\    part "channel.item:hover" border="#000023"
        \\}
        \\layout { channel-list }
    , null);
    defer t.deinit();
    const tb = t.parts.?;
    const base = P.get(tb, .channel_item, .{});
    try testing.expectEqual(@as(u32, 1), rgb(&t, base.bg));
    try testing.expectEqual(@as(u32, 0x11), rgb(&t, base.color));
    try testing.expectEqual(Weight.medium, base.weight.?);
    // hover < unread < mention < selected, cada propriedade por si.
    const h = P.get(tb, .channel_item, .{ .hover = true });
    try testing.expectEqual(@as(u32, 2), rgb(&t, h.bg));
    try testing.expectEqual(@as(u32, 0x11), rgb(&t, h.color));
    // Duas regras iguais: a de baixo no arquivo vence.
    try testing.expectEqual(@as(u32, 0x23), rgb(&t, h.border));
    const hu = P.get(tb, .channel_item, .{ .hover = true, .unread = true });
    try testing.expectEqual(@as(u32, 2), rgb(&t, hu.bg));
    try testing.expectEqual(@as(u32, 0x14), rgb(&t, hu.color));
    try testing.expectEqual(Weight.bold, hu.weight.?);
    try testing.expectEqual(@as(?f32, 2), hu.radius);
    const hm = P.get(tb, .channel_item, .{ .hover = true, .unread = true, .mention = true });
    try testing.expectEqual(@as(u32, 5), rgb(&t, hm.bg));
    try testing.expectEqual(@as(u32, 0x14), rgb(&t, hm.color));
    const s = P.get(tb, .channel_item, .{ .selected = true, .mention = true, .unread = true });
    try testing.expectEqual(@as(u32, 3), rgb(&t, s.bg));
    try testing.expectEqual(@as(u32, 0x13), rgb(&t, s.color));
    try testing.expectEqual(Weight.bold, s.weight.?);
    try testing.expect(s.bar == null);
    // A combinada (selected + hover) vem depois da de um estado só com o mesmo mais forte.
    const sh = P.get(tb, .channel_item, .{ .selected = true, .hover = true });
    try testing.expectEqual(@as(u32, 0x33), rgb(&t, sh.bar));
    try testing.expectEqual(@as(u32, 3), rgb(&t, sh.bg));
    try testing.expectEqual(@as(u32, 0x23), rgb(&t, sh.border));
    // Partes sem regra ficam como sempre.
    try testing.expect(!P.get(tb, .message, .{ .hover = true }).any);
}

test "erros apontam a linha" {
    const casos = [_]struct { src: []const u8, line: u32 }{
        .{ .src = "parts {\n  part \"mensagem\" bg=\"#fff\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n\n  part \"message:clicado\" bg=\"#fff\"\n}\nlayout { messages }", .line = 3 },
        .{ .src = "parts {\n  part \"member.row:unread\" bg=\"#fff\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  part \"message\" bg=\"#fff\"\n  part \"message.time\" weight=bold\n}\nlayout { messages }", .line = 3 },
        .{ .src = "parts {\n  part \"message\" fundo=\"#fff\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  part \"message\" bg=\"@nada\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  part \"message\" bg=\"mix(#fff, 0.2)\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  part \"message\" radius=\"seis\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  part \"message.author\" weight=gorda\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  part \"message:\" bg=\"#fff\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  estilo \"message\"\n}\nlayout { messages }", .line = 2 },
        .{ .src = "parts {\n  part bg=\"#fff\"\n}\nlayout { messages }", .line = 2 },
    };
    for (casos) |k| {
        var d: theme.Diagnostic = .{};
        try testing.expectError(error.InvalidTheme, loadSrc(k.src, &d));
        try testing.expectEqual(k.line, d.line);
        try testing.expect(d.message.len > 0);
    }
}

test "as cores seguem os tokens do momento" {
    var t = try loadSrc(
        \\colors { accent "#102030" }
        \\parts {
        \\    part "message:mention" bg="alpha(@accent, 0.5)" bar=accent
        \\    part "composer.box" bg="wal:1"
        \\}
        \\layout { messages }
    , null);
    defer t.deinit();
    const l = P.get(t.parts, .message, .{ .mention = true });
    try testing.expectEqual(@as(u32, 0x102030), rgb(&t, l.bar));
    try testing.expectApproxEqAbs(@as(f32, 0.5), l.bg.?.eval(t.tokenValues()).a, 0.001);
    // A cor escolhida nas configurações (ou a do servidor) troca o token: a parte acompanha.
    t.colors.set(.accent, color.Rgba.hex(0xa0b0c0));
    try testing.expectEqual(@as(u32, 0xa0b0c0), rgb(&t, l.bar));
    // A cópia do tema com outras cores (root.zig, `c-…`) aponta para a mesma tabela.
    var local = t;
    local.colors.set(.accent, color.Rgba.hex(0x000001));
    try testing.expectEqual(@as(u32, 0x000001), rgb(&local, P.get(local.parts, .message, .{ .mention = true }).bar));
    // Cor da paleta já vem resolvida.
    try testing.expect(P.get(t.parts, .composer_box, .{}).bg.?.* == .lit);
}

test "modo e opção valem para o bloco" {
    const src =
        \\options { option "realce" label="Realce" default=#false }
        \\parts mode=light { part "message:hover" bg="#ffffff" }
        \\parts when=realce { part "message:mention" bar="#ff0000" }
        \\layout { messages }
    ;
    cord.registrar();
    var dark = try theme.loadWith(testing.allocator, src, .{ .mode = .dark }, null);
    defer dark.deinit();
    try testing.expect(dark.parts == null);
    var light = try theme.loadWith(testing.allocator, src, .{ .mode = .light }, null);
    defer light.deinit();
    try testing.expect(P.get(light.parts, .message, .{ .hover = true }).bg != null);
    try testing.expect(P.get(light.parts, .message, .{ .mention = true }).bar == null);
}

test "sem parts, nada muda: os temas embutidos não têm tabela" {
    cord.registrar();
    for (cord.temas) |b| for ([_]theme.Mode{ .dark, .light }) |mode| {
        var t = try theme.loadWith(testing.allocator, b.source, .{ .mode = mode }, null);
        defer t.deinit();
        try testing.expect(t.parts == null);
    };
    // Bloco vazio também não monta tabela.
    var t = try loadSrc("parts { }\nlayout { messages }", null);
    defer t.deinit();
    try testing.expect(t.parts == null);
    try testing.expect(!none.any);
}

test "a tabela declarativa é coerente" {
    // Toda parte tem ao menos uma propriedade, e os estados de cada uma existem.
    for (cord.partes, 0..) |p, i| {
        try testing.expect(P.conjunto.valid_props[i] != 0);
        try testing.expect(p.desc.len > 0);
    }
    try testing.expect(P.hasState(.channel_item, .selected));
    try testing.expect(!P.hasState(.member_row, .unread));
    try testing.expect(P.hasProp(.message, .bar));
    try testing.expect(!P.hasProp(.message_time, .weight));
}
