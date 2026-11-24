//! Quem é o app que usa o kit. Ele preenche ao abrir, antes de qualquer outra coisa do kit.
const std = @import("std");

/// O nome nas mensagens ("needs a newer larperCord").
pub var nome: []const u8 = "LarperKit";

/// A pasta dele dentro da de configurações do sistema ($XDG_CONFIG_HOME/<pasta>,
/// %APPDATA%\<pasta>): os temas, as traduções e as configurações ficam lá.
pub var pasta: []const u8 = "larperkit";

// --- Testes ---------------------------------------------------------------------------

// O larperCord guarda o login no chaveiro e as configurações nas pastas com estes nomes:
// com `nome` e `pasta` dele, o kit precisa dar os mesmos, byte por byte, nos dois sistemas.
// Senão, quem atualiza perde o login, os segredos dos plugins e as configurações, e
// "Apagar todos os dados" deixa coisa para trás. As strings esperadas foram copiadas do
// larperCord b5b3fc2 (platform/apagar.zig, platform/fsutil.zig, theme/manager.zig), não do
// código do kit.
test "os nomes do larperCord saem iguais (chaveiro e pastas, Linux e Windows)" {
    const apagar = @import("../platform/apagar.zig");
    const fsutil = @import("../platform/fsutil.zig");
    const manager = @import("../theme/manager.zig");
    const old_nome = nome;
    const old_pasta = pasta;
    defer {
        nome = old_nome;
        pasta = old_pasta;
    }
    nome = "larperCord";
    pasta = "larpercord";
    var buf: [600]u8 = undefined;

    // O chaveiro, como "Apagar todos os dados" do larperCord apaga (as contas, o token de
    // antes das várias contas e os segredos dos plugins).
    const chaves = [_][]const u8{ "account", "", "plugin" };
    const linux = [_][]const u8{
        "secret-tool clear service larpercord-account 2>/dev/null",
        "secret-tool clear service larpercord 2>/dev/null",
        "secret-tool clear service larpercord-plugin 2>/dev/null",
    };
    for (chaves, linux) |k, want| try std.testing.expectEqualStrings(want, apagar.apagaChave(&buf, k, false).?);
    try std.testing.expectEqualStrings("larperCord/account/*", apagar.apagaChave(&buf, "account", true).?);
    try std.testing.expectEqualStrings("larperCord/plugin/*", apagar.apagaChave(&buf, "plugin", true).?);

    // As pastas: configurações e cache (as duas que "Apagar todos os dados" leva), temas e
    // traduções, com a base do Linux e a do Windows.
    for ([_][]const u8{ "/home/x/.config", "C:\\Users\\x\\AppData\\Roaming" }) |base| {
        var want: [600]u8 = undefined;
        try std.testing.expectEqualStrings(try std.fmt.bufPrint(&want, "{s}/larpercord", .{base}), apagar.pastaEm(&buf, base).?);
        try std.testing.expectEqualStrings(try std.fmt.bufPrint(&want, "{s}/larpercord", .{base}), fsutil.configPathIn(&buf, base, "").?);
        try std.testing.expectEqualStrings(try std.fmt.bufPrint(&want, "{s}/larpercord/i18n", .{base}), fsutil.configPathIn(&buf, base, "i18n").?);
        const themes = manager.configDirIn(std.testing.allocator, base).?;
        defer std.testing.allocator.free(themes);
        try std.testing.expectEqualStrings(try std.fmt.bufPrint(&want, "{s}/larpercord/themes", .{base}), themes);
    }
    for ([_][]const u8{ "/home/x/.cache", "C:\\Users\\x\\AppData\\Local" }) |base| {
        var want: [600]u8 = undefined;
        try std.testing.expectEqualStrings(try std.fmt.bufPrint(&want, "{s}/larpercord", .{base}), apagar.pastaEm(&buf, base).?);
    }
}
