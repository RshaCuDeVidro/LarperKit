//! Identificadores por nome para os elementos clicáveis (`draw.hit`): `id("salvar", 0)`, e
//! não um número escolhido na mão, que bate com o de outro lugar (o botão B da barra de
//! formatação com o mesmo número do microfone, no larperCord). O nome é comptime: um erro
//! de digitação aparece no código, não num clique que vai para outro botão.
//! A ideia e as contas são as do WooferSoundPad (src/ui.zig), devolvendo `usize`, o tipo
//! que `draw.hit` recebe.
const std = @import("std");

/// O elemento `n` (a linha, o item da lista) do grupo `tag`.
pub fn id(comptime tag: []const u8, n: usize) usize {
    var h = std.hash.Wyhash.init(0x5EED);
    h.update(tag);
    h.update(std.mem.asBytes(&n));
    return @truncate(h.final());
}

/// Como `id`, com um texto no lugar do número (o nome de um plugin, de uma opção).
pub fn idStr(comptime tag: []const u8, s: []const u8) usize {
    var h = std.hash.Wyhash.init(0xD06);
    h.update(tag);
    h.update(s);
    return @truncate(h.final());
}

/// O filho `n` de um id (os botões de uma linha, os itens de um menu).
pub fn sub(base: usize, n: usize) usize {
    return @truncate(std.hash.Wyhash.hash(base, std.mem.asBytes(&n)));
}

test "nomes diferentes, ids diferentes; o mesmo nome, o mesmo id" {
    try std.testing.expectEqual(id("salvar", 0), id("salvar", 0));
    try std.testing.expect(id("salvar", 0) != id("salvar", 1));
    try std.testing.expect(id("salvar", 0) != id("apagar", 0));
    try std.testing.expect(idStr("plugin", "a") != idStr("plugin", "b"));
    try std.testing.expect(sub(id("linha", 3), 0) != sub(id("linha", 3), 1));
    try std.testing.expect(sub(id("linha", 3), 0) != sub(id("linha", 4), 0));
}
