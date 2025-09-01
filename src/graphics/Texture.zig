options: Options,

width: u32,
height: u32,

// vulkan
image: vk.Image,
view_table: std.AutoArrayHashMapUnmanaged(ViewDescription, vk.ImageView),

sampler: vk.Sampler,
allocation: vma.VmaAllocation,
format: vk.Format,

pub fn getStage(texture: Texture) vk.PipelineStageFlags {
    return switch (texture.options.preferred_format orelse return .{ .color_attachment_output_bit = true }) {
        .depth => .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
        else => .{ .color_attachment_output_bit = true },
    };
}

pub fn getAttachment(
    texture: *Texture,
    ally: std.mem.Allocator,
    gpu: graphics.Gpu,
    current_layout: vk.ImageLayout,
    clear: graphics.RenderingOptions.ClearValue,
    view: ViewDescription,
) !vk.RenderingAttachmentInfoKHR {
    return .{
        .image_view = try texture.getViewOrCreate(ally, gpu, view, true),
        .image_layout = current_layout,
        .load_op = switch (clear) {
            .none => |_| .load,
            else => .clear,
        },
        .store_op = .store,
        .resolve_mode = .{},
        .resolve_image_layout = .undefined,
        .clear_value = switch (clear) {
            .depth => |depth| .{
                .depth_stencil = .{ .depth = depth, .stencil = 0 },
            },
            .color => |col| .{
                .color = .{ .float_32 = .{
                    col.val[0],
                    col.val[1],
                    col.val[2],
                    col.val[3],
                } },
            },
            .none => |_| undefined,
        },
    };
}

pub fn init(ally: std.mem.Allocator, win: *graphics.Window, width: u32, height: u32, options: Options) !Texture {
    const format = if (options.preferred_format) |f| f else win.preferred_format;
    const vk_format = blk: {
        if (options.type == .multisampling) {
            break :blk win.preferred_format.getSurfaceFormat(win.gpu);
        } else {
            break :blk format.getSurfaceFormat(win.gpu);
        }
    };

    if (options.cubemap) std.debug.assert(options.layer_count == 6);

    const image_options: vk.ImageCreateInfo = .{
        .image_type = .@"2d",
        .extent = .{ .width = width, .height = height, .depth = 1 },
        .mip_levels = options.level_count,
        .array_layers = options.layer_count,
        .format = vk_format,
        .tiling = blk: {
            if (options.type == .render_target or options.type == .multisampling) {
                break :blk .optimal;
            } else {
                break :blk switch (format) {
                    .depth => .optimal,
                    else => .linear,
                };
            }
        },
        .initial_layout = .undefined,
        .usage = blk: {
            switch (options.type) {
                .multisampling => break :blk .{ .transient_attachment_bit = true, .color_attachment_bit = true },
                .render_target => break :blk .{
                    .color_attachment_bit = true,
                    .transfer_src_bit = true,
                    .transfer_dst_bit = true,
                    .sampled_bit = true,
                },
                .storage => break :blk .{ .transfer_dst_bit = true, .sampled_bit = true, .storage_bit = true },
                .regular => break :blk switch (format) {
                    .depth => .{ .depth_stencil_attachment_bit = true, .sampled_bit = true },
                    else => .{
                        .transfer_src_bit = true,
                        .transfer_dst_bit = true,
                        .sampled_bit = true,
                    },
                },
            }
        },
        .samples = if (options.type == .multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
        .sharing_mode = .exclusive,
        .flags = if (options.cubemap) .{ .cube_compatible_bit = true } else .{},
    };

    var allocation: vma.VmaAllocation = undefined;
    var allocation_info: vma.VmaAllocationInfo = undefined;

    const alloc_info: vma.VmaAllocationCreateInfo = .{
        .usage = vma.VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE,
        //.flags = vma.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT | vma.VMA_ALLOCATION_CREATE_MAPPED_BIT,
    };

    var image: vk.Image = undefined;
    if (vma.vmaCreateImage(
        win.gpu.vma_ally,
        @ptrCast(&image_options),
        &alloc_info,
        @ptrCast(&image),
        &allocation,
        &allocation_info,
    ) != 0) return error.BufferAllocationFailed;

    if (format == .depth) {
        try graphics.transitionImageLayout(win.gpu, win.pool, image, .{
            .old_layout = .undefined,
            .new_layout = .depth_stencil_attachment_optimal,
        });
    }
    if (options.type == .storage) {
        try graphics.transitionImageLayout(win.gpu, win.pool, image, .{
            .old_layout = .undefined,
            .new_layout = .general,
        });
    }

    var tex: Texture = .{
        .options = options,
        .image = image,

        .width = width,
        .height = height,

        .sampler = undefined,
        .view_table = .empty,

        .allocation = allocation,
        .format = vk_format,
    };

    _ = try tex.createImageView(ally, win.gpu, tex.getReadDesc(), false);
    try tex.createTextureSampler(win.gpu, false);

    if (builtin.mode == .Debug) {
        //std.debug.dumpCurrentStackTrace(null);
        //std.debug.print("texture {any}\n", .{tex.image});
        try graphics.addDebugMark(win.gpu, .image, @intFromEnum(tex.image), "texture image");
    }

    return tex;
}

pub fn deinit(tex: *Texture, ally: std.mem.Allocator, gpu: graphics.Gpu) void {
    gpu.vkd.destroySampler(gpu.dev, tex.sampler, null);
    for (tex.view_table.values()) |oldest_view| {
        gpu.vkd.destroyImageView(gpu.dev, oldest_view, null);
    }

    tex.view_table.deinit(ally);

    vma.vmaDestroyImage(gpu.vma_ally, @ptrFromInt(@intFromEnum(tex.image)), tex.allocation);
}

pub fn initFromMemory(ally: std.mem.Allocator, win: *graphics.Window, buffer: []const u8, options: Options) !Texture {
    const trace = graphics.tracy.trace(@src());
    defer trace.end();

    var width_c: c_int = undefined;
    var height_c: c_int = undefined;
    var channels: c_int = undefined;

    switch (options.preferred_format orelse .unorm8_rgba) {
        else => {
            const res = stb_image.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &width_c, &height_c, &channels, 4);
            defer stb_image.stbi_image_free(res);

            const width: usize = @intCast(width_c);
            const height: usize = @intCast(height_c);

            var tex = try Texture.init(ally, win, @intCast(width), @intCast(height), options);
            try tex.setFromBuffer(ally, win.gpu, res[0 .. width * height * @sizeOf(Rgba32)], options.flip);
            return tex;
        },
    }
}

