const std = @import("std");

const ui = @import("ui");
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;
const Ui = ui.Ui;
const math = ui.math;
const Box = ui.Box;

var main_program: *Program = undefined;
var main_irc: *Irc = undefined;
var global_ally: std.mem.Allocator = undefined;

const Program = struct {
    color: graphics.ColoredRect,
    chat_background: graphics.ColoredRect,
    input_box: ui.InputBox,
    button: ui.Button,
    state: *Ui,
    ally: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    border: ui.NineRectSprite,
    root: *Box,
    list: *Box,
    textures: Textures,
    messages: std.ArrayList(*Message),

    const Textures = struct {
        text_border: ui.NineRectTexture,
        border: ui.NineRectTexture,
        button: ui.ButtonTexture,
    };

    pub fn create(state: *Ui) !*Program {
        const ally = global_ally;
        const color = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("c0c0c0"));

        const text_border_texture: ui.NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/right.png", .{}),
        };

        const border_texture: ui.NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/right.png", .{}),
        };

        const button_idle_texture: ui.NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/right.png", .{}),
        };

        const button_pressed_texture: ui.NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/right.png", .{}),
        };

        const button_texture: ui.ButtonTexture = .{
            .idle = button_idle_texture,
            .pressed = button_pressed_texture,
            .idle_inner = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/inner.png", .{}),
        };

        const program = try ally.create(Program);

        program.* = .{
            .color = color,
            .chat_background = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("ffffff")),
            .input_box = try ui.InputBox.init(&state.scene, global_ally, .{
                .on_send = .{ .ptr = program, .func = enteredText },
                .border_texture = text_border_texture,
            }),
            .state = state,
            .ally = global_ally,
            .arena = std.heap.ArenaAllocator.init(global_ally),
            .textures = .{
                .text_border = text_border_texture,
                .border = border_texture,
                .button = button_texture,
            },
            .border = try ui.NineRectSprite.init(&state.scene, border_texture),
            .button = try ui.Button.init(&state.scene, ally, .{ .texture = button_texture, .margins = 3, .label = "󱥁󱤧󱤬" }),
            .root = undefined,
            .list = undefined,
            .messages = std.ArrayList(*Message).init(global_ally),
        };

        const margins = 10;
        //const text_margin = 20;
        const arena = program.arena.allocator();
        var list: ?*Box = undefined;

        var root = try Box.create(arena, .{
            .size = .{ 1920, 1080 },
            .children = &.{
                try Box.create(arena, .{
                    .expand = .{ .vertical = true, .horizontal = true },
                    .callbacks = &.{ui.getColorCallback(&program.color)},
                }),
                try ui.MarginBox(arena, .{ .top = margins, .bottom = margins, .left = margins, .right = margins }, try Box.create(arena, .{
                    .expand = .{ .vertical = true, .horizontal = true },
                    .flow = .{ .vertical = true },
                    .children = &.{
                        try program.border.makeBox(arena, try Box.create(arena, .{
                            .expand = .{ .vertical = true, .horizontal = true },
                            .flow = .{ .vertical = true },
                            .callbacks = &.{.{ .box = &list }},
                        })),
                        try Box.create(arena, .{ .size = .{ 0, 10 } }),
                        try program.button.makeBox(program.state, arena),
                        try Box.create(arena, .{ .size = .{ 0, 10 } }),
                        try program.input_box.makeBox(program.state, arena),
                    },
                })),
            },
        });

        try root.resolve();
        root.print(0);
        program.root = root;
        program.list = list.?;

        return program;
    }

    fn enteredText(program_ptr: *anyopaque, _: *ui.InputBox, text: []const u8) !void {
        const program: *Program = @ptrCast(@alignCast(program_ptr));

        main_irc.mutex.lock();
        defer main_irc.mutex.unlock();

        var buf: [4096]u8 = undefined;
        try program.addMessage(try std.fmt.bufPrint(&buf, "{s} | {s}: {s}", .{ main_irc.channel, main_irc.name, text }));

        try main_irc.send("{s}", .{text});
    }

    pub fn addMessage(program: *Program, string: []const u8) !void {
        const ally = program.arena.allocator();
        const message = try Message.create(program, ally, string);
        try program.list.append(message.box);
        try program.messages.append(message);
    }

    pub fn destroy(program: *Program) void {
        program.border.deinit(program.ally, &program.state.scene);
        program.button.deinit(&program.state.scene);
        program.input_box.deinit();
        program.state.scene.delete(program.ally, program.color.drawing);

        program.textures.text_border.deinit();
        program.textures.border.deinit();
        program.textures.button.deinit();

        for (program.messages.items) |message| {
            message.deinit(program);
        }
        program.messages.deinit();

        program.root.deinit();
        program.arena.deinit();

        program.ally.destroy(program);
    }
};

pub fn frameUpdate(width: i32, height: i32) !void {
    main_program.root.fixed_size = .{ @floatFromInt(width), @floatFromInt(height) };
    main_program.root.current_size = .{ @floatFromInt(width), @floatFromInt(height) };
    try main_program.root.resolve();
}

