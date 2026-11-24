//! Exemplo de registro: os componentes, as partes e as miniaturas do larperCord, do jeito
//! que um app registra os seus (`registrar`), com dois temas dele (exemplo_cord/). Os
//! testes do kit usam isto para conferir o motor com os temas de um app de verdade.
//! Tirado de src/theme/schema.zig e src/theme/parts.zig do larperCord.
const std = @import("std");
const schema = @import("schema.zig");
const parts = @import("parts.zig");
const bases = @import("bases.zig");

const num = schema.num;
const flag = schema.flag;
const pick = schema.pick;
const of = schema.of;
const fieldNames = schema.fieldNames;
const layout_sets = schema.layout_sets;

pub const componentes = [_]schema.NodeSpec{
    .{
        .name = "guild-bar",
        .role = .component,
        .desc = "The server bar.",
        .pt = "A barra de servidores.",
        .sets = layout_sets,
        .props = &.{
            pick("variant", &.{ "bar", "dock", "list" }, "Bar, macOS-style dock or list with names.", .{ .def = .{ .text = "bar" }, .tweak = true }),
            pick("icon-style", fieldNames(enum { fill, soft, outline }), "How the server icons are filled.", .{ .def = .{ .text = "fill" }, .tweak = true }),
            pick("orientation", &.{ "vertical", "horizontal" }, "Direction (default: by the node's shape).", .{ .tweak = true }),
            pick("shape", &.{ "circle", "squircle", "square", "text" }, "Shape of the icons; text = tabs with the names.", .{ .def = .{ .text = "circle" }, .tweak = true }),
            num("size", "Icon size (default 48; 36 horizontal, 40 dock, 26 list).", .{ .range = .{ 16, 80, 1 }, .def = .{ .num = 48 }, .tweak = true }),
            flag("labels", "Names under the icons (horizontal bar).", .{ .def = .{ .flag = false }, .tweak = true }),
            flag("home", "The home (DMs) button.", .{ .def = .{ .flag = true }, .tweak = true }),
            flag("indicators", "Unread and selection marks.", .{ .def = .{ .flag = true }, .tweak = true }),
            num("font-size", "Text size of shape=text tabs.", .{ .range = .{ 10, 24, 0.5 } }),
        },
    },
    .{
        .name = "channel-list",
        .role = .component,
        .desc = "The server's channels (or the DM list).",
        .pt = "Os canais do servidor (ou a lista de DMs).",
        .sets = layout_sets,
        .props = &.{
            pick("variant", &.{ "discord", "tree", "pills" }, "Look of the list.", .{ .def = .{ .text = "discord" }, .tweak = true }),
            flag("header", "Server name at the top.", .{ .def = .{ .flag = true }, .tweak = true }),
            flag("banner", "Colored banner with the server name (variant=discord).", .{ .def = .{ .flag = false }, .tweak = true }),
        },
    },
    .{
        .name = "user-panel",
        .role = .component,
        .desc = "Your name, status, mute/deafen and the settings button.",
        .pt = "Seu nome, status, mudo/surdo e o botão de configurações.",
        .sets = layout_sets,
        .props = &.{pick("variant", &.{ "discord", "tty" }, "Look of the panel.", .{ .def = .{ .text = "discord" }, .tweak = true })},
    },
    .{
        .name = "header",
        .role = .component,
        .desc = "Channel name, topic and buttons above the chat.",
        .pt = "Nome do canal, tópico e botões em cima da conversa.",
        .sets = layout_sets,
        .props = &.{
            pick("variant", &.{ "discord", "minimal", "tty" }, "Look of the header.", .{ .def = .{ .text = "discord" }, .tweak = true }),
            flag("divider", "Line under the header.", .{ .def = .{ .flag = true }, .tweak = true }),
        },
    },
    .{
        .name = "tabs",
        .role = .component,
        .desc = "Open conversations as tabs.",
        .pt = "Conversas abertas em abas.",
        .sets = layout_sets,
        .props = &.{pick("variant", &.{ "pills", "underline", "tty" }, "Look of the tabs.", .{ .def = .{ .text = "pills" }, .tweak = true })},
    },
    .{
        .name = "messages",
        .role = .component,
        .desc = "The conversation (and the call screen when a voice channel is open).",
        .pt = "A conversa (e a tela da call quando um canal de voz está aberto).",
        .sets = layout_sets,
        .props = &.{
            pick("variant", &.{ "cozy", "irc", "bubbles" }, "Layout of the messages.", .{ .def = .{ .text = "cozy" }, .tweak = true }),
            pick("avatar", &.{ "circle", "squircle", "square", "none" }, "Shape of the photos.", .{ .def = .{ .text = "circle" }, .tweak = true }),
            num("avatar-size", "Photo size (default 40; 30 with bubbles).", .{ .range = .{ 16, 72, 1 }, .def = .{ .num = 40 }, .tweak = true }),
            num("spacing", "Space between groups of messages.", .{ .range = .{ 0, 48, 1 }, .def = .{ .num = 16 }, .tweak = true }),
            num("font-size", "Text size (default: the fonts size).", .{ .range = .{ 10, 24, 0.5 }, .tweak = true }),
            flag("ruled", "Ruled paper.", .{ .def = .{ .flag = false }, .tweak = true }),
            flag("margin-line", "Red margin line.", .{ .def = .{ .flag = false }, .tweak = true }),
            flag("ticks", "\"Delivered ✓✓\" under your messages.", .{ .def = .{ .flag = false }, .tweak = true }),
            flag("typing-bubble", "Typing bubble (variant=bubbles).", .{ .def = .{ .flag = false }, .tweak = true }),
            of(.style, "call-style", "Named style for each tile of the call screen.", .{}),
            num("call-tint", "How much of each person's photo color goes into the call tile.", .{ .min = 0, .max = 1, .range = .{ 0, 1, 0.01 }, .def = .{ .num = 0.22 } }),
        },
    },
    .{
        .name = "composer",
        .role = .component,
        .desc = "The text box.",
        .pt = "A caixa de texto.",
        .sets = layout_sets,
        .props = &.{
            pick("variant", &.{ "box", "pill", "prompt" }, "Look of the box.", .{ .def = .{ .text = "box" }, .tweak = true }),
            flag("typing", "\"x is typing…\" above the box.", .{ .def = .{ .flag = true }, .tweak = true }),
        },
    },
    .{
        .name = "member-list",
        .role = .component,
        .desc = "Members of the server (or the profile in a DM).",
        .pt = "Membros do servidor (ou o perfil numa DM).",
        .sets = layout_sets,
        .props = &.{pick("variant", &.{ "discord", "tty" }, "Look of the list.", .{ .def = .{ .text = "discord" }, .tweak = true })},
    },
    .{
        .name = "status-bar",
        .role = .component,
        .desc = "A status line: connection, ping, memory, voice, theme, keys, clock.",
        .pt = "Uma linha de status: conexão, ping, memória, voz, tema, atalhos, relógio.",
        .sets = layout_sets,
        .props = &.{
            pick("variant", &.{ "pills", "tty", "plain" }, "Look of the bar.", .{ .def = .{ .text = "pills" }, .tweak = true }),
            .{
                .key = "items",
                .kind = .words,
                .values = &.{ "conn", "ping", "ram", "frame", "voice", "theme", "keys", "clock", "me", "mic", "deaf", "spacer" },
                .desc = "What the bar shows, in order; after spacer it goes to the right. me, mic and deaf: your status and the mute/deafen buttons.",
                .default = .{ .text = "conn ping ram voice spacer theme keys clock" },
                .tweak = true,
            },
        },
    },
    .{
        .name = "logo",
        .role = .component,
        .desc = "The app logo, in ASCII or as a wordmark.",
        .pt = "O logo do app, em ASCII ou como texto.",
        .sets = layout_sets,
        .props = &.{
            pick("variant", &.{ "wordmark", "ascii" }, "ASCII art or text.", .{ .def = .{ .text = "wordmark" }, .tweak = true }),
            num("size", "Text size (default 17; 13 in ASCII).", .{ .range = .{ 8, 40, 1 }, .def = .{ .num = 17 }, .tweak = true }),
        },
    },
    .{ .name = "topbar", .role = .component, .desc = "Top bar: back/forward between tabs, search and help.", .pt = "Barra de cima: voltar/avançar entre abas, busca e ajuda.", .sets = layout_sets },
};