pub fn initFromPath(ally: std.mem.Allocator, win: *graphics.Window, path: []const u8, options: Options) !Texture {
    const trace = graphics.tracy.trace(@src());
    defer trace.end();

    var width_c: c_int = undefined;
    var height_c: c_int = undefined;
    var channels: c_int = undefined;

    switch (options.preferred_format orelse .unorm8_rgba) {
        .f32_rgb => {
            const res = stb_image.stbi_loadf(path.ptr, &width_c, &height_c, &channels, 3);
            defer stb_image.stbi_image_free(res);

            const width: usize = @intCast(width_c);
            const height: usize = @intCast(height_c);

            var tex = try Texture.init(ally, win, @intCast(width), @intCast(height), options);
            const res_u8: []const u8 = @as([*]u8, @ptrCast(@alignCast(res)))[0 .. width * height * @sizeOf(FloatRgb)];
            try tex.setFromBuffer(ally, win.gpu, res_u8, options.flip);
            return tex;
        },
        else => {
            const res = stb_image.stbi_load(path.ptr, &width_c, &height_c, &channels, 4);
            defer stb_image.stbi_image_free(res);

            const width: usize = @intCast(width_c);
            const height: usize = @intCast(height_c);

            var tex = try Texture.init(ally, win, @intCast(width), @intCast(height), options);
            try tex.setFromBuffer(ally, win.gpu, res[0 .. width * height * @sizeOf(Rgba32)], options.flip);
            return tex;
        },
    }
}

pub fn getReadDesc(tex: Texture) ViewDescription {
    return .{
        .layer_index = 0,
        .layer_count = tex.options.layer_count,
        .level_index = 0,
        .level_count = tex.options.level_count,
    };
}
// always has it, as it's created in the imageview
pub fn getReadView(tex: Texture) vk.ImageView {
    return tex.view_table.get(tex.getReadDesc()).?;
}

pub fn getViewOrCreate(tex: *Texture, ally: std.mem.Allocator, gpu: graphics.Gpu, desc: ViewDescription, is_attachment: bool) !vk.ImageView {
    return tex.view_table.get(desc) orelse try tex.createImageView(ally, gpu, desc, is_attachment);
}

