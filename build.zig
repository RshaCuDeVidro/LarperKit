const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // A biblioteca: quem usa importa `larperkit`.
    const mod = b.addModule("larperkit", .{
        .root_source_file = b.path("src/larperkit.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Testes das partes puras (sem janela nem GPU): rodam em qualquer CI. Para Windows
    // saindo do Linux, `-fwine` roda com o wine.
    const tests = b.addTest(.{ .name = "larperkit-test", .root_module = mod });
    b.step("test", "Roda os testes").dependOn(&b.addRunArtifact(tests).step);
    // O executável dos testes, para rodar em outra máquina (o CI compila para Windows no
    // Linux e roda num Windows de verdade).
    b.step("test-bin", "Instala o executável dos testes").dependOn(&b.addInstallArtifact(tests, .{}).step);
}
