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
    input_box: graphics.ColoredRect,
    char_test: graphics.TextFt,
    text_region: ui.Region,
    state: *Ui,
    ally: std.mem.Allocator,

    pub fn init(state_ui: *Ui) !Program {
        const color = try graphics.ColoredRect.init(&state.scene, try math.color.parseHexRGBA("c0c0c0"));
        const input_box = try graphics.ColoredRect.init(&state.scene, .{ 1.0, 1.0, 1.0, 1.0 });
        const char_test = try graphics.TextFt.init(global_ally, "resources/fonts/Fairfax.ttf", 12, 1, 250);

        const text_region: ui.Region = .{ .transform = input_box.transform };

        return .{
            .color = color,
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
    top_left: graphics.Sprite,
    left: graphics.Sprite,
    bottom_left: graphics.Sprite,
    top: graphics.Sprite,
    bottom: graphics.Sprite,
    top_right: graphics.Sprite,
    right: graphics.Sprite,
    bottom_right: graphics.Sprite,

    pub fn init(rect: *NineRectSprite, ally: std.mem.Allocator, in_box: Box) !Box {
        return NineRectBox(ally, .{
            .top_left = try Box.init(ally, .{
                .size = .{ rect.top_left.width, rect.top_left.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_left)},
            }),
            .bottom_left = try Box.init(ally, .{
                .size = .{ rect.bottom_left.width, rect.bottom_left.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_left)},
            }),
            .top_right = try Box.init(ally, .{
                .size = .{ rect.top_right.width, rect.top_right.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top_right)},
            }),
            .bottom_right = try Box.init(ally, .{
                .size = .{ rect.bottom_right.width, rect.bottom_right.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom_right)},
            }),
            .top = try Box.init(ally, .{
                .expand = .{ .horizontal = true },
                .size = .{ rect.top.width, rect.top.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.top)},
            }),
            .bottom = try Box.init(ally, .{
                .expand = .{ .horizontal = true },
                .size = .{ rect.bottom.width, rect.bottom.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.bottom)},
            }),
            .left = try Box.init(ally, .{
                .expand = .{ .vertical = true },
                .size = .{ rect.left.width, rect.left.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.left)},
            }),
            .right = try Box.init(ally, .{
                .expand = .{ .vertical = true },
                .size = .{ rect.right.width, rect.right.height },
                .callbacks = &.{ui.getSpriteCallback(&rect.right)},
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

    state = try Ui.init(ally, .{ .name = "box test", .width = 500, .height = 500, .resizable = true });
    defer state.deinit(ally);

    //var sprite = try graphics.Sprite.init(&state.scene, .{ .tex = tex });

    var program = try Program.init(state);
    try program.initPtr();

    //const margins = 10;
    //const text_margin = 20;

    var nine = NineRectSprite{
        .top_left = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_left.png", .{}),
        }),
        .bottom_left = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_left.png", .{}),
        }),
        .top_right = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top_right.png", .{}),
        }),
        .bottom_right = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom_right.png", .{}),
        }),
        .top = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/top.png", .{}),
        }),
        .bottom = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/bottom.png", .{}),
        }),
        .left = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/left.png", .{}),
        }),
        .right = try graphics.Sprite.init(&state.scene, .{
            .tex = try graphics.Texture.initFromPath(ally, state.main_win, "resources/ui/box_1/right.png", .{}),
        }),
    };

    root = try Box.init(ally, .{
        .size = .{ 1920, 1080 },
        .children = &.{
            try Box.init(ally, .{
                .expand = .{ .vertical = true, .horizontal = true },
                .callbacks = &.{ui.getColorCallback(&program.color)},
            }),
            try Box.init(ally, .{
                .expand = .{ .vertical = true, .horizontal = true },
                .flow = .{ .vertical = true },
                .children = &.{
                    try nine.init(ally, try Box.init(ally, .{
                        .expand = .{ .horizontal = true, .vertical = true },
                        .size = .{ 0, 30 },
                        .callbacks = &.{
                            ui.getColorCallback(&program.input_box),
                            ui.getRegionCallback(&program.text_region),
                            ui.getTextCallback(&program.char_test),
                        },
                    })),
                },
            }),
        },
    });
    defer root.deinit();

    state.frame_func = frameUpdate;

    while (state.main_win.alive) {
        try state.updateEvents();
        try state.render();
    }
}