/// Os estados, na ordem da precedência: numa combinação, o de baixo vence o de cima.
pub const State = enum(u3) { self, muted, offline, hover, unread, mention, selected, speaking };

/// Os mesmos estados como bits, para quem desenha montar a combinação.
pub const States = packed struct(u8) {
    self: bool = false,
    muted: bool = false,
    offline: bool = false,
    hover: bool = false,
    unread: bool = false,
    mention: bool = false,
    selected: bool = false,
    speaking: bool = false,
};

pub const estados = [_]parts.StateSpec{
    .{ .name = "self", .desc = "your own message, or your own row in a list" },
    .{ .name = "muted", .desc = "a channel you muted (or can't open)" },
    .{ .name = "offline", .desc = "a member who is offline" },
    .{ .name = "hover", .desc = "the mouse is over it" },
    .{ .name = "unread", .desc = "a channel with unread messages (not when muted)" },
    .{ .name = "mention", .desc = "a message that pings you, or a channel with unread pings" },
    .{ .name = "selected", .desc = "the open channel" },
    .{ .name = "speaking", .desc = "someone talking in the voice call you are in" },
};

pub const Part = enum(u4) {
    message,
    message_author,
    message_time,
    message_body,
    message_reply,
    channel_item,
    channel_category,
    channel_unread,
    channel_badge,
    channel_voice_member,
    member_row,
    member_name,
    member_role_header,
    composer_box,
    composer_placeholder,
};

