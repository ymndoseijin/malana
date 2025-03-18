drawing_array: std.ArrayList(*graphics.Drawing),
window: *graphics.Window,
//render_pass: *RenderPass,
flip_z: bool,
default_pipelines: DefaultPipelines,
queue: graphics.OpQueue,

current_rendering: ?graphics.RenderTarget,
textures: std.AutoHashMap(u64, TextureInfo),
last_pipeline: ?u64,

// gpu allocation handling
buffers: std.ArrayList(graphics.BufferMemory),

const DefaultPipelines = struct {
    color: graphics.RenderPipeline,
    sprite: graphics.RenderPipeline,
    sprite_batch: graphics.RenderPipeline,
    textft: graphics.RenderPipeline,
    line: graphics.RenderPipeline,

    pub fn init(win: *graphics.Window, flip_z: bool) !DefaultPipelines {
        const shaders = win.default_shaders;

        return .{
            .color = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.ColorRect.description,
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
            .line = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.Line.description,
                .shaders = &shaders.line_shaders,
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
        pipelines.line.deinit(gpu);
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

        .textures = std.AutoHashMap(u64, TextureInfo).init(win.ally),
        .current_rendering = null,
        .last_pipeline = null,
        .buffers = std.ArrayList(graphics.BufferMemory).init(win.ally),
    };
}

pub fn deinit(scene: *Scene) void {
    //for (scene.drawing_array.items) |elem| {
    //    elem.deinit(scene.window.ally);
    //    scene.window.ally.destroy(elem);
    //}
    scene.drawing_array.deinit();
    scene.queue.deinit();
    scene.textures.deinit();
    scene.default_pipelines.deinit(&scene.window.gpu);
    scene.clearBuffers();
    scene.buffers.deinit();
}

pub fn clearBuffers(scene: *Scene) void {
    const gpu = scene.window.gpu;
    for (scene.buffers.items) |buff| {
        buff.deinit(gpu);
    }
    scene.buffers.clearRetainingCapacity();
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

const TextureInfo = struct {
    layout: vk.ImageLayout,
    last_dst: vk.AccessFlags,
};

pub fn getTextureInfo(scene: *Scene, tex: *const graphics.Texture) ?TextureInfo {
    return scene.textures.get(@intFromEnum(tex.image));
}

pub fn putTextureInfo(scene: *Scene, tex: graphics.Texture, info: TextureInfo) !void {
    try scene.textures.put(@intFromEnum(tex.image), info);
}

pub fn isCurrentRendering(scene: *Scene, target: graphics.RenderTarget) bool {
    if (scene.current_rendering) |current| {
        return current.eql(target);
    } else {
        return false;
    }
}

pub fn textureBarriers(scene: *Scene, builder: *graphics.CommandBuilder, descriptor: graphics.Descriptor) !void {
    const gpu = &scene.window.gpu;

    for (descriptor.dependencies.textures.values()) |*tex_dep| {
        const tex_or = scene.getTextureInfo(tex_dep);

        const layout = if (tex_or) |t| t.layout else tex_dep.getIdealLayout();

        const target_layout: vk.ImageLayout = switch (tex_dep.info.type) {
            .multisampling, .render_target, .regular => .shader_read_only_optimal,
            .storage => .general,
        };
        const dst_access: vk.AccessFlags = switch (target_layout) {
            .shader_read_only_optimal => .{ .shader_read_bit = true },
            else => .{},
        };

        if (tex_or != null and layout == target_layout) continue;
        builder.pipelineBarrier(gpu, .{
            .src_stage = tex_dep.getStage(),
            .dst_stage = switch (target_layout) {
                .shader_read_only_optimal => .{ .fragment_shader_bit = true },
                .general => .{ .compute_shader_bit = true },
                else => .{},
            },
            .image_barriers = &.{
                .{
                    .image = tex_dep.image,
                    .src_access = if (tex_or) |t| t.last_dst else .{},
                    .dst_access = dst_access,
                    .old_layout = layout,
                    .new_layout = target_layout,
                },
            },
        });
        try scene.putTextureInfo(tex_dep.*, .{ .layout = target_layout, .last_dst = dst_access });
    }
}

pub fn renderingBarriers(scene: *Scene, builder: *graphics.CommandBuilder, target: graphics.RenderTarget.TextureTarget, flip_z: bool) !graphics.RenderRegion {
    var render_region: ?graphics.RenderRegion = null;
    const gpu = &scene.window.gpu;

    for (target.color_textures) |color_tex| {
        const target_info = scene.getTextureInfo(color_tex);
        if (target_info != null and target_info.?.layout == .color_attachment_optimal) continue;

        if (render_region == null) {
            try builder.setViewport(gpu, .{
                .flip_z = flip_z,
                .width = color_tex.width,
                .height = color_tex.height,
            });
            render_region = .{
                .width = color_tex.width,
                .height = color_tex.height,
                .x = 0,
                .y = 0,
            };
        } else {
            if (render_region.?.width != color_tex.width or
                render_region.?.height != color_tex.height)
            {
                return error.NonMatchingDrawing;
            }
        }

        builder.pipelineBarrier(gpu, .{
            .src_stage = .{ .color_attachment_output_bit = true },
            .dst_stage = .{ .color_attachment_output_bit = true },
            .image_barriers = &.{
                .{
                    .image = color_tex.image,
                    .src_access = .{},
                    .dst_access = .{ .color_attachment_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .color_attachment_optimal,
                },
            },
        });

        try scene.putTextureInfo(color_tex.*, .{ .layout = .color_attachment_optimal, .last_dst = .{
            .color_attachment_write_bit = true,
        } });
    }

    if (target.depth_texture) |depth_tex| {
        const target_info = scene.getTextureInfo(depth_tex);
        if (target_info == null or target_info.?.layout != .depth_stencil_attachment_optimal) {
            if (render_region == null) {
                try builder.setViewport(gpu, .{
                    .flip_z = flip_z,
                    .width = depth_tex.width,
                    .height = depth_tex.height,
                });
                render_region = .{
                    .width = depth_tex.width,
                    .height = depth_tex.height,
                    .x = 0,
                    .y = 0,
                };
            } else {
                if (render_region.?.width != depth_tex.width or
                    render_region.?.height != depth_tex.height)
                {
                    return error.NonMatchingDrawing;
                }
            }

            builder.pipelineBarrier(gpu, .{
                .src_stage = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
                .dst_stage = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
                .image_barriers = &.{
                    .{
                        .image = depth_tex.image,
                        .src_access = .{},
                        .dst_access = .{ .depth_stencil_attachment_write_bit = true },
                        .old_layout = .undefined,
                        .new_layout = .depth_stencil_attachment_optimal,
                    },
                },
            });

            try scene.putTextureInfo(depth_tex.*, .{ .layout = .depth_stencil_attachment_optimal, .last_dst = .{
                .depth_stencil_attachment_write_bit = true,
            } });
        }
    }

    return render_region orelse return error.NoRenderRegion;
}

pub fn begin(scene: *Scene) !void {
    try scene.queue.execute();
    scene.clearBuffers();
}
pub fn end(scene: *Scene, builder: *graphics.CommandBuilder) void {
    const gpu = &scene.window.gpu;

    if (scene.current_rendering != null) builder.endRendering(gpu);
    scene.current_rendering = null;
}

pub fn dispatch(scene: *Scene, builder: *graphics.CommandBuilder, elem: *graphics.Compute) !void {
    try scene.textureBarriers(builder, elem.descriptor);
    try elem.dispatch(builder.getCurrent(), .{ .bind_pipeline = true, .frame_id = 0 });
}

pub fn draw(scene: *Scene, builder: *graphics.CommandBuilder, elem: *graphics.Drawing, image_index: graphics.Swapchain.ImageIndex) !void {
    var swapchain = scene.window.swapchain;
    const gpu = &scene.window.gpu;

    if (!scene.isCurrentRendering(elem.render_target)) {
        // end rendering if drawing render target isn't the current one
        if (scene.current_rendering != null) builder.endRendering(gpu);

        // set dependencies barriers to the shader read only optimal layout
        try scene.textureBarriers(builder, elem.descriptor);

        switch (elem.render_target) {
            .texture => |target| {
                const render_region = try scene.renderingBarriers(
                    builder,
                    target,
                    switch (elem.flip_z) {
                        .auto => scene.flip_z,
                        .true => true,
                        .false => false,
                    },
                );
                var color_buf: [256]vk.RenderingAttachmentInfo = undefined;

                for (target.color_textures, color_buf[0..target.color_textures.len]) |tex, *ptr| {
                    ptr.* = tex.getAttachment(.color_attachment_optimal);
                }
                builder.beginRendering(gpu, .{
                    .region = render_region,
                    .color_attachments = color_buf[0..target.color_textures.len],
                    .depth_attachment = if (target.depth_texture) |tex| tex.getAttachment(.depth_stencil_attachment_optimal) else null,
                });
            },
            .swapchain => |_| {
                const extent = swapchain.extent;
                var render_region: ?graphics.RenderRegion = null;

                try builder.setViewport(gpu, .{
                    .flip_z = switch (elem.flip_z) {
                        .auto => scene.flip_z,
                        .true => true,
                        .false => false,
                    },
                    .width = extent.width,
                    .height = extent.height,
                });
                render_region = .{
                    .width = extent.width,
                    .height = extent.height,
                    .x = 0,
                    .y = 0,
                };

                //std.debug.print("swapchain is {any}\n", .{swapchain.getImage(image_index)});
                builder.pipelineBarrier(gpu, .{
                    .src_stage = .{ .color_attachment_output_bit = true },
                    .dst_stage = .{ .color_attachment_output_bit = true },
                    .image_barriers = &.{
                        .{
                            .image = swapchain.getImage(image_index),
                            .src_access = .{},
                            .dst_access = .{ .color_attachment_write_bit = true },
                            .old_layout = .undefined,
                            .new_layout = .color_attachment_optimal,
                        },
                    },
                });

                builder.beginRendering(gpu, .{
                    .region = render_region.?,
                    .color_attachments = &.{swapchain.getAttachment(image_index)},
                });
            },
        }
        scene.current_rendering = elem.render_target;
    }

    try elem.draw(gpu, builder.getCurrent(), .{
        .swapchain = swapchain,
        .frame_id = builder.frame_id,
        .bind_pipeline = if (scene.last_pipeline) |pipeline| pipeline != @intFromEnum(elem.descriptor.pipeline.vk_pipeline) else true,
    });
    scene.last_pipeline = @intFromEnum(elem.descriptor.pipeline.vk_pipeline);
}

// should be allocator-esque implementation, eventually decouple this from Scene
// creates a buffer that will be freed after the frame is sent
pub fn createBuffer(scene: *Scene, size: usize) !graphics.BufferMemory {
    const gpu = &scene.window.gpu;
    const buff = try gpu.createStagingBuffer(size);
    try scene.buffers.append(buff);

    return buff;
}

// this is the amd threshold
// const allocationStep = 262144;

pub fn bindVertex(
    scene: *Scene,
    builder: graphics.CommandBuilder,
    comptime description: graphics.VertexDescription,
    drawing: *graphics.Drawing,
    vertices: []const description.getAttributeType(),
    indices: []const u32,
) !void {
    const trace = graphics.tracy.trace(@src());
    defer trace.end();

    drawing.vert_count = indices.len;
    const gpu = &scene.window.gpu;

    if (indices.len == 0) return;

    //try drawing.destroyVertex();

    const vertex_buff = try scene.createBuffer(description.getVertexSize() * vertices.len);

    drawing.vertex_buffer = try description.createBuffer(gpu, vertices.len);
    try drawing.vertex_buffer.?.setVertex(description, gpu, gpu.graphics_pool, vertices, vertex_buff, .{ .queue = builder });

    const index_buff = try scene.createBuffer(@sizeOf(u32) * indices.len);

    drawing.index_buffer = try graphics.BufferHandle.init(gpu, .{ .size = @sizeOf(u32) * indices.len, .buffer_type = .index });
    try drawing.index_buffer.?.setIndices(gpu, gpu.graphics_pool, indices, index_buff, .{ .queue = builder });
}

const Scene = @This();

pub const SceneInfo = struct {
    flip_z: bool = false,
    render_pass: ?*graphics.RenderPass = null,
};

const vk = @import("vulkan");
const img = @import("img");
const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
