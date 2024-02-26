const std = @import("std");

const ui = @import("ui");
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;
const Ui = ui.Ui;
const math = ui.math;
const Box = ui.Box;

var state: *Ui = undefined;
var root: Box = undefined;
var global_ally: std.mem.Allocator = undefined;

const Program = struct {
    color: graphics.ColoredRect,
    chat_background: graphics.ColoredRect,
    input_box: graphics.ColoredRect,
    char_test: graphics.TextFt,
    text_region: ui.Region,
    state: *Ui,
    ally: std.mem.Allocator,

    pub fn init(state_ui: *Ui) !Program {
        const color = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("c0c0c0"));
        const input_box = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("8e8eb9"));
        const char_test = try graphics.TextFt.init(global_ally, "resources/fonts/Fairfax.ttf", 12, 1, 250);

        const text_region: ui.Region = .{ .transform = input_box.transform };

        return .{
            .color = color,
            .chat_background = try graphics.ColoredRect.init(&state.scene, comptime try math.color.parseHexRGBA("ffffff")),
            .input_box = input_box,
            .char_test = char_test,
            .text_region = text_region,
            .state = state_ui,
            .ally = global_ally,
        };
    }

    pub fn initPtr(program: *Program) !void {
        try state.callback.elements.append(.{ @ptrCast(program), .{ .char_func = textInput, .region = &program.text_region } });
    }
};

pub fn frameUpdate(width: i32, height: i32) !void {
    root.fixed_size = .{ @floatFromInt(width), @floatFromInt(height) };
    root.current_size = .{ @floatFromInt(width), @floatFromInt(height) };
    try root.resolve(global_ally);
}

fn textInput(program_ptr: *anyopaque, _: *ui.Callback, codepoint: u32) !void {
    var program: *Program = @alignCast(@ptrCast(program_ptr));

    var buf: [4]u8 = undefined;
    const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
    try program.char_test.print(&program.state.scene, program.ally, .{ .text = string, .color = .{ 0.0, 0.0, 0.0 } });
}

const NineInfo = struct {
    top_left: Box,
    left: Box,
    bottom_left: Box,
    top: Box,
    bottom: Box,
    top_right: Box,
    right: Box,
    bottom_right: Box,
};

const NineRectSprite = struct {
    top_left: graphics.Texture,
    left: graphics.Texture,
    bottom_left: graphics.Texture,
    top: graphics.Texture,
    bottom: graphics.Texture,
    top_right: graphics.Texture,
    right: graphics.Texture,
    bottom_right: graphics.Texture,

    top_left_sprite: ?graphics.Sprite = null,
    left_sprite: ?graphics.Sprite = null,
    bottom_left_sprite: ?graphics.Sprite = null,
    top_sprite: ?graphics.Sprite = null,
    bottom_sprite: ?graphics.Sprite = null,
    top_right_sprite: ?graphics.Sprite = null,
    right_sprite: ?graphics.Sprite = null,
    bottom_right_sprite: ?graphics.Sprite = null,

    pub fn init(rect: *NineRectSprite, ally: std.mem.Allocator, in_box: Box) !Box {
        rect.top_left_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.top_left });
        rect.left_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.left });
        rect.bottom_left_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.bottom_left });
        rect.top_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.top });
        rect.bottom_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.bottom });
        rect.top_right_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.top_right });
        rect.right_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.right });
        rect.bottom_right_sprite = try graphics.Sprite.init(&state.scene, .{ .tex = rect.bottom_right });

        return NineRectBox(ally, .{
            .top_left = try Box.init(ally, .{
                .size = .{ rect.top_left_sprite.?.width, rect.top_left_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_left_sprite.?)},
            }),
            .bottom_left = try Box.init(ally, .{
                .size = .{ rect.bottom_left_sprite.?.width, rect.bottom_left_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_left_sprite.?)},
            }),
            .top_right = try Box.init(ally, .{
                .size = .{ rect.top_right_sprite.?.width, rect.top_right_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_right_sprite.?)},
            }),
            .bottom_right = try Box.init(ally, .{
                .size = .{ rect.bottom_right_sprite.?.width, rect.bottom_right_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_right_sprite.?)},
            }),
            .top = try Box.init(ally, .{
                .expand = .{ .horizontal = true },
                .size = .{ rect.top_sprite.?.width, rect.top_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_sprite.?)},
            }),
            .bottom = try Box.init(ally, .{
                .expand = .{ .horizontal = true },
                .size = .{ rect.bottom_sprite.?.width, rect.bottom_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_sprite.?)},
            }),
            .left = try Box.init(ally, .{
                .expand = .{ .vertical = true },
                .size = .{ rect.left_sprite.?.width, rect.left_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.left_sprite.?)},
            }),
            .right = try Box.init(ally, .{
                .expand = .{ .vertical = true },
                .size = .{ rect.right_sprite.?.width, rect.right_sprite.?.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.right_sprite.?)},
            }),
        }, in_box);
    }
};

