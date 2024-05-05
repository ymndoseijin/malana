drawing_array: std.ArrayList(*graphics.Drawing),
window: *graphics.Window,
//render_pass: *RenderPass,
flip_z: bool,
default_pipelines: DefaultPipelines,
queue: graphics.OpQueue,

const DefaultPipelines = struct {
    color: graphics.RenderPipeline,
    sprite: graphics.RenderPipeline,
    sprite_batch: graphics.RenderPipeline,
    textft: graphics.RenderPipeline,

    pub fn init(win: *graphics.Window, flip_z: bool) !DefaultPipelines {
        const shaders = win.default_shaders;

        return .{
            .color = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.ColoredRect.description,
                .shaders = &shaders.color_shaders,
                .rendering = win.rendering_options,
                .gpu = &win.gpu,
                .flipped_z = flip_z,
            }),
            .sprite = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.Sprite.description,
                .shaders = &shaders.sprite_shaders,
                .rendering = win.rendering_options,
                .gpu = &win.gpu,
                .flipped_z = flip_z,
            }),
            .sprite_batch = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.SpriteBatch.description,
                .shaders = &shaders.sprite_batch_shaders,
                .rendering = win.rendering_options,
                .gpu = &win.gpu,
                .flipped_z = flip_z,
            }),
            .textft = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.TextFt.description,
                .shaders = &shaders.textft_shaders,
                .rendering = win.rendering_options,
                .gpu = &win.gpu,
                .flipped_z = flip_z,
            }),
        };
    }

    pub fn deinit(pipelines: *DefaultPipelines, gpu: *const graphics.Gpu) void {
        pipelines.color.deinit(gpu);
        pipelines.sprite.deinit(gpu);
        pipelines.sprite_batch.deinit(gpu);
        pipelines.textft.deinit(gpu);
    }
};

pub fn init(win: *graphics.Window, info: SceneInfo) !Scene {
    //const render_pass = if (info.render_pass) |pass| pass else &win.render_pass;
    return .{
        .drawing_array = std.ArrayList(*graphics.Drawing).init(win.ally),
        .window = win,
        //.render_pass = render_pass,
        .flip_z = info.flip_z,
        .default_pipelines = try DefaultPipelines.init(win, info.flip_z),
        .queue = graphics.OpQueue.init(win.ally, &win.gpu),
    };
}

pub fn deinit(scene: *Scene) void {
    for (scene.drawing_array.items) |elem| {
        elem.deinit(scene.window.ally);
        scene.window.ally.destroy(elem);
    }
    scene.drawing_array.deinit();
    scene.default_pipelines.deinit(&scene.window.gpu);
}

pub fn new(scene: *Scene) !*graphics.Drawing {
    const val = try scene.window.ally.create(graphics.Drawing);
    try scene.drawing_array.append(val);

    return val;
}

pub fn delete(scene: *Scene, ally: std.mem.Allocator, drawing: *graphics.Drawing) void {
    const idx_or = std.mem.indexOfScalar(*graphics.Drawing, scene.drawing_array.items, drawing);
    if (idx_or) |idx| _ = scene.drawing_array.orderedRemove(idx);
    drawing.deinit(ally);
    ally.destroy(drawing);
}

pub fn draw(scene: *Scene, builder: *graphics.CommandBuilder) !void {
    const frame_id = builder.frame_id;

    var last_pipeline: u64 = 0;
    var is_first = true;
    for (scene.drawing_array.items) |elem| {
        try elem.draw(builder.getCurrent(), .{
            .frame_id = frame_id,
            .bind_pipeline = is_first or (last_pipeline != @intFromEnum(elem.descriptor.pipeline.vk_pipeline)),
        });
        last_pipeline = @intFromEnum(elem.descriptor.pipeline.vk_pipeline);
        if (is_first) is_first = false;
    }
}

const Scene = @This();

pub const SceneInfo = struct {
    flip_z: bool = false,
    render_pass: ?*graphics.RenderPass = null,
};

const vk = @import("vk.zig");
const img = @import("img");
const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
