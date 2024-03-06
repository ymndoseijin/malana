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

const ButtonTexture = struct {
    hover: NineRectTexture = undefined,
    idle: NineRectTexture,
    pressed: NineRectTexture,

    hover_inner: graphics.Texture = undefined,
    idle_inner: graphics.Texture,
    pressed_inner: graphics.Texture = undefined,

    pub fn deinit(textures: ButtonTexture) void {
        //textures.hover.deinit();
        textures.idle.deinit();
        textures.pressed.deinit();
        //textures.hover_inner.deinit();
        textures.idle_inner.deinit();
        //textures.pressed_inner.deinit();
    }
};

const Button = struct {
    border: NineRectSprite,
    inner: graphics.Sprite,
    text: ui.TextBox,
    region: ui.Region,
    texture: ButtonTexture,
    margins: f32,
    ally: std.mem.Allocator,
    box: ?*Box,

    const ButtonInfo = struct {
        label: []const u8,
        texture: ButtonTexture,
        margins: f32,
    };

    pub fn init(scene: *graphics.Scene, ally: std.mem.Allocator, info: ButtonInfo) !Button {
        const inner = try graphics.Sprite.init(scene, .{ .tex = info.texture.idle_inner });
        var text = ui.TextBox.init(try graphics.TextFt.init(global_ally, .{
            .path = "resources/fonts/Fairfax.ttf",
            .size = 12,
            .line_spacing = 1,
            .wrap = false,
        }));

        try text.content.print(scene, ally, .{ .text = info.label, .color = .{ 0.0, 0.0, 0.0 } });

        return .{
            .border = try NineRectSprite.init(scene, info.texture.idle),
            .inner = inner,
            .text = text,
            .region = .{ .transform = .{} },
            .texture = info.texture,
            .margins = info.margins,
            .ally = ally,
            .box = null,
        };
    }

    pub fn deinit(button: *Button, scene: *graphics.Scene) void {
        button.border.deinit(button.ally, scene);
        button.text.content.deinit(button.ally);
        scene.delete(button.ally, button.inner.drawing);
    }

    fn mouseButton(button_ptr: *anyopaque, callback: *ui.Callback, button_clicked: i32, action: graphics.Action, _: i32) !void {
        const button: *Button = @alignCast(@ptrCast(button_ptr));

        if (button_clicked == 0) {
            if (action == .press) {
                try button.border.updateTexture(button.ally, button.texture.pressed);
            } else if (action == .release) {
                try button.border.updateTexture(button.ally, button.texture.idle);
                try callback.unfocus();
            }
        }
    }

    pub fn makeBox(button: *Button, current_ui: *ui.Ui, ally: std.mem.Allocator) !*Box {
        try current_ui.callback.elements.append(.{
            @ptrCast(button), .{
                .mouse_func = Button.mouseButton,
                .region = &button.region,
            },
        });

        const m = button.margins;
        button.box = try button.border.makeBox(ally, try Box.create(ally, .{
            .size = .{ button.inner.width, button.inner.height },
            .fit = .{ .vertical = true, .horizontal = true },
            .callbacks = &.{
                ui.getSpriteCallback(&button.inner),
                ui.getRegionCallback(&button.region),
            },
            .children = &.{
                try ui.MarginBox(ally, .{ .top = m, .bottom = m, .left = m, .right = m }, try Box.create(ally, .{
                    .callbacks = &.{
                        button.text.getCallback(),
                    },
                })),
            },
        }));

        return button.box.?;
    }
};

