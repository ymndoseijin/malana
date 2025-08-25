info: TextureInfo,

width: u32,
height: u32,

// vulkan
image: vk.Image,
view_table: std.AutoArrayHashMapUnmanaged(ViewDescription, vk.ImageView),

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

pub fn getAttachment(texture: *Texture, current_layout: vk.ImageLayout, clear: graphics.RenderingOptions.ClearValue, view: ViewDescription) !vk.RenderingAttachmentInfoKHR {
    return .{
        .image_view = try texture.getViewOrCreate(view, true),
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

pub fn init(win: *graphics.Window, width: u32, height: u32, info: TextureInfo) !Texture {
    const format = if (info.preferred_format) |f| f else win.preferred_format;
    const vk_format = blk: {
        if (info.type == .multisampling) {
            break :blk win.preferred_format.getSurfaceFormat(win.gpu);
        } else {
            break :blk format.getSurfaceFormat(win.gpu);
        }
    };

    if (info.cubemap) std.debug.assert(info.layer_count == 6);

    const image_info: vk.ImageCreateInfo = .{
        .image_type = .@"2d",
        .extent = .{ .width = width, .height = height, .depth = 1 },
        .mip_levels = info.level_count,
        .array_layers = info.layer_count,
        .format = vk_format,
        .tiling = blk: {
            if (info.type == .render_target or info.type == .multisampling) {
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
            switch (info.type) {
                .multisampling => break :blk .{ .transient_attachment_bit = true, .color_attachment_bit = true },
                .render_target => break :blk .{ .color_attachment_bit = true, .sampled_bit = true },
                .storage => break :blk .{ .transfer_dst_bit = true, .sampled_bit = true, .storage_bit = true },
                .regular => break :blk switch (format) {
                    .depth => .{ .depth_stencil_attachment_bit = true, .sampled_bit = true },
                    else => .{ .transfer_dst_bit = true, .sampled_bit = true },
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

    var tex: Texture = .{
        .info = info,
        .image = image,
        .window = win,

        .width = width,
        .height = height,

        .sampler = undefined,
        .view_table = .empty,

        .memory = image_memory,
        .format = vk_format,
    };

    _ = try tex.createImageView(tex.getReadDesc(), false);
    try tex.createTextureSampler(false);

    if (builtin.mode == .Debug) {
        //std.debug.dumpCurrentStackTrace(null);
        //std.debug.print("texture {any}\n", .{tex.image});
        try graphics.addDebugMark(win.gpu, .image, @intFromEnum(tex.image), "texture image");
    }

    return tex;
}

pub fn deinit(tex: Texture) void {
    const win = tex.window;
    win.gpu.vkd.destroySampler(win.gpu.dev, tex.sampler, null);
    for (tex.view_table.values()) |oldest_view| {
        win.gpu.vkd.destroyImageView(win.gpu.dev, oldest_view, null);
    }
    win.gpu.vkd.destroyImage(win.gpu.dev, tex.image, null);
    win.gpu.vkd.freeMemory(win.gpu.dev, tex.memory, null);
}

pub fn initFromMemory(ally: std.mem.Allocator, win: *graphics.Window, buffer: []const u8, info: TextureInfo) !Texture {
    _ = ally;
    const trace = graphics.tracy.trace(@src());
    defer trace.end();

    var width_c: c_int = undefined;
    var height_c: c_int = undefined;
    var channels: c_int = undefined;

    switch (info.preferred_format orelse .unorm8_rgba) {
        else => {
            const res = stb_image.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &width_c, &height_c, &channels, 4);
            defer stb_image.stbi_image_free(res);

            const width: usize = @intCast(width_c);
            const height: usize = @intCast(height_c);

            var tex = try Texture.init(win, @intCast(width), @intCast(height), info);
            try tex.setFromBuffer(res[0 .. width * height * @sizeOf(Rgba32)], info.flip);
            return tex;
        },
    }
}

pub fn initFromPath(ally: std.mem.Allocator, win: *graphics.Window, path: []const u8, info: TextureInfo) !Texture {
    _ = ally;
    const trace = graphics.tracy.trace(@src());
    defer trace.end();

    var width_c: c_int = undefined;
    var height_c: c_int = undefined;
    var channels: c_int = undefined;

    switch (info.preferred_format orelse .unorm8_rgba) {
        .f32_rgb => {
            const res = stb_image.stbi_loadf(path.ptr, &width_c, &height_c, &channels, 3);
            defer stb_image.stbi_image_free(res);

            const width: usize = @intCast(width_c);
            const height: usize = @intCast(height_c);

            var tex = try Texture.init(win, @intCast(width), @intCast(height), info);
            const res_u8: []const u8 = @as([*]u8, @ptrCast(@alignCast(res)))[0 .. width * height * @sizeOf(FloatRgb)];
            try tex.setFromBuffer(res_u8, info.flip);
            return tex;
        },
        else => {
            const res = stb_image.stbi_load(path.ptr, &width_c, &height_c, &channels, 4);
            defer stb_image.stbi_image_free(res);

            const width: usize = @intCast(width_c);
            const height: usize = @intCast(height_c);

            var tex = try Texture.init(win, @intCast(width), @intCast(height), info);
            try tex.setFromBuffer(res[0 .. width * height * @sizeOf(Rgba32)], info.flip);
            return tex;
        },
    }
}

pub fn getReadDesc(tex: Texture) ViewDescription {
    return .{
        .layer_index = 0,
        .layer_count = tex.info.layer_count,
    };
}
// always has it, as it's created in the imageview
pub fn getReadView(tex: Texture) vk.ImageView {
    return tex.view_table.get(tex.getReadDesc()).?;
}

pub fn getViewOrCreate(tex: *Texture, desc: ViewDescription, is_attachment: bool) !vk.ImageView {
    return tex.view_table.get(desc) orelse try tex.createImageView(desc, is_attachment);
}

fn createTextureSampler(tex: *Texture, reuse: bool) !void {
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
    if (reuse) win.gpu.vkd.destroySampler(win.gpu.dev, tex.sampler, null);
    tex.sampler = try gpu.vkd.createSampler(gpu.dev, &sampler_info, null);
    if (builtin.mode == .Debug) {
        try graphics.addDebugMark(win.gpu, .sampler, @intFromEnum(tex.sampler), "texture sampler");
    }
}

pub const ViewDescription = struct {
    level_count: u32 = 1,
    level_index: u32 = 0,
    layer_count: u32 = 1,
    layer_index: u32,
};

fn createImageView(tex: *Texture, view_desc: ViewDescription, is_attachment: bool) !vk.ImageView {
    const gpu = &tex.window.gpu;

    const view_info: vk.ImageViewCreateInfo = .{
        .image = tex.image,
        .view_type = blk: {
            if (is_attachment) break :blk .@"2d";
            if (tex.info.cubemap) {
                break :blk .cube;
            } else {
                break :blk .@"2d";
            }
        },
        .format = tex.format,
        .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        .subresource_range = .{
            .aspect_mask = if (tex.info.preferred_format == .depth) .{ .depth_bit = true } else .{ .color_bit = true },
            .base_mip_level = view_desc.level_index,
            .level_count = view_desc.level_count,
            .base_array_layer = view_desc.layer_index,
            .layer_count = view_desc.layer_count,
        },
    };

    const win = tex.window;
    if (tex.view_table.get(view_desc)) |oldest_view| {
        win.gpu.vkd.destroyImageView(win.gpu.dev, oldest_view, null);
    }

    const view = try gpu.vkd.createImageView(gpu.dev, &view_info, null);
    try tex.view_table.put(tex.window.ally, view_desc, view);

    if (builtin.mode == .Debug) {
        try graphics.addDebugMark(win.gpu, .image_view, @intFromEnum(view), "texture image view");
    }

    return view;
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
pub fn createImage(tex: Texture, input: []const u8, flip: bool) !void {
    //const size: usize = switch (tex.format) {
    //    .b8g8r8a8_srgb, .b8g8r8a8_unorm => @sizeOf(Bgra),
    //    .r32_sfloat => @sizeOf(f32),
    //    else => return error.UnhandledFormat,
    //};

    // thus the staging_buff is just input up to rearranging
    const staging_buff = try tex.window.gpu.createStagingBuffer(input.len * @sizeOf(u8), .src);
    defer staging_buff.deinit(tex.window.gpu);

    {
        const data = try tex.window.gpu.vkd.mapMemory(tex.window.gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
        defer tex.window.gpu.vkd.unmapMemory(tex.window.gpu.dev, staging_buff.memory);

        switch (tex.format) {
            .b8g8r8a8_srgb, .b8g8r8a8_unorm => {
                const pix_len = @divExact(input.len, 4);
                const input_slice = @as([*]const Rgba32, @ptrCast(input.ptr))[0..pix_len];
                var slice = @as([*]Bgra, @ptrCast(data))[0..pix_len];

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
            },
            .r32g32b32_sfloat, .r32_sfloat => {
                @memcpy(@as([*]u8, @ptrCast(@alignCast(data)))[0..input.len], input);
            },
            else => return error.InvalidTextureFormat,
        }
    }

    try graphics.transitionImageLayout(&tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .layer_count = tex.info.layer_count,
        .level_count = tex.info.level_count,
    });
    try tex.copyBufferToImage(staging_buff.buffer);
    try graphics.transitionImageLayout(&tex.window.gpu, tex.window.pool, tex.image, .{
        .old_layout = .transfer_dst_optimal,
        .new_layout = tex.getIdealLayout(),
        .layer_count = tex.info.layer_count,
        .level_count = tex.info.level_count,
    });
}

pub fn getIdealLayout(texture: Texture) vk.ImageLayout {
    if (texture.info.preferred_format == .depth) return .depth_stencil_attachment_optimal;
    return switch (texture.info.type) {
        .storage => .general,
        .render_target, .regular, .multisampling => .shader_read_only_optimal,
    };
}

// TODO: assert
pub fn setFromRgba(self: *Texture, input: anytype, flip: bool) !void {
    const ptr: [*]const u8 = @ptrCast(@alignCast(input.ptr));
    return self.setFromBuffer(ptr[0 .. input.len * 4], flip);
}

pub fn eraseViews(tex: *Texture) void {
    const win = tex.window;
    for (tex.view_table.values()) |oldest_view| {
        win.gpu.vkd.destroyImageView(win.gpu.dev, oldest_view, null);
    }
    tex.view_table.clearRetainingCapacity();
}

pub fn setFromBuffer(self: *Texture, input: []const u8, flip: bool) !void {
    self.eraseViews();
    try self.createImage(input, flip);
    _ = try self.createImageView(self.getReadDesc(), false);
    try self.createTextureSampler(true);
}

// eventually remove
pub const Image = struct {
    width: u32,
    height: u32,
    data: []Rgba32,
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
