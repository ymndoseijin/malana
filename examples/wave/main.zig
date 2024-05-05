const std = @import("std");

const ui = @import("ui");
const shaders = @import("shaders");

const graphics = ui.graphics;
const Ui = ui.Ui;
const math = ui.math;
const gl = ui.gl;

var state: *Ui = undefined;

const Toy = struct {
    zoom: f32,
    is_pan: bool = false,
    press_time: f32 = 0,
    speed: f32 = 1.0,

    offset: math.Vec2 = math.Vec2.init(.{ 0, 0 }),

    last_pos: math.Vec2,
    text: graphics.TextFt,

    pub fn getZoom(toy: Toy) f32 {
        return std.math.pow(f32, 1.2, toy.zoom);
    }

    pub fn getOffset(toy: Toy) math.Vec2 {
        return toy.offset.scale(-1);
    }

    pub fn updateText(toy: *Toy) !void {
        try toy.text.clear();
        try toy.text.printFmt(state.main_win.ally, "{d}x speed {d:.4}x zoom", .{ toy.speed, toy.zoom });
    }
};

var bad_code: *Toy = undefined;

fn keyDown(key_state: ui.KeyState, mods: i32, dt: f32) !void {
    _ = mods;
    _ = dt;
    if (key_state.pressed_table[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    const toy = bad_code;

    const factor = toy.speed;

    if (state.time - toy.press_time > 0.3) {
        if (key_state.pressed_table[graphics.glfw.GLFW_KEY_RIGHT]) {
            toy.speed += 0.5 * state.dt * factor;
            try toy.updateText();
        } else if (key_state.pressed_table[graphics.glfw.GLFW_KEY_LEFT]) {
            toy.speed -= 0.5 * state.dt * factor;
            try toy.updateText();
        }
    }
}

fn cursorMove(toy_ptr: *anyopaque, _: *ui.Callback, x: f64, y: f64) !void {
    const toy: *Toy = @alignCast(@ptrCast(toy_ptr));
    const pos = math.Vec2.init(.{ @floatCast(x), @floatCast(y) });

    if (toy.is_pan) {
        const offset = pos.sub(toy.last_pos).scale(2).div(state.main_win.getSize());
        toy.offset = toy.offset.add(offset.scale(toy.getZoom()));
    }
    toy.last_pos = pos;
}

fn mouseAction(toy_ptr: *anyopaque, _: *ui.Callback, button: i32, action: graphics.Action, _: i32) !void {
    const toy: *Toy = @alignCast(@ptrCast(toy_ptr));

    if (button == 2) {
        if (action == .press) toy.is_pan = true;
        if (action == .release) toy.is_pan = false;
    }
}

fn keyAction(toy_ptr: *anyopaque, _: *ui.Callback, button: i32, _: i32, action: graphics.Action, _: i32) !void {
    const toy: *Toy = @alignCast(@ptrCast(toy_ptr));

    if (button == graphics.glfw.GLFW_KEY_RIGHT) {
        if (action == .press) {
            toy.speed += 0.5;
            toy.press_time = @floatCast(state.time);
            try toy.updateText();
        }
    } else if (button == graphics.glfw.GLFW_KEY_LEFT) {
        if (action == .press) {
            toy.speed -= 0.5;
            toy.press_time = @floatCast(state.time);
            try toy.updateText();
        }
    }
}

fn zoomScroll(toy_ptr: *anyopaque, _: *ui.Callback, _: f64, y: f64) !void {
    const toy: *Toy = @alignCast(@ptrCast(toy_ptr));
    toy.zoom += @as(f32, @floatCast(y));
    try toy.updateText();
}

pub fn main() !void {
    const ally = std.heap.c_allocator;

    // get image file
    var arg_it = std.process.args();
    _ = arg_it.next();

    const image_path = arg_it.next() orelse return error.NotEnoughArguments;
    const frequency = try std.fmt.parseFloat(f32, arg_it.next() orelse return error.NotEnoughArguments);

    state = try Ui.init(ally, .{ .window = .{ .name = "Wave Sim", .width = 800, .height = 800, .resizable = true } });
    defer state.deinit(ally);

    const gpu = &state.main_win.gpu;
    const win = state.main_win;
    state.key_down = keyDown;

    const ComputeUniform: graphics.DataDescription = .{
        .T = extern struct {
            delta: f32,
            time: f32,
            frequency: f32,
            mouse_on: u32,
            mouse_pos: [2]f32 align(4 * 2),
            size: u32,
        },
    };

    const PushConstants: graphics.DataDescription = .{ .T = extern struct {
        switch_val: u32,
    } };

    const ComputeDescription: graphics.ComputeDescription = .{
        .sets = &.{.{
            .bindings = &.{
                .{ .uniform = .{ .size = ComputeUniform.getSize() } },
                .{ .sampler = .{ .type = .storage, .count = 3 } },
                .{ .sampler = .{} },
            },
        }},
        .constants_size = PushConstants.getSize(),
    };

    const space_tex = try graphics.Texture.initFromPath(ally, state.main_win, image_path, .{ .mag_filter = .linear, .min_filter = .linear, .texture_type = .flat });
    defer space_tex.deinit();

    const compute_shader = try graphics.Shader.init(win.gpu, &shaders.compute, .compute);
    defer compute_shader.deinit(gpu.*);

    var compute_pipeline = try graphics.ComputePipeline.init(ally, .{
        .description = ComputeDescription,
        .shader = compute_shader,
        .gpu = &win.gpu,
        .flipped_z = true,
    });
    defer compute_pipeline.deinit(&win.gpu);
    var compute = try graphics.Compute.init(ally, .{ .win = win, .pipeline = compute_pipeline });
    defer compute.deinit(ally);

    const size = 16 * 100 * 2;

    compute.setCount(size / 16, size / 16, 1);

    const init_tex = blk: {
        const grid = try ally.alloc(f32, size * size);
        for (grid) |*pix| {
            pix.* = 0;
        }
        break :blk grid;
    };
    defer ally.free(init_tex);

    var previous_tex = try graphics.Texture.init(win, size, size, .{ .preferred_format = .float, .type = .storage });
    var current_tex = try graphics.Texture.init(win, size, size, .{ .preferred_format = .float, .type = .storage });
    var next_tex = try graphics.Texture.init(win, size, size, .{ .preferred_format = .float, .type = .storage });

    try previous_tex.setFromRgba(.{ .data = init_tex });
    try current_tex.setFromRgba(.{ .data = init_tex });
    try next_tex.setFromRgba(.{ .data = init_tex });

    const image_vert = try graphics.Shader.init(win.gpu, &shaders.image_vert, .vertex);
    defer image_vert.deinit(win.gpu);

    const image_frag = try graphics.Shader.init(win.gpu, &shaders.image_frag, .fragment);
    defer image_frag.deinit(win.gpu);

    const ImageUniform: graphics.DataDescription = .{ .T = extern struct {
        zoom: f32,
        offset: [2]f32 align(2 * 4),
        size: u32,
    } };

    const image_description: graphics.PipelineDescription = comptime .{
        .vertex_description = .{
            .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 } },
        },
        .depth_test = false,
        .cull_type = .none,
        .render_type = .triangle,
        .sets = &.{.{
            .bindings = &.{
                .{ .uniform = .{ .size = ImageUniform.getSize() } },
                .{ .sampler = .{} },
                .{ .sampler = .{} },
            },
        }},
    };

    var image_pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = image_description,
        .shaders = &.{ image_vert, image_frag },
        .rendering = state.main_win.rendering_options,
        .gpu = &win.gpu,
        .flipped_z = true,
    });
    defer image_pipeline.deinit(gpu);

    const image_drawing = try ally.create(graphics.Drawing);
    defer ally.destroy(image_drawing);

    try image_drawing.init(ally, .{
        .win = win,
        .pipeline = image_pipeline,
    });
    defer image_drawing.deinit(ally);

    try image_description.vertex_description.bindVertex(image_drawing, &.{
        .{ .{ -1, -1, 1 }, .{ 0, 0 } },
        .{ .{ 1, -1, 1 }, .{ 1, 0 } },
        .{ .{ 1, 1, 1 }, .{ 1, 1 } },
        .{ .{ -1, 1, 1 }, .{ 0, 1 } },
    }, &.{ 0, 1, 2, 2, 3, 0 });

    try image_drawing.descriptor.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 1, .textures = &.{next_tex}, .type = .combined_storage }} });
    try image_drawing.descriptor.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 2, .textures = &.{space_tex} }} });

    var pressed: bool = false;

    var toy: Toy = .{
        .zoom = 1,
        .last_pos = win.getCursorPos(),
        .text = try graphics.TextFt.init(ally, .{
            .path = "resources/cmunrm.ttf",
            .size = 25,
            .line_spacing = 1,
            .bounding_width = 2500,
            .flip_y = false,
            .scene = &state.scene,
        }),
    };
    defer toy.text.deinit();

    bad_code = &toy;

    toy.text.transform.translation = math.Vec2.init(.{ 10, 10 });
    try toy.updateText();

    state.callback.focused = .{ @ptrCast(&toy), .{
        .scroll_func = zoomScroll,
        .cursor_func = cursorMove,
        .mouse_func = mouseAction,
        .key_func = keyAction,
    } };
    var zoom: f32 = toy.getZoom();

    var switch_val: u32 = 0;

    try compute.descriptor.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 1, .dst = 0, .textures = &.{previous_tex}, .type = .storage }} });
    try compute.descriptor.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 1, .dst = 1, .textures = &.{current_tex}, .type = .storage }} });
    try compute.descriptor.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 1, .dst = 2, .textures = &.{next_tex}, .type = .storage }} });

    try compute.descriptor.updateDescriptorSets(ally, .{ .samplers = &.{.{ .idx = 2, .textures = &.{space_tex} }} });

    var sim_time: f32 = 0;

    while (win.alive) {
        const frame = graphics.tracy.namedFrame("Frame");
        defer frame.end();

        try state.updateEvents();

        if (win.getMouseButton(0) == .press) pressed = true;
        if (win.getMouseButton(0) == .release) pressed = false;

        const target_zoom = toy.getZoom();
        const dist = target_zoom - zoom;
        zoom += 5 * dist * state.dt;

        image_drawing.descriptor.getUniformOr(0, 0, 0).?.setAsUniform(ImageUniform, .{
            .zoom = zoom,
            .offset = toy.getOffset().val,
            .size = size,
        });

        const cursor_uv = win.getCursorPos().div(win.getSize());

        const speed = @max(0, toy.speed);
        sim_time += @round(speed) * 0.01;

        compute.descriptor.getUniformOr(0, 0, 0).?.setAsUniform(ComputeUniform, .{
            .delta = 0.01,
            .time = sim_time,
            .frequency = frequency,
            .mouse_on = if (pressed) 1 else 0,
            .mouse_pos = cursor_uv.scale(2).sub(math.Vec2.init(.{ 1, 1 })).scale(zoom).add(toy.getOffset()).scale(0.5).add(math.Vec2.init(.{ 0.5, 0.5 })).val,
            .size = size,
        });

        const builder = &state.command_builder;
        const frame_id = builder.frame_id;
        const swapchain = &win.swapchain;
        const extent = swapchain.extent;

        // compute compute
        const compute_builder = &state.compute_builder;
        try compute.wait(frame_id);

        const compute_trace = graphics.tracy.traceNamed(@src(), "Compute Builder");
        try compute_builder.beginCommand(gpu);

        for (0..@intFromFloat(@round(speed))) |_| {
            const data: PushConstants.T = .{
                .switch_val = switch_val,
            };

            switch_val += 1;
            switch_val %= 3;

            compute_builder.push(PushConstants, gpu, compute_pipeline.pipeline, &data);

            try compute.dispatch(compute_builder.getCurrent(), .{ .bind_pipeline = true, .frame_id = 0 });
        }

        try compute_builder.endCommand(gpu);
        compute_trace.end();

        try compute.submit(ally, compute_builder.*, .{});

        // render graphics

        try swapchain.wait(gpu, frame_id);

        try state.scene.queue.execute();

        state.image_index = try swapchain.acquireImage(gpu, frame_id);

        const builder_trace = graphics.tracy.traceNamed(@src(), "Color Builder");
        try builder.beginCommand(gpu);

        builder.pipelineBarrier(gpu, .{
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

        builder.pipelineBarrier(gpu, .{
            .src_stage = .{ .color_attachment_output_bit = true },
            .dst_stage = .{ .color_attachment_output_bit = true },
            .image_barriers = &.{
                .{
                    .image = state.post_color_tex.image,
                    .src_access = .{},
                    .dst_access = .{ .color_attachment_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .color_attachment_optimal,
                },
            },
        });
        state.post_color_tex.current_layout = .color_attachment_optimal;

        builder.pipelineBarrier(gpu, .{
            .src_stage = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .dst_stage = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .image_barriers = &.{
                .{
                    .image = state.post_depth_tex.image,
                    .src_access = .{ .depth_stencil_attachment_write_bit = true },
                    .dst_access = .{ .depth_stencil_attachment_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .depth_stencil_attachment_optimal,
                },
            },
        });
        state.post_depth_tex.current_layout = .depth_stencil_attachment_optimal;

        // first
        try builder.setViewport(gpu, .{ .flip_z = state.scene.flip_z, .width = extent.width, .height = extent.height });
        builder.beginRendering(gpu, .{
            .color_attachments = &.{state.post_color_tex.getAttachment()},
            .depth_attachment = state.post_depth_tex.getAttachment(),
            .region = .{
                .x = 0,
                .y = 0,
                .width = extent.width,
                .height = extent.height,
            },
        });
        try image_drawing.draw(builder.getCurrent(), .{
            .frame_id = builder.frame_id,
            .bind_pipeline = true,
        });
        try state.scene.draw(builder);
        builder.endRendering(gpu);

        builder.pipelineBarrier(gpu, .{
            .src_stage = .{ .color_attachment_output_bit = true },
            .dst_stage = .{ .fragment_shader_bit = true },
            .image_barriers = &.{
                .{
                    .image = state.post_color_tex.image,
                    .src_access = .{ .color_attachment_write_bit = true },
                    .dst_access = .{ .shader_read_bit = true },
                    .old_layout = .color_attachment_optimal,
                    .new_layout = state.post_color_tex.getIdealLayout(),
                },
            },
        });

        // post
        try builder.setViewport(gpu, .{ .flip_z = false, .width = extent.width, .height = extent.height });
        builder.beginRendering(gpu, .{
            .color_attachments = &.{swapchain.getAttachment(state.image_index)},
            .region = .{
                .x = 0,
                .y = 0,
                .width = extent.width,
                .height = extent.height,
            },
        });
        try state.post_scene.draw(builder);
        builder.endRendering(gpu);

        try builder.transitionLayout(gpu, swapchain.getImage(state.image_index), .{
            .old_layout = .color_attachment_optimal,
            .new_layout = .present_src_khr,
        });

        try builder.endCommand(gpu);
        builder_trace.end();

        try swapchain.submit(gpu, state.command_builder, .{ .wait = &.{
            .{ .semaphore = compute.compute_semaphores[frame_id], .flag = .{ .fragment_shader_bit = true, .vertex_input_bit = true } },
            .{ .semaphore = swapchain.image_acquired[frame_id], .flag = .{ .color_attachment_output_bit = true } },
        } });
        try swapchain.present(gpu, .{ .wait = &.{swapchain.render_finished[frame_id]}, .image_index = state.image_index });
    }

    try win.gpu.vkd.deviceWaitIdle(win.gpu.dev);
}