const InputBox = struct {
    region: ui.Region,
    text_box: ui.TextBox,
    background: graphics.ColoredRect,
    border: NineRectSprite,
    ally: std.mem.Allocator,
    scene: *graphics.Scene,
    text: std.ArrayList(u8),
    on_send: ?SendCallback,
    box: ?*Box,

    const SendCallback = struct { ptr: *anyopaque, func: *const fn (*anyopaque, *InputBox, []const u8) anyerror!void };
    pub const InputInfo = struct {
        border_texture: NineRectTexture,
        on_send: ?SendCallback = null,
    };

    pub fn init(scene: *graphics.Scene, ally: std.mem.Allocator, info: InputInfo) !InputBox {
        const input_box = try graphics.ColoredRect.init(scene, comptime try math.color.parseHexRGBA("8e8eb9"));
        const text_box = ui.TextBox.init(try graphics.TextFt.init(ally, .{
            .path = "resources/fonts/Fairfax.ttf",
            .size = 12,
            .line_spacing = 1,
            .bounding_width = 250,
        }));

        const text_region: ui.Region = .{ .transform = input_box.transform };

        return .{
            .region = text_region,
            .text_box = text_box,
            .background = input_box,
            .text = std.ArrayList(u8).init(ally),
            .ally = ally,
            .scene = scene,
            .border = try NineRectSprite.init(scene, info.border_texture),
            .on_send = info.on_send,
            .box = null,
        };
    }

    pub fn deinit(input: *InputBox) void {
        input.border.deinit(input.ally, input.scene);
        input.text_box.content.deinit(input.ally);
        input.scene.delete(input.ally, input.background.drawing);
    }

    pub fn makeBox(input: *InputBox, current_ui: *ui.Ui, ally: std.mem.Allocator) !*Box {
        try current_ui.callback.elements.append(.{ @ptrCast(input), .{
            .key_func = keyInput,
            .char_func = textInput,
            .region = &input.region,
        } });
        const box = try input.border.makeBox(ally, try Box.create(ally, .{
            .label = "Text",
            .expand = .{ .horizontal = true },
            .size = .{ 0, 30 },
            .callbacks = &.{
                ui.getColorCallback(&input.background),
                ui.getRegionCallback(&input.region),
                input.text_box.getCallback(),
            },
        }));
        input.box = box;
        return box;
    }

    fn keyInput(input_ptr: *anyopaque, _: *ui.Callback, key: i32, scancode: i32, action: graphics.Action, mods: i32) !void {
        _ = scancode;
        _ = mods;
        const input: *InputBox = @alignCast(@ptrCast(input_ptr));

        if (key == graphics.glfw.GLFW_KEY_ENTER and action == .press) {
            if (input.on_send) |on_send| try on_send.func(on_send.ptr, input, input.text.items);
            input.text.clearRetainingCapacity();
            try input.text_box.content.clear(input.scene, input.ally);
            if (input.box) |b| try b.resolve();
        } else if (key == graphics.glfw.GLFW_KEY_BACKSPACE and action == .press) {
            if (input.text.items.len == 0) return;
            var text = &input.text_box.content;
            if (input.text.items[input.text.items.len - 1] != ' ') {
                const char = text.characters.pop();
                input.scene.delete(input.ally, char.sprite.drawing);
                char.deinit(input.ally);
            }

            var buf: [4]u8 = undefined;
            const codepoint = text.codepoints.pop();
            const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
            input.text.shrinkRetainingCapacity(input.text.items.len - string.len);
        }
    }

    fn textInput(input_ptr: *anyopaque, _: *ui.Callback, codepoint: u32) !void {
        const input: *InputBox = @alignCast(@ptrCast(input_ptr));

        var buf: [4]u8 = undefined;
        const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
        for (string) |c| try input.text.append(c);
        try input.text_box.content.print(input.scene, input.ally, .{ .text = string, .color = .{ 0.0, 0.0, 0.0 } });
    }
};