pub fn NineRectBox(ally: std.mem.Allocator, info: NineInfo, in_box: Box) !Box {
    var box = in_box;
    box.expand = .{ .vertical = true, .horizontal = true };
    box.fixed_size = .{ 0, 0 };

    return try Box.init(ally, .{
        .flow = .{ .horizontal = true },
        .expand = in_box.expand,
        .size = in_box.fixed_size,
        .children = &.{
            try Box.init(ally, .{
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true },
                .size = .{ 0, 0 },
                .children = &.{
                    info.top_left,
                    info.left,
                    info.bottom_left,
                },
            }),
            try Box.init(ally, .{
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true, .horizontal = true },
                .children = &.{
                    info.top,
                    box,
                    info.bottom,
                },
            }),
            try Box.init(ally, .{
                .flow = .{ .vertical = true },
                .expand = .{ .vertical = true },
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    global_ally = gpa.allocator();
    const ally = global_ally;

    state = try Ui.init(ally, .{ .name = "box test", .width = 500, .height = 500, .resizable = true, .preferred_format = .unorm });
    defer state.deinit(ally);

    //var sprite = try graphics.Sprite.init(&state.scene, .{ .tex = tex });

    var program = try Program.init(state);
    try program.initPtr();

    const margins = 10;
    //const text_margin = 20;

    var text_border = NineRectSprite{
        .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_left.png", .{}),
        .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_left.png", .{}),
        .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_right.png", .{}),
        .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_right.png", .{}),
        .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top.png", .{}),
        .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom.png", .{}),
        .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/left.png", .{}),
        .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/right.png", .{}),
    };

    var border = NineRectSprite{
        .top_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top_left.png", .{}),
        .bottom_left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom_left.png", .{}),
        .top_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top_right.png", .{}),
        .bottom_right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom_right.png", .{}),
        .top = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/top.png", .{}),
        .bottom = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/bottom.png", .{}),
        .left = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/left.png", .{}),
        .right = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_2/right.png", .{}),
    };

    root = try Box.init(ally, .{
        .size = .{ 1920, 1080 },
        .children = &.{
            try Box.init(ally, .{
                .expand = .{ .vertical = true, .horizontal = true },
                .callbacks = &.{ui.getColorCallback(&program.color)},
            }),
            try ui.MarginBox(ally, .{ .top = margins, .bottom = margins, .left = margins, .right = margins }, try Box.init(ally, .{
                .expand = .{ .vertical = true, .horizontal = true },
                .flow = .{ .vertical = true },
                .children = &.{
                    try border.init(ally, try Box.init(ally, .{
                        .expand = .{ .vertical = true, .horizontal = true },
                        .callbacks = &.{},
                    })),
                    try Box.init(ally, .{ .size = .{ 0, 10 } }),
                    try text_border.init(ally, try Box.init(ally, .{
                        .expand = .{ .horizontal = true },
                        .size = .{ 0, 30 },
                        .callbacks = &.{
                            ui.getColorCallback(&program.input_box),
                            ui.getRegionCallback(&program.text_region),
                            ui.getTextCallback(&program.char_test),
                        },
                    })),
                },
            })),
        },
    });
    defer root.deinit();

    state.frame_func = frameUpdate;

    while (state.main_win.alive) {
        try state.updateEvents();
        try state.render();
    }
}
