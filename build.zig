const std = @import("std");

/// As traduções de um app, embutidas: cada `<pasta>/<código>.kdl` é um idioma, sem lista no
/// código (um arquivo novo entra no próximo build), comprimido com o cabeçalho na frente
/// (tools/comprimir.zig --i18n), e `<pasta>/keys.txt`, se houver, os textos em inglês do
/// código (a porcentagem traduzida). O app importa o módulo e passa ao kit ao abrir:
/// `lk.i18n.embutir(@import("traducoes"))`.
///
///     const kit = b.dependency("larperkit", .{});
///     mod.addImport("traducoes", @import("larperkit").traducoes(b, kit.builder, "i18n"));
///
/// `pasta` é relativa à raiz do projeto de `b`; `kit` é o builder do LarperKit.
pub fn traducoes(b: *std.Build, kit: *std.Build, pasta: []const u8) *std.Build.Module {
    const io = b.graph.io;
    // A lista muda quando um arquivo entra ou sai da pasta: o build relê.
    b.dependOnDirectoryContents(b.path(pasta));
    var dir = b.root.openDir(io, pasta, .{ .iterate = true }) catch std.debug.panic("sem a pasta {s}", .{pasta});
    defer dir.close(io);
    var names: std.ArrayList([]const u8) = .empty;
    var has_keys = false;
    var it = dir.iterate();
    while (it.next(io) catch std.debug.panic("{s} ilegível", .{pasta})) |e| {
        if (e.kind != .file) continue;
        if (std.mem.eql(u8, e.name, "keys.txt")) has_keys = true;
        if (!std.mem.endsWith(u8, e.name, ".kdl")) continue;
        names.append(b.allocator, b.dupe(e.name)) catch @panic("OOM");
    }
    std.mem.sort([]const u8, names.items, {}, struct {
        fn lt(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.lessThan(u8, x, y);
        }
    }.lt);
    const tool = comprimir(b, kit);
    const wf = b.addWriteFiles();
    var src: std.ArrayList(u8) = .empty;
    src.appendSlice(b.allocator,
        \\//! Gerado pelo build.zig do LarperKit: as traduções do app, comprimidas (ver
        \\//! src/ui/i18n.zig do kit).
        \\pub const files = [_]struct { name: []const u8, data: []const u8 }{
        \\
    ) catch @panic("OOM");
    for (names.items) |name| {
        const run = b.addRunArtifact(tool);
        run.addArg("--i18n");
        run.addFileArg(b.path(b.fmt("{s}/{s}", .{ pasta, name })));
        _ = wf.addCopyFile(run.addOutputFileArg(b.fmt("{s}.z", .{name})), b.fmt("{s}.z", .{name}));
        src.appendSlice(b.allocator, b.fmt("    .{{ .name = \"{s}\", .data = @embedFile(\"{s}.z\") }},\n", .{ name[0 .. name.len - 4], name })) catch @panic("OOM");
    }
    src.appendSlice(b.allocator, "};\n") catch @panic("OOM");
    if (has_keys) {
        const keys = b.addRunArtifact(tool);
        keys.addFileArg(b.path(b.fmt("{s}/keys.txt", .{pasta})));
        _ = wf.addCopyFile(keys.addOutputFileArg("keys.txt.z"), "keys.txt.z");
        src.appendSlice(b.allocator, "pub const keys: []const u8 = @embedFile(\"keys.txt.z\");\n") catch @panic("OOM");
    } else src.appendSlice(b.allocator, "pub const keys: []const u8 = \"\";\n") catch @panic("OOM");
    return b.createModule(.{ .root_source_file = wf.add("traducoes.zig", src.items) });
}

/// GNU FriBidi (third_party/fribidi): o texto da direita para a esquerda na ordem de desenho
/// (src/ui/bidi.zig). Os includes vão só nestes arquivos: o config.h e o common.h dele têm
/// nomes comuns demais.
const fribidi_sources = [_][]const u8{
    "fribidi-arabic.c", "fribidi-bidi.c", "fribidi-bidi-types.c", "fribidi-brackets.c", "fribidi-joining.c",
    "fribidi-joining-types.c", "fribidi-mirroring.c", "fribidi-run.c", "fribidi-shape.c",
};

fn addFribidi(b: *std.Build, m: *std.Build.Module) void {
    const inc = struct {
        fn f(bb: *std.Build, sub: []const u8) []const u8 {
            return bb.fmt("-I{s}", .{bb.root.joinString(bb.allocator, sub) catch @panic("OOM")});
        }
    }.f;
    m.addCSourceFiles(.{
        .root = b.path("third_party/fribidi/lib"),
        .files = &fribidi_sources,
        .flags = &.{
            "-std=gnu99",
            "-O2",
            "-fno-sanitize=undefined",
            "-DHAVE_CONFIG_H",
            "-DFRIBIDI_ENTRY=",
            inc(b, "third_party/fribidi/config"),
            inc(b, "third_party/fribidi/lib"),
        },
    });
}

/// tools/comprimir.zig, para a máquina que compila.
fn comprimir(b: *std.Build, kit: *std.Build) *std.Build.Step.Compile {
    const m = b.createModule(.{
        .root_source_file = kit.path("tools/comprimir.zig"),
        .target = b.graph.host,
        .optimize = .safe,
    });
    m.addAnonymousImport("cabecalho", .{ .root_source_file = kit.path("src/core/i18n_cabecalho.zig") });
    return b.addExecutable(.{ .name = "comprimir", .root_module = m });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const windows = target.result.os.tag == .windows;
    // O que não está no repositório (tools/deps.sh): a SDL3 do Windows.
    const deps_opt = b.option([]const u8, "deps", "Pasta das dependências (tools/deps.sh; padrão: .deps)") orelse ".deps";
    const deps: std.Build.LazyPath = if (std.fs.path.isAbsolute(deps_opt)) .{ .cwd_relative = deps_opt } else b.path(deps_opt);
    // Headers da SDL3 de outra pasta no lugar dos do sistema (o CI não tem a SDL3 instalada).
    const sdl_include = b.option([]const u8, "sdl-include", "Pasta com SDL3/SDL.h (padrão: a do sistema, pelo pkg-config)");

    // Headers C (SDL3, Dear ImGui, libc) traduzidos num módulo Zig.
    const translate = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate.addIncludePath(b.path("third_party/imgui"));
    translate.addIncludePath(b.path("third_party/dcimgui"));
    translate.addIncludePath(b.path("third_party/dcimgui/backends"));
    translate.defineCMacro("IMGUI_USE_WCHAR32", "1");
    if (sdl_include) |dir| {
        translate.addIncludePath(.{ .cwd_relative = dir });
    } else if (windows) {
        translate.addIncludePath(deps.path(b, "windows/include"));
    } else {
        translate.linkSystemLibrary("sdl3", .{});
    }
    const c = translate.createModule();

    // As marcas dos testes visuais (ui/qa.zig). O padrão é o do larperCord: só no debug,
    // nunca numa release. O app passa o dele adiante (`b.dependency("larperkit", .{ .qa = qa })`)
    // para as marcas do kit valerem junto com o robô dele.
    const opts = b.addOptions();
    opts.addOption(bool, "qa", b.option(bool, "qa", "Compila as marcas dos testes visuais (ui/qa.zig); padrão: só no debug") orelse (optimize == .debug));

    // A biblioteca: quem usa importa `larperkit` (e pode trocar o `c` pelo dele).
    const mod = b.addModule("larperkit", .{
        .root_source_file = b.path("src/larperkit.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport("c", c);
    mod.addOptions("build_options", opts);
    addFribidi(b, mod);

    // Testes das partes puras (sem janela nem GPU, sem SDL): rodam em qualquer CI. Para
    // Windows saindo do Linux, `-fwine` roda com o wine.
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/larperkit.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addOptions("build_options", opts);
    addFribidi(b, test_mod);
    // Os testes das traduções embutem o japonês e o russo de exemplo como um app embutiria.
    test_mod.addImport("i18n_exemplo", traducoes(b, b, "src/ui/exemplo_i18n"));
    const tests = b.addTest(.{ .name = "larperkit-test", .root_module = test_mod });
    b.step("test", "Roda os testes").dependOn(&b.addRunArtifact(tests).step);
    // O executável dos testes, para rodar em outra máquina (o CI compila para Windows no
    // Linux e roda num Windows de verdade).
    b.step("test-bin", "Instala o executável dos testes").dependOn(&b.addInstallArtifact(tests, .{}).step);

    // Confere que tudo o que o módulo exporta compila, inclusive o que chama a SDL e o
    // ImGui (sem ligar nada, então serve para qualquer alvo).
    const check_mod = b.createModule(.{
        .root_source_file = b.path("src/checagem.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    check_mod.addImport("larperkit", mod);
    const check = b.addTest(.{ .name = "larperkit-check", .root_module = check_mod });
    b.step("check", "Confere que o módulo inteiro compila").dependOn(&check.step);
}