fn createTextureSampler(tex: *Texture, gpu: graphics.Gpu, reuse: bool) !void {
    const properties = gpu.vki.getPhysicalDeviceProperties(gpu.pdev);

    const sampler_options: vk.SamplerCreateInfo = .{
        .mag_filter = tex.options.mag_filter.getVulkan(),
        .min_filter = tex.options.min_filter.getVulkan(),
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
        .anisotropy_enable = vk.TRUE,
        .max_anisotropy = properties.limits.max_sampler_anisotropy,
        .border_color = .int_opaque_black,
        .unnormalized_coordinates = vk.FALSE,
        .compare_enable = vk.FALSE,
        .compare_op = .always,
        .mipmap_mode = .linear,
        .mip_lod_bias = 0,
        .min_lod = 0,
        .max_lod = 1000.0,
    };

    if (reuse) gpu.vkd.destroySampler(gpu.dev, tex.sampler, null);
    tex.sampler = try gpu.vkd.createSampler(gpu.dev, &sampler_options, null);
    if (builtin.mode == .Debug) {
        try graphics.addDebugMark(gpu, .sampler, @intFromEnum(tex.sampler), "texture sampler");
    }
}

pub const ViewDescription = struct {
    level_count: u32,
    level_index: u32,
    layer_count: u32,
    layer_index: u32,

    pub fn oneLayer(index: u32) ViewDescription {
        return .{
            .level_count = 1,
            .level_index = 0,
            .layer_count = 1,
            .layer_index = index,
        };
    }

    pub fn oneLevel(index: u32) ViewDescription {
        return .{
            .level_count = 1,
            .level_index = index,
            .layer_count = 1,
            .layer_index = 0,
        };
    }

    pub fn oneLayerLevel(layer: u32, level: u32) ViewDescription {
        return .{
            .level_count = 1,
            .level_index = level,
            .layer_count = 1,
            .layer_index = layer,
        };
    }

    pub const ones: ViewDescription = .{
        .level_count = 1,
        .level_index = 0,
        .layer_count = 1,
        .layer_index = 0,
    };
};

fn createImageView(tex: *Texture, ally: std.mem.Allocator, gpu: graphics.Gpu, view_desc: ViewDescription, is_attachment: bool) !vk.ImageView {
    const view_options: vk.ImageViewCreateInfo = .{
        .image = tex.image,
        .view_type = blk: {
            if (is_attachment) break :blk .@"2d";
            if (tex.options.cubemap) {
                break :blk .cube;
            } else {
                break :blk .@"2d";
            }
        },
        .format = tex.format,
        .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        .subresource_range = .{
            .aspect_mask = if (tex.options.preferred_format == .depth) .{ .depth_bit = true } else .{ .color_bit = true },
            .base_mip_level = view_desc.level_index,
            .level_count = view_desc.level_count,
            .base_array_layer = view_desc.layer_index,
            .layer_count = view_desc.layer_count,
        },
    };

    if (tex.view_table.get(view_desc)) |oldest_view| {
        gpu.vkd.destroyImageView(gpu.dev, oldest_view, null);
    }

    const view = try gpu.vkd.createImageView(gpu.dev, &view_options, null);
    try tex.view_table.put(ally, view_desc, view);

    if (builtin.mode == .Debug) {
        try graphics.addDebugMark(gpu, .image_view, @intFromEnum(view), "texture image view");
    }

    return view;
}

// TODO: move to commandbuilder
fn copyBufferToImage(tex: Texture, gpu: graphics.Gpu, buffer: vk.Buffer, cmdbuf: vk.CommandBuffer) !void {
    const region: vk.BufferImageCopy = .{
        .buffer_offset = 0,
        .buffer_row_length = 0,
        .buffer_image_height = 0,
        .image_subresource = .{
            .aspect_mask = .{ .color_bit = true },
            .mip_level = 0,
            .base_array_layer = 0,
            .layer_count = if (tex.options.cubemap) 6 else 1,
        },
        .image_offset = .{ .x = 0, .y = 0, .z = 0 },
        .image_extent = .{ .width = tex.width, .height = tex.height, .depth = 1 },
    };

    gpu.vkd.cmdCopyBufferToImage(cmdbuf, buffer, tex.image, .transfer_dst_optimal, 1, @ptrCast(&region));
}

