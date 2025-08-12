info: TextureInfo,

width: u32,
height: u32,

// vulkan
image: vk.Image,
image_view: vk.ImageView,

window: *graphics.Window,
sampler: vk.Sampler,
memory: vk.DeviceMemory,
format: vk.Format,

pub fn getStage(texture: Texture) vk.PipelineStageFlags {
    return switch (texture.info.preferred_format orelse return .{ .color_attachment_output_bit = true }) {
        .depth => .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
        else => .{ .color_attachment_output_bit = true },
    };
}

pub fn getAttachment(texture: Texture, current_layout: vk.ImageLayout) vk.RenderingAttachmentInfoKHR {
    const clear_color = vk.ClearValue{
        .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
    };
    const clear_depth = vk.ClearValue{
        .depth_stencil = .{ .depth = 1, .stencil = 0 },
    };

    return .{
        .image_view = texture.image_view,
        .image_layout = current_layout,
        .load_op = .clear,
        .store_op = .store,
        .resolve_mode = .{},
        .resolve_image_layout = .undefined,
        .clear_value = switch (texture.info.preferred_format orelse .unorm) {
            .depth => clear_depth,
            else => clear_color,
        },
    };
}

pub fn init(win: *graphics.Window, width: u32, height: u32, info: TextureInfo) !Texture {
    const format = if (info.preferred_format) |f| f else win.preferred_format;
    const vk_format = blk: {
        if (info.type == .multisampling) {
            break :blk win.preferred_format.getSurfaceFormat(win.gpu);
        } else {
            break :blk format.getSurfaceFormat(win.gpu);
        }
    };

    const image_info: vk.ImageCreateInfo = .{
        .image_type = .@"2d",
        .extent = .{ .width = width, .height = height, .depth = 1 },
        .mip_levels = 1,
        .array_layers = if (info.cubemap) 6 else 1,
        .format = vk_format,
        .tiling = blk: {
            if (info.type == .render_target or info.type == .multisampling) {
                break :blk .optimal;
            } else {
                break :blk switch (format) {
                    .depth => .optimal,
                    .unorm, .srgb, .float => .linear,
                };
            }
        },
        .initial_layout = .undefined,
        .usage = blk: {
            switch (info.type) {
                .multisampling => break :blk .{ .transient_attachment_bit = true, .color_attachment_bit = true },
                .render_target => break :blk .{ .color_attachment_bit = true, .sampled_bit = true },
                .storage => break :blk .{ .transfer_dst_bit = true, .sampled_bit = true, .storage_bit = true },
                .regular => break :blk switch (format) {
                    .depth => .{ .depth_stencil_attachment_bit = true, .sampled_bit = true },
                    .unorm, .srgb, .float => .{ .transfer_dst_bit = true, .sampled_bit = true },
                },
            }
        },
        .samples = if (info.type == .multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
        .sharing_mode = .exclusive,
        .flags = if (info.cubemap) .{ .cube_compatible_bit = true } else .{},
    };

    const image = try win.gpu.vkd.createImage(win.gpu.dev, &image_info, null);
    const mem_reqs = win.gpu.vkd.getImageMemoryRequirements(win.gpu.dev, image);
    const image_memory = try win.gpu.allocate(mem_reqs, .{ .device_local_bit = true });
    try win.gpu.vkd.bindImageMemory(win.gpu.dev, image, image_memory, 0);

    if (format == .depth) {
        try graphics.transitionImageLayout(&win.gpu, win.pool, image, .{
            .old_layout = .undefined,
            .new_layout = .depth_stencil_attachment_optimal,
        });
    }
    if (info.type == .storage) {
        try graphics.transitionImageLayout(&win.gpu, win.pool, image, .{
            .old_layout = .undefined,
            .new_layout = .general,
        });
    }

    const view_info: vk.ImageViewCreateInfo = .{
        .image = image,
        .view_type = if (info.cubemap) .cube else .@"2d",
        .format = vk_format,
        .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        .subresource_range = .{
            .aspect_mask = if (format == .depth) .{ .depth_bit = true } else .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = if (info.cubemap) 6 else 1,
        },
    };

    const properties = win.gpu.vki.getPhysicalDeviceProperties(win.gpu.pdev);

    const sampler_info: vk.SamplerCreateInfo = .{
        .mag_filter = info.mag_filter.getVulkan(),
        .min_filter = info.min_filter.getVulkan(),
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
        .anisotropy_enable = vk.TRUE,
        .max_anisotropy = properties.limits.max_sampler_anisotropy,
        .border_color = .int_opaque_black,
        .unnormalized_coordinates = vk.FALSE,
        .compare_enable = if (info.compare_less) vk.TRUE else vk.FALSE,
        .compare_op = if (info.compare_less) .less else .always,
        .mipmap_mode = .linear,
        .mip_lod_bias = 0,
        .min_lod = 0,
        .max_lod = 0,
    };

    const tex: Texture = .{
        .info = info,
        .image = image,
        .window = win,

        .width = width,
        .height = height,

        .sampler = try win.gpu.vkd.createSampler(win.gpu.dev, &sampler_info, null),
        .image_view = try win.gpu.vkd.createImageView(win.gpu.dev, &view_info, null),
        .memory = image_memory,
        .format = vk_format,
    };

    if (builtin.mode == .Debug) {
        //std.debug.dumpCurrentStackTrace(null);
        //std.debug.print("texture {any}\n", .{tex.image});
        try graphics.addDebugMark(win.gpu, .image, @intFromEnum(tex.image), "texture image");
        try graphics.addDebugMark(win.gpu, .image_view, @intFromEnum(tex.image_view), "texture image view");
    }

    return tex;
}

pub fn deinit(self: Texture) void {
    const win = self.window;
    win.gpu.vkd.destroySampler(win.gpu.dev, self.sampler, null);
    win.gpu.vkd.destroyImageView(win.gpu.dev, self.image_view, null);
    win.gpu.vkd.destroyImage(win.gpu.dev, self.image, null);
    win.gpu.vkd.freeMemory(win.gpu.dev, self.memory, null);
}

pub fn initFromMemory(ally: std.mem.Allocator, win: *graphics.Window, buffer: []const u8, info: TextureInfo) !Texture {
    var read_image = try img.Image.fromMemory(ally, buffer);
    defer read_image.deinit();

    switch (read_image.pixels) {
        inline .rgba32, .rgba64, .rgb24 => |data| {
            var tex = try Texture.init(win, @intCast(read_image.width), @intCast(read_image.height), info);
            try tex.setFromRgba(.{
                .width = read_image.width,
                .height = read_image.height,
                .data = data,
            });
            return tex;
        },
        else => return error.InvalidImage,
    }
}

pub fn initFromPath(ally: std.mem.Allocator, win: *graphics.Window, path: []const u8, info: TextureInfo) !Texture {
    var read_image = try img.Image.fromFilePath(ally, path);
    defer read_image.deinit();

    switch (read_image.pixels) {
        inline .rgba32, .rgba64, .rgb24 => |data| {
            var tex = try Texture.init(win, @intCast(read_image.width), @intCast(read_image.height), info);
            try tex.setFromRgba(.{
                .width = read_image.width,
                .height = read_image.height,
                .data = data,
            }, info.flip);
            return tex;
        },
        else => return error.InvalidImage,
    }
}

fn createTextureSampler(tex: *Texture) !void {
    const gpu = &tex.window.gpu;
    const properties = gpu.vki.getPhysicalDeviceProperties(gpu.pdev);

    const sampler_info: vk.SamplerCreateInfo = .{
        .mag_filter = tex.info.mag_filter.getVulkan(),
        .min_filter = tex.info.min_filter.getVulkan(),
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
        .max_lod = 0,
    };

    const win = tex.window;
    win.gpu.vkd.destroySampler(win.gpu.dev, tex.sampler, null);
    tex.sampler = try gpu.vkd.createSampler(gpu.dev, &sampler_info, null);
    if (builtin.mode == .Debug) {
        try graphics.addDebugMark(win.gpu, .sampler, @intFromEnum(tex.sampler), "texture sampler");
    }
}

fn createImageView(tex: *Texture) !void {
    const gpu = &tex.window.gpu;

    const view_info: vk.ImageViewCreateInfo = .{
        .image = tex.image,
        .view_type = if (tex.info.cubemap) .cube else .@"2d",
        .format = tex.format,
        .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        .subresource_range = .{
            .aspect_mask = .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
    };

    const win = tex.window;
    win.gpu.vkd.destroyImageView(win.gpu.dev, tex.image_view, null);
    tex.image_view = try gpu.vkd.createImageView(gpu.dev, &view_info, null);
    if (builtin.mode == .Debug) {
        try graphics.addDebugMark(win.gpu, .image_view, @intFromEnum(tex.image_view), "texture image view");
    }
}

fn copyBufferToImage(tex: Texture, buffer: vk.Buffer) !void {
    const cmdbuf = try graphics.createSingleCommandBuffer(&tex.window.gpu, tex.window.pool);
    defer graphics.freeSingleCommandBuffer(cmdbuf, &tex.window.gpu, tex.window.pool);

    const region: vk.BufferImageCopy = .{
        .buffer_offset = 0,
        .buffer_row_length = 0,
        .buffer_image_height = 0,
        .image_subresource = .{
            .aspect_mask = .{ .color_bit = true },
            .mip_level = 0,
            .base_array_layer = 0,
            .layer_count = if (tex.info.cubemap) 6 else 1,
        },
        .image_offset = .{ .x = 0, .y = 0, .z = 0 },
        .image_extent = .{ .width = tex.width, .height = tex.height, .depth = 1 },
    };

    tex.window.gpu.vkd.cmdCopyBufferToImage(cmdbuf, buffer, tex.image, .transfer_dst_optimal, 1, @ptrCast(&region));

    try graphics.finishSingleCommandBuffer(cmdbuf, &tex.window.gpu);
}

pub fn setCube(tex: Texture, ally: std.mem.Allocator, paths: [6][]const u8) !void {
    const size = tex.width * tex.height;
    const staging_buff = try tex.window.gpu.createStagingBuffer(size * 4 * 6, .src);
    defer staging_buff.deinit(tex.window.gpu);

    const Rgba = struct {
        b: u8,
        g: u8,
        r: u8,
        a: u8,
    };

    {
        const data = try tex.window.gpu.vkd.mapMemory(tex.window.gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
        defer tex.window.gpu.vkd.unmapMemory(tex.window.gpu.dev, staging_buff.memory);

        for (paths, 0..) |path, i| {
            var read_image = try img.Image.fromFilePath(ally, path);
            defer read_image.deinit();

            switch (read_image.pixels) {
                .rgba32 => |rgba| {
                    var pixel_data: [*]align(4) Rgba = @alignCast(@ptrCast(data));
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

    try graphics.transitionImageLayout(&tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .layer_count = 6,
    });
    try tex.copyBufferToImage(staging_buff.buffer);
    try graphics.transitionImageLayout(&tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .transfer_dst_optimal,
        .new_layout = tex.getIdealLayout(),
        .layer_count = 6,
    });
}

const Bgra = struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
};

pub fn createImage(tex: Texture, input: anytype, flip: bool) !void {
    const T = @typeInfo(@TypeOf(input.data)).pointer.child;
    const input_type = blk: {
        if (@typeInfo(T) == .@"struct") {
            if (@hasField(T, "r") and @hasField(T, "g") and @hasField(T, "b")) {
                if (@hasField(T, "a")) {
                    break :blk .rgba;
                } else {
                    break :blk .rgb;
                }
            }
        } else {
            if (T == f32) break :blk .float;
            @compileError("Invalid input image");
        }
    };
    const size: usize = switch (tex.format) {
        .b8g8r8a8_srgb, .b8g8r8a8_unorm => @sizeOf(Bgra),
        .r32_sfloat => @sizeOf(f32),
        else => return error.UnhandledFormat,
    };

    const staging_buff = try tex.window.gpu.createStagingBuffer(size * input.data.len, .src);
    defer staging_buff.deinit(tex.window.gpu);

    {
        const data = try tex.window.gpu.vkd.mapMemory(tex.window.gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
        defer tex.window.gpu.vkd.unmapMemory(tex.window.gpu.dev, staging_buff.memory);

        switch (tex.format) {
            .b8g8r8a8_srgb, .b8g8r8a8_unorm => {
                switch (input_type) {
                    .rgb, .rgba => {
                        const Format = Bgra;

                        var slice = @as([*]Format, @ptrCast(data))[0..input.data.len];

                        for (0..tex.width) |i| {
                            for (0..tex.height) |j_in| {
                                const j = if (flip) tex.height - j_in - 1 else j_in;
                                const p = &slice[j * tex.width + i];
                                const source = j_in * tex.width + i;

                                const v = input.data[source].to.u32Rgba();

                                p.r = @intCast(v >> 24 & 0xFF);
                                p.g = @intCast(v >> 16 & 0xFF);
                                p.b = @intCast(v >> 8 & 0xFF);
                                p.a = @intCast(v >> 0 & 0xFF);
                            }
                        }
                    },
                    else => return error.InvalidTextureFormat,
                }
            },
            .r32_sfloat => {
                if (T == f32) {
                    const Format = f32;
                    for (@as([*]Format, @ptrCast(@alignCast(data)))[0..input.data.len], 0..) |*p, i| {
                        p.* = input.data[i];
                    }
                } else {
                    return error.InvalidTextureFormat;
                }
            },
            else => return error.InvalidTextureFormat,
        }
    }

    try graphics.transitionImageLayout(&tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .layer_count = if (tex.info.cubemap) 6 else 1,
    });
    try tex.copyBufferToImage(staging_buff.buffer);
    try graphics.transitionImageLayout(&tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .transfer_dst_optimal,
        .new_layout = tex.getIdealLayout(),
        .layer_count = if (tex.info.cubemap) 6 else 1,
    });
}

pub fn getIdealLayout(texture: Texture) vk.ImageLayout {
    if (texture.info.preferred_format == .depth) return .depth_stencil_attachment_optimal;
    return switch (texture.info.type) {
        .storage => .general,
        .render_target, .regular, .multisampling => .shader_read_only_optimal,
    };
}

pub fn setFromRgba(self: *Texture, input: anytype, flip: bool) !void {
    try self.createImage(input, flip);
    try self.createImageView();
    try self.createTextureSampler();
}

// eventually remove
pub const Image = struct {
    width: u32,
    height: u32,
    data: []img.color.Rgba32,
};

pub const TextureInfo = struct {
    const FilterEnum = enum {
        nearest,
        linear,

        pub fn getVulkan(filter: FilterEnum) vk.Filter {
            return switch (filter) {
                .nearest => .nearest,
                .linear => .linear,
            };
        }
    };
    const TextureType = enum {
        flat,
    };

    texture_type: TextureType = .flat,
    mag_filter: FilterEnum = .nearest,
    min_filter: FilterEnum = .nearest,

    type: enum {
        multisampling,
        render_target,
        storage,
        regular,
    } = .regular,

    cubemap: bool = false,
    compare_less: bool = false,
    preferred_format: ?graphics.PreferredFormat = null,
    flip: bool = false,
};

const Texture = @This();

const vk = @import("vulkan");
const img = @import("img");
const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
