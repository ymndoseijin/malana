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
    input_box: graphics.ColoredRect,
    char_test: ui.TextBox,
    text_region: ui.Region,
    text: std.ArrayList(u8),
    state: *Ui,
    ally: std.mem.Allocator,

    border: NineRectSprite,
    text_border: NineRectSprite,
    root: *Box,
    list: *Box,
    textures: Textures,

    const Textures = struct {
        text_border: NineRectTexture,
        border: NineRectTexture,
    };

    pub fn init(state: *Ui) !Program {
        const ally = global_ally;
        const color = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("c0c0c0"));
        const input_box = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("8e8eb9"));
        const char_test = ui.TextBox.init(try graphics.TextFt.init(global_ally, "resources/fonts/Fairfax.ttf", 12, 1, 250));

        const text_region: ui.Region = .{ .transform = input_box.transform };

        const text_border_texture: NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/right.png", .{}),
        };

        const border_texture: NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/right.png", .{}),
        };

        return .{
            .color = color,
            .chat_background = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("ffffff")),
            .input_box = input_box,
            .char_test = char_test,
            .text_region = text_region,
            .text = std.ArrayList(u8).init(global_ally),
            .state = state,
            .ally = global_ally,
            .textures = .{
                .text_border = text_border_texture,
                .border = border_texture,
            },
            .border = .{ .texture = border_texture },
            .text_border = .{ .texture = text_border_texture },
            .root = undefined,
            .list = undefined,
        };
    }

    pub fn initPtr(program: *Program) !void {
        try program.state.callback.elements.append(.{ @ptrCast(program), .{
            .key_func = keyInput,
            .char_func = textInput,
            .region = &program.text_region,
        } });
        const margins = 10;
        //const text_margin = 20;
        const ally = program.ally;
        var list: ?*Box = undefined;

        var root = try Box.create(ally, .{
            .size = .{ 1920, 1080 },
            .children = &.{
                try Box.create(ally, .{
                    .expand = .{ .vertical = true, .horizontal = true },
                    .callbacks = &.{ui.getColorCallback(&program.color)},
                }),
                try ui.MarginBox(ally, .{ .top = margins, .bottom = margins, .left = margins, .right = margins }, try Box.create(ally, .{
                    .expand = .{ .vertical = true, .horizontal = true },
                    .flow = .{ .vertical = true },
                    .children = &.{
                        try program.border.init(&program.state.scene, ally, try Box.create(ally, .{
                            .expand = .{ .vertical = true, .horizontal = true },
                            .flow = .{ .vertical = true },
                            .callbacks = &.{.{ .box = &list }},
                        })),
                        try Box.create(ally, .{ .size = .{ 1000, 10 } }),
                        try program.text_border.init(&program.state.scene, ally, try Box.create(ally, .{
                            .label = "Text",
                            .expand = .{ .horizontal = true },
                            .size = .{ 0, 30 },
                            .callbacks = &.{
                                ui.getColorCallback(&program.input_box),
                                ui.getRegionCallback(&program.text_region),
                                program.char_test.getTextCallback(),
                            },
                        })),
                    },
                })),
            },
        });

        try root.resolve();
        root.print(0);
        program.root = root;
        program.list = list.?;
    }

    pub fn addMessage(program: *Program, string: []const u8) !void {
        const ally = program.ally;
        const message = try Message.create(program, ally, string);
        try program.list.append(message.box);
    }

    pub fn deinit(program: Program) void {
        program.text.deinit();
        program.root.deinit();
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
    border: NineRectSprite,
    box: *Box,

    pub fn create(program: *Program, ally: std.mem.Allocator, string: []const u8) !*Message {
        const message = try ally.create(Message);
        const background = try graphics.ColoredRect.init(&program.state.scene, comptime try math.color.parseHexRGBA("8e8eb9"));
        var text = ui.TextBox.init(try graphics.TextFt.init(global_ally, "resources/fonts/Fairfax.ttf", 12, 1, 250));
        try text.content.print(&program.state.scene, ally, .{ .text = string, .color = .{ 0.0, 0.0, 0.0 } });

        message.* = .{
            .background = background,
            .text = text,
            .border = .{ .texture = program.textures.text_border },
            .box = undefined,
        };

        const border = 5;

        message.box =
            try message.border.init(
            &program.state.scene,
            ally,
            try Box.create(ally, .{
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
                            .size = .{ 0, 30 },
                            .callbacks = &.{
                                message.text.getTextCallback(),
                            },
                        }),
                    ),
                },
            }),
        );

        return message;
    }
};

fn keyInput(program_ptr: *anyopaque, _: *ui.Callback, key: i32, scancode: i32, action: graphics.Action, mods: i32) !void {
    _ = scancode;
    _ = mods;
    const program: *Program = @alignCast(@ptrCast(program_ptr));

    if (key == graphics.glfw.GLFW_KEY_ENTER and action == .press) {
        main_irc.mutex.lock();
        defer main_irc.mutex.unlock();

        var buf: [4096]u8 = undefined;
        try program.addMessage(try std.fmt.bufPrint(&buf, "{s} | {s}: {s}", .{ main_irc.channel, main_irc.name, program.text.items }));

        try main_irc.send("{s}", .{program.text.items});

        program.text.clearRetainingCapacity();
        try program.char_test.content.clear(&program.state.scene, program.ally);
        try program.root.resolve();
    } else if (key == graphics.glfw.GLFW_KEY_BACKSPACE and action == .press) {
        if (program.text.items.len == 0) return;
        var text = &program.char_test.content;
        const char = text.characters.pop();
        try program.state.scene.delete(program.ally, char.sprite.drawing);
        char.deinit(program.ally);

        var buf: [4]u8 = undefined;
        const codepoint = text.codepoints.pop();
        const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
        std.debug.print("text before: {s}\n", .{program.text.items});
        program.text.shrinkRetainingCapacity(program.text.items.len - string.len);
        std.debug.print("text after: {s}\n", .{program.text.items});
    }
}

