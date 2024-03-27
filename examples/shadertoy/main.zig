const std = @import("std");

const ui = @import("ui");
const shaders = @import("shaders");

const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Vertex = ui.Vertex;
const common = ui.common;

const Ui = ui.Ui;

const math = ui.math;
const gl = ui.gl;

var state: *Ui = undefined;

fn keyDown(key_state: ui.KeyState, mods: i32, dt: f32) !void {
    _ = mods;
    _ = dt;
    if (key_state.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    var arg_it = std.process.args();
    _ = arg_it.next();

    const shader_path = arg_it.next() orelse return error.NotEnoughArguments;

    if ((try std.posix.fork()) == 0) std.process.execve(ally, &.{ "glslc", "--target-env=vulkan1.2", shader_path, "-o", "/tmp/shadertoy.spv" }, null) catch {};
    _ = std.posix.waitpid(-1, 0);

    const shader_file = try std.fs.cwd().openFile("/tmp/shadertoy.spv", .{});
    const shader_content = try shader_file.readToEndAlloc(ally, std.math.maxInt(u32));
    defer ally.free(shader_content);

    state = try Ui.init(ally, .{ .window = .{ .name = "Shadertoy Impl", .width = 800, .height = 600, .resizable = true } });
    defer state.deinit(ally);
    state.key_down = keyDown;

    const shader = try graphics.Shader.init(state.main_win.gc, @alignCast(shader_content), .fragment);
    defer shader.deinit(state.main_win.gc);
    const vert_shader = try graphics.Shader.init(state.main_win.gc, &shaders.vert, .vertex);
    defer vert_shader.deinit(state.main_win.gc);

    const shader_desc = comptime graphics.PipelineDescription{
        .vertex_description = .{
            .vertex_attribs = &[_]graphics.VertexAttribute{ .{ .size = 3 }, .{ .size = 2 } },
        },
        .render_type = .triangle,
        .depth_test = false,
        .uniform_sizes = &.{graphics.GlobalUniform.getSize()},
        .global_ubo = true,
    };

    var pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = shader_desc,
        .shaders = &.{ vert_shader, shader },
        .render_pass = state.first_pass,
        .gc = &state.main_win.gc,
        .flipped_z = false,
    });
    defer pipeline.deinit(&state.main_win.gc);

    const drawing = try state.scene.new();

    try drawing.init(ally, .{
        .win = state.main_win,
        .pipeline = pipeline,
    });

    try shader_desc.vertex_description.bindVertex(drawing, &.{
        .{ .{ -1, -1, 1 }, .{ 0, 0 } },
        .{ .{ 1, -1, 1 }, .{ 1, 0 } },
        .{ .{ 1, 1, 1 }, .{ 1, 1 } },
        .{ .{ -1, 1, 1 }, .{ 0, 1 } },
    }, &.{ 0, 1, 2, 2, 3, 0 });

    while (state.main_win.alive) {
        try state.updateEvents();
        try state.render();
        //if (true) std.os.exit(0);
    }
}
