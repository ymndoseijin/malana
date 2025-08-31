window: *graphics.Window,
//render_pass: *RenderPass,
flip_z: bool,
default_pipelines: DefaultPipelines,
queue: graphics.OpQueue,

current_rendering: ?struct {
    target: graphics.RenderTarget,
    options: ?graphics.RenderingOptions,
    pipeline: graphics.RenderPipeline,
},
textures: std.AutoHashMap(u64, TextureOptions),
last_pipeline: ?graphics.Pipeline,

// gpu allocation handling
buffers: std.ArrayList(graphics.BufferMemory),

command_batch: std.ArrayListUnmanaged(union(enum) {
    draw: struct {
        draw: *graphics.Drawing,
    },
    push: struct {
        constant: *const anyopaque,
        size: u32,
    },
}) = .empty,

frame_arena: std.heap.ArenaAllocator,

// TODO: I don't think it's the scene's job to provide these pipelines, move it to State and then add functions like State.initTextft or something?
const DefaultPipelines = struct {
    color: graphics.RenderPipeline,
    sprite: graphics.RenderPipeline,
    sprite_batch: graphics.RenderPipeline,
    textft: graphics.RenderPipeline,
    //line: graphics.RenderPipeline,

    const default_rendering: graphics.AttachmentOptions = .{
        .descriptions = &.{.{ .format = .swapchain }},
        .depth = .{ .format = .depth },
    };

    pub fn init(win: *graphics.Window, flip_z: bool) !DefaultPipelines {
        const shaders = win.default_shaders;

        return .{
            .color = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.ColorRect.description,
                .shaders = &shaders.color_shaders,
                .gpu = win.gpu,
                .flipped_z = flip_z,
                .rendering = default_rendering,
            }),
            .sprite = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.Sprite.description,
                .shaders = &shaders.sprite_shaders,
                .gpu = win.gpu,
                .flipped_z = flip_z,
                .rendering = default_rendering,
            }),
            .sprite_batch = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.SpriteBatch.description,
                .shaders = &shaders.sprite_batch_shaders,
                .gpu = win.gpu,
                .flipped_z = flip_z,
                .rendering = default_rendering,
            }),
            .textft = try graphics.RenderPipeline.init(win.ally, .{
                .description = graphics.TextFt.description,
                .shaders = &shaders.textft_shaders,
                .gpu = win.gpu,
                .flipped_z = flip_z,
                .rendering = default_rendering,
            }),
            //.line = try graphics.RenderPipeline.init(win.ally, .{
            //    .description = graphics.Line.description,
            //    .shaders = &shaders.line_shaders,
            //    .gpu = win.gpu,
            //    .flipped_z = flip_z,
            //    .rendering = default_rendering,
            //}),
        };
    }

    pub fn deinit(pipelines: *DefaultPipelines, ally: std.mem.Allocator, gpu: graphics.Gpu) void {
        pipelines.color.deinit(ally, gpu);
        pipelines.sprite.deinit(ally, gpu);
        pipelines.sprite_batch.deinit(ally, gpu);
        pipelines.textft.deinit(ally, gpu);
        //pipelines.line.deinit(gpu);
    }
};

pub fn init(win: *graphics.Window, options: SceneOptions) !Scene {
    //const render_pass = if (options.render_pass) |pass| pass else &win.render_pass;
    return .{
        .window = win,
        //.render_pass = render_pass,
        .flip_z = options.flip_z,
        .default_pipelines = try DefaultPipelines.init(win, options.flip_z),
        .queue = graphics.OpQueue.init(win.ally, win.gpu),

        .textures = std.AutoHashMap(u64, TextureOptions).init(win.ally),
        .current_rendering = null,
        .last_pipeline = null,
        .buffers = .empty,
        .frame_arena = .init(win.ally),
    };
}

pub fn deinit(scene: *Scene) void {
    scene.queue.deinit();
    scene.textures.deinit();
    scene.default_pipelines.deinit(scene.window.ally, scene.window.gpu);
    scene.clearBuffers();
    scene.buffers.deinit(scene.window.ally);
    scene.frame_arena.deinit();
}

