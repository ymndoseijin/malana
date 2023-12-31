const std = @import("std");

const ui = @import("ui");
const shaders = @import("shaders");

const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const display = ui.display;

const math = ui.math;
const gl = ui.gl;

var state: *display.State = undefined;

fn keyDown(key_state: display.KeyState, mods: i32, dt: f32) !void {
    _ = mods;
    _ = dt;
    if (key_state.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    state = try display.State.init(.{ .name = "image test", .width = 1920, .height = 1080, .resizable = false });
    defer state.deinit();
    state.key_down = keyDown;

    var tex = try graphics.Texture.initFromPath(state.main_win, "resources/ear.qoi", .{ .mag_filter = .linear, .min_filter = .mipmap, .texture_type = .flat });
    defer tex.deinit();

    var sprite = try graphics.Sprite.init(&state.scene, .{ .tex = tex });

    while (state.main_win.alive) {
        try state.updateEvents();

        sprite.transform.rotation.angle += 0.1;
        sprite.updateTransform();

        try state.render();
    }

    try state.main_win.gc.vkd.deviceWaitIdle(state.main_win.gc.dev);
}
