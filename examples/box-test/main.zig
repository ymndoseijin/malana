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

fn colorBoxBind(box: *Box, color_ptr: *anyopaque) !void {
    var color: *graphics.ColoredRect = @ptrCast(@alignCast(color_ptr));

    std.debug.print("size: {d}\n", .{box.current_size});

    color.transform.scale = box.current_size;
    color.transform.translation = box.absolute_pos;
    color.updateTransform();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    state = try Ui.init(ally, .{ .name = "box test", .width = 500, .height = 500, .resizable = true });
    defer state.deinit(ally);

    var color = try graphics.ColoredRect.init(&state.scene, .{ 1.0, 0.0, 0, 1 });

    var root = try Box.init(ally, .{
        .flow = .{ .vertical = true },
        .size = .{ 1920, 1080 },
        .children = &.{
            try ui.MarginBox(
                ally,
                .{ .top = 100, .bottom = 100, .left = 100, .right = 100 },
                try Box.init(ally, .{
                    .expand = .{ .vertical = true, .horizontal = true },
                    .callbacks = &.{.{ .fun = colorBoxBind, .data = &color }},
                }),
            ),
        },
    });
    defer root.deinit();

    try root.resolve(ally);

    while (state.main_win.alive) {
        try state.updateEvents();
        try state.render();
    }

    try state.main_win.gc.vkd.deviceWaitIdle(state.main_win.gc.dev);
}