pub fn clearBuffers(scene: *Scene) void {
    const gpu = scene.window.gpu;
    for (scene.buffers.items) |buff| {
        buff.deinit(gpu);
    }
    scene.buffers.clearRetainingCapacity();
}

const TextureOptions = struct {
    layout: vk.ImageLayout,
    last_dst: vk.AccessFlags,
};

pub fn getTextureOptions(scene: *Scene, tex: *const graphics.Texture) ?TextureOptions {
    return scene.textures.get(@intFromEnum(tex.image));
}

pub fn putTextureOptions(scene: *Scene, tex: graphics.Texture, options: TextureOptions) !void {
    try scene.textures.put(@intFromEnum(tex.image), options);
}

pub fn isCurrentRendering(scene: *Scene, target: graphics.RenderTarget, options: ?graphics.RenderingOptions) bool {
    if (scene.current_rendering) |current| {
        if (!current.target.eql(target)) return false;

        return std.meta.eql(options, current.options);
    } else {
        return false;
    }
}

pub fn textureBarriers(scene: *Scene, builder: *graphics.CommandBuilder, descriptor: graphics.Descriptor) !void {
    const gpu = scene.window.gpu;

    for (descriptor.dependencies.textures.values()) |*tex_dep| {
        const tex_or = scene.getTextureOptions(tex_dep);

        const layout = if (tex_or) |t| t.layout else tex_dep.getIdealLayout();

        const target_layout: vk.ImageLayout = switch (tex_dep.options.type) {
            .multisampling, .render_target, .regular => .shader_read_only_optimal,
            .storage => .general,
        };

        if (layout == target_layout) continue;

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
                    .layer_count = tex_dep.options.layer_count,
                    .level_count = tex_dep.options.level_count,
                    .src_access = if (tex_or) |t| t.last_dst else .{},
                    .dst_access = dst_access,
                    .old_layout = layout,
                    .new_layout = target_layout,
                },
            },
        });
        try scene.putTextureOptions(tex_dep.*, .{ .layout = target_layout, .last_dst = dst_access });
    }
}

