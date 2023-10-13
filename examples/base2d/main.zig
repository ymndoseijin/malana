const std = @import("std");

const ui = @import("ui");
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const display = ui.display;

const math = ui.math;
const gl = ui.gl;

var state: *display.State = undefined;

var num_clicked: u32 = 0;

fn keyDown(key_state: display.KeyState, mods: i32, dt: f32) !void {
    _ = mods;
    _ = dt;
    if (key_state.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }
}
fn nice(_: *anyopaque, _: *display.Ui, _: i32, action: graphics.Action, _: i32) !bool {
    if (action == .press) num_clicked += 1;
    return true;
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try ui.parsing.BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    state = try display.State.init(.{ .name = "image test" });
    defer state.deinit();

    // get image file
    var arg_it = std.process.args();
    _ = arg_it.next();

    var image_path = arg_it.next() orelse return error.NotEnoughArguments;

    var sprite = try graphics.Sprite.init(try state.scene.new(.flat), image_path);

    var text = try graphics.Text.init(
        try state.scene.new(.flat),
        bdf,
        .{ 0, 0, 0 },
    );
    defer text.deinit();

    try text.initUniform();

    state.key_down = keyDown;

    var color = try graphics.ColoredRect.init(try state.scene.new(.flat), .{ 0.3, 0.3, 1, 1 });
    color.transform.scale = .{ 200, 200 };
    color.transform.rotation.angle = 0.78;
    color.updateTransform();

    var color_region: display.Region = .{ .transform = color.transform };

    try state.ui.elements.append(.{ @ptrCast(&color), .{ .mouse_func = nice, .region = &color_region } });

    while (state.main_win.alive) {
        try state.updateEvents();
        try text.printFmt("rect clicked {} times! {d:.4} {d:.1}", .{ num_clicked, state.cam.move, 1 / state.dt });

        sprite.transform.rotation.angle += state.dt;
        sprite.updateTransform();

        try state.render();
    }
}
