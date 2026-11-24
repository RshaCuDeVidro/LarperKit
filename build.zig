const std = @import("std");

/// As traduções de um app, embutidas: cada `<pasta>/<código>.kdl` é um idioma, sem lista no
/// código (um arquivo novo entra no próximo build), comprimido com o cabeçalho na frente
/// (tools/comprimir.zig --i18n), e `<pasta>/keys.txt`, se houver, os textos em inglês do
/// código (a porcentagem traduzida). O app importa o módulo e passa ao kit ao abrir:
/// `lk.i18n.embed(@import("translations"))`.
///
///     const kit = b.dependency("larperkit", .{});
///     mod.addImport("translations", @import("larperkit").translations(b, kit.builder, "i18n"));
///
/// `dir` é relativa à raiz do projeto de `b`; `kit` é o builder do LarperKit.
pub fn translations(b: *std.Build, kit: *std.Build, dir: []const u8) *std.Build.Module {
    const io = b.graph.io;
    // A lista muda quando um arquivo entra ou sai da dir: o build relê.
    b.dependOnDirectoryContents(b.path(dir));
    var folder = b.root.openDir(io, dir, .{ .iterate = true }) catch std.debug.panic("sem a dir {s}", .{dir});
    defer folder.close(io);
    var names: std.ArrayList([]const u8) = .empty;
    var has_keys = false;
    var it = folder.iterate();
    while (it.next(io) catch std.debug.panic("{s} ilegível", .{dir})) |e| {
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
        run.addFileArg(b.path(b.fmt("{s}/{s}", .{ dir, name })));
        _ = wf.addCopyFile(run.addOutputFileArg(b.fmt("{s}.z", .{name})), b.fmt("{s}.z", .{name}));
        src.appendSlice(b.allocator, b.fmt("    .{{ .name = \"{s}\", .data = @embedFile(\"{s}.z\") }},\n", .{ name[0 .. name.len - 4], name })) catch @panic("OOM");
    }
    src.appendSlice(b.allocator, "};\n") catch @panic("OOM");
    if (has_keys) {
        const keys = b.addRunArtifact(tool);
        keys.addFileArg(b.path(b.fmt("{s}/keys.txt", .{dir})));
        _ = wf.addCopyFile(keys.addOutputFileArg("keys.txt.z"), "keys.txt.z");
        src.appendSlice(b.allocator, "pub const keys: []const u8 = @embedFile(\"keys.txt.z\");\n") catch @panic("OOM");
    } else src.appendSlice(b.allocator, "pub const keys: []const u8 = \"\";\n") catch @panic("OOM");
    return b.createModule(.{ .root_source_file = wf.add("translations.zig", src.items) });
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

/// O Dear ImGui do kit (third_party/imgui, com as mudanças do larperCord) e as bindings em
/// C, sem FreeType (as letras do stb_truetype do ImGui). `sdl`: também os backends da SDL3.
fn addImgui(b: *std.Build, m: *std.Build.Module, sdl: bool) void {
    m.addIncludePath(b.path("third_party/imgui"));
    m.addIncludePath(b.path("third_party/imgui/backends"));
    m.addIncludePath(b.path("third_party/dcimgui"));
    m.addIncludePath(b.path("third_party/dcimgui/backends"));
    m.addCMacro("IMGUI_USE_WCHAR32", "1");
    // Os ganchos de item do ImGui para o Inspetor (src/inspect/ganchos.cpp), como no app.
    m.addCMacro("IMGUI_ENABLE_TEST_ENGINE", "1");
    const flags: []const []const u8 = &.{ "-std=c++17", "-fno-exceptions", "-fno-rtti" };
    m.addCSourceFiles(.{
        .root = b.path("third_party"),
        .files = &.{ "imgui/imgui.cpp", "imgui/imgui_draw.cpp", "imgui/imgui_tables.cpp", "imgui/imgui_widgets.cpp", "dcimgui/dcimgui.cpp" },
        .flags = flags,
    });
    if (sdl) m.addCSourceFiles(.{
        .root = b.path("third_party"),
        .files = &.{ "imgui/backends/imgui_impl_sdl3.cpp", "imgui/backends/imgui_impl_sdlrenderer3.cpp", "dcimgui/backends/dcimgui_impl_sdl3.cpp", "dcimgui/backends/dcimgui_impl_sdlrenderer3.cpp" },
        .flags = flags,
    });
    // Só os stubs: as bindings citam ShowDemoWindow.
    m.addCSourceFile(.{ .file = b.path("third_party/imgui/imgui_demo.cpp"), .flags = &.{ "-std=c++17", "-fno-exceptions", "-fno-rtti", "-DIMGUI_DISABLE_DEMO_WINDOWS" } });
    m.addCSourceFile(.{ .file = b.path("src/inspect/ganchos.cpp"), .flags = flags });
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
    // Headers da SDL3 de outra pasta no lugar dos do sistema (o CI não tem a SDL3 instalada).
    const sdl_include = b.option([]const u8, "sdl-include", "Pasta com SDL3/SDL.h (padrão: a do sistema, pelo pkg-config)");
    // O Dear ImGui do kit (com as mudanças do larperCord) e os backends da SDL3, compilados no
    // módulo. Um app que compila o próprio ImGui (o larperCord, com FreeType) desliga.
    const with_imgui = b.option(bool, "imgui", "Compila o Dear ImGui do kit no módulo (padrão: sim)") orelse true;
    // A SDL3 ligada no módulo. Um app que liga a dele de outro jeito (estática, numa release)
    // desliga e liga a dele.
    const link_sdl = b.option(bool, "link-sdl", "Liga a SDL3 no módulo (padrão: sim)") orelse true;
    // A SDL3 do Windows (a do MinGW): o build baixa sozinho, pelo build.zig.zon, quando o alvo
    // é Windows.
    const win_sdl: ?std.Build.LazyPath = if (windows and sdl_include == null) blk: {
        const dep = b.lazyDependency("sdl3_mingw", .{}) orelse break :blk null;
        break :blk dep.path("SDL3-3.4.20/x86_64-w64-mingw32");
    } else null;

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
    } else if (win_sdl) |w| {
        translate.addIncludePath(w.path(b, "include"));
    } else if (!windows) {
        translate.linkSystemLibrary("sdl3", .{});
    }
    const c = translate.createModule();

    // As marcas dos testes visuais (ui/qa.zig). O padrão é o do larperCord: só no debug,
    // nunca numa release. O app passa o dele adiante (`b.dependency("larperkit", .{ .qa = qa })`)
    // para as marcas do kit valerem junto com o robô dele.
    const opts = b.addOptions();
    opts.addOption(bool, "qa", b.option(bool, "qa", "Compila as marcas dos testes visuais (ui/qa.zig); padrão: só no debug") orelse (optimize == .debug));

    // A biblioteca: quem usa importa `larperkit` e ganha junto o ImGui, os backends e a SDL3
    // (veja "Using it in an app" no README). O `c` dela é `larperkit.c`.
    const mod = b.addModule("larperkit", .{
        .root_source_file = b.path("src/larperkit.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = with_imgui,
    });
    mod.addImport("c", c);
    mod.addOptions("build_options", opts);
    addFribidi(b, mod);
    if (sdl_include) |dir| mod.addIncludePath(.{ .cwd_relative = dir });
    if (win_sdl) |w| {
        mod.addIncludePath(w.path(b, "include"));
        // O app instala junto do .exe: `dep.namedLazyPath("SDL3.dll")`.
        b.addNamedLazyPath("SDL3.dll", w.path(b, "bin/SDL3.dll"));
    }
    if (with_imgui) {
        addImgui(b, mod, true);
        // O ImGui usa o IME e a área de transferência do Windows.
        if (windows) for ([_][]const u8{ "imm32", "user32", "gdi32", "ole32", "shell32" }) |l| mod.linkSystemLibrary(l, .{ .use_pkg_config = .no });
    }
    if (link_sdl) {
        if (win_sdl) |w| {
            mod.addLibraryPath(w.path(b, "lib"));
            mod.linkSystemLibrary("SDL3.dll", .{ .use_pkg_config = .no });
        } else if (sdl_include != null) {
            mod.linkSystemLibrary("SDL3", .{ .use_pkg_config = .no });
        } else if (!windows) mod.linkSystemLibrary("sdl3", .{});
    }

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
    test_mod.addImport("i18n_example", translations(b, b, "src/ui/example_i18n"));
    const tests = b.addTest(.{ .name = "larperkit-test", .root_module = test_mod });
    b.step("test", "Roda os testes").dependOn(&b.addRunArtifact(tests).step);
    // O executável dos testes, para rodar em outra máquina (o CI compila para Windows no
    // Linux e roda num Windows de verdade).
    b.step("test-bin", "Instala o executável dos testes").dependOn(&b.addInstallArtifact(tests, .{}).step);

    // Os componentes num ImGui de verdade, sem janela, com o módulo como um app o usa.
    const ui_mod = b.createModule(.{
        .root_source_file = b.path("src/ui_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    ui_mod.addImport("larperkit", mod);
    const ui_tests = b.addTest(.{ .name = "larperkit-test-ui", .root_module = ui_mod });
    b.step("test-ui", "Roda os testes dos componentes num ImGui sem janela").dependOn(&b.addRunArtifact(ui_tests).step);
    const ui_bin = b.step("test-ui-bin", "Instala o executável dos testes dos componentes");
    ui_bin.dependOn(&b.addInstallArtifact(ui_tests, .{}).step);
    if (win_sdl) |w| ui_bin.dependOn(&b.addInstallBinFile(w.path(b, "bin/SDL3.dll"), "SDL3.dll").step);

    // A vitrine (examples/vitrine): cada componente em cada tema, desenhado sem janela
    // (driver offscreen da SDL) e gravado em PNG, para os exemplos da documentação.
    const vit_mod = b.createModule(.{
        .root_source_file = b.path("examples/vitrine/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    vit_mod.addImport("larperkit", mod);
    const vitrine = b.addExecutable(.{ .name = "vitrine", .root_module = vit_mod });
    const vit_step = b.step("vitrine", "Compila a vitrine (examples/vitrine)");
    vit_step.dependOn(&b.addInstallArtifact(vitrine, .{}).step);
    if (win_sdl) |w| vit_step.dependOn(&b.addInstallBinFile(w.path(b, "bin/SDL3.dll"), "SDL3.dll").step);

    // Confere que tudo o que o módulo exporta compila, inclusive o que chama a SDL e o
    // ImGui (sem ligar nada, então serve para qualquer alvo).
    const check_mod = b.createModule(.{
        .root_source_file = b.path("src/check.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    check_mod.addImport("larperkit", mod);
    const check = b.addTest(.{ .name = "larperkit-check", .root_module = check_mod });
    b.step("check", "Confere que o módulo inteiro compila").dependOn(&check.step);
}