pub fn setCube(tex: Texture, ally: std.mem.Allocator, paths: [6][]const u8) !void {
    const size = tex.width * tex.height;
    const staging_buff = try tex.window.gpu.createStagingBuffer(size * 4 * 6, .src);
    defer staging_buff.deinit(tex.window.gpu);

    {
        const data = try tex.window.gpu.vkd.mapMemory(tex.window.gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
        defer tex.window.gpu.vkd.unmapMemory(tex.window.gpu.dev, staging_buff.memory);

        for (paths, 0..) |path, i| {
            var read_image = try img.Image.fromFilePath(ally, path);
            defer read_image.deinit();

            switch (read_image.pixels) {
                .rgba32 => |rgba| {
                    var pixel_data: [*]align(4) Rgba32 = @ptrCast(@alignCast(data));
                    for (pixel_data[size * i ..][0..size], rgba) |*p, byte| {
                        p.r = byte.r;
                        p.g = byte.g;
                        p.b = byte.b;
                        p.a = byte.a;
                    }
                },
                else => return error.InvalidImage,
            }
        }
    }

    try graphics.transitionImageLayout(tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .layer_count = 6,
    });
    try tex.copyBufferToImage(staging_buff.buffer);
    try graphics.transitionImageLayout(tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .transfer_dst_optimal,
        .new_layout = tex.getIdealLayout(),
        .layer_count = 6,
    });
}

const Bgra = extern struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
};

pub const FloatRgb = extern struct {
    r: f32,
    g: f32,
    b: f32,
};

pub const FloatRgba = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Rgba32 = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// currently assumes input is in the Texture format
pub fn createImage(tex: Texture, ally: std.mem.Allocator, gpu: graphics.Gpu, input: []const u8, flip: bool) !void {
    const pool = gpu.graphics_pool;
    // thus the staging_buff is just input up to rearranging
    const staging_buff = try graphics.BufferHandle.init(gpu, .{ .size = input.len * @sizeOf(u8), .buffer_type = .src });
    defer staging_buff.deinit(gpu);

    switch (tex.format) {
        .b8g8r8a8_srgb, .b8g8r8a8_unorm => {
            const pix_len = @divExact(input.len, 4);
            const input_slice = @as([*]const Rgba32, @ptrCast(input.ptr))[0..pix_len];
            var slice = try ally.alloc(Bgra, pix_len);
            defer ally.free(slice);

            for (0..tex.width) |i| {
                for (0..tex.height) |j_in| {
                    const j = if (flip) tex.height - j_in - 1 else j_in;
                    const p = &slice[j * tex.width + i];
                    const v = input_slice[j_in * tex.width + i];

                    p.r = v.r;
                    p.g = v.g;
                    p.b = v.b;
                    p.a = v.a;
                }
            }
            try staging_buff.set(Bgra, gpu, slice, 0);
        },
        .r32g32b32_sfloat, .r32_sfloat => {
            try staging_buff.set(u8, gpu, input, 0);
        },
        else => return error.InvalidTextureFormat,
    }

    // so, Scene is like a graph abstraction over builder that can set barriers and everything automatically
    // but we also have the raw builder api that requires these barriers, but of course barrier itself is
    // a thin wrapper over the vulkan api
    //
    // we could simply merge the two of them, it would require a lot of clean up on the scene's side though,
    // but it would be worth it
    var builder = try graphics.CommandBuilder.init(gpu, pool, ally, 1);
    defer builder.deinit(gpu, pool, ally);

    try builder.beginCommand(gpu);

    try builder.transitionLayout(gpu, tex.image, .{
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .layer_count = tex.options.layer_count,
        .level_count = tex.options.level_count,
    });
    try tex.copyBufferToImage(gpu, staging_buff.vk_buffer, builder.getCurrent());
    try builder.transitionLayout(gpu, tex.image, .{
        .old_layout = .transfer_dst_optimal,
        .new_layout = tex.getIdealLayout(),
        .layer_count = tex.options.layer_count,
        .level_count = tex.options.level_count,
    });

    try builder.endCommand(gpu);
    try builder.queueSubmit(gpu, ally, .{ .queue = gpu.graphics_queue });
    try gpu.waitIdle();
}

pub fn getIdealLayout(texture: Texture) vk.ImageLayout {
    if (texture.options.preferred_format == .depth) return .depth_stencil_attachment_optimal;
    return switch (texture.options.type) {
        .storage => .general,
        .render_target => .color_attachment_optimal,
        .regular, .multisampling => .shader_read_only_optimal,
    };
}

// TODO: assert
pub fn setFromRgba(tex: *Texture, ally: std.mem.Allocator, gpu: graphics.Gpu, input: anytype, flip: bool) !void {
    const ptr: [*]const u8 = @ptrCast(@alignCast(input.ptr));
    return tex.setFromBuffer(ally, gpu, ptr[0 .. input.len * 4], flip);
}