const Message = struct {
    background: graphics.ColoredRect,
    text: ui.TextBox,
    border: ui.NineRectSprite,
    box: *Box,

    pub fn deinit(message: *Message, program: *Program) void {
        message.border.deinit(program.ally, &program.state.scene);
        program.state.scene.delete(program.ally, message.background.drawing);
        message.text.content.deinit(program.ally);
        message.box.deinit();
    }

    pub fn create(program: *Program, ally: std.mem.Allocator, string: []const u8) !*Message {
        const message = try ally.create(Message);
        const background = try graphics.ColoredRect.init(&program.state.scene, comptime try math.color.parseHexRGBA("8e8eb9"));
        var text = ui.TextBox.init(try graphics.TextFt.init(program.ally, .{
            .path = "resources/fonts/Fairfax.ttf",
            .size = 12,
            .line_spacing = 1,
            .bounding_width = 250,
        }));
        try text.content.print(&program.state.scene, program.ally, .{ .text = string, .color = .{ 0.0, 0.0, 0.0 } });

        message.* = .{
            .background = background,
            .text = text,
            .border = try ui.NineRectSprite.init(&program.state.scene, program.textures.text_border),
            .box = undefined,
        };

        const border = 5;

        message.box =
            try message.border.makeBox(ally, try Box.create(ally, .{
            .expand = .{ .horizontal = true },
            .fit = .{ .vertical = true, .horizontal = true },
            .callbacks = &.{ui.getColorCallback(&message.background)},
            .children = &.{
                try ui.MarginBox(
                    ally,
                    .{ .top = border, .bottom = border, .left = border, .right = border },
                    try Box.create(ally, .{
                        .label = "Text",
                        .expand = .{ .horizontal = true },
                        .size = .{ 0, 12 },
                        .callbacks = &.{
                            message.text.getCallback(),
                        },
                    }),
                ),
            },
        }));

        return message;
    }
};

const Irc = struct {
    server: std.net.Stream,
    name: []const u8,
    channel: []const u8,
    ally: std.mem.Allocator,

    mutex: std.Thread.Mutex,

    fn handleMessage(irc: *Irc, sender: []const u8, message_in: []const u8, channel: []const u8) !void {
        irc.mutex.lock();
        defer irc.mutex.unlock();

        std.debug.print("{s} {s}: {s}\n", .{ channel, sender, message_in });
        var buf: [4096]u8 = undefined;
        try main_program.addMessage(try std.fmt.bufPrint(&buf, "{s} | {s}: {s}", .{ channel, sender, message_in }));
        try main_program.root.resolve();
    }

    fn handleIrcMessage(irc: *Irc, sender: []const u8, command_string: []const u8) !void {
        var space_split = std.mem.split(u8, command_string, " ");
        const message_type = space_split.next() orelse return error.InvalidServerMessage;
        var server_writer = irc.server.writer();

        if (std.mem.eql(u8, message_type, "PRIVMSG")) {
            var msg_split = std.mem.split(u8, command_string, ":");
            _ = msg_split.next();
            const channel = space_split.next() orelse return error.InvalidPrivMsg;
            const message = msg_split.rest();
            var sender_split = std.mem.splitSequence(u8, sender, "!");
            var sender_proc = sender_split.next() orelse return error.InvalidMessage;
            sender_proc = std.mem.trim(u8, sender_proc, ":");
            try irc.handleMessage(sender_proc, std.mem.trim(u8, message, "\x00\r\n"), channel);
        } else if (std.mem.eql(u8, message_type, "PING")) {
            _ = try server_writer.print("PONG {s}\r\n", .{space_split.next() orelse return error.InvalidPong});
        }
    }

    pub fn send(irc: *Irc, comptime message: []const u8, args: anytype) !void {
        const formatted = try std.fmt.allocPrint(irc.ally, message, args);
        defer irc.ally.free(formatted);
        var server_writer = irc.server.writer();
        _ = try server_writer.print("PRIVMSG {s} :{s}\r\n", .{ irc.channel, formatted });
    }

    pub fn init(ally: std.mem.Allocator, name: []const u8, channel: []const u8) !Irc {
        const address = std.net.Address.initIp4([4]u8{ 10, 8, 0, 1 }, 6667);
        var server = try std.net.tcpConnectToAddress(address);

        var server_writer = server.writer();

        _ = try server_writer.print("NICK {s}\r\n", .{name});
        _ = try server_writer.print("USER {s} 0 * :{s}\r\n", .{ name, name });
        _ = try server_writer.print("JOIN {s}\r\n", .{channel});
        std.debug.print("Bot irc funcionando!\n", .{});

        return .{
            .server = server,
            .name = name,
            .channel = channel,
            .ally = ally,
            .mutex = .{},
        };
    }

    pub fn deinit(irc: *Irc) void {
        irc.server.close();
        irc.last_message.deinit();
    }

    pub fn loop(irc: *Irc) !void {
        var buf: [2048]u8 = undefined;
        while (true) {
            const size = try irc.server.read(&buf);
            const msg = buf[0..size];
            var space_split = std.mem.split(u8, msg, " ");
            const sender = space_split.next() orelse return error.InvalidServerMessage;
            const command_string = space_split.rest();

            std.debug.print("sender: {s} command_string: {s}\n", .{ sender, command_string });
            try irc.handleIrcMessage(sender, command_string);
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    global_ally = gpa.allocator();
    const ally = global_ally;

    var irc = try Irc.init(ally, "cliente", "#robit");
    main_irc = &irc;

    _ = try std.Thread.spawn(.{}, Irc.loop, .{&irc});

    var state = try Ui.init(ally, .{ .window = .{ .name = "box test", .width = 500, .height = 500, .resizable = true, .preferred_format = .unorm } });
    defer state.deinit(ally);

    //var sprite = try graphics.Sprite.init(&state.scene, .{ .tex = tex });

    var program = try Program.create(state);
    defer program.destroy();
    main_program = program;

    state.frame_func = frameUpdate;

    while (!state.main_win.shouldClose()) {
        try state.updateEvents();
        irc.mutex.lock();
        defer irc.mutex.unlock();
        try state.render();
    }
}
