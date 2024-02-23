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
var ally: std.mem.Allocator = undefined;

const Program = struct {
    color: graphics.ColoredRect,
    input_box: graphics.ColoredRect,
    char_test: graphics.TextFt,
    text_region: ui.Region,
    state: *Ui,

    pub fn init(state_ui: *Ui) !Program {
        const color = try graphics.ColoredRect.init(&state.scene, .{ 0.2, 0.2, 0.2, 1.0 });
        const input_box = try graphics.ColoredRect.init(&state.scene, .{ 1.0, 1.0, 1.0, 1.0 });
        var char_test = try graphics.TextFt.init(ally, "nasin-nanpa-3.1.0.woff", 20, 1, 250);

        try char_test.print(&state.scene, ally, .{ .text = "hello world! " });
        try char_test.print(&state.scene, ally, .{ .text = "I'm here!" });

        const text_region: ui.Region = .{ .transform = input_box.transform };

        return .{
            .color = color,
            .input_box = input_box,
            .char_test = char_test,
            .text_region = text_region,
            .state = state_ui,
        };
    }

    pub fn initPtr(program: *Program) !void {
        try state.callback.elements.append(.{ @ptrCast(program), .{ .char_func = textInput, .region = &program.text_region } });
    }
};

pub fn frameUpdate(width: i32, height: i32) !void {
    root.fixed_size = .{ @floatFromInt(width), @floatFromInt(height) };
    root.current_size = .{ @floatFromInt(width), @floatFromInt(height) };
    try root.resolve(ally);
}

fn textInput(program_ptr: *anyopaque, _: *ui.Callback, codepoint: u32) !void {
    var program: *Program = @alignCast(@ptrCast(program_ptr));

    var buf: [4]u8 = undefined;
    const string = buf[0..try std.unicode.utf8Encode(@intCast(codepoint), &buf)];
    try program.char_test.print(&program.state.scene, ally, .{ .text = string, .color = .{ 0.9, 1.0, 0.9 } });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    ally = gpa.allocator();

    state = try Ui.init(ally, .{ .name = "box test", .width = 500, .height = 500, .resizable = true });
    defer state.deinit(ally);

    var program = try Program.init(state);
    try program.initPtr();

    const margins = 10;
    const text_margin = 20;
    root = try Box.init(ally, .{
        .size = .{ 1920, 1080 },
        .children = &.{
            try ui.MarginBox(
                ally,
                .{ .top = margins, .bottom = margins, .left = margins, .right = margins },
                try Box.init(ally, .{
                    .expand = .{ .vertical = true, .horizontal = true },
                    .callbacks = &.{ui.getColorCallback(&program.color)},
                }),
            ),
            try ui.MarginBox(
                ally,
                .{ .top = text_margin, .bottom = text_margin, .left = text_margin, .right = text_margin },
                try Box.init(ally, .{
                    .expand = .{ .vertical = true, .horizontal = true },
                    .flow = .{ .vertical = true },
                    .children = &.{
                        try Box.init(ally, .{
                            .expand = .{ .vertical = true, .horizontal = true },
                            .callbacks = &.{ui.getTextCallback(&program.char_test)},
                        }),
                        try Box.init(ally, .{
                            .expand = .{ .horizontal = true },
                            .size = .{ 0, 100 },
                            .callbacks = &.{ ui.getColorCallback(&program.input_box), ui.getRegionCallback(&program.text_region) },
                        }),
                    },
                }),
            ),
        },
    });
    defer root.deinit();

    state.frame_func = frameUpdate;

    while (state.main_win.alive) {
        try state.updateEvents();
        try state.render();
    }
}