pub const partes = [_]parts.PartSpec{
    .{ .name = "message", .states = "self hover mention", .props = "bg border border-width radius bar bar-width opacity", .desc = "a whole message row, behind the avatar, the name and the text" },
    .{ .name = "message.author", .states = "self hover mention", .props = "color weight", .desc = "the author's name (the nick column in irc)" },
    .{ .name = "message.time", .states = "self hover mention", .props = "color", .desc = "the time of the message" },
    .{ .name = "message.body", .states = "self hover mention", .props = "color", .desc = "the text of the message" },
    .{ .name = "message.reply", .states = "self hover mention", .props = "color", .desc = "the line that quotes the message being replied to" },
    .{ .name = "channel.item", .states = "muted hover unread mention selected", .props = "bg color border border-width radius bar bar-width opacity weight", .desc = "a channel row of a server; color and weight are the name's" },
    .{ .name = "channel.category", .states = "hover", .props = "bg color border border-width radius weight", .desc = "a category header in the channel list" },
    .{ .name = "channel.unread", .states = "", .props = "color", .desc = "the unread marker of a channel row" },
    .{ .name = "channel.badge", .states = "", .props = "bg color", .desc = "the count of unread pings on a channel row" },
    .{ .name = "channel.voice-member", .states = "self hover speaking", .props = "bg color border border-width radius weight", .desc = "someone in a voice channel, listed under it" },
    .{ .name = "member.row", .states = "self offline hover speaking", .props = "bg border border-width radius bar bar-width opacity", .desc = "a row of the member list" },
    .{ .name = "member.name", .states = "self offline hover speaking", .props = "color weight", .desc = "the name in a member row" },
    .{ .name = "member.role-header", .states = "", .props = "color weight", .desc = "a group heading of the member list (ONLINE — 3)" },
    .{ .name = "composer.box", .states = "", .props = "bg border border-width radius", .desc = "the message box" },
    .{ .name = "composer.placeholder", .states = "", .props = "color weight", .desc = "the hint in the empty message box" },
};

pub const Partes = parts.Partes(Part, States, &estados, &partes);

/// As miniaturas das Configurações do larperCord (`theme … preview=`).
pub const previews = [_][]const u8{ "classic", "glass", "terminal", "bubbles", "zen", "mirror", "office", "desktop" };

pub const extensao: schema.Extensao = .{ .componentes = &componentes, .partes = &Partes.conjunto, .previews = &previews };

pub const temas = [_]bases.Builtin{
    .{ .name = "classico", .source = @embedFile("exemplo_cord/classico.kdl") },
    .{ .name = "zen", .source = @embedFile("exemplo_cord/zen.kdl") },
};

/// O que o larperCord faz ao abrir: registra os componentes e as partes e passa os temas
/// embutidos.
pub fn registrar() void {
    schema.registrar(&extensao);
    bases.embutidos = &temas;
}
