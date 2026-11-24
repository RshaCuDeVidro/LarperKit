//! Quem é o app que usa o kit. Ele preenche ao abrir, antes de qualquer outra coisa do kit.
const std = @import("std");

/// O nome nas mensagens ("needs a newer larperCord").
pub var nome: []const u8 = "LarperKit";

/// A pasta dele dentro da de configurações do sistema ($XDG_CONFIG_HOME/<pasta>,
/// %APPDATA%\<pasta>): os temas, as traduções e as configurações ficam lá.
pub var pasta: []const u8 = "larperkit";