pub fn renderingBarriers(scene: *Scene, builder: *graphics.CommandBuilder, target: graphics.RenderTarget.TextureTarget, flip_z: bool) !graphics.RenderRegion {
    var render_region: ?graphics.RenderRegion = null;
    const gpu = scene.window.gpu;

    for (target.color_textures) |color_tex| {
        const target_options = scene.getTextureOptions(color_tex);

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

        // don't do a pipelineBarrier if it's already in the expected layout
        if (target_options != null and target_options.?.layout == .color_attachment_optimal) continue;
        builder.pipelineBarrier(gpu, .{
            .src_stage = .{ .color_attachment_output_bit = true },
            .dst_stage = .{ .color_attachment_output_bit = true },
            .image_barriers = &.{
                .{
                    .image = color_tex.image,
                    .layer_count = color_tex.options.layer_count,
                    .level_count = color_tex.options.level_count,
                    .src_access = .{},
                    .dst_access = .{ .color_attachment_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .color_attachment_optimal,
                },
            },
        });

        try scene.putTextureOptions(color_tex.*, .{ .layout = .color_attachment_optimal, .last_dst = .{
            .color_attachment_write_bit = true,
        } });
    }

    if (target.depth_texture) |depth_tex| {
        const target_options = scene.getTextureOptions(depth_tex);
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

        if (target_options == null or target_options.?.layout != .depth_stencil_attachment_optimal) {
            builder.pipelineBarrier(gpu, .{
                .src_stage = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
                .dst_stage = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
                .image_barriers = &.{
                    .{
                        .image = depth_tex.image,
                        .layer_count = 1,
                        .level_count = 1,
                        .src_access = .{},
                        .dst_access = .{ .depth_stencil_attachment_write_bit = true },
                        .old_layout = .undefined,
                        .new_layout = .depth_stencil_attachment_optimal,
                    },
                },
            });

            try scene.putTextureOptions(depth_tex.*, .{ .layout = .depth_stencil_attachment_optimal, .last_dst = .{
                .depth_stencil_attachment_write_bit = true,
            } });
        }
    }

    if (render_region == null) {
        // TODO: neat error messages
        std.debug.print("Render region could not be set! (are you drawing in the correct order?)\n", .{});
        @breakpoint();
    }

    return render_region orelse return error.NoRenderRegion;
}

pub fn begin(scene: *Scene) !void {
    try scene.queue.execute();
    scene.clearBuffers();
}
pub fn end(scene: *Scene, builder: *graphics.CommandBuilder, image_index: graphics.Swapchain.ImageIndex) !void {
    const gpu = scene.window.gpu;

    if (scene.current_rendering != null) {
        try scene.flushBatch(builder, image_index, null);
        builder.endRendering(gpu);
    }
    scene.current_rendering = null;
    _ = scene.frame_arena.reset(.retain_capacity);
    scene.command_batch = .empty;
}

pub fn dispatch(scene: *Scene, builder: *graphics.CommandBuilder, elem: *graphics.Compute) !void {
    try scene.textureBarriers(builder, elem.descriptor);
    try elem.dispatch(builder.getCurrent(), .{ .bind_pipeline = true, .frame_id = 0 });
}

pub fn flushBatch(
    scene: *Scene,
    builder: *graphics.CommandBuilder,
    image_index: graphics.Swapchain.ImageIndex,
    flush_from_pipeline: ?graphics.Pipeline,
) !void {
    var swapchain = scene.window.swapchain;
    const gpu = scene.window.gpu;
    const ally = scene.window.ally;

    // set dependencies barriers to the shader read only optimal layout
    for (scene.command_batch.items) |elem| {
        switch (elem) {
            .draw => |draw_cmd| try scene.textureBarriers(builder, draw_cmd.draw.descriptor),
            else => {},
        }
    }

    const current_rendering = scene.current_rendering.?;

    const temp_flip_z = blk: {
        for (scene.command_batch.items) |elem| {
            switch (elem) {
                .draw => |draw_cmd| break :blk switch (draw_cmd.draw.flip_z) {
                    .auto => scene.flip_z,
                    .true => true,
                    .false => false,
                },
                else => {},
            }
        }
        return error.NoFlipZ;
    };
    const rendering_options = current_rendering.options;

    switch (current_rendering.target) {
        .texture => |target| {
            const render_region = try scene.renderingBarriers(
                builder,
                target,
                temp_flip_z,
            );
            var color_buf: [256]vk.RenderingAttachmentInfo = undefined;

            if (rendering_options) |options| {
                std.debug.assert(options.descriptions.len == target.color_textures.len);
                for (target.color_textures, color_buf[0..target.color_textures.len], options.descriptions) |tex, *ptr, attachment| {
                    ptr.* = try tex.getAttachment(ally, gpu, .color_attachment_optimal, attachment.clear, attachment.view);
                    //std.debug.print("attachment is {any} with {any}\n", .{ptr.*, attachments});
                }
            } else {
                for (target.color_textures, color_buf[0..target.color_textures.len]) |tex, *ptr| {
                    ptr.* = try tex.getAttachment(ally, gpu, .color_attachment_optimal, .black, .ones);
                    //std.debug.print("lone attachment is {any}\n", .{ptr.*});
                }
            }

            builder.beginRendering(gpu, .{
                .region = render_region,
                .color_attachments = color_buf[0..target.color_textures.len],
                .depth_attachment = if (target.depth_texture) |tex| try tex.getAttachment(
                    ally,
                    gpu,
                    .depth_stencil_attachment_optimal,
                    blk: {
                        if (rendering_options) |options| {
                            if (options.depth) |depth| {
                                break :blk depth.clear;
                            } else {
                                break :blk .never;
                            }
                        }

                        break :blk .far;
                    },
                    blk: {
                        if (rendering_options) |options| {
                            if (options.depth) |depth| {
                                break :blk depth.view;
                            }
                        }
                        break :blk .ones;
                    },
                ) else null,
            });
        },
        .swapchain => |_| {
            if (rendering_options) |options| std.debug.assert(options.descriptions.len == 1);
            const extent = swapchain.extent;
            var render_region: ?graphics.RenderRegion = null;

            try builder.setViewport(gpu, .{
                .flip_z = temp_flip_z,
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
                        .layer_count = 1,
                        .level_count = 1,
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

    for (scene.command_batch.items, 0..) |elem, i| {
        switch (elem) {
            .draw => |draw_cmd| {
                try draw_cmd.draw.draw(gpu, builder.getCurrent(), .{
                    .swapchain = swapchain,
                    .frame_id = builder.frame_id,
                    .bind_pipeline = blk: {
                        if (scene.last_pipeline) |pipeline| {
                            scene.last_pipeline = draw_cmd.draw.descriptor.pipeline;
                            break :blk pipeline.vk_pipeline != draw_cmd.draw.descriptor.pipeline.vk_pipeline;
                        } else {
                            scene.last_pipeline = draw_cmd.draw.descriptor.pipeline;
                            break :blk true;
                        }
                    },
                });
            },
            .push => |push_cmd| {
                const cmdbuf = builder.getCurrent();
                const pipeline = blk: {
                    for (scene.command_batch.items[i + 1 ..]) |cmd| {
                        switch (cmd) {
                            .draw => |draw_cmd| {
                                break :blk draw_cmd.draw.descriptor.pipeline;
                            },
                            else => {},
                        }
                    } else {
                        if (i != scene.command_batch.items.len - 1 or flush_from_pipeline == null) return error.NoPipelineForPush;
                        break :blk flush_from_pipeline.?;
                    }
                };
                gpu.vkd.cmdPushConstants(
                    cmdbuf,
                    pipeline.layout,
                    switch (pipeline.type) {
                        .compute => .{ .compute_bit = true },
                        .render => .{ .vertex_bit = true, .fragment_bit = true },
                    },
                    0,
                    push_cmd.size,
                    @ptrCast(@alignCast(push_cmd.constant)),
                );
            },
        }
    }
    scene.command_batch.clearRetainingCapacity();
}

pub fn draw(
    scene: *Scene,
    builder: *graphics.CommandBuilder,
    elem: *graphics.Drawing,
    options: struct {
        rendering_options: ?graphics.RenderingOptions = null,
        image_index: graphics.Swapchain.ImageIndex,
    },
) !void {
    const gpu = scene.window.gpu;
    const ally = scene.frame_arena.allocator();

    if (!scene.isCurrentRendering(elem.render_target, options.rendering_options)) {
        // end rendering if drawing render target isn't the current one
        if (scene.current_rendering != null) {
            try scene.flushBatch(builder, options.image_index, elem.descriptor.pipeline);
            builder.endRendering(gpu);
        }

        scene.current_rendering = .{
            .target = elem.render_target,
            .pipeline = elem.pipeline,
            .options = if (options.rendering_options) |rendering| .{
                .descriptions = try ally.dupe(graphics.RenderingOptions.Description, rendering.descriptions),
                .depth = rendering.depth,
            } else null,
        };
    }

    //const debug_line = try graphics.getLineString(scene.window.ally, "idk");
    try scene.command_batch.append(ally, .{ .draw = .{ .draw = elem } });
}

pub fn push(scene: *Scene, comptime self: graphics.DataDescription, constants: *const self.T) !void {
    const ally = scene.frame_arena.allocator();
    const ptr = try ally.create(self.T);
    ptr.* = constants.*;
    try scene.command_batch.append(ally, .{ .push = .{
        .size = @intCast(self.getSize()),
        .constant = @ptrCast(@alignCast(ptr)),
    } });
}

// should be allocator-esque implementation, eventually decouple this from Scene
// creates a buffer that will be freed after the frame is sent
pub fn createBuffer(scene: *Scene, size: usize) !graphics.BufferMemory {
    const gpu = scene.window.gpu;
    const buff = try gpu.createStagingBuffer(size);
    try scene.buffers.append(scene.window.ally, buff);

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
    const gpu = scene.window.gpu;

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

pub const SceneOptions = struct {
    flip_z: bool = false,
    render_pass: ?*graphics.RenderPass = null,
};

const vk = @import("vulkan");
const img = @import("img");
const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