fn textInput(program_ptr: *anyopaque, _: *ui.Callback, codepoint: u32) !void {
    var program: *Program = @alignCast(@ptrCast(program_ptr));

    var buf: [4]u8 = undefined;
    const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
    for (string) |c| try program.text.append(c);
    try program.char_test.content.print(&program.state.scene, program.ally, .{ .text = string, .color = .{ 0.0, 0.0, 0.0 } });
}

const NineInfo = struct {
    top_left: *Box,
    left: *Box,
    bottom_left: *Box,
    top: *Box,
    bottom: *Box,
    top_right: *Box,
    right: *Box,
    bottom_right: *Box,
};

const NineRectTexture = struct {
    top_left: graphics.Texture,
    left: graphics.Texture,
    bottom_left: graphics.Texture,
    top: graphics.Texture,
    bottom: graphics.Texture,
    top_right: graphics.Texture,
    right: graphics.Texture,
    bottom_right: graphics.Texture,
};

const NineRectSprite = struct {
    top_left_sprite: ?graphics.Sprite = null,
    left_sprite: ?graphics.Sprite = null,
    bottom_left_sprite: ?graphics.Sprite = null,
    top_sprite: ?graphics.Sprite = null,
    bottom_sprite: ?graphics.Sprite = null,
    top_right_sprite: ?graphics.Sprite = null,
    right_sprite: ?graphics.Sprite = null,
    bottom_right_sprite: ?graphics.Sprite = null,
    texture: NineRectTexture,

    pub fn init(rect: *NineRectSprite, scene: *graphics.Scene, ally: std.mem.Allocator, in_box: *Box) !*Box {
        rect.top_left_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.top_left });
        rect.left_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.left });
        rect.bottom_left_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.bottom_left });
        rect.top_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.top });
        rect.bottom_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.bottom });
        rect.top_right_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.top_right });
        rect.right_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.right });
        rect.bottom_right_sprite = try graphics.Sprite.init(scene, .{ .tex = rect.texture.bottom_right });

        return NineRectBox(ally, .{
            .top_left = try Box.create(ally, .{
                .label = "top left",
                .size = .{ rect.top_left_sprite.?.width, rect.top_left_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_left_sprite.?)},
            }),
            .bottom_left = try Box.create(ally, .{
                .label = "bottom left",
                .size = .{ rect.bottom_left_sprite.?.width, rect.bottom_left_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_left_sprite.?)},
            }),
            .top_right = try Box.create(ally, .{
                .label = "top right",
                .size = .{ rect.top_right_sprite.?.width, rect.top_right_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_right_sprite.?)},
            }),
            .bottom_right = try Box.create(ally, .{
                .label = "bottom right",
                .size = .{ rect.bottom_right_sprite.?.width, rect.bottom_right_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_right_sprite.?)},
            }),
            .top = try Box.create(ally, .{
                .label = "top",
                .expand = .{ .horizontal = true },
                .size = .{ rect.top_sprite.?.width, rect.top_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_sprite.?)},
            }),
            .bottom = try Box.create(ally, .{
                .label = "bottom",
                .expand = .{ .horizontal = true },
                .size = .{ rect.bottom_sprite.?.width, rect.bottom_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_sprite.?)},
            }),
            .left = try Box.create(ally, .{
                .label = "left",
                .expand = .{ .vertical = true },
                .size = .{ rect.left_sprite.?.width, rect.left_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.left_sprite.?)},
            }),
            .right = try Box.create(ally, .{
                .label = "right",
                .expand = .{ .vertical = true },
                .size = .{ rect.right_sprite.?.width, rect.right_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.right_sprite.?)},
            }),
        }, in_box);
    }
};

pub fn NineRectBox(ally: std.mem.Allocator, info: NineInfo, box: *Box) !*Box {
    return try Box.create(ally, .{
        .label = "nine rect",
        .flow = .{ .horizontal = true },
        .expand = box.expand,
        .fit = .{ .vertical = true, .horizontal = true },
        .children = &.{
            try Box.create(ally, .{
                .label = "left nine",
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true },
                .fit = .{ .vertical = true, .horizontal = true },
                .size = .{ 0, 0 },
                .children = &.{
                    info.top_left,
                    info.left,
                    info.bottom_left,
                },
            }),
            try Box.create(ally, .{
                .label = "middle nine",
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true, .horizontal = true },
                .fit = .{ .vertical = true, .horizontal = true },
                .children = &.{
                    info.top,
                    box,
                    info.bottom,
                },
            }),
            try Box.create(ally, .{
                .label = "right nine",
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true },
                .fit = .{ .vertical = true, .horizontal = true },
                .size = .{ 0, 0 },
                .children = &.{
                    info.top_right,
                    info.right,
                    info.bottom_right,
                },
            }),
        },
    });
}

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

    var irc = try Irc.init(ally, "cliente", "#pas");
    main_irc = &irc;

    _ = try std.Thread.spawn(.{}, Irc.loop, .{&irc});

    var state = try Ui.init(ally, .{ .name = "box test", .width = 500, .height = 500, .resizable = true, .preferred_format = .unorm });
    defer state.deinit(ally);

    //var sprite = try graphics.Sprite.init(&state.scene, .{ .tex = tex });

    var program_stack = try Program.init(state);
    try program_stack.initPtr();
    defer program_stack.deinit();
    main_program = &program_stack;

    state.frame_func = frameUpdate;

    while (state.main_win.alive) {
        try state.updateEvents();
        irc.mutex.lock();
        defer irc.mutex.unlock();
        try state.render();
    }
}
