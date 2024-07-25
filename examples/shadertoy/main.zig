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

    if ((try std.posix.fork()) == 0) {
        std.process.execve(ally, &.{ "glslang", "-gVS", "--target-env", "vulkan1.2", shader_path, "-o", "/tmp/shadertoy.spv" }, null) catch {};
    }
    _ = std.posix.waitpid(-1, 0);

    const shader_file = try std.fs.cwd().openFile("/tmp/shadertoy.spv", .{});
    const shader_content = try shader_file.readToEndAlloc(ally, std.math.maxInt(u32));
    defer ally.free(shader_content);

    state = try Ui.init(ally, .{ .window = .{ .name = "Shadertoy Impl", .width = 800, .height = 600, .resizable = true } });
    defer state.deinit(ally);

    const gc = &state.main_win.gc;
    const win = state.main_win;

    state.key_down = keyDown;

    const shader = try graphics.Shader.init(win.gc, @alignCast(shader_content), .fragment);
    defer shader.deinit(win.gc);
    const vert_shader = try graphics.Shader.init(win.gc, &shaders.vert, .vertex);
    defer vert_shader.deinit(win.gc);

    const shader_desc: graphics.PipelineDescription = comptime .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 } },
        },
        .render_type = .triangle,
        .depth_test = false,
        .sets = &.{.{
            .bindings = &.{
                .{ .uniform = .{ .size = graphics.GlobalUniform.getSize() } },
            },
        }},
        .global_ubo = true,
    };

    var pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = shader_desc,
        .shaders = &.{ vert_shader, shader },
        .gc = &win.gc,
        .flipped_z = false,
        .rendering = state.main_win.rendering_options,
    });
    defer pipeline.deinit(&win.gc);

    const drawing = try state.scene.new();

    try drawing.init(ally, .{
        .win = win,
        .pipeline = pipeline,
    });

    try shader_desc.vertex_description.bindVertex(drawing, &.{
        .{ .{ -1, -1, 1 }, .{ 0, 0 } },
        .{ .{ 1, -1, 1 }, .{ 1, 0 } },
        .{ .{ 1, 1, 1 }, .{ 1, 1 } },
        .{ .{ -1, 1, 1 }, .{ 0, 1 } },
    }, &.{ 0, 1, 2, 2, 3, 0 });

    while (win.alive) {
        try state.updateEvents();

        const builder = &state.command_builder;
        const frame_id = builder.frame_id;
        const swapchain = &win.swapchain;
        const extent = swapchain.extent;

        try swapchain.wait(gc, frame_id);

        state.image_index = try swapchain.acquireImage(gc, frame_id);
        try builder.beginCommand(gc);

        builder.pipelineBarrier(gc, .{
            .src_stage = .{ .color_attachment_output_bit = true },
            .dst_stage = .{ .color_attachment_output_bit = true },
            .image_barriers = &.{
                .{
                    .image = swapchain.getImage(state.image_index),
                    .src_access = .{},
                    .dst_access = .{ .color_attachment_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .color_attachment_optimal,
                },
            },
        });

        try builder.setViewport(gc, .{ .flip_z = false, .width = extent.width, .height = extent.height });
        builder.beginRendering(gc, .{
            .color_attachments = &.{swapchain.getAttachment(state.image_index)},
            .region = .{
                .x = 0,
                .y = 0,
                .width = extent.width,
                .height = extent.height,
            },
        });
        try state.scene.draw(builder);
        builder.endRendering(gc);

        builder.pipelineBarrier(gc, .{
            .src_stage = .{ .color_attachment_output_bit = true },
            .dst_stage = .{ .bottom_of_pipe_bit = true },
            .image_barriers = &.{
                .{
                    .image = swapchain.getImage(state.image_index),
                    .src_access = .{ .color_attachment_write_bit = true },
                    .dst_access = .{},
                    .old_layout = .color_attachment_optimal,
                    .new_layout = .present_src_khr,
                },
            },
        });

        try builder.endCommand(gc);

        try swapchain.submit(gc, state.command_builder, .{ .wait = &.{
            .{ .semaphore = swapchain.image_acquired[frame_id], .flag = .{ .color_attachment_output_bit = true } },
        } });
        try swapchain.present(gc, .{ .wait = &.{swapchain.render_finished[frame_id]}, .image_index = state.image_index });
    }
}
