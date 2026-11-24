const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // O kit traz o Dear ImGui, os backends e a SDL3 (no Windows, baixada pelo build).
    const kit = b.dependency("larperkit", .{ .target = target, .optimize = optimize });
    const mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("larperkit", kit.module("larperkit"));
    const exe = b.addExecutable(.{ .name = "hello", .root_module = mod });
    b.installArtifact(exe);
    @import("larperkit").installSdl(b, kit);
}
