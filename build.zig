const std = @import("std");

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

    // A biblioteca: quem usa importa `larperkit` (e pode trocar o `c` pelo dele).
    const mod = b.addModule("larperkit", .{
        .root_source_file = b.path("src/larperkit.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport("c", c);

    // Testes das partes puras (sem janela nem GPU, sem SDL): rodam em qualquer CI. Para
    // Windows saindo do Linux, `-fwine` roda com o wine.
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/larperkit.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
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
