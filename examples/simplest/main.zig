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
pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var state = try display.State(union { sprite: *graphics.Drawing(graphics.SpritePipeline) }).init(.{ .name = "image test", .width = 1920, .height = 1080, .resizable = false });
    defer state.deinit();

    const tex = try graphics.Texture.initFromPath(state.main_win, "resources/ear.qoi", .{ .mag_filter = .linear, .min_filter = .mipmap, .texture_type = .flat });

    var sprite = try graphics.Sprite(graphics.SpritePipeline).init(&state.scene, .{ .tex = tex });

    while (true) {
        try state.updateEvents();

        sprite.transform.rotation.angle += 0.1;
        sprite.updateTransform();

        try state.render();
    }
}