const Program = struct {
    color: graphics.ColoredRect,
    chat_background: graphics.ColoredRect,
    input_box: InputBox,
    button: Button,
    state: *Ui,
    ally: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    border: NineRectSprite,
    root: *Box,
    list: *Box,
    textures: Textures,
    messages: std.ArrayList(*Message),

    const Textures = struct {
        text_border: NineRectTexture,
        border: NineRectTexture,
        button: ButtonTexture,
    };

    pub fn create(state: *Ui) !*Program {
        const ally = global_ally;
        const color = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("c0c0c0"));

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

        const button_idle_texture: NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/right.png", .{}),
        };

        const button_pressed_texture: NineRectTexture = .{
            .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/top_left.png", .{}),
            .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/bottom_left.png", .{}),
            .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/top_right.png", .{}),
            .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/bottom_right.png", .{}),
            .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/top.png", .{}),
            .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/bottom.png", .{}),
            .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/left.png", .{}),
            .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/pressed/right.png", .{}),
        };

        const button_texture: ButtonTexture = .{
            .idle = button_idle_texture,
            .pressed = button_pressed_texture,
            .idle_inner = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/button/idle/inner.png", .{}),
        };

        const program = try ally.create(Program);

        program.* = .{
            .color = color,
            .chat_background = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("ffffff")),
            .input_box = try InputBox.init(&state.scene, global_ally, .{
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
            .border = try NineRectSprite.init(&state.scene, border_texture),
            .button = try Button.init(&state.scene, ally, .{ .texture = button_texture, .margins = 3, .label = "󱥁󱤧󱤬" }),
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

    fn enteredText(program_ptr: *anyopaque, _: *InputBox, text: []const u8) !void {
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
    border: NineRectSprite,
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
            .border = try NineRectSprite.init(&program.state.scene, program.textures.text_border),
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

    pub fn deinit(textures: NineRectTexture) void {
        textures.top_left.deinit();
        textures.left.deinit();
        textures.bottom_left.deinit();
        textures.top.deinit();
        textures.bottom.deinit();
        textures.top_right.deinit();
        textures.right.deinit();
        textures.bottom_right.deinit();
    }
};

const NineRectSprite = struct {
    top_left_sprite: graphics.Sprite,
    left_sprite: graphics.Sprite,
    bottom_left_sprite: graphics.Sprite,
    top_sprite: graphics.Sprite,
    bottom_sprite: graphics.Sprite,
    top_right_sprite: graphics.Sprite,
    right_sprite: graphics.Sprite,
    bottom_right_sprite: graphics.Sprite,

    box: ?*Box,

    pub fn updateTexture(sprite: *NineRectSprite, ally: std.mem.Allocator, texture: NineRectTexture) !void {
        try sprite.top_left_sprite.updateTexture(ally, .{ .tex = texture.top_left });
        try sprite.left_sprite.updateTexture(ally, .{ .tex = texture.left });
        try sprite.bottom_left_sprite.updateTexture(ally, .{ .tex = texture.bottom_left });
        try sprite.top_sprite.updateTexture(ally, .{ .tex = texture.top });
        try sprite.bottom_sprite.updateTexture(ally, .{ .tex = texture.bottom });
        try sprite.top_right_sprite.updateTexture(ally, .{ .tex = texture.top_right });
        try sprite.right_sprite.updateTexture(ally, .{ .tex = texture.right });
        try sprite.bottom_right_sprite.updateTexture(ally, .{ .tex = texture.bottom_right });

        const box = sprite.box orelse return;

        box.leaves.items[0].leaves.items[0].fixed_size = .{ @floatFromInt(texture.top_left.width), @floatFromInt(texture.top_left.height) };
        box.leaves.items[0].leaves.items[1].fixed_size = .{ @floatFromInt(texture.left.width), @floatFromInt(texture.left.height) };
        box.leaves.items[0].leaves.items[2].fixed_size = .{ @floatFromInt(texture.bottom_left.width), @floatFromInt(texture.bottom_left.height) };

        box.leaves.items[1].leaves.items[0].fixed_size = .{ @floatFromInt(texture.top.width), @floatFromInt(texture.top.height) };
        box.leaves.items[1].leaves.items[2].fixed_size = .{ @floatFromInt(texture.bottom.width), @floatFromInt(texture.bottom.height) };

        box.leaves.items[2].leaves.items[0].fixed_size = .{ @floatFromInt(texture.top_right.width), @floatFromInt(texture.top_right.height) };
        box.leaves.items[2].leaves.items[1].fixed_size = .{ @floatFromInt(texture.right.width), @floatFromInt(texture.right.height) };
        box.leaves.items[2].leaves.items[2].fixed_size = .{ @floatFromInt(texture.bottom_right.width), @floatFromInt(texture.bottom_right.height) };

        try box.resolve();
    }

    pub fn init(scene: *graphics.Scene, texture: NineRectTexture) !NineRectSprite {
        return .{
            .top_left_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.top_left }),
            .left_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.left }),
            .bottom_left_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.bottom_left }),
            .top_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.top }),
            .bottom_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.bottom }),
            .top_right_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.top_right }),
            .right_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.right }),
            .bottom_right_sprite = try graphics.Sprite.init(scene, .{ .tex = texture.bottom_right }),
            .box = null,
        };
    }

    pub fn makeBox(rect: *NineRectSprite, ally: std.mem.Allocator, in_box: *Box) !*Box {
        const box = try NineRectBox(ally, .{
            .top_left = try Box.create(ally, .{
                .label = "top left",
                .size = .{ rect.top_left_sprite.width, rect.top_left_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_left_sprite)},
            }),
            .bottom_left = try Box.create(ally, .{
                .label = "bottom left",
                .size = .{ rect.bottom_left_sprite.width, rect.bottom_left_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_left_sprite)},
            }),
            .top_right = try Box.create(ally, .{
                .label = "top right",
                .size = .{ rect.top_right_sprite.width, rect.top_right_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_right_sprite)},
            }),
            .bottom_right = try Box.create(ally, .{
                .label = "bottom right",
                .size = .{ rect.bottom_right_sprite.width, rect.bottom_right_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_right_sprite)},
            }),
            .top = try Box.create(ally, .{
                .label = "top",
                .expand = .{ .horizontal = true },
                .size = .{ rect.top_sprite.width, rect.top_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_sprite)},
            }),
            .bottom = try Box.create(ally, .{
                .label = "bottom",
                .expand = .{ .horizontal = true },
                .size = .{ rect.bottom_sprite.width, rect.bottom_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_sprite)},
            }),
            .left = try Box.create(ally, .{
                .label = "left",
                .expand = .{ .vertical = true },
                .size = .{ rect.left_sprite.width, rect.left_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.left_sprite)},
            }),
            .right = try Box.create(ally, .{
                .label = "right",
                .expand = .{ .vertical = true },
                .size = .{ rect.right_sprite.width, rect.right_sprite.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.right_sprite)},
            }),
        }, in_box);
        rect.box = box;
        return box;
    }

    pub fn deinit(rect: NineRectSprite, ally: std.mem.Allocator, scene: *graphics.Scene) void {
        scene.delete(ally, rect.top_left_sprite.drawing);
        scene.delete(ally, rect.left_sprite.drawing);
        scene.delete(ally, rect.bottom_left_sprite.drawing);
        scene.delete(ally, rect.top_sprite.drawing);
        scene.delete(ally, rect.bottom_sprite.drawing);
        scene.delete(ally, rect.top_right_sprite.drawing);
        scene.delete(ally, rect.right_sprite.drawing);
        scene.delete(ally, rect.bottom_right_sprite.drawing);
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
