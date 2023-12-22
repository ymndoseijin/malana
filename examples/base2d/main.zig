const std = @import("std");

const ui = @import("ui");
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const display = ui.display;

const math = ui.math;

const DrawingList = union {
    sprite: *graphics.Drawing(graphics.SpritePipeline),
    color: *graphics.Drawing(graphics.ColoredRect.Pipeline),
    bdf: *graphics.Drawing(graphics.TextBdf.Pipeline),
    character: *graphics.Drawing(graphics.TextFt.Character.Pipeline),
};

var state: *display.State(DrawingList) = undefined;

var num_clicked: u32 = 0;

var color: graphics.ColoredRect = undefined;

fn keyDown(key_state: display.KeyState, mods: i32, dt: f32) !void {
    _ = mods;
    _ = dt;
    if (key_state.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }
}
fn nice(_: *anyopaque, _: *display.Ui, _: i32, action: graphics.Action, _: i32) !bool {
    if (action == .press) {
        std.debug.print("Hey!", .{});
        try state.scene.delete(color.drawing);
        num_clicked += 1;
    }
    return true;
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try ui.parsing.BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    state = try display.State(DrawingList).init(.{ .name = "image test", .width = 1920, .height = 1080, .resizable = false });
    defer state.deinit();

    state.main_win.setSize(1920, 1080);
    // get image file
    var arg_it = std.process.args();
    _ = arg_it.next();

    const image_path = arg_it.next() orelse return error.NotEnoughArguments;

    const tex = try graphics.Texture.initFromPath(state.main_win, image_path, .{ .mag_filter = .linear, .min_filter = .mipmap, .texture_type = .flat });

    var sprite = try graphics.Sprite(graphics.SpritePipeline).init(&state.scene, .{ .tex = tex });

    color = try graphics.ColoredRect.init(&state.scene, .{ 0.3, 0.3, 1, 1 });
    color.transform.scale = .{ 200, 200 };
    color.transform.translation = .{ 0, 0 };
    color.transform.rotation.angle = 0.5;
    color.updateTransform();

    var color_region: display.Region = .{ .transform = color.transform };

    try state.ui.elements.append(.{ @ptrCast(&color), .{ .mouse_func = nice, .region = &color_region } });

    var text = try graphics.TextBdf.init(
        &state.scene,
        bdf,
        .{ 0, 0, 0 },
    );
    defer text.deinit();

    //try text.initUniform();

    var char_test = try graphics.TextFt.init("resources/cmunrm.ttf", 50, 1, 250);
    char_test.transform.translation = .{ 0, 200 };
    try char_test.print(&state.scene, .{ .text = "hello world! " });
    try char_test.print(&state.scene, .{ .text = "I'm here!" });
    char_test.setOpacity(0.5);
    defer char_test.deinit();

    state.key_down = keyDown;

    while (state.main_win.alive) {
        try state.updateEvents();
        try text.printFmt("rect clicked {} times! {d:.4} {d:.1}", .{ num_clicked, state.cam.move, 1 / state.dt });

        sprite.transform.rotation.angle += state.dt;
        sprite.updateTransform();

        try state.render();
    }
}