pub fn eraseViews(tex: *Texture, gpu: graphics.Gpu) void {
    for (tex.view_table.values()) |oldest_view| {
        gpu.vkd.destroyImageView(gpu.dev, oldest_view, null);
    }
    tex.view_table.clearRetainingCapacity();
}

pub fn setFromBuffer(tex: *Texture, ally: std.mem.Allocator, gpu: graphics.Gpu, input: []const u8, flip: bool) !void {
    tex.eraseViews(gpu);
    try tex.createImage(ally, gpu, input, flip);
    _ = try tex.createImageView(ally, gpu, tex.getReadDesc(), false);
    try tex.createTextureSampler(gpu, true);
}

pub fn generateMipmaps(tex: *Texture, ally: std.mem.Allocator, gpu: graphics.Gpu) !void {
    const pool = gpu.graphics_pool;
    var builder = try graphics.CommandBuilder.init(gpu, pool, ally, 1);
    defer builder.deinit(gpu, pool, ally);

    try builder.beginCommand(gpu);

    var width = tex.width;
    var height = tex.height;

    try builder.transitionLayout(gpu, tex.image, .{
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .layer_count = tex.options.layer_count,
        .layer_index = 0,
        .level_count = tex.options.level_count,
        .level_index = 0,
    });

    for (1..tex.options.level_count) |i| {
        try builder.transitionLayout(gpu, tex.image, .{
            .old_layout = .transfer_dst_optimal,
            .new_layout = .transfer_src_optimal,
            .layer_count = tex.options.layer_count,
            .level_count = 1,
            .level_index = @intCast(i - 1),
        });

        builder.blitImage(gpu, tex.image, tex.image, .{
            .old_layout = .transfer_src_optimal,
            .new_layout = .transfer_dst_optimal,
            .src_region = .{
                .{ 0, 0, 0 },
                .{ @intCast(width), @intCast(height), 1 },
            },
            .dst_region = .{
                .{ 0, 0, 0 },
                .{ @intCast(if (width > 1) width / 2 else 1), @intCast(if (height > 1) height / 2 else 1), 1 },
            },
            .filter = .linear,
            .src_view = .{
                .layer_count = tex.options.layer_count,
                .level_index = @intCast(i - 1),
                .layer_index = 0,
            },
            .dst_view = .{
                .layer_count = tex.options.layer_count,
                .level_index = @intCast(i),
                .layer_index = 0,
            },
        });

        if (width > 1) width /= 2;
        if (height > 1) height /= 2;
    }

    try builder.transitionLayout(gpu, tex.image, .{
        .old_layout = .transfer_dst_optimal,
        .new_layout = tex.getIdealLayout(),
        .layer_count = tex.options.layer_count,
        .level_count = 1,
        .level_index = tex.options.level_count - 1,
    });

    try builder.transitionLayout(gpu, tex.image, .{
        .old_layout = .transfer_src_optimal,
        .new_layout = tex.getIdealLayout(),
        .layer_count = tex.options.layer_count,
        .level_count = tex.options.level_count - 1,
        .level_index = 0,
    });

    try builder.endCommand(gpu);
    try builder.queueSubmit(gpu, ally, .{ .queue = gpu.graphics_queue });
    try gpu.waitIdle();
}

// eventually remove
pub const Image = struct {
    width: u32,
    height: u32,
    data: []Rgba32,
};

pub const FilterEnum = enum {
    nearest,
    linear,

    pub fn getVulkan(filter: FilterEnum) vk.Filter {
        return switch (filter) {
            .nearest => .nearest,
            .linear => .linear,
        };
    }
};

pub const Options = struct {
    const Type = enum {
        flat,
    };

    texture_type: Type = .flat,
    mag_filter: FilterEnum = .nearest,
    min_filter: FilterEnum = .nearest,

    type: enum {
        multisampling,
        render_target,
        storage,
        regular,
    } = .regular,

    cubemap: bool = false,
    layer_count: u32 = 1,
    level_count: u32 = 1,

    compare_less: bool = false,
    preferred_format: ?graphics.PreferredFormat = null,
    flip: bool = false,
};

const Texture = @This();

const vk = @import("vulkan");
pub const img = @import("img");
const stb_image = @import("stb_image");
const std = @import("std");
const math = @import("math");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
const vma = graphics.Gpu.vma;
