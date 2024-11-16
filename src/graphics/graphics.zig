// TODO: remove pub
pub const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

const max_boundless = 2560;

const common = @import("common");
const std = @import("std");
const builtin = @import("builtin");
const math = @import("math");

const freetype = @cImport({
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
});

pub const tracy = @import("tracy.zig");

const vk = @import("vk.zig");

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwGetPhysicalDevicePresentationSupport(instance: vk.Instance, pdev: vk.PhysicalDevice, queuefamily: u32) c_int;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.GLFWwindow, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

pub const Cube = @import("elems/cube.zig").Cube;
pub const Line = @import("elems/line.zig").Line;
pub const Grid = @import("elems/grid.zig").makeGrid;
pub const Axis = @import("elems/axis.zig").makeAxis;
pub const Camera = @import("elems/camera.zig").Camera;
pub const TextBdf = @import("elems/textbdf.zig").Text;
pub const TextFt = @import("elems/textft.zig").Text;

pub const Sprite = @import("elems/sprite.zig").Sprite;
pub const CustomSprite = @import("elems/sprite.zig").CustomSprite;

pub const SpriteBatch = @import("elems/sprite_batch.zig").SpriteBatch;
pub const CustomSpriteBatch = @import("elems/sprite_batch.zig").CustomSpriteBatch;

pub const ColorRect = @import("elems/color_rect.zig").ColorRect;

pub const MeshBuilder = @import("meshbuilder.zig").MeshBuilder;
pub const SpatialMesh = @import("elems/spatialmesh.zig").SpatialMesh;
pub const ObjParse = @import("obj.zig").ObjParse;
pub const ComptimeMeshBuilder = @import("comptime_meshbuilder.zig").ComptimeMeshBuilder;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec3;

const elem_shaders = @import("elem_shaders");

// global vars
pub var global_object_map: std.AutoHashMap(u64, []const u8) = undefined;
var windowMap: ?std.AutoHashMap(*glfw.GLFWwindow, MapType) = null;
pub var ft_lib: freetype.FT_Library = undefined;

pub const Gpu = @import("Gpu.zig");

const Allocator = std.mem.Allocator;

pub const Swapchain = struct {
    pub const PresentState = enum {
        optimal,
        suboptimal,
    };

    ally: Allocator,

    surface_format: vk.SurfaceFormatKHR,
    present_mode: vk.PresentModeKHR,
    extent: vk.Extent2D,
    handle: vk.SwapchainKHR,

    swap_images: []SwapImage,

    render_finished: []vk.Semaphore,
    image_acquired: []vk.Semaphore,
    frame_fence: []vk.Fence,

    pub const ImageIndex = enum(u32) { _ };

    pub fn init(gpu: *const Gpu, ally: Allocator, extent: vk.Extent2D, format: PreferredFormat) !Swapchain {
        const finished = try ally.alloc(vk.Semaphore, frames_in_flight);
        for (finished) |*f| {
            f.* = try gpu.vkd.createSemaphore(gpu.dev, &.{}, null);
            if (builtin.mode == .Debug) {
                try addDebugMark(gpu.*, .semaphore, @intFromEnum(f.*), "swapchain finished semaphore");
            }
        }

        const image = try ally.alloc(vk.Semaphore, frames_in_flight);
        for (image) |*f| {
            f.* = try gpu.vkd.createSemaphore(gpu.dev, &.{}, null);
            if (builtin.mode == .Debug) {
                try addDebugMark(gpu.*, .semaphore, @intFromEnum(f.*), "swapchain acquire semaphore");
            }
        }

        const frame_fence = try ally.alloc(vk.Fence, frames_in_flight);
        for (frame_fence) |*f| {
            f.* = try gpu.vkd.createFence(gpu.dev, &.{ .flags = .{ .signaled_bit = true } }, null);
            if (builtin.mode == .Debug) {
                try addDebugMark(gpu.*, .fence, @intFromEnum(f.*), "swapchain frame fence");
            }
        }

        return try initRecycle(gpu, ally, .{
            .extent = extent,
            .old_handle = .null_handle,
            .format = format,
            .finished = finished,
            .image = image,
            .frames = frame_fence,
        });
    }

    pub fn initRecycle(gpu: *const Gpu, ally: Allocator, options: struct {
        extent: vk.Extent2D,
        old_handle: vk.SwapchainKHR,
        format: PreferredFormat,
        finished: []vk.Semaphore,
        image: []vk.Semaphore,
        frames: []vk.Fence,
    }) !Swapchain {
        const caps = try gpu.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(gpu.pdev, gpu.surface.?);
        const actual_extent = findActualExtent(caps, options.extent);
        if (actual_extent.width == 0 or actual_extent.height == 0) {
            return error.InvalidSurfaceDimensions;
        }

        const surface_format = try findSurfaceFormat(gpu, ally, options.format);
        const present_mode: vk.PresentModeKHR = .fifo_khr;

        var image_count = caps.min_image_count + 1;
        if (caps.max_image_count > 0) {
            image_count = @min(image_count, caps.max_image_count);
        }

        const qfi = [_]u32{ gpu.graphics_queue.family, gpu.present_queue.family };
        const sharing_mode: vk.SharingMode = if (gpu.graphics_queue.family != gpu.present_queue.family)
            .concurrent
        else
            .exclusive;

        const handle = try gpu.vkd.createSwapchainKHR(gpu.dev, &.{
            .surface = gpu.surface.?,
            .min_image_count = image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = actual_extent,
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true },
            .image_sharing_mode = sharing_mode,
            .queue_family_index_count = qfi.len,
            .p_queue_family_indices = &qfi,
            .pre_transform = caps.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = options.old_handle,
        }, null);
        errdefer gpu.vkd.destroySwapchainKHR(gpu.dev, handle, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .swapchain_khr, @intFromEnum(handle), "swapchain");
        }

        if (options.old_handle != .null_handle) {
            gpu.vkd.destroySwapchainKHR(gpu.dev, options.old_handle, null);
        }

        const swap_images = try initSwapchainImages(gpu, handle, surface_format.format, ally);
        errdefer {
            for (swap_images) |si| si.deinit(gpu);
            ally.free(swap_images);
        }
        //errdefer gpu.vkd.destroySemaphore(gpu.dev, next_image_acquired, null);

        return Swapchain{
            .ally = ally,
            .surface_format = surface_format,
            .present_mode = present_mode,
            .extent = actual_extent,
            .handle = handle,
            .swap_images = swap_images,
            .render_finished = options.finished,
            .frame_fence = options.frames,
            .image_acquired = options.image,
        };
    }

    fn deinitExceptSwapchain(self: Swapchain, gpu: *Gpu) void {
        for (self.swap_images) |si| si.deinit(gpu);
        self.ally.free(self.swap_images);
    }

    pub fn deinit(self: Swapchain, gpu: *Gpu) void {
        self.deinitExceptSwapchain(gpu);
        gpu.vkd.destroySwapchainKHR(gpu.dev, self.handle, null);

        for (self.render_finished) |s| gpu.vkd.destroySemaphore(gpu.dev, s, null);
        self.ally.free(self.render_finished);

        for (self.image_acquired) |s| gpu.vkd.destroySemaphore(gpu.dev, s, null);
        self.ally.free(self.image_acquired);

        for (self.frame_fence) |f| gpu.vkd.destroyFence(gpu.dev, f, null);
        self.ally.free(self.frame_fence);
    }

    pub fn recreate(self: *Swapchain, gpu: *Gpu, new_extent: vk.Extent2D, format: PreferredFormat) !void {
        const ally = self.ally;
        const old_handle = self.handle;
        self.deinitExceptSwapchain(gpu);
        self.* = try initRecycle(gpu, ally, .{
            .extent = new_extent,
            .old_handle = old_handle,
            .format = format,
            .finished = self.render_finished,
            .image = self.image_acquired,
            .frames = self.frame_fence,
        });
    }

    pub fn wait(swapchain: *Swapchain, gpu: *Gpu, frame_id: usize) !void {
        _ = try gpu.vkd.waitForFences(gpu.dev, 1, @ptrCast(&swapchain.frame_fence[frame_id]), vk.TRUE, std.math.maxInt(u64));
        try gpu.vkd.resetFences(gpu.dev, 1, @ptrCast(&swapchain.frame_fence[frame_id]));
    }

    pub fn acquireImage(swapchain: *Swapchain, gpu: *Gpu, frame_id: usize) !ImageIndex {
        return @enumFromInt((try gpu.vkd.acquireNextImageKHR(
            gpu.dev,
            swapchain.handle,
            std.math.maxInt(u64),
            swapchain.image_acquired[frame_id],
            .null_handle,
        )).image_index);
    }

    pub fn getImage(swapchain: *Swapchain, index: ImageIndex) vk.Image {
        const swap_image = swapchain.swap_images[@intFromEnum(index)];
        return swap_image.image;
    }

    pub fn getAttachment(swapchain: *Swapchain, index: ImageIndex) vk.RenderingAttachmentInfoKHR {
        const clear_value: vk.ClearValue = .{
            .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
        };

        const swap_image = swapchain.swap_images[@intFromEnum(index)];

        return .{
            .image_view = swap_image.view,
            .image_layout = vk.ImageLayout.attachment_optimal_khr,
            .load_op = .clear,
            .store_op = .store,
            .clear_value = clear_value,

            // ?
            .resolve_mode = .{},
            .resolve_image_layout = .undefined,
        };
    }

    pub fn submit(swapchain: *Swapchain, gpu: *Gpu, builder: CommandBuilder, options: struct { wait: []const struct {
        semaphore: vk.Semaphore,
        flag: vk.PipelineStageFlags,
    } }) !void {
        const wait_stage = try swapchain.ally.alloc(vk.PipelineStageFlags, options.wait.len);
        defer swapchain.ally.free(wait_stage);

        const semaphores = try swapchain.ally.alloc(vk.Semaphore, options.wait.len);
        defer swapchain.ally.free(semaphores);

        for (semaphores, options.wait) |*dst, src| dst.* = src.semaphore;

        for (wait_stage, options.wait) |*stage, semaphore| {
            stage.* = semaphore.flag;
        }

        const cmdbuf = builder.getCurrent();

        try gpu.vkd.queueSubmit(gpu.graphics_queue.handle, 1, &.{.{
            .wait_semaphore_count = @intCast(semaphores.len),
            .p_wait_semaphores = if (semaphores.len == 0) null else semaphores.ptr,
            .p_wait_dst_stage_mask = wait_stage.ptr,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&cmdbuf),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(&swapchain.render_finished[builder.frame_id]),
        }}, swapchain.frame_fence[builder.frame_id]);
    }

    pub fn present(swapchain: *Swapchain, gpu: *Gpu, options: struct {
        wait: []const vk.Semaphore,
        image_index: ImageIndex,
    }) !void {
        _ = try gpu.vkd.queuePresentKHR(gpu.present_queue.handle, &.{
            .wait_semaphore_count = @intCast(options.wait.len),
            .p_wait_semaphores = if (options.wait.len == 0) null else options.wait.ptr,
            .swapchain_count = 1,
            .p_swapchains = @as([*]const vk.SwapchainKHR, @ptrCast(&swapchain.handle)),
            .p_image_indices = @as([*]const u32, @ptrCast(&options.image_index)),
        });
    }
};

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,

    fn init(gpu: *const Gpu, image: vk.Image, format: vk.Format) !SwapImage {
        const view = try gpu.vkd.createImageView(gpu.dev, &.{
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
        errdefer gpu.vkd.destroyImageView(gpu.dev, view, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .image_view, @intFromEnum(view), "swapchain image view");
            try addDebugMark(gpu.*, .image, @intFromEnum(image), "swapchain image");
        }

        const image_acquired = try gpu.vkd.createSemaphore(gpu.dev, &.{}, null);
        errdefer gpu.vkd.destroySemaphore(gpu.dev, image_acquired, null);

        return SwapImage{
            .image = image,
            .view = view,
            .image_acquired = image_acquired,
        };
    }

    fn deinit(self: SwapImage, gpu: *const Gpu) void {
        //self.waitForFence(gpu) catch return;
        gpu.vkd.destroyImageView(gpu.dev, self.view, null);
        gpu.vkd.destroySemaphore(gpu.dev, self.image_acquired, null);
    }
};

fn initSwapchainImages(gpu: *const Gpu, swapchain: vk.SwapchainKHR, format: vk.Format, allocator: Allocator) ![]SwapImage {
    var count: u32 = undefined;
    _ = try gpu.vkd.getSwapchainImagesKHR(gpu.dev, swapchain, &count, null);
    const images = try allocator.alloc(vk.Image, count);
    defer allocator.free(images);
    _ = try gpu.vkd.getSwapchainImagesKHR(gpu.dev, swapchain, &count, images.ptr);

    const swap_images = try allocator.alloc(SwapImage, count);
    errdefer allocator.free(swap_images);

    var i: usize = 0;
    errdefer for (swap_images[0..i]) |si| si.deinit(gpu);

    for (images) |image| {
        swap_images[i] = try SwapImage.init(gpu, image, format);
        i += 1;
    }

    return swap_images;
}

fn findSurfaceFormat(gpu: *const Gpu, allocator: Allocator, format: PreferredFormat) !vk.SurfaceFormatKHR {
    const preferred = vk.SurfaceFormatKHR{
        .format = format.getSurfaceFormat(gpu.*),
        .color_space = .srgb_nonlinear_khr,
    };

    var count: u32 = undefined;
    _ = try gpu.vki.getPhysicalDeviceSurfaceFormatsKHR(gpu.pdev, gpu.surface.?, &count, null);
    const surface_formats = try allocator.alloc(vk.SurfaceFormatKHR, count);
    defer allocator.free(surface_formats);
    _ = try gpu.vki.getPhysicalDeviceSurfaceFormatsKHR(gpu.pdev, gpu.surface.?, &count, surface_formats.ptr);

    for (surface_formats) |sfmt| {
        if (std.meta.eql(sfmt, preferred)) {
            return preferred;
        }
    }

    return surface_formats[0];
}

fn findPresentMode(gpu: *const Gpu, allocator: Allocator) !vk.PresentModeKHR {
    var count: u32 = undefined;
    _ = try gpu.vki.getPhysicalDeviceSurfacePresentModesKHR(gpu.pdev, gpu.surface.?, &count, null);
    const present_modes = try allocator.alloc(vk.PresentModeKHR, count);
    defer allocator.free(present_modes);
    _ = try gpu.vki.getPhysicalDeviceSurfacePresentModesKHR(gpu.pdev, gpu.surface.?, &count, present_modes.ptr);

    const preferred = [_]vk.PresentModeKHR{
        .mailbox_khr,
        .immediate_khr,
    };

    for (preferred) |mode| {
        if (std.mem.indexOfScalar(vk.PresentModeKHR, present_modes, mode) != null) {
            return mode;
        }
    }

    return .fifo_khr;
}

fn findActualExtent(caps: vk.SurfaceCapabilitiesKHR, extent: vk.Extent2D) vk.Extent2D {
    if (caps.current_extent.width != 0xFFFF_FFFF) {
        return caps.current_extent;
    } else {
        return .{
            .width = std.math.clamp(extent.width, caps.min_image_extent.width, caps.max_image_extent.width),
            .height = std.math.clamp(extent.height, caps.min_image_extent.height, caps.max_image_extent.height),
        };
    }
}

// decide whether a command will be execute immediately or queued to current cmd buffer
pub const CommandMode = union(enum) {
    queue: CommandBuilder,
    immediate: void,
};

// eventually make a helper struct for any sized command buffers
pub fn createSingleCommandBuffer(gpu: *const Gpu, pool: vk.CommandPool) !vk.CommandBuffer {
    var cmdbuf: vk.CommandBuffer = undefined;
    try gpu.vkd.allocateCommandBuffers(gpu.dev, &.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&cmdbuf));
    try gpu.vkd.beginCommandBuffer(cmdbuf, &.{
        .flags = .{ .one_time_submit_bit = true },
    });
    return cmdbuf;
}

pub fn freeSingleCommandBuffer(cmdbuf: vk.CommandBuffer, gpu: *const Gpu, pool: vk.CommandPool) void {
    gpu.vkd.freeCommandBuffers(gpu.dev, pool, 1, @ptrCast(&cmdbuf));
}

pub fn finishSingleCommandBuffer(cmdbuf: vk.CommandBuffer, gpu: *const Gpu) !void {
    try gpu.vkd.endCommandBuffer(cmdbuf);

    const si = vk.SubmitInfo{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&cmdbuf),
        .p_wait_dst_stage_mask = undefined,
    };
    try gpu.vkd.queueSubmit(gpu.graphics_queue.handle, 1, @ptrCast(&si), .null_handle);

    // TODO: make a system that signals a fence (or a timeline semaphore?!) instead, at least optionally
    try gpu.vkd.queueWaitIdle(gpu.graphics_queue.handle);
}

pub fn copyBuffer(
    gpu: *const Gpu,
    pool: vk.CommandPool,
    dst: vk.Buffer,
    src: vk.Buffer,
    size: vk.DeviceSize,
    mode: CommandMode,
) !void {
    const cmdbuf = if (mode == .immediate) try createSingleCommandBuffer(gpu, pool) else mode.queue.getCurrent();
    defer switch (mode) {
        .immediate => |_| freeSingleCommandBuffer(cmdbuf, gpu, pool),
        else => {},
    };

    const region = vk.BufferCopy{
        .src_offset = 0,
        .dst_offset = 0,
        .size = size,
    };
    gpu.vkd.cmdCopyBuffer(cmdbuf, src, dst, 1, @ptrCast(&region));

    // Access info (
    // usage: SYNC_INDEX_INPUT_INDEX_READ,
    // prior_usage: SYNC_COPY_TRANSFER_WRITE,
    // write_barriers: SYNC_VERTEX_ATTRIBUTE_INPUT_VERTEX_ATTRIBUTE_READ, command: vkCmdCopyBuffer, seq_no: 3, reset_no: 2)

    switch (mode) {
        .queue => |builder| {
            builder.pipelineBarrier(gpu, .{
                .src_stage = .{ .transfer_bit = true },
                .dst_stage = .{ .vertex_input_bit = true },
                .memory_barriers = &.{
                    .{
                        .src_access = .{ .transfer_write_bit = true },
                        .dst_access = .{ .vertex_attribute_read_bit = true, .index_read_bit = true },
                    },
                },
            });
        },
        else => {},
    }

    if (mode == .immediate) try finishSingleCommandBuffer(cmdbuf, gpu);
}

// end

pub fn addDebugMark(gpu: Gpu, object_type: vk.ObjectType, handle: u64, name: []const u8) !void {
    if (true) return;
    const ally = std.heap.page_allocator;
    const debug_info = try std.debug.getSelfDebugInfo();

    var image_name = std.ArrayList(u8).init(ally);
    const stream = image_name.writer();

    var it = std.debug.StackIterator.init(null, null);
    defer it.deinit();

    try stream.print("{s} (", .{name});
    _ = it.next();
    while (it.next()) |return_address| {
        const address = if (return_address == 0) return_address else return_address - 1;

        const module = debug_info.getModuleForAddress(address) catch break;
        const symbol_info = try module.getSymbolAtAddress(debug_info.allocator, address);

        const line_info = symbol_info.line_info.?;
        try stream.print("{s}:{}:{}|", .{ std.fs.path.basename(line_info.file_name), line_info.line, line_info.column });
    }
    try stream.print(")", .{});

    //try global_object_map.put(handle, image_name.items);

    try gpu.vkd.setDebugUtilsObjectNameEXT(gpu.dev, &.{
        .object_type = object_type,
        .object_handle = handle,
        .p_object_name = try ally.dupeZ(u8, image_name.items),
    });
}

pub const Texture = @import("Texture.zig");

const TransitionOptions = struct {
    old_layout: vk.ImageLayout,
    new_layout: vk.ImageLayout,
    layer_count: u32 = 1,
};

pub fn recordTransitionImageLayout(gpu: *const Gpu, cmdbuf: vk.CommandBuffer, image: vk.Image, options: TransitionOptions) !void {
    const barrier: vk.ImageMemoryBarrier = .{
        .old_layout = options.old_layout,
        .new_layout = options.new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresource_range = .{
            // stencil also has to be marked if the format supports it
            .aspect_mask = blk: {
                if (options.new_layout == .depth_stencil_attachment_optimal or options.old_layout == .depth_stencil_attachment_optimal) {
                    break :blk .{ .depth_bit = true };
                } else {
                    break :blk .{ .color_bit = true };
                }
            },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = options.layer_count,
        },
        .src_access_mask = switch (options.old_layout) {
            .undefined => .{},
            .depth_stencil_attachment_optimal => .{ .depth_stencil_attachment_write_bit = true },
            .general, .transfer_dst_optimal => .{ .transfer_write_bit = true },
            .color_attachment_optimal => .{ .color_attachment_write_bit = true },
            else => return error.InvalidOldLayout,
        },
        .dst_access_mask = switch (options.new_layout) {
            .general, .transfer_dst_optimal => .{ .transfer_write_bit = true },
            .color_attachment_optimal, .shader_read_only_optimal => .{ .shader_read_bit = true },
            .depth_stencil_attachment_optimal => .{ .depth_stencil_attachment_read_bit = true, .depth_stencil_attachment_write_bit = true },
            .present_src_khr => .{},
            else => return error.InvalidNewLayout,
        },
    };

    gpu.vkd.cmdPipelineBarrier(
        cmdbuf,
        switch (options.old_layout) {
            .undefined => .{ .top_of_pipe_bit = true },
            .depth_stencil_attachment_optimal => .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .general, .transfer_dst_optimal => .{ .transfer_bit = true },
            .color_attachment_optimal => .{ .color_attachment_output_bit = true },
            else => return error.InvalidOldLayout,
        },
        switch (options.new_layout) {
            .general, .transfer_dst_optimal => .{ .transfer_bit = true },
            .color_attachment_optimal, .shader_read_only_optimal => .{ .fragment_shader_bit = true },
            .depth_stencil_attachment_optimal => .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .present_src_khr => .{ .bottom_of_pipe_bit = true },
            else => return error.InvalidNewLayout,
        },
        .{},
        0,
        null,
        0,
        null,
        1,
        @ptrCast(&barrier),
    );
}

pub fn transitionImageLayout(gpu: *const Gpu, pool: vk.CommandPool, image: vk.Image, options: TransitionOptions) !void {
    const cmdbuf = try createSingleCommandBuffer(gpu, pool);
    defer freeSingleCommandBuffer(cmdbuf, gpu, pool);

    try recordTransitionImageLayout(gpu, cmdbuf, image, options);

    try finishSingleCommandBuffer(cmdbuf, gpu);
}

const ShaderType = enum {
    vertex,
    fragment,
    compute,
};

pub const Shader = struct {
    module: vk.ShaderModule,
    type: ShaderType,

    pub fn init(gpu: Gpu, file_src: []align(@alignOf(u32)) const u8, shader_enum: ShaderType) !Shader {
        //std.debug.dumpCurrentStackTrace(null);
        const module = try gpu.vkd.createShaderModule(gpu.dev, &.{
            .code_size = file_src.len,
            .p_code = std.mem.bytesAsSlice(u32, file_src).ptr,
        }, null);
        if (builtin.mode == .Debug) {
            try addDebugMark(gpu, .shader_module, @intFromEnum(module), "shader");
        }
        return Shader{
            .module = module,
            .type = shader_enum,
        };
    }

    pub fn deinit(self: *const Shader, gpu: Gpu) void {
        gpu.vkd.destroyShaderModule(gpu.dev, self.module, null);
    }
};

pub const OpQueue = struct {
    pub const SetUpdate = struct {
        options: Descriptor.WriteOptions,
        descriptor: *Descriptor,
    };
    set_update: std.ArrayList(SetUpdate),
    buffer_deletion: std.ArrayList(BufferHandle),

    gpu: *Gpu,
    ally: std.mem.Allocator,

    pub fn deinit(queue: *OpQueue) void {
        queue.set_update.deinit();
        queue.buffer_deletion.deinit();
    }

    pub fn appendBufferDeletion(queue: *OpQueue, buffer: BufferHandle) !void {
        try queue.buffer_deletion.append(buffer);
    }

    pub fn appendSet(queue: *OpQueue, options: Descriptor.WriteOptions, descriptor: *Descriptor) !void {
        const samplers = try queue.ally.dupe(Descriptor.SamplerWrite, options.samplers);
        for (samplers) |*s| s.textures = try queue.ally.dupe(Texture, s.textures);
        try queue.set_update.append(.{
            .descriptor = descriptor,
            .options = .{
                .samplers = samplers,
                .uniforms = try queue.ally.dupe(Descriptor.UniformWrite, options.uniforms),
                .storage = try queue.ally.dupe(Descriptor.StorageWrite, options.storage),
            },
        });
    }

    pub fn execute(queue: *OpQueue) !void {
        for (queue.set_update.items) |update| {
            try update.descriptor.updateSets(queue.gpu, update.options);
        }

        while (queue.set_update.popOrNull()) |update| {
            for (update.options.samplers) |s| queue.ally.free(s.textures);
            queue.ally.free(update.options.samplers);
            queue.ally.free(update.options.uniforms);
            queue.ally.free(update.options.storage);
        }

        while (queue.buffer_deletion.popOrNull()) |buffer| {
            buffer.deinit(queue.gpu.*);
        }
    }

    pub fn init(ally: std.mem.Allocator, gpu: *Gpu) OpQueue {
        return .{
            .set_update = std.ArrayList(SetUpdate).init(ally),
            .buffer_deletion = std.ArrayList(BufferHandle).init(ally),
            .gpu = gpu,
            .ally = ally,
        };
    }
};

pub const Semaphore = struct {
    semaphore: vk.Semaphore,
};

pub const Descriptor = struct {
    descriptor_sets: []vk.DescriptorSet,
    descriptor_pools: []vk.DescriptorPool,
    uniform_buffers: [][]std.ArrayList(UniformHandle),
    pipeline: Pipeline,
    queue: ?*OpQueue,

    ally: std.mem.Allocator,
    dependencies: Dependencies,

    pub const Dependencies = struct {
        textures: std.AutoArrayHashMap(Location, Texture),

        pub fn deinit(dep: *Dependencies, ally: std.mem.Allocator) void {
            _ = ally;
            dep.textures.deinit();
        }
    };

    pub const UniformHandle = struct {
        buffer: BufferHandle,
        idx: u32,
    };

    pub const SamplerWrite = struct {
        dst: u32 = 0,
        // binding index
        idx: u32,
        set: u32 = 0,
        textures: []const Texture = &.{},
        type: enum {
            combined,
            storage,
            combined_storage,
        } = .combined,
    };

    pub const UniformWrite = struct {
        dst: u32 = 0,
        // binding index
        idx: u32,
        set: u32 = 0,
        buffer: BufferHandle,
    };

    pub const StorageWrite = struct {
        dst: u32 = 0,
        // binding index
        idx: u32,
        set: u32 = 0,
        buffer: BufferHandle,
    };

    pub const WriteOptions = struct {
        samplers: []const SamplerWrite = &.{},
        uniforms: []const UniformWrite = &.{},
        storage: []const StorageWrite = &.{},
    };

    pub const Location = struct {
        dst: u32 = 0,
        // binding index
        idx: u32,
        set: u32 = 0,
    };

    pub const Info = struct {
        pipeline: Pipeline,
        queue: ?*OpQueue,
    };

    pub fn init(ally: std.mem.Allocator, gpu: *Gpu, options: Info) !Descriptor {
        const pipeline = options.pipeline;
        const description = options.pipeline.description;

        const pools = try ally.alloc(vk.DescriptorPool, description.sets.len);

        for (pools, description.sets, pipeline.set_bindings) |*pool, set_desc, bindings| {
            const pool_sizes = try ally.alloc(vk.DescriptorPoolSize, set_desc.bindings.len);
            defer ally.free(pool_sizes);

            for (pool_sizes, bindings) |*pool_size, binding| {
                pool_size.* = .{
                    .type = binding.descriptor_type,
                    .descriptor_count = binding.descriptor_count,
                };
            }

            const pool_info: vk.DescriptorPoolCreateInfo = .{
                .max_sets = 1,
                .p_pool_sizes = pool_sizes.ptr,
                .pool_size_count = @intCast(bindings.len),
                .flags = if (pipeline.description.bindless) .{ .update_after_bind_bit = true } else .{},
            };
            pool.* = try gpu.vkd.createDescriptorPool(gpu.dev, &pool_info, null);
            if (builtin.mode == .Debug) {
                try addDebugMark(gpu.*, .descriptor_pool, @intFromEnum(pool.*), "pool");
            }
        }

        var descriptor: Descriptor = .{
            .pipeline = options.pipeline,
            .uniform_buffers = undefined,
            .descriptor_pools = pools,
            .descriptor_sets = try ally.alloc(vk.DescriptorSet, pipeline.description.sets.len),
            .ally = ally,
            .queue = null,
            .dependencies = .{
                .textures = std.AutoArrayHashMap(Location, Texture).init(ally),
            },
        };

        try descriptor.createDescriptorSets(ally, gpu);
        try descriptor.createUniformBuffers(ally, gpu);

        descriptor.queue = options.queue;

        return descriptor;
    }

    pub fn getUniformOr(descriptor: *Descriptor, set: u32, binding: u32, dst: u32) ?BufferHandle {
        for (descriptor.uniform_buffers[set][binding].items) |uniform| {
            if (uniform.idx == dst) return uniform.buffer;
        }
        return null;
    }

    pub fn getUniformOrCreate(descriptor: *Descriptor, gpu: *Gpu, set: u32, binding: u32, dst: u32) !BufferHandle {
        const pipeline_description = descriptor.pipeline.description;
        for (descriptor.uniform_buffers[set][binding].items) |uniform| {
            if (uniform.idx == dst) return uniform.buffer;
        }
        try descriptor.uniform_buffers[set][binding].append(.{
            .idx = dst,
            .buffer = try BufferHandle.init(gpu, .{
                .size = pipeline_description.sets[set].bindings[binding].uniform.size,
                .buffer_type = .uniform,
            }),
        });
        const buffer = descriptor.uniform_buffers[set][binding].items[descriptor.uniform_buffers[set][binding].items.len - 1];

        try descriptor.updateDescriptorSets(gpu, .{ .uniforms = &.{.{
            .dst = dst,
            .idx = binding,
            .buffer = buffer.buffer,
        }} });

        return buffer.buffer;
    }

    pub fn setUniformOrCreate(
        descriptor: *Descriptor,
        comptime Data: DataDescription,
        gpu: *Gpu,
        set: u32,
        binding: u32,
        dst: u32,
        value: Data.T,
    ) !void {
        (try descriptor.getUniformOrCreate(gpu, set, binding, dst)).setAsUniform(Data, value);
    }

    pub fn createUniformBuffers(descriptor: *Descriptor, ally: std.mem.Allocator, gpu: *Gpu) !void {
        const trace = tracy.trace(@src());
        defer trace.end();

        const pipeline_description = descriptor.pipeline.description;

        descriptor.uniform_buffers = try ally.alloc([]std.ArrayList(UniformHandle), pipeline_description.sets.len);

        for (pipeline_description.sets, descriptor.uniform_buffers, 0..) |set_desc, *set_uniforms, set_i| {
            set_uniforms.* = try ally.alloc(std.ArrayList(UniformHandle), pipeline_description.getUniformCount(set_i));

            var uniform_i: usize = 0;
            for (set_desc.bindings, 0..) |binding, i| {
                if (binding == .uniform) {
                    const description = binding.uniform;
                    const array = &descriptor.uniform_buffers[set_i][uniform_i];

                    array.* = std.ArrayList(UniformHandle).init(ally);
                    uniform_i += 1;

                    if (!description.boundless) {
                        try array.append(.{ .idx = 0, .buffer = try BufferHandle.init(gpu, .{
                            .size = description.size,
                            .buffer_type = .uniform,
                        }) });
                        try descriptor.updateDescriptorSets(gpu, .{ .uniforms = &.{.{ .idx = @intCast(i), .buffer = array.items[0].buffer }} });
                    }
                }
            }
        }
    }

    // automatically deinit all buffers, but keep descriptor
    pub fn deinitAllUniforms(descriptor: *Descriptor, gpu: Gpu) void {
        for (descriptor.uniform_buffers) |set_array| {
            for (set_array) |*array| {
                for (array.items) |uni| uni.buffer.deinit(gpu);
                array.clearRetainingCapacity();
            }
        }
    }

    pub fn deinit(descriptor: *Descriptor, ally: std.mem.Allocator, gpu: Gpu) void {
        gpu.vkd.deviceWaitIdle(gpu.dev) catch {};

        for (descriptor.uniform_buffers) |set_array| {
            for (set_array) |*array| {
                array.deinit();
            }
            ally.free(set_array);
        }

        ally.free(descriptor.uniform_buffers);

        for (descriptor.descriptor_pools) |pool| gpu.vkd.destroyDescriptorPool(gpu.dev, pool, null);

        descriptor.dependencies.deinit(ally);

        ally.free(descriptor.descriptor_pools);
        ally.free(descriptor.descriptor_sets);
    }

    pub fn createDescriptorSets(descriptor: *Descriptor, ally: std.mem.Allocator, gpu: *Gpu) !void {
        const pipeline = descriptor.pipeline.description;

        for (descriptor.descriptor_sets, descriptor.descriptor_pools, descriptor.pipeline.layouts) |*set, pool, *layout| {
            const counts = try ally.create(u32);
            defer ally.destroy(counts);

            counts.* = if (pipeline.bindless) max_boundless else 1;

            const variable_counts: vk.DescriptorSetVariableDescriptorCountAllocateInfo = .{
                .descriptor_set_count = 1,
                .p_descriptor_counts = @ptrCast(counts),
            };

            const allocate_info: vk.DescriptorSetAllocateInfo = .{
                .descriptor_pool = pool,
                .descriptor_set_count = 1,
                .p_set_layouts = @ptrCast(layout),
                .p_next = &variable_counts,
            };

            try gpu.vkd.allocateDescriptorSets(gpu.dev, &allocate_info, @ptrCast(set));
        }
    }

    pub fn updateSets(descriptor: *Descriptor, gpu: *Gpu, options: WriteOptions) !void {
        const trace = tracy.trace(@src());
        defer trace.end();

        const ally = descriptor.ally;
        var arena = std.heap.ArenaAllocator.init(ally);
        defer arena.deinit();
        const arena_ally = arena.allocator();

        var descriptor_writes = std.ArrayList(vk.WriteDescriptorSet).init(arena_ally);
        defer descriptor_writes.deinit();

        for (options.uniforms) |uniform| {
            const buffer_info = try arena_ally.alloc(vk.DescriptorBufferInfo, 1);

            buffer_info[0] = vk.DescriptorBufferInfo{
                .buffer = uniform.buffer.buff_mem.buffer,
                .offset = 0,
                .range = uniform.buffer.size,
            };

            try descriptor_writes.append(.{
                .dst_set = descriptor.descriptor_sets[uniform.set],
                .dst_binding = uniform.idx,
                .dst_array_element = uniform.dst,
                .descriptor_type = .uniform_buffer,
                .descriptor_count = 1,
                .p_buffer_info = @ptrCast(&buffer_info[0]),
                .p_image_info = undefined,
                .p_texel_buffer_view = undefined,
            });
        }

        for (options.storage) |storage| {
            const buffer_info = try arena_ally.alloc(vk.DescriptorBufferInfo, 1);

            buffer_info[0] = vk.DescriptorBufferInfo{
                .buffer = storage.buffer.buff_mem.buffer,
                .offset = 0,
                .range = storage.buffer.size,
            };

            try descriptor_writes.append(.{
                .dst_set = descriptor.descriptor_sets[storage.set],
                .dst_binding = storage.idx,
                .dst_array_element = storage.dst,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .p_buffer_info = @ptrCast(&buffer_info[0]),
                .p_image_info = undefined,
                .p_texel_buffer_view = undefined,
            });
        }

        for (options.samplers) |write| {
            const image_infos = try arena_ally.alloc(vk.DescriptorImageInfo, write.textures.len);

            for (image_infos, 0..) |*info, texture_i| {
                try descriptor.dependencies.textures.put(.{
                    .dst = write.dst,
                    .idx = write.idx,
                    .set = write.set,
                }, write.textures[texture_i]);
                info.* = .{
                    .image_layout = switch (write.type) {
                        .combined => .shader_read_only_optimal,
                        .storage => .general,
                        .combined_storage => .general,
                    },
                    .image_view = write.textures[texture_i].image_view,
                    .sampler = write.textures[texture_i].sampler,
                };
            }

            try descriptor_writes.append(.{
                .dst_set = descriptor.descriptor_sets[write.set],
                .dst_binding = write.idx,
                .dst_array_element = write.dst,
                .descriptor_type = switch (write.type) {
                    .combined => .combined_image_sampler,
                    .storage => .storage_image,
                    .combined_storage => .combined_image_sampler,
                },
                .descriptor_count = @intCast(write.textures.len),
                .p_buffer_info = undefined,
                .p_image_info = image_infos.ptr,
                .p_texel_buffer_view = undefined,
            });
        }

        gpu.vkd.updateDescriptorSets(gpu.dev, @intCast(descriptor_writes.items.len), descriptor_writes.items.ptr, 0, null);
    }

    pub fn updateDescriptorSets(descriptor: *Descriptor, gpu: *Gpu, options: WriteOptions) !void {
        if (descriptor.queue) |queue| {
            try queue.appendSet(options, descriptor);
        } else {
            try gpu.vkd.deviceWaitIdle(gpu.dev);
            try descriptor.updateSets(gpu, options);
        }
    }
};

pub const Compute = struct {
    global_ubo: bool,

    descriptor: Descriptor,
    gpu: *Gpu,

    compute_semaphores: []vk.Semaphore,
    compute_fences: []vk.Fence,

    count_x: u32,
    count_y: u32,
    count_z: u32,

    pub fn setCount(compute: *Compute, x: u32, y: u32, z: u32) void {
        compute.count_x = x;
        compute.count_y = y;
        compute.count_z = z;
    }

    pub fn init(ally: std.mem.Allocator, options: struct {
        win: *Window,
        compute: ComputePipeline,
        queue: ?*OpQueue = null,
    }) !Compute {
        const gpu = &options.win.gpu;

        const compute_semaphores = try ally.alloc(vk.Semaphore, frames_in_flight);
        for (compute_semaphores) |*f| {
            f.* = try gpu.vkd.createSemaphore(gpu.dev, &.{}, null);
            if (builtin.mode == .Debug) {
                try addDebugMark(gpu.*, .semaphore, @intFromEnum(f.*), "compute semaphore");
            }
        }

        const compute_fences = try ally.alloc(vk.Fence, frames_in_flight);
        for (compute_fences) |*f| {
            f.* = try gpu.vkd.createFence(gpu.dev, &.{ .flags = .{ .signaled_bit = true } }, null);
            if (builtin.mode == .Debug) {
                try addDebugMark(gpu.*, .fence, @intFromEnum(f.*), "compute fence");
            }
        }

        return .{
            .global_ubo = options.compute.description.global_ubo,
            .descriptor = try Descriptor.init(ally, .{ .gpu = gpu, .pipeline = options.compute.pipeline, .queue = null }),
            .compute_semaphores = compute_semaphores,
            .compute_fences = compute_fences,
            .gpu = gpu,
            .count_x = 0,
            .count_y = 0,
            .count_z = 0,
        };
    }

    pub fn deinit(compute: *Compute, ally: std.mem.Allocator) void {
        const gpu = compute.gpu;

        gpu.vkd.deviceWaitIdle(gpu.dev) catch {};

        for (compute.compute_semaphores) |s| gpu.vkd.destroySemaphore(gpu.dev, s, null);
        ally.free(compute.compute_semaphores);

        for (compute.compute_fences) |f| gpu.vkd.destroyFence(gpu.dev, f, null);
        ally.free(compute.compute_fences);

        compute.descriptor.deinit(ally);
    }

    pub fn wait(compute: *Compute, frame_id: usize) !void {
        const gpu = compute.gpu;

        _ = try gpu.vkd.waitForFences(gpu.dev, 1, @ptrCast(&compute.compute_fences[frame_id]), vk.TRUE, std.math.maxInt(u64));
        try gpu.vkd.resetFences(gpu.dev, 1, @ptrCast(&compute.compute_fences[frame_id]));
    }

    pub fn submit(compute: *Compute, ally: std.mem.Allocator, builder: CommandBuilder, options: struct {
        wait: []const struct {
            semaphore: vk.Semaphore,
            type: enum {
                color,
                vertex,
            },
        } = &.{},
    }) !void {
        const gpu = compute.gpu;

        const wait_stage = try ally.alloc(vk.PipelineStageFlags, options.wait.len);
        defer ally.free(wait_stage);

        const semaphores = try ally.alloc(vk.Semaphore, options.wait.len);
        defer ally.free(wait_stage);

        for (semaphores, options.wait) |*dst, src| dst.* = src.semaphore;

        for (wait_stage, options.wait) |*stage, semaphore| {
            switch (semaphore.type) {
                .color => stage.* = .{ .color_attachment_output_bit = true },
                .vertex => stage.* = .{ .vertex_input_bit = true },
            }
        }

        const cmdbuf = builder.getCurrent();

        try gpu.vkd.queueSubmit(gpu.compute_queue.handle, 1, &[_]vk.SubmitInfo{.{
            .wait_semaphore_count = @intCast(semaphores.len),
            // best practice according to amd!
            .p_wait_semaphores = if (semaphores.len == 0) null else semaphores.ptr,
            .p_wait_dst_stage_mask = wait_stage.ptr,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&cmdbuf),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(&compute.compute_semaphores[builder.frame_id]),
        }}, compute.compute_fences[builder.frame_id]);
    }

    pub fn dispatch(compute: *Compute, command_buffer: vk.CommandBuffer, options: struct {
        frame_id: usize,
        bind_pipeline: bool,
    }) !void {
        const gpu = compute.gpu;

        if (options.bind_pipeline) gpu.vkd.cmdBindPipeline(command_buffer, .compute, compute.descriptor.pipeline.vk_pipeline);
        gpu.vkd.cmdBindDescriptorSets(
            command_buffer,
            .compute,
            compute.descriptor.pipeline.layout,
            0,
            @intCast(compute.descriptor.descriptor_sets.len),
            compute.descriptor.descriptor_sets.ptr,
            0,
            null,
        );

        gpu.vkd.cmdDispatch(command_buffer, compute.count_x, compute.count_y, compute.count_z);
    }
};

pub const RenderTarget = union(enum) {
    texture: TextureTarget,
    swapchain: void,

    pub const TextureTarget = struct {
        region: struct {
            x: f32 = 0,
            y: f32 = 0,
        },
        color_textures: []const *Texture,
        depth_texture: ?*const Texture = null,

        pub fn eql(a: TextureTarget, b: TextureTarget) bool {
            if (a.color_textures.len != b.color_textures.len) return false;
            for (a.color_textures, b.color_textures) |ca, cb| {
                if (ca != cb) return false;
            }
            if (a.depth_texture != b.depth_texture) return false;
            return true;
        }
    };

    pub fn eql(a: RenderTarget, b: RenderTarget) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .texture => |at| at.eql(b.texture),
            .swapchain => |_| true,
        };
    }
};

pub const Drawing = struct {
    vert_count: usize,
    instances: u32 = 1,
    global_ubo: bool,

    descriptor: Descriptor,
    vertex_buffer: ?BufferHandle,
    index_buffer: ?BufferHandle,

    render_target: RenderTarget,
    flip_z: Flip,

    pub const Flip = enum {
        true,
        false,
        auto,
    };

    pub const Info = struct {
        pipeline: RenderPipeline,
        queue: ?*OpQueue = null,
        target: RenderTarget,
        flip_z: Flip = .auto,
    };

    pub fn init(drawing: *Drawing, ally: std.mem.Allocator, gpu: *Gpu, options: Info) !void {
        drawing.* = .{
            .vert_count = 0,
            .global_ubo = options.pipeline.pipeline.description.global_ubo,
            .descriptor = try Descriptor.init(ally, gpu, .{ .pipeline = options.pipeline.pipeline, .queue = options.queue }),
            .vertex_buffer = null,
            .index_buffer = null,
            .render_target = options.target,
            .flip_z = options.flip_z,
        };

        if (drawing.global_ubo) {
            try drawing.descriptor.setUniformOrCreate(GlobalUniform, gpu, 0, 0, 0, .{
                .time = 0,
                .in_resolution = .{ 0, 0 },
            });
        }
    }

    pub fn deinit(self: *Drawing, ally: std.mem.Allocator, gpu: Gpu) void {
        self.descriptor.deinit(ally, gpu);

        //if (self.index_buffer) |ib| ib.deinit(&win.gpu);
        //if (self.vertex_buffer) |vb| vb.deinit(&win.gpu);
    }

    pub fn deinitAllBuffers(drawing: *Drawing, ally: std.mem.Allocator, gpu: Gpu) void {
        drawing.vertex_buffer.?.deinit(gpu);
        drawing.index_buffer.?.deinit(gpu);
        drawing.descriptor.deinitAllUniforms(gpu);
        drawing.deinit(ally, gpu);
    }

    pub fn draw(drawing: *Drawing, gpu: *Gpu, command_buffer: vk.CommandBuffer, options: struct {
        swapchain: Swapchain,
        frame_id: usize,
        bind_pipeline: bool,
    }) !void {
        const extent = options.swapchain.extent;
        const resolution: [2]f32 = .{ @floatFromInt(extent.width), @floatFromInt(extent.height) };
        const now: f32 = @floatCast(glfw.glfwGetTime());

        if (drawing.global_ubo) {
            try drawing.descriptor.setUniformOrCreate(GlobalUniform, gpu, 0, 0, 0, .{ .time = now, .in_resolution = resolution });
        }

        if (options.bind_pipeline) gpu.vkd.cmdBindPipeline(command_buffer, .graphics, drawing.descriptor.pipeline.vk_pipeline);

        if (drawing.instances == 0 or drawing.vert_count == 0) return;

        const offset = [_]vk.DeviceSize{0};
        if (drawing.vertex_buffer) |vb| gpu.vkd.cmdBindVertexBuffers(command_buffer, 0, 1, @ptrCast(&vb.buff_mem.buffer), &offset);
        gpu.vkd.cmdBindDescriptorSets(
            command_buffer,
            .graphics,
            drawing.descriptor.pipeline.layout,
            0,
            @intCast(drawing.descriptor.descriptor_sets.len),
            drawing.descriptor.descriptor_sets.ptr,
            0,
            null,
        );
        if (drawing.index_buffer) |ib| {
            gpu.vkd.cmdBindIndexBuffer(command_buffer, ib.buff_mem.buffer, 0, .uint32);
            gpu.vkd.cmdDrawIndexed(command_buffer, @intCast(drawing.vert_count), drawing.instances, 0, 0, 0);
        } else gpu.vkd.cmdDraw(command_buffer, @intCast(drawing.vert_count), drawing.instances, 0, 0);
    }

    pub fn destroyVertex(drawing: *Drawing, gpu: *Gpu) !void {
        if (drawing.vertex_buffer) |vb| {
            if (drawing.descriptor.queue) |queue| {
                try queue.appendBufferDeletion(vb);
            } else {
                try gpu.vkd.deviceWaitIdle(gpu.dev);
                vb.deinit(gpu.*);
            }
        }

        if (drawing.index_buffer) |vb| {
            if (drawing.descriptor.queue) |queue| {
                try queue.appendBufferDeletion(vb);
            } else {
                try gpu.vkd.deviceWaitIdle(gpu.dev);
                vb.deinit(gpu.*);
            }
        }
    }
};

const MapType = struct {
    *anyopaque,
    *Window,
};

pub fn initGraphics(ally: std.mem.Allocator) !void {
    if (glfw.glfwInit() == glfw.GLFW_FALSE) return GlfwError.FailedGlfwInit;

    //@breakpoint();
    if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
        std.log.err("GLFW could not find libvulkan", .{});
        return error.NoVulkan;
    }

    windowMap = std.AutoHashMap(*glfw.GLFWwindow, MapType).init(ally);
    global_object_map = std.AutoHashMap(u64, []const u8).init(ally);

    _ = freetype.FT_Init_FreeType(&ft_lib);
}

pub fn deinitGraphics() void {
    windowMap.?.deinit();
    _ = freetype.FT_Done_FreeType(ft_lib);
}

const GlfwError = error{
    FailedGlfwInit,
    FailedGlfwWindow,
};

pub const Square = struct {
    pub const vertices = [_]f32{
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
        1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    };
    pub const indices = [_]u32{
        0, 1, 2, 2, 3, 0,
    };
};

fn printError(err: anyerror) noreturn {
    var buf: [2048]u8 = undefined;
    @panic(std.fmt.bufPrint(&buf, "error: {s}", .{@errorName(err)}) catch @panic("error name too long"));
}

pub fn getGlfwCursorPos(win_or: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |map| {
        const win = map[1];
        if (win.events.cursor_func) |fun| {
            fun(map[0], xpos, ypos) catch |err| {
                printError(err);
            };
        }
    }
}

pub const Action = enum(i32) {
    release = 0,
    press = 1,
    repeat = 2,
};

pub fn getGlfwMouseButton(win_or: ?*glfw.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |map| {
        const win = map[1];
        if (win.events.mouse_func) |fun| {
            fun(map[0], button, @enumFromInt(action), mods) catch |err| {
                printError(err);
            };
        }
    }
}

pub fn getGlfwKey(win_or: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |map| {
        const win = map[1];
        if (win.events.key_func) |fun| {
            fun(map[0], key, scancode, @enumFromInt(action), mods) catch |err| {
                printError(err);
            };
        }
    }
}

pub fn getGlfwChar(win_or: ?*glfw.GLFWwindow, codepoint: c_uint) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |map| {
        const win = map[1];
        if (win.events.char_func) |fun| {
            fun(map[0], codepoint) catch |err| {
                printError(err);
            };
        }
    }
}

pub fn getFramebufferSize(win_or: ?*glfw.GLFWwindow, in_width: c_int, in_height: c_int) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |map| {
        var win = map[1];
        var swapchain = &map[1].swapchain;

        win.gpu.vkd.deviceWaitIdle(win.gpu.dev) catch |err| {
            printError(err);
        };

        if (win.fixed_size) {
            _ = glfw.glfwSetWindowSize(glfw_win, win.frame_width, win.frame_height);
            if (!win.size_dirty) return;
        }

        swapchain.recreate(&win.gpu, .{ .width = @intCast(in_width), .height = @intCast(in_height) }, win.preferred_format) catch |err| {
            printError(err);
        };

        const width: i32 = @intCast(swapchain.extent.width);
        const height: i32 = @intCast(swapchain.extent.height);

        win.destroyFramebuffers();
        win.depth_buffer.deinit(&win.gpu);
        win.depth_buffer = Window.createDepthBuffer(&win.gpu, swapchain.*, win.pool) catch |err| {
            printError(err);
        };

        win.framebuffers = Window.createFramebuffers(&win.gpu, win.ally, win.render_pass.pass, swapchain.*, win.depth_buffer) catch |err| {
            printError(err);
        };

        //gl.viewport(0, 0, width, height);

        win.frame_width = width;
        win.frame_height = height;

        win.viewport_width = width;
        win.viewport_height = height;

        if (win.events.frame_func) |fun| {
            fun(map[0], width, height) catch |err| {
                printError(err);
            };
        }
    }
}

pub fn getScroll(win_or: ?*glfw.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |map| {
        const win = map[1];
        if (win.events.scroll_func) |fun| {
            fun(map[0], xoffset, yoffset) catch |err| {
                printError(err);
            };
        }
    }
}

pub fn waitGraphicsEvent() void {
    glfw.glfwPollEvents();
}

pub const EventTable = struct {
    key_func: ?*const fn (*anyopaque, i32, i32, Action, i32) anyerror!void,
    char_func: ?*const fn (*anyopaque, u32) anyerror!void,
    frame_func: ?*const fn (*anyopaque, i32, i32) anyerror!void,
    scroll_func: ?*const fn (*anyopaque, f64, f64) anyerror!void,
    mouse_func: ?*const fn (*anyopaque, i32, Action, i32) anyerror!void,
    cursor_func: ?*const fn (*anyopaque, f64, f64) anyerror!void,
};

pub const PreferredFormat = enum {
    unorm,
    srgb,
    depth,
    float,

    pub fn getSurfaceFormat(format: PreferredFormat, gpu: Gpu) vk.Format {
        return switch (format) {
            .srgb => .b8g8r8a8_srgb,
            .unorm => .b8g8r8a8_unorm,
            .depth => gpu.depth_format,
            .float => .r32_sfloat,
        };
    }
};

pub const WindowInfo = struct {
    width: i32 = 256,
    height: i32 = 256,
    resizable: bool = true,
    preferred_format: PreferredFormat = .srgb,
    name: [:0]const u8 = "default name",
};

pub const Framebuffer = struct {
    pub const FramebufferInfo = struct {
        // TODO: change this to a Texture instead
        attachments: []const vk.ImageView,
        render_pass: vk.RenderPass,

        width: u32,
        height: u32,
        layers: u32 = 1,
    };
    buffer: vk.Framebuffer,

    pub fn deinit(fb: Framebuffer, gpu: Gpu) void {
        gpu.vkd.destroyFramebuffer(gpu.dev, fb.buffer, null);
    }
    pub fn init(gpu: *const Gpu, options: FramebufferInfo) !Framebuffer {
        const buffer = try gpu.vkd.createFramebuffer(gpu.dev, &.{
            .render_pass = options.render_pass,
            .attachment_count = @intCast(options.attachments.len),
            .p_attachments = options.attachments.ptr,
            .width = options.width,
            .height = options.height,
            .layers = options.layers,
        }, null);
        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .framebuffer, @intFromEnum(buffer), "framebuffer");
        }
        return .{
            .buffer = buffer,
        };
    }
};

pub const RenderPass = struct {
    pass: vk.RenderPass,
    info: Info,

    pub const Info = struct {
        format: vk.Format,
        color: bool = true,
        depth: bool = true,
        multisampling: bool = false,
        target: bool = false,
    };

    pub fn init(gpu: *const Gpu, info: Info) !RenderPass {
        const color_attachment: vk.AttachmentDescription = .{
            .format = info.format,
            .samples = if (info.multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = blk: {
                if (info.multisampling) break :blk .color_attachment_optimal;
                if (info.target) {
                    break :blk .shader_read_only_optimal;
                } else {
                    break :blk .present_src_khr;
                }
            },
        };

        var color_attachment_ref: vk.AttachmentReference = .{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const depth_attachment: vk.AttachmentDescription = .{
            .format = try gpu.findDepthFormat(),
            .samples = if (info.multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .depth_stencil_attachment_optimal,
        };

        var depth_attachment_ref: vk.AttachmentReference = .{
            .attachment = 1,
            .layout = .depth_stencil_attachment_optimal,
        };

        const color_resolve_attachment: vk.AttachmentDescription = .{
            .format = info.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = blk: {
                if (info.target) {
                    break :blk .shader_read_only_optimal;
                } else {
                    break :blk .present_src_khr;
                }
            },
        };

        var color_resolve_attachment_ref: vk.AttachmentReference = .{
            .attachment = 2,
            .layout = .color_attachment_optimal,
        };

        const color_dependency: vk.SubpassDependency = .{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true },
        };

        const depth_dependency: vk.SubpassDependency = .{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .dst_access_mask = .{ .depth_stencil_attachment_write_bit = true },
        };

        const target_first_dependency: vk.SubpassDependency = .{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .fragment_shader_bit = true },
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{ .shader_read_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true },
        };

        const target_second_dependency: vk.SubpassDependency = .{
            .src_subpass = 0,
            .dst_subpass = vk.SUBPASS_EXTERNAL,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_stage_mask = .{ .fragment_shader_bit = true },
            .src_access_mask = .{ .color_attachment_write_bit = true },
            .dst_access_mask = .{ .shader_read_bit = true },
        };

        var dependency_buff: [8]vk.SubpassDependency = undefined;
        var attachment_buff: [8]vk.AttachmentDescription = undefined;

        const dependencies: []const vk.SubpassDependency = blk: {
            if (info.target) {
                break :blk &.{ target_first_dependency, target_second_dependency };
            } else {
                var i: usize = 0;
                if (info.color) {
                    dependency_buff[i] = color_dependency;
                    i += 1;
                }

                if (info.depth) {
                    dependency_buff[i] = depth_dependency;
                    i += 1;
                }
                break :blk dependency_buff[0..i];
            }
        };

        const attachments: []const vk.AttachmentDescription = blk: {
            var i: usize = 0;
            if (info.color) {
                color_attachment_ref.attachment = @intCast(i);
                attachment_buff[i] = color_attachment;
                i += 1;
            }

            if (info.depth) {
                depth_attachment_ref.attachment = @intCast(i);
                attachment_buff[i] = depth_attachment;
                i += 1;
            }

            if (info.multisampling) {
                color_resolve_attachment_ref.attachment = @intCast(i);
                attachment_buff[i] = color_resolve_attachment;
                i += 1;
            }

            break :blk attachment_buff[0..i];
        };

        const subpass: vk.SubpassDescription = .{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = if (info.color) 1 else 0,
            .p_color_attachments = if (info.color) @ptrCast(&color_attachment_ref) else null,
            .p_depth_stencil_attachment = if (info.depth) @ptrCast(&depth_attachment_ref) else null,
            .p_resolve_attachments = if (info.multisampling) @ptrCast(&color_resolve_attachment_ref) else null,
        };

        const pass = try gpu.vkd.createRenderPass(gpu.dev, &.{
            .attachment_count = @intCast(attachments.len),
            .p_attachments = attachments.ptr,
            .subpass_count = 1,
            .p_subpasses = @as([*]const vk.SubpassDescription, @ptrCast(&subpass)),
            .dependency_count = @intCast(dependencies.len),
            .p_dependencies = dependencies.ptr,
        }, null);
        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .render_pass, @intFromEnum(pass), "render pass");
        }

        return .{
            .pass = pass,
            .info = info,
        };
    }

    pub fn deinit(pass: RenderPass, gpu: *const Gpu) void {
        gpu.vkd.destroyRenderPass(gpu.dev, pass.pass, null);
    }
};

pub const RenderRegion = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};

const debug_command_builder = false;

pub const CommandBuilder = struct {
    buffers: []vk.CommandBuffer,
    frame_id: usize,

    pub fn pipelineBarrier(
        builder: CommandBuilder,
        gpu: *const Gpu,
        options: struct {
            src_stage: vk.PipelineStageFlags = .{},
            dst_stage: vk.PipelineStageFlags = .{},

            image_barriers: []const struct {
                old_layout: vk.ImageLayout,
                new_layout: vk.ImageLayout,
                layer_count: u32 = 1,

                src_access: vk.AccessFlags,
                dst_access: vk.AccessFlags,

                image: vk.Image,
            } = &.{},

            memory_barriers: []const struct {
                src_access: vk.AccessFlags,
                dst_access: vk.AccessFlags,
            } = &.{},
        },
    ) void {
        if (debug_command_builder) {
            std.debug.print(
                \\pipelineBarrier {{
                \\    src_stage: {any}
                \\    dst_stage: {any}
                \\    image_barriers {{
                \\
            , .{
                options.src_stage,
                options.dst_stage,
            });

            for (options.image_barriers) |barrier| {
                std.debug.print(
                    \\        old_layout: {any},
                    \\        new_layout: {any},
                    \\        layer_count: {},
                    \\
                    \\        src_acces: {any},
                    \\        dst_access: {any},
                    \\
                    \\        image: {any},
                , .{
                    barrier.old_layout,
                    barrier.new_layout,
                    barrier.layer_count,
                    barrier.src_access,
                    barrier.dst_access,
                    barrier.image,
                });
            }

            std.debug.print("    }}\n", .{});
            std.debug.print("}}\n", .{});
        }
        const cmdbuf = builder.getCurrent();

        var image_buf: [256]vk.ImageMemoryBarrier = undefined;

        for (image_buf[0..options.image_barriers.len], options.image_barriers) |*ptr, barrier| {
            ptr.* = .{
                .old_layout = barrier.old_layout,
                .new_layout = barrier.new_layout,
                .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .image = barrier.image,
                .subresource_range = .{
                    // stencil also has to be marked if the format supports it
                    .aspect_mask = blk: {
                        if (barrier.new_layout == .depth_stencil_attachment_optimal or barrier.old_layout == .depth_stencil_attachment_optimal) {
                            break :blk .{ .depth_bit = true };
                        } else {
                            break :blk .{ .color_bit = true };
                        }
                    },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = barrier.layer_count,
                },
                .src_access_mask = barrier.src_access,
                .dst_access_mask = barrier.dst_access,
            };
        }

        var mem_buf: [256]vk.MemoryBarrier = undefined;

        for (mem_buf[0..options.memory_barriers.len], options.memory_barriers) |*ptr, barrier| {
            ptr.* = .{
                .src_access_mask = barrier.src_access,
                .dst_access_mask = barrier.dst_access,
            };
        }

        gpu.vkd.cmdPipelineBarrier(
            cmdbuf,
            options.src_stage,
            options.dst_stage,
            .{},
            @intCast(options.memory_barriers.len),
            &mem_buf,
            0,
            null,
            @intCast(options.image_barriers.len),
            &image_buf,
        );
    }

    pub fn transitionSwapimage(builder: *CommandBuilder, gpu: *Gpu, swapimage: vk.Image) void {
        builder.pipelineBarrier(gpu, .{
            .src_stage = .{ .color_attachment_output_bit = true },
            .dst_stage = .{ .bottom_of_pipe_bit = true },
            .image_barriers = &.{
                .{
                    .image = swapimage,
                    .src_access = .{ .color_attachment_write_bit = true },
                    .dst_access = .{},
                    .old_layout = .color_attachment_optimal,
                    .new_layout = .present_src_khr,
                },
            },
        });
    }

    pub fn beginRendering(
        builder: CommandBuilder,
        gpu: *Gpu,
        options: struct {
            region: RenderRegion,
            // get from a function
            color_attachments: []const vk.RenderingAttachmentInfo,
            depth_attachment: ?vk.RenderingAttachmentInfo = null,
        },
    ) void {
        if (debug_command_builder) {
            std.debug.print(
                \\beginRendering {{
                \\    region: {any},
                \\    color_attachments: {any},
                \\    depth_attachment: {any},
                \\}}
                \\
            , .{ options.region, options.color_attachments, options.depth_attachment });
        }
        const cmdbuf = builder.getCurrent();

        const render_area = vk.Rect2D{
            .offset = .{ .x = options.region.x, .y = options.region.y },
            .extent = .{ .width = options.region.width, .height = options.region.height },
        };

        const depth_ptr: ?*const vk.RenderingAttachmentInfo = if (options.depth_attachment) |*d| d else null;

        gpu.vkd.cmdBeginRendering(cmdbuf, &.{
            .p_color_attachments = options.color_attachments.ptr,
            .color_attachment_count = @intCast(options.color_attachments.len),
            .p_depth_attachment = depth_ptr,
            .layer_count = 1,
            .render_area = render_area,

            // ?
            .view_mask = 0,
        });
    }

    pub fn endRendering(builder: *CommandBuilder, gpu: *Gpu) void {
        const cmdbuf = builder.getCurrent();
        gpu.vkd.cmdEndRendering(cmdbuf);
    }

    pub fn beginRenderPass(builder: CommandBuilder, gpu: *Gpu, render_pass: RenderPass, framebuffer: Framebuffer, region: RenderRegion) void {
        const cmdbuf = builder.getCurrent();

        const clear_color = vk.ClearValue{
            .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
        };
        const clear_depth = vk.ClearValue{
            .depth_stencil = .{ .depth = 1, .stencil = 0 },
        };

        const render_area = vk.Rect2D{
            .offset = .{ .x = region.x, .y = region.y },
            .extent = .{ .width = region.width, .height = region.height },
        };

        const clear_values: []const vk.ClearValue = blk: {
            if (render_pass.info.multisampling) {
                break :blk &.{ clear_color, clear_depth, clear_color };
            } else {
                break :blk &.{ clear_color, clear_depth };
            }
        };

        gpu.vkd.cmdBeginRenderPass(cmdbuf, &.{
            .render_pass = render_pass.pass,
            .framebuffer = framebuffer.buffer,
            .render_area = render_area,
            .clear_value_count = @intCast(clear_values.len),
            .p_clear_values = clear_values.ptr,
        }, .@"inline");
    }

    pub fn transitionLayoutTexture(builder: *CommandBuilder, gpu: *Gpu, tex: *Texture, options: TransitionOptions) !void {
        const cmdbuf = builder.getCurrent();
        try recordTransitionImageLayout(gpu, cmdbuf, tex.image, options);

        tex.current_layout = options.new_layout;
    }

    pub fn transitionLayout(builder: *CommandBuilder, gpu: *Gpu, image: vk.Image, options: TransitionOptions) !void {
        const cmdbuf = builder.getCurrent();
        try recordTransitionImageLayout(gpu, cmdbuf, image, options);
    }

    pub fn setViewport(builder: *CommandBuilder, gpu: *Gpu, info: struct { flip_z: bool, width: u32, height: u32 }) !void {
        if (debug_command_builder) {
            std.debug.print("{any}\n", .{info});
        }

        const cmdbuf = builder.getCurrent();
        if (info.flip_z) {
            gpu.vkd.cmdSetViewport(cmdbuf, 0, 1, @ptrCast(&vk.Viewport{
                .x = 0,
                .y = @as(f32, @floatFromInt(info.height)),
                .width = @as(f32, @floatFromInt(info.width)),
                .height = -@as(f32, @floatFromInt(info.height)),
                .min_depth = 0,
                .max_depth = 1,
            }));
        } else {
            gpu.vkd.cmdSetViewport(cmdbuf, 0, 1, @ptrCast(&vk.Viewport{
                .x = 0,
                .y = 0,
                .width = @as(f32, @floatFromInt(info.width)),
                .height = @as(f32, @floatFromInt(info.height)),
                .min_depth = 0,
                .max_depth = 1,
            }));
        }
        gpu.vkd.cmdSetScissor(cmdbuf, 0, 1, @ptrCast(&vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = info.width, .height = info.height },
        }));
    }

    pub fn push(builder: *CommandBuilder, comptime self: DataDescription, gpu: *Gpu, pipeline: Pipeline, constants: *const self.T) void {
        const cmdbuf = builder.getCurrent();
        gpu.vkd.cmdPushConstants(
            cmdbuf,
            pipeline.layout,
            switch (pipeline.type) {
                .compute => .{ .compute_bit = true },
                .render => .{ .vertex_bit = true, .fragment_bit = true },
            },
            0,
            @intCast(self.getSize()),
            @alignCast(@ptrCast(constants)),
        );
    }

    pub fn beginCommand(builder: *CommandBuilder, gpu: *Gpu) !void {
        const cmdbuf = builder.getCurrent();
        try gpu.vkd.resetCommandBuffer(cmdbuf, .{});
        try gpu.vkd.beginCommandBuffer(cmdbuf, &.{});
    }

    pub fn endRenderPass(builder: *CommandBuilder, gpu: *Gpu) void {
        const cmdbuf = builder.getCurrent();
        gpu.vkd.cmdEndRenderPass(cmdbuf);
    }

    pub fn endCommand(builder: *CommandBuilder, gpu: *Gpu) !void {
        const cmdbuf = builder.getCurrent();

        //if (builder.current_rendering != null) builder.endRendering(gpu);
        //builder.current_rendering = null;

        try gpu.vkd.endCommandBuffer(cmdbuf);
    }

    pub fn getCurrent(builder: CommandBuilder) vk.CommandBuffer {
        //return builder.buffers[builder.frame_id];
        return builder.buffers[0];
    }

    pub fn next(builder: *CommandBuilder) void {
        //builder.frame_id = (builder.frame_id + 1) % frames_in_flight;
        builder.frame_id = 0;
    }
    pub fn init(gpu: *Gpu, pool: vk.CommandPool, ally: std.mem.Allocator) !CommandBuilder {
        const cmd_buffs = try ally.alloc(vk.CommandBuffer, frames_in_flight);

        try gpu.vkd.allocateCommandBuffers(gpu.dev, &.{
            .command_pool = pool,
            .level = .primary,
            .command_buffer_count = @as(u32, @truncate(cmd_buffs.len)),
        }, cmd_buffs.ptr);

        return .{
            .buffers = cmd_buffs,
            .frame_id = 0,
        };
    }

    pub fn deinit(builder: CommandBuilder, gpu: *Gpu, pool: vk.CommandPool, ally: std.mem.Allocator) void {
        gpu.vkd.freeCommandBuffers(gpu.dev, pool, @intCast(builder.buffers.len), builder.buffers.ptr);
        ally.free(builder.buffers);
    }
};

pub const Window = struct {
    glfw_win: *glfw.GLFWwindow,
    alive: bool,

    frame_width: i32,
    frame_height: i32,

    viewport_width: i32,
    viewport_height: i32,

    fixed_size: bool,
    size_dirty: bool,
    preferred_format: PreferredFormat,
    ally: std.mem.Allocator,

    events: EventTable,

    gpu: Gpu,
    swapchain: Swapchain,
    render_pass: RenderPass,
    pool: vk.CommandPool,
    framebuffers: []Framebuffer,
    depth_buffer: DepthBuffer,

    default_shaders: DefaultShaders,

    rendering_options: RenderingOptions,

    const DepthBuffer = struct {
        image: vk.Image,
        view: vk.ImageView,
        memory: vk.DeviceMemory,

        pub fn deinit(buffer: DepthBuffer, gpu: *const Gpu) void {
            gpu.vkd.destroyImageView(gpu.dev, buffer.view, null);
            gpu.vkd.destroyImage(gpu.dev, buffer.image, null);
            gpu.vkd.freeMemory(gpu.dev, buffer.memory, null);
        }
    };

    const DefaultShaders = struct {
        sprite_shaders: [2]Shader,
        sprite_batch_shaders: [2]Shader,
        color_shaders: [2]Shader,
        text_shaders: [2]Shader,
        textft_shaders: [2]Shader,
        post_shaders: [2]Shader,
        line_shaders: [2]Shader,

        pub fn init(gpu: Gpu) !DefaultShaders {
            const sprite_vert = try Shader.init(gpu, &elem_shaders.sprite_vert, .vertex);
            const sprite_frag = try Shader.init(gpu, &elem_shaders.sprite_frag, .fragment);

            const sprite_batch_vert = try Shader.init(gpu, &elem_shaders.sprite_batch_vert, .vertex);
            const sprite_batch_frag = try Shader.init(gpu, &elem_shaders.sprite_batch_frag, .fragment);

            const color_vert = try Shader.init(gpu, &elem_shaders.color_vert, .vertex);
            const color_frag = try Shader.init(gpu, &elem_shaders.color_frag, .fragment);

            const text_vert = try Shader.init(gpu, &elem_shaders.text_vert, .vertex);
            const text_frag = try Shader.init(gpu, &elem_shaders.text_frag, .fragment);

            const textft_vert = try Shader.init(gpu, &elem_shaders.textft_vert, .vertex);
            const textft_frag = try Shader.init(gpu, &elem_shaders.textft_frag, .fragment);

            const post_vert = try Shader.init(gpu, &elem_shaders.post_vert, .vertex);
            const post_frag = try Shader.init(gpu, &elem_shaders.post_frag, .fragment);

            const line_vert = try Shader.init(gpu, &elem_shaders.line_vert, .vertex);
            const line_frag = try Shader.init(gpu, &elem_shaders.line_frag, .fragment);

            return .{
                .sprite_shaders = .{ sprite_vert, sprite_frag },
                .sprite_batch_shaders = .{ sprite_batch_vert, sprite_batch_frag },
                .color_shaders = .{ color_vert, color_frag },
                .text_shaders = .{ text_vert, text_frag },
                .textft_shaders = .{ textft_vert, textft_frag },
                .post_shaders = .{ post_vert, post_frag },
                .line_shaders = .{ line_vert, line_frag },
            };
        }

        pub fn deinit(self: DefaultShaders, gpu: Gpu) void {
            for (self.sprite_shaders) |s| s.deinit(gpu);
            for (self.sprite_batch_shaders) |s| s.deinit(gpu);
            for (self.color_shaders) |s| s.deinit(gpu);
            for (self.text_shaders) |s| s.deinit(gpu);
            for (self.textft_shaders) |s| s.deinit(gpu);
            for (self.post_shaders) |s| s.deinit(gpu);
            for (self.line_shaders) |s| s.deinit(gpu);
        }
    };

    pub fn swapBuffers(self: Window) void {
        glfw.glfwSwapBuffers(self.glfw_win);
    }

    pub fn shouldClose(self: Window) bool {
        return glfw.glfwWindowShouldClose(self.glfw_win) != 0;
    }

    pub fn getCursorPos(win: Window) math.Vec2 {
        var x: f64 = 0;
        var y: f64 = 0;
        glfw.glfwGetCursorPos(win.glfw_win, &x, &y);
        return math.Vec2.init(.{ @floatCast(x), @floatCast(y) });
    }

    pub fn getMouseButton(win: Window, button: i32) Action {
        const current_button = glfw.glfwGetMouseButton(win.glfw_win, button);
        return @enumFromInt(current_button);
    }

    pub fn getSize(win: Window) math.Vec2 {
        return math.Vec2.init(.{
            @floatFromInt(win.frame_width),
            @floatFromInt(win.frame_height),
        });
    }

    pub fn setScrollCallback(self: *Window, fun: *const fn (*anyopaque, f64, f64) anyerror!void) void {
        self.events.scroll_func = fun;
    }

    pub fn setKeyCallback(self: *Window, fun: *const fn (*anyopaque, i32, i32, Action, i32) anyerror!void) void {
        self.events.key_func = fun;
    }

    pub fn setCharCallback(self: *Window, fun: *const fn (*anyopaque, u32) anyerror!void) void {
        self.events.char_func = fun;
    }

    pub fn setFrameCallback(self: *Window, fun: *const fn (*anyopaque, i32, i32) anyerror!void) void {
        self.events.frame_func = fun;
    }

    pub fn setMouseButtonCallback(self: *Window, fun: *const fn (*anyopaque, i32, Action, i32) anyerror!void) void {
        self.events.mouse_func = fun;
    }

    pub fn setCursorCallback(self: *Window, fun: *const fn (*anyopaque, f64, f64) anyerror!void) void {
        self.events.cursor_func = fun;
    }

    pub fn addToMap(self: *Window, elem: *anyopaque) !void {
        try windowMap.?.put(self.glfw_win, .{ elem, self });
    }

    pub fn setSize(self: Window, width: u32, height: u32) void {
        glfw.glfwSetWindowSize(self.glfw_win, @intCast(width), @intCast(height));
    }

    fn destroyFramebuffers(self: Window) void {
        for (self.framebuffers) |fb| fb.deinit(self.gpu);
        self.ally.free(self.framebuffers);
    }

    fn createFramebuffers(gpu: *Gpu, allocator: Allocator, render_pass: vk.RenderPass, swapchain: Swapchain, depth_image_or: ?DepthBuffer) ![]Framebuffer {
        const framebuffers = try allocator.alloc(Framebuffer, swapchain.swap_images.len);
        errdefer allocator.free(framebuffers);

        var i: usize = 0;
        errdefer for (framebuffers[0..i]) |fb| gpu.vkd.destroyFramebuffer(gpu.dev, fb.buffer, null);

        for (framebuffers) |*fb| {
            if (depth_image_or) |depth_image| {
                fb.* = try Framebuffer.init(gpu, .{
                    .attachments = &.{ swapchain.swap_images[i].view, depth_image.view },
                    .render_pass = render_pass,
                    .width = swapchain.extent.width,
                    .height = swapchain.extent.height,
                });
            } else {
                fb.* = try Framebuffer.init(gpu, .{
                    .attachments = &.{swapchain.swap_images[i].view},
                    .render_pass = render_pass,
                    .width = swapchain.extent.width,
                    .height = swapchain.extent.height,
                });
            }
            i += 1;
        }

        return framebuffers;
    }

    pub fn createDepthBuffer(gpu: *Gpu, swapchain: Swapchain, pool: vk.CommandPool) !DepthBuffer {
        const format = try gpu.findDepthFormat();

        const width = swapchain.extent.width;
        const height = swapchain.extent.height;
        const image_info: vk.ImageCreateInfo = .{
            .image_type = .@"2d",
            .extent = .{ .width = width, .height = height, .depth = 1 },
            .mip_levels = 1,
            .array_layers = 1,
            .format = format,
            .tiling = .optimal,
            .initial_layout = .undefined,
            .usage = .{ .depth_stencil_attachment_bit = true },
            .samples = .{ .@"1_bit" = true },
            .sharing_mode = .exclusive,
        };

        const image = try gpu.vkd.createImage(gpu.dev, &image_info, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .image, @intFromEnum(image), "depth image");
        }

        const mem_reqs = gpu.vkd.getImageMemoryRequirements(gpu.dev, image);
        const image_memory = try gpu.allocate(mem_reqs, .{ .device_local_bit = true });

        try gpu.vkd.bindImageMemory(gpu.dev, image, image_memory, 0);

        const view_info: vk.ImageViewCreateInfo = .{
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .depth_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        };

        const depth_image_view = try gpu.vkd.createImageView(gpu.dev, &view_info, null);
        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .image_view, @intFromEnum(depth_image_view), "depth image view");
        }
        try transitionImageLayout(gpu, pool, image, .{
            .old_layout = .undefined,
            .new_layout = .depth_stencil_attachment_optimal,
        });

        return .{ .view = depth_image_view, .image = image, .memory = image_memory };
    }
    pub fn init(info: WindowInfo, ally: std.mem.Allocator) !*Window {
        var win = try ally.create(Window);
        win.* = try initBare(info, ally);
        try win.addToMap(win);
        return win;
    }

    pub fn initBare(info: WindowInfo, ally: std.mem.Allocator) !Window {
        glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, if (info.resizable) glfw.GLFW_TRUE else glfw.GLFW_FALSE);
        glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
        const win_or = glfw.glfwCreateWindow(info.width, info.height, info.name, null, null);

        const glfw_win = win_or orelse return GlfwError.FailedGlfwWindow;

        glfw.glfwMakeContextCurrent(glfw_win);
        //glfw.glfwSetWindowAspectRatio(glfw_win, 16, 9);
        _ = glfw.glfwSetKeyCallback(glfw_win, getGlfwKey);
        _ = glfw.glfwSetCharCallback(glfw_win, getGlfwChar);
        _ = glfw.glfwSetFramebufferSizeCallback(glfw_win, getFramebufferSize);
        _ = glfw.glfwSetMouseButtonCallback(glfw_win, getGlfwMouseButton);
        _ = glfw.glfwSetCursorPosCallback(glfw_win, getGlfwCursorPos);
        _ = glfw.glfwSetScrollCallback(glfw_win, getScroll);

        var gpu = try Gpu.init(ally, info.name, glfw_win);

        const swapchain = try Swapchain.init(&gpu, ally, .{ .width = @intCast(info.width), .height = @intCast(info.height) }, info.preferred_format);

        const render_pass = try RenderPass.init(&gpu, .{ .format = swapchain.surface_format.format });

        const pool = gpu.graphics_pool;

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu, .command_pool, @intFromEnum(pool), "command pool");
        }

        const depth_buffer = try createDepthBuffer(&gpu, swapchain, pool);

        const framebuffers = try createFramebuffers(&gpu, ally, render_pass.pass, swapchain, depth_buffer);

        const events: EventTable = .{
            .key_func = null,
            .char_func = null,
            .scroll_func = null,
            .frame_func = null,
            .mouse_func = null,
            .cursor_func = null,
        };

        const color_formats = try ally.alloc(vk.Format, 1);
        color_formats[0] = swapchain.surface_format.format;

        return .{
            .glfw_win = glfw_win,
            .events = events,
            .alive = true,
            .viewport_width = info.width,
            .frame_width = info.width,
            .viewport_height = info.height,
            .frame_height = info.height,
            .fixed_size = !info.resizable,
            .size_dirty = false,
            .ally = ally,
            .preferred_format = info.preferred_format,

            // vulkan
            .gpu = gpu,
            .swapchain = swapchain,
            .render_pass = render_pass,
            .pool = pool,
            .framebuffers = framebuffers,
            .depth_buffer = depth_buffer,
            .default_shaders = try DefaultShaders.init(gpu),

            // useful
            .rendering_options = .{
                .color_formats = color_formats,
                .depth_format = try gpu.findDepthFormat(),
            },
        };
    }

    pub fn deinit(win: *Window) void {
        win.default_shaders.deinit(win.gpu);
        win.gpu.vkd.destroyCommandPool(win.gpu.dev, win.pool, null);

        for (win.framebuffers) |fb| fb.deinit(win.gpu);
        win.ally.free(win.framebuffers);

        win.ally.free(win.rendering_options.color_formats);

        win.render_pass.deinit(&win.gpu);
        win.depth_buffer.deinit(&win.gpu);

        win.swapchain.deinit(&win.gpu);
        win.gpu.deinit();
        glfw.glfwDestroyWindow(win.glfw_win);
        //gl.makeDispatchTableCurrent(null);
        glfw.glfwTerminate();
        win.ally.destroy(win);
    }
};

pub const Transform2D = struct {
    scale: Vec2 = Vec2.init(.{ 1, 1 }),
    rotation: struct { angle: f32 = 0, center: Vec2 = Vec2.init(.{ 0, 0 }) } = .{},
    translation: Vec2 = Vec2.init(.{ 0, 0 }),

    pub fn getMat(self: Transform2D) math.Mat3 {
        return math.transform2D(f32, self.scale, .{ .angle = self.rotation.angle, .center = self.rotation.center }, self.translation);
    }

    pub fn getInverseMat(self: Transform2D) math.Mat3 {
        return math.transform2D(
            f32,
            Vec2.init(.{ 1, 1 }).div(self.scale),
            .{ .angle = -self.rotation.angle, .center = self.rotation.center },
            Vec2.init(.{ -1, -1 }).div(self.scale).mul(self.translation),
        );
    }

    pub fn apply(self: Transform2D, v: Vec2) Vec2 {
        var res: [3]f32 = self.getMat().dot(Vec3.init(.{ v.val[0], v.val[1], 1 })).val;
        return Vec2.init(res[0..2].*);
    }

    pub fn reverse(self: Transform2D, v: Vec2) Vec2 {
        var res: [3]f32 = self.getInverseMat().dot(Vec3.init(.{ v.val[0], v.val[1], 1 })).val;
        return Vec2.init(res[0..2].*);
    }
};

const Uniform1f = struct {
    name: [:0]const u8,
    value: *f32,
};

const Uniform3f = struct {
    name: [:0]const u8,
    value: *Vec3,
};

const Uniform3fv = struct {
    name: [:0]const u8,
    value: *math.Mat3,
};

const Uniform4fv = struct {
    name: [:0]const u8,
    value: *math.Mat4,
};

pub fn embedProcess(comptime source: [:0]const u8) [:0]const u8 {
    const version_idx = comptime std.mem.indexOf(u8, source, "\n").?;
    const processed_source = source[0..version_idx] ++ "\n" ++ @embedFile("common.glsl") ++ source[version_idx..];
    return processed_source;
}

const frames_in_flight = 2;

pub const Scene = @import("Scene.zig");

pub fn getTime() f64 {
    return glfw.glfwGetTime();
}

const RenderType = enum {
    line,
    point,
    triangle,
};

pub const VertexAttribute = struct {
    attribute: enum {
        float,
        short,
        uint,
    } = .float,

    size: usize,

    pub fn getType(comptime self: @This()) type {
        switch (self.attribute) {
            .float => return [self.size]f32,
            .short => return [self.size]i16,
            .uint => return [self.size]u32,
        }
    }

    pub fn getSize(self: @This()) usize {
        switch (self.attribute) {
            .float => return @sizeOf(f32) * self.size,
            .short => return @sizeOf(i16) * self.size,
            .uint => return @sizeOf(u32) * self.size,
        }
    }

    pub fn getVK(self: @This()) !vk.Format {
        switch (self.attribute) {
            .float => {
                if (self.size == 1) {
                    return .r32_sfloat;
                } else if (self.size == 2) {
                    return .r32g32_sfloat;
                } else if (self.size == 3) {
                    return .r32g32b32_sfloat;
                } else if (self.size == 4) {
                    return .r32g32b32a32_sfloat;
                } else {
                    return error.UnsupportedVertexSize;
                }
            },
            .short => return .r16g16_sint,
            .uint => return .r32_uint,
        }
    }
};

pub const VertexDescription = struct {
    vertex_attribs: []const VertexAttribute,

    pub fn getAttributeType(comptime description: VertexDescription) type {
        var fields: []const std.builtin.Type.StructField = &.{};
        for (description.vertex_attribs, 0..) |attrib, i| {
            const T = attrib.getType();
            var num_buf: [128]u8 = undefined;

            fields = fields ++ .{.{
                .name = std.fmt.bufPrintZ(&num_buf, "{d}", .{i}) catch unreachable,
                .type = T,
                .default_value = null,
                .is_comptime = false,
                //.alignment = if (@sizeOf(T) > 0) 1 else 0,
                .alignment = if (@sizeOf(T) > 0) @alignOf(T) else 0,
            }};
        }

        return @Type(.{
            .@"struct" = .{
                .is_tuple = true,
                .layout = .auto,
                .decls = &.{},
                .fields = fields,
            },
        });
    }

    pub fn getVertexSize(description: VertexDescription) usize {
        var total: usize = 0;
        for (description.vertex_attribs) |attrib| {
            total += attrib.getSize();
        }
        return total;
    }

    pub fn createBuffer(comptime description: VertexDescription, gpu: *Gpu, vert_count: usize) !BufferHandle {
        return BufferHandle.init(gpu, .{ .size = vert_count * description.getVertexSize(), .buffer_type = .vertex });
    }

    pub fn bindVertex(
        comptime description: VertexDescription,
        draw: *Drawing,
        gpu: *Gpu,
        vertices: []const description.getAttributeType(),
        indices: []const u32,
        mode: CommandMode,
    ) !void {
        const trace = tracy.trace(@src());
        defer trace.end();

        draw.vert_count = indices.len;

        if (indices.len == 0) return;

        if (mode == .immediate) {
            try draw.destroyVertex(gpu);
        }

        const vertex_buff = try gpu.createStagingBuffer(description.getVertexSize() * vertices.len);
        defer vertex_buff.deinit(gpu.*);

        draw.vertex_buffer = try description.createBuffer(gpu, vertices.len);
        try draw.vertex_buffer.?.setVertex(description, gpu, gpu.graphics_pool, vertices, vertex_buff, mode);

        const index_buff = try gpu.createStagingBuffer(@sizeOf(u32) * indices.len);
        defer index_buff.deinit(gpu.*);

        draw.index_buffer = try BufferHandle.init(gpu, .{ .size = @sizeOf(u32) * indices.len, .buffer_type = .index });
        try draw.index_buffer.?.setIndices(gpu, gpu.graphics_pool, indices, index_buff, mode);
    }
};

const CullType = enum {
    front,
    back,
    front_and_back,
    none,
};

pub const SamplerDescription = struct {
    count: u32 = 1,
    boundless: bool = false,
    type: enum {
        storage,
        combined,
    } = .combined,
};

pub const UniformDescription = struct {
    size: usize,
    boundless: bool = false,
};

pub const BufferDescription = struct {
    size: usize,
    boundless: bool = false,
};

pub const AttachmentDescription = struct {};

pub const Binding = union(enum) {
    uniform: UniformDescription,
    storage: UniformDescription,
    sampler: SamplerDescription,
};

pub const Set = struct {
    bindings: []const Binding,
};

pub const PipelineDescription = struct {
    vertex_description: VertexDescription,
    render_type: RenderType,
    depth_test: bool,
    cull_type: CullType = .none,

    constants_size: ?usize = null,

    sets: []const Set = &.{},
    attachment_descriptions: []const AttachmentDescription = &.{.{}},
    // assume DefaultUbo at index 0
    global_ubo: bool = false,
    bindless: bool = false,

    pub fn getBindingDescription(pipeline: PipelineDescription) vk.VertexInputBindingDescription {
        return .{
            .binding = 0,
            .stride = @intCast(pipeline.vertex_description.getVertexSize()),
            .input_rate = .vertex,
        };
    }
};
pub fn createBindingsFromSets(ally: std.mem.Allocator, gpu: *Gpu, options: struct {
    sets: []const Set,
    bindless: bool,
    type: enum {
        drawing,
        compute,
    },
}) !struct {
    [][]vk.DescriptorSetLayoutBinding,
    []vk.DescriptorSetLayout,
} {
    const set_bindings = try ally.alloc([]vk.DescriptorSetLayoutBinding, options.sets.len);
    const layouts = try ally.alloc(vk.DescriptorSetLayout, options.sets.len);

    for (options.sets, set_bindings, layouts) |set, *bindings, *descriptor_layout| {
        bindings.* = try ally.alloc(vk.DescriptorSetLayoutBinding, set.bindings.len);
        var binding_flags = try ally.alloc(vk.DescriptorBindingFlags, set.bindings.len);
        defer ally.free(binding_flags);

        for (set.bindings, 0..) |binding, idx| {
            const stage_flags: vk.ShaderStageFlags = switch (options.type) {
                .drawing => .{ .vertex_bit = true, .fragment_bit = true },
                .compute => .{ .compute_bit = true, .vertex_bit = true },
            };
            switch (binding) {
                .uniform => |binding_desc| {
                    bindings.*[idx] = .{
                        .binding = @intCast(idx),
                        .descriptor_count = if (binding_desc.boundless) max_boundless else 1,
                        .descriptor_type = .uniform_buffer,
                        .p_immutable_samplers = null,
                        .stage_flags = stage_flags,
                    };

                    binding_flags[idx] = if (binding_desc.boundless) .{
                        .variable_descriptor_count_bit = true,
                        .partially_bound_bit = true,
                        .update_after_bind_bit = true,
                        .update_unused_while_pending_bit = true,
                    } else .{};
                },

                .storage => |binding_desc| {
                    bindings.*[idx] = .{
                        .binding = @intCast(idx),
                        .descriptor_count = if (binding_desc.boundless) max_boundless else 1,
                        .descriptor_type = .storage_buffer,
                        .p_immutable_samplers = null,
                        .stage_flags = stage_flags,
                    };

                    binding_flags[idx] = if (binding_desc.boundless) .{
                        .variable_descriptor_count_bit = true,
                        .partially_bound_bit = true,
                        .update_after_bind_bit = true,
                        .update_unused_while_pending_bit = true,
                    } else .{};
                },

                .sampler => |binding_desc| {
                    bindings.*[idx] = vk.DescriptorSetLayoutBinding{
                        .binding = @intCast(idx),
                        .descriptor_count = if (binding_desc.boundless) max_boundless else binding_desc.count,
                        .descriptor_type = switch (binding_desc.type) {
                            .storage => .storage_image,
                            .combined => .combined_image_sampler,
                        },
                        .p_immutable_samplers = null,
                        .stage_flags = stage_flags,
                    };

                    binding_flags[idx] = if (binding_desc.boundless) .{
                        .variable_descriptor_count_bit = true,
                        .partially_bound_bit = true,
                        .update_after_bind_bit = true,
                        .update_unused_while_pending_bit = true,
                    } else .{};
                },
            }
        }

        const layout_info: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = @intCast(bindings.len),
            .p_bindings = bindings.ptr,
            .flags = .{ .update_after_bind_pool_bit = options.bindless },
            .p_next = &vk.DescriptorSetLayoutBindingFlagsCreateInfo{
                .binding_count = @intCast(bindings.len),
                .p_binding_flags = binding_flags.ptr,
            },
        };

        descriptor_layout.* = try gpu.vkd.createDescriptorSetLayout(gpu.dev, &layout_info, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .descriptor_set_layout, @intFromEnum(descriptor_layout.*), "descriptor layout");
        }
    }
    return .{ set_bindings, layouts };
}

pub const ComputeDescription = struct {
    constants_size: ?usize = null,
    sets: []const Set = &.{},
    attachment_descriptions: []const AttachmentDescription = &.{.{}},
    global_ubo: bool = false,
    bindless: bool = false,
};

pub const ComputePipeline = struct {
    ally: std.mem.Allocator,
    description: GenericPipelineDescription,
    pipeline: Pipeline,

    vk_pipeline: vk.Pipeline,
    layout: vk.PipelineLayout,
    layouts: []vk.DescriptorSetLayout,
    set_bindings: [][]vk.DescriptorSetLayoutBinding,

    pub const Info = struct {
        description: ComputeDescription,
        shader: Shader,
        gpu: *Gpu,
        flipped_z: bool = false,
    };
    pub fn init(ally: std.mem.Allocator, info: Info) !ComputePipeline {
        const description = info.description;
        const gpu = info.gpu;

        const set_bindings, const layouts = try createBindingsFromSets(ally, gpu, .{
            .sets = description.sets,
            .bindless = description.bindless,
            .type = .compute,
        });

        const pipeline_layout = try gpu.vkd.createPipelineLayout(gpu.dev, &.{
            .flags = .{},
            .set_layout_count = @intCast(layouts.len),
            .p_set_layouts = layouts.ptr,
            .push_constant_range_count = if (description.constants_size) |_| 1 else 0,
            .p_push_constant_ranges = if (description.constants_size) |size| @ptrCast(&vk.PushConstantRange{
                .offset = 0,
                .size = @intCast(size),
                .stage_flags = .{ .compute_bit = true },
            }) else undefined,
        }, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .pipeline_layout, @intFromEnum(pipeline_layout), "compute pipeline layout");
        }

        // change shaders system for multiple compute pipelines
        const shader_stage: vk.PipelineShaderStageCreateInfo = .{
            .stage = .{
                .compute_bit = true,
            },
            .module = info.shader.module,
            .p_name = "main",
        };

        var pipeline: vk.Pipeline = undefined;
        _ = try gpu.vkd.createComputePipelines(gpu.dev, .null_handle, 1, @ptrCast(&vk.ComputePipelineCreateInfo{
            .layout = pipeline_layout,
            .stage = shader_stage,
            .base_pipeline_index = 0,
        }), null, @ptrCast(&pipeline));

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .pipeline, @intFromEnum(pipeline), "compute pipeline");
        }

        return .{
            .vk_pipeline = pipeline,
            .layout = pipeline_layout,
            .layouts = layouts,
            .ally = ally,
            .set_bindings = set_bindings,
            .description = .{
                .constants_size = info.description.constants_size,
                .sets = info.description.sets,
                .attachment_descriptions = info.description.attachment_descriptions,
                .global_ubo = info.description.global_ubo,
                .bindless = info.description.bindless,
            },
            .pipeline = .{
                .vk_pipeline = pipeline,
                .layout = pipeline_layout,
                .layouts = layouts,
                .ally = ally,
                .set_bindings = set_bindings,
                .type = .compute,
                .description = .{
                    .constants_size = info.description.constants_size,
                    .sets = info.description.sets,
                    .attachment_descriptions = info.description.attachment_descriptions,
                    .global_ubo = info.description.global_ubo,
                    .bindless = info.description.bindless,
                },
            },
        };
    }

    pub fn deinit(compute: *ComputePipeline, gpu: *const Gpu) void {
        compute.pipeline.deinit(gpu);
    }
};

pub const RenderingOptions = struct {
    color_formats: []const vk.Format,
    depth_format: ?vk.Format,
};

pub const RenderPipeline = struct {
    pipeline: Pipeline,

    pub const Info = struct {
        description: PipelineDescription,
        shaders: []const Shader,
        rendering: RenderingOptions,
        gpu: *Gpu,
        flipped_z: bool = false,
    };
    pub fn init(ally: std.mem.Allocator, info: Info) !RenderPipeline {
        const shaders = info.shaders;
        const description = info.description;
        const gpu = info.gpu;

        const set_bindings, const layouts = try createBindingsFromSets(ally, gpu, .{
            .sets = description.sets,
            .bindless = description.bindless,
            .type = .drawing,
        });

        const pipeline_layout = try gpu.vkd.createPipelineLayout(gpu.dev, &.{
            .flags = .{},
            .set_layout_count = @intCast(layouts.len),
            .p_set_layouts = layouts.ptr,
            .push_constant_range_count = if (description.constants_size) |_| 1 else 0,
            .p_push_constant_ranges = if (description.constants_size) |size| @ptrCast(&vk.PushConstantRange{
                .offset = 0,
                .size = @intCast(size),
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
            }) else undefined,
        }, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .pipeline_layout, @intFromEnum(pipeline_layout), "render pipeline layout");
        }

        var pssci = try ally.alloc(vk.PipelineShaderStageCreateInfo, shaders.len);
        defer ally.free(pssci);
        for (shaders, 0..) |shader, i| {
            pssci[i] = .{
                .stage = .{
                    .fragment_bit = shader.type == .fragment,
                    .vertex_bit = shader.type == .vertex,
                    .compute_bit = shader.type == .compute,
                },
                .module = shader.module,
                .p_name = "main",
            };
        }

        var attribute_desc = try ally.alloc(vk.VertexInputAttributeDescription, description.vertex_description.vertex_attribs.len);
        defer ally.free(attribute_desc);
        {
            var off: u32 = 0;
            for (description.vertex_description.vertex_attribs, 0..) |attrib, i| {
                attribute_desc[i] = .{
                    .binding = 0,
                    .location = @intCast(i),
                    .format = try attrib.getVK(),
                    .offset = off,
                };
                off += @intCast(attrib.getSize()); // ?
            }
        }

        const binding_description = description.getBindingDescription();

        const dynstate = [_]vk.DynamicState{ .viewport, .scissor };

        const attachments = try ally.alloc(vk.PipelineColorBlendAttachmentState, description.attachment_descriptions.len);
        defer ally.free(attachments);
        for (attachments) |*a| {
            a.* = .{
                .blend_enable = vk.TRUE,
                .src_color_blend_factor = .src_alpha,
                .dst_color_blend_factor = .one_minus_src_alpha,
                .color_blend_op = .add,
                .src_alpha_blend_factor = .one,
                .dst_alpha_blend_factor = .one_minus_src_alpha,
                .alpha_blend_op = .add,
                .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
            };
        }

        var vk_pipeline: vk.Pipeline = undefined;
        _ = try gpu.vkd.createGraphicsPipelines(
            gpu.dev,
            .null_handle,
            1,
            @ptrCast(&vk.GraphicsPipelineCreateInfo{
                .flags = .{},
                .stage_count = @intCast(pssci.len),
                .p_stages = pssci.ptr,
                .p_vertex_input_state = &vk.PipelineVertexInputStateCreateInfo{
                    .vertex_binding_description_count = if (description.vertex_description.vertex_attribs.len == 0) 0 else 1,
                    .p_vertex_binding_descriptions = @ptrCast(&binding_description),
                    .vertex_attribute_description_count = @intCast(attribute_desc.len),
                    .p_vertex_attribute_descriptions = attribute_desc.ptr,
                },
                .p_input_assembly_state = &vk.PipelineInputAssemblyStateCreateInfo{
                    .topology = switch (description.render_type) {
                        .triangle => .triangle_list,
                        .point => .point_list,
                        .line => .line_list,
                    },
                    .primitive_restart_enable = vk.FALSE,
                },
                .p_tessellation_state = null,
                .p_viewport_state = &vk.PipelineViewportStateCreateInfo{
                    .viewport_count = 1,
                    .p_viewports = undefined,
                    .scissor_count = 1,
                    .p_scissors = undefined,
                },
                .p_rasterization_state = &vk.PipelineRasterizationStateCreateInfo{
                    .depth_clamp_enable = vk.FALSE,
                    .rasterizer_discard_enable = vk.FALSE,
                    .polygon_mode = .fill,
                    .cull_mode = switch (description.cull_type) {
                        .back => .{ .back_bit = true },
                        .front => .{ .front_bit = true },
                        .front_and_back => .{ .front_bit = true, .back_bit = true },
                        .none => .{},
                    },
                    .front_face = if (info.flipped_z) .counter_clockwise else .clockwise,
                    .depth_bias_enable = vk.FALSE,
                    .depth_bias_constant_factor = 0,
                    .depth_bias_clamp = 0,
                    .depth_bias_slope_factor = 0,
                    .line_width = 1,
                },
                .p_multisample_state = &vk.PipelineMultisampleStateCreateInfo{
                    //.rasterization_samples = if (info.render_pass.info.multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
                    .rasterization_samples = .{ .@"1_bit" = true },
                    .sample_shading_enable = vk.FALSE,
                    .min_sample_shading = 1,
                    .alpha_to_coverage_enable = vk.FALSE,
                    .alpha_to_one_enable = vk.FALSE,
                },
                .p_depth_stencil_state = &vk.PipelineDepthStencilStateCreateInfo{
                    .depth_test_enable = if (description.depth_test) vk.TRUE else vk.FALSE,
                    .depth_write_enable = if (description.depth_test) vk.TRUE else vk.FALSE,
                    .depth_compare_op = .less,
                    .depth_bounds_test_enable = vk.FALSE,
                    .min_depth_bounds = 0,
                    .max_depth_bounds = 0,
                    .stencil_test_enable = vk.FALSE,
                    // :p
                    .front = std.mem.zeroes(vk.StencilOpState),
                    .back = std.mem.zeroes(vk.StencilOpState),
                },
                .p_color_blend_state = &vk.PipelineColorBlendStateCreateInfo{
                    .logic_op_enable = vk.FALSE,
                    .logic_op = .clear,
                    .attachment_count = @intCast(attachments.len),
                    .p_attachments = attachments.ptr,
                    .blend_constants = [_]f32{ 0, 0, 0, 0 },
                },
                .p_dynamic_state = &vk.PipelineDynamicStateCreateInfo{
                    .flags = .{},
                    .dynamic_state_count = dynstate.len,
                    .p_dynamic_states = &dynstate,
                },
                .layout = pipeline_layout,
                .render_pass = .null_handle,
                .subpass = 0,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = -1,
                .p_next = &vk.PipelineRenderingCreateInfo{
                    .color_attachment_count = @intCast(info.rendering.color_formats.len),
                    .p_color_attachment_formats = info.rendering.color_formats.ptr,
                    .depth_attachment_format = info.rendering.depth_format orelse .undefined,
                    .stencil_attachment_format = .undefined,
                    // ?
                    .view_mask = 0,
                },
            }),
            null,
            @ptrCast(&vk_pipeline),
        );

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .pipeline, @intFromEnum(vk_pipeline), "render pipeline");
        }
        return .{
            .pipeline = .{
                .vk_pipeline = vk_pipeline,
                .layout = pipeline_layout,
                .layouts = layouts,
                .ally = ally,
                .set_bindings = set_bindings,
                .type = .render,
                .description = .{
                    .constants_size = info.description.constants_size,
                    .sets = info.description.sets,
                    .attachment_descriptions = info.description.attachment_descriptions,
                    .global_ubo = info.description.global_ubo,
                    .bindless = info.description.bindless,
                },
            },
        };
    }

    pub fn deinit(render: *RenderPipeline, gpu: *const Gpu) void {
        render.pipeline.deinit(gpu);
    }
};

pub const GenericPipelineDescription = struct {
    constants_size: ?usize = null,
    sets: []const Set = &.{},
    attachment_descriptions: []const AttachmentDescription = &.{.{}},
    global_ubo: bool = false,
    bindless: bool = false,

    pub fn getUniformCount(pipeline: GenericPipelineDescription, set: usize) usize {
        var uniforms: usize = 0;
        for (pipeline.sets[set].bindings) |binding| {
            if (binding == .uniform) uniforms += 1;
        }
        return uniforms;
    }
};

pub const Pipeline = struct {
    ally: std.mem.Allocator,
    description: GenericPipelineDescription,

    vk_pipeline: vk.Pipeline,
    layout: vk.PipelineLayout,
    layouts: []vk.DescriptorSetLayout,
    set_bindings: [][]vk.DescriptorSetLayoutBinding,

    type: enum {
        render,
        compute,
    },

    pub fn deinit(render: *Pipeline, gpu: *const Gpu) void {
        for (render.set_bindings) |bindings| render.ally.free(bindings);
        render.ally.free(render.set_bindings);

        gpu.vkd.deviceWaitIdle(gpu.dev) catch {};
        gpu.vkd.destroyPipeline(gpu.dev, render.vk_pipeline, null);
        gpu.vkd.destroyPipelineLayout(gpu.dev, render.layout, null);

        for (render.layouts) |layout| gpu.vkd.destroyDescriptorSetLayout(gpu.dev, layout, null);
        render.ally.free(render.layouts);
    }
};

pub const FlatPipeline = RenderPipeline{
    .vertex_attrib = &VertexAttribute{ .{ .size = 3 }, .{ .size = 2 } },
    .render_type = .triangle,
    .depth_test = false,
};

pub const LinePipeline = RenderPipeline{
    .vertex_attrib = &[_]VertexAttribute{ .{ .size = 3 }, .{ .size = 3 } },
    .render_type = .line,
    .depth_test = true,
};

pub const BufferMemory = struct {
    pub fn deinit(buff: BufferMemory, gpu: Gpu) void {
        gpu.vkd.destroyBuffer(gpu.dev, buff.buffer, null);
        gpu.vkd.freeMemory(gpu.dev, buff.memory, null);
    }

    pub fn deinitRetainingMemory(buff: BufferMemory, gpu: Gpu) void {
        gpu.vkd.destroyBuffer(gpu.dev, buff.buffer, null);
    }

    pub fn slice(buff: BufferMemory, gpu: Gpu, offset: u64, size: u64) BufferMemory {
        const buffer = try gpu.vkd.createBuffer(gpu.dev, &.{
            .size = size,
            .usage = .{ .transfer_src_bit = true },
            .sharing_mode = .exclusive,
        }, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .buffer, @intFromEnum(buffer), "sliced buffer");
        }

        try gpu.vkd.bindBufferMemory(gpu.dev, buffer, buff.memory, offset + buff.offset);

        return .{
            .buffer = buffer,
            .memory = buff.memory,
            .offset = offset + buff.offset,
            .size = buff.size,
        };
    }

    buffer: vk.Buffer,
    offset: u64,

    // memory data, retain from parent
    memory: vk.DeviceMemory,
    size: u64,
};

pub const BufferHandle = struct {
    buff_mem: BufferMemory,
    size: usize,
    data: ?*anyopaque,

    pub fn init(gpu: *Gpu, options: struct {
        size: usize,
        buffer_type: enum {
            uniform,
            storage,
            index,
            vertex,
        },
    }) !BufferHandle {
        const buffer = try gpu.vkd.createBuffer(gpu.dev, &.{
            .size = options.size,
            .usage = switch (options.buffer_type) {
                .uniform => .{ .uniform_buffer_bit = true },
                .storage => .{ .storage_buffer_bit = true, .vertex_buffer_bit = true, .transfer_dst_bit = true },
                .index => .{ .index_buffer_bit = true, .transfer_dst_bit = true },
                .vertex => .{ .vertex_buffer_bit = true, .transfer_dst_bit = true },
            },
            .sharing_mode = .exclusive,
        }, null);

        if (builtin.mode == .Debug) {
            try addDebugMark(gpu.*, .buffer, @intFromEnum(buffer), "buffer");
        }

        const mem_reqs = gpu.vkd.getBufferMemoryRequirements(gpu.dev, buffer);
        const memory = try gpu.allocate(mem_reqs, switch (options.buffer_type) {
            .uniform => .{ .host_visible_bit = true, .host_coherent_bit = true },
            else => .{ .device_local_bit = true },
        });
        try gpu.vkd.bindBufferMemory(gpu.dev, buffer, memory, 0);

        return .{
            .buff_mem = .{
                .buffer = buffer,
                .memory = memory,
                .offset = 0,
                .size = options.size,
            },
            .size = options.size,
            .data = if (options.buffer_type == .uniform) (try gpu.vkd.mapMemory(gpu.dev, memory, 0, vk.WHOLE_SIZE, .{})).? else null,
        };
    }

    pub fn deinit(buffer: BufferHandle, gpu: Gpu) void {
        buffer.buff_mem.deinit(gpu);
    }

    pub fn setVertex(
        buffer: BufferHandle,
        comptime self: VertexDescription,
        gpu: *Gpu,
        pool: vk.CommandPool,
        vertices: []const self.getAttributeType(),
        staging_buff: BufferMemory,
        mode: CommandMode,
    ) !void {
        const trace = tracy.trace(@src());
        defer trace.end();

        if (vertices.len == 0) return;

        {
            const data = try gpu.vkd.mapMemory(gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer gpu.vkd.unmapMemory(gpu.dev, staging_buff.memory);

            const gpu_vertices: [*]self.getAttributeType() = @ptrCast(@alignCast(data));
            for (vertices, 0..) |vertex, i| {
                gpu_vertices[i] = vertex;
            }
        }

        try copyBuffer(gpu, pool, buffer.buff_mem.buffer, staging_buff.buffer, self.getVertexSize() * vertices.len, mode);
    }

    pub fn setIndices(
        buffer: BufferHandle,
        gpu: *Gpu,
        pool: vk.CommandPool,
        indices: []const u32,
        staging_buff: BufferMemory,
        mode: CommandMode,
    ) !void {
        const trace = tracy.trace(@src());
        defer trace.end();

        if (indices.len == 0) return;

        {
            const data = try gpu.vkd.mapMemory(gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer gpu.vkd.unmapMemory(gpu.dev, staging_buff.memory);

            const gpu_indices: [*]u32 = @ptrCast(@alignCast(data));
            for (indices, 0..) |index, i| {
                gpu_indices[i] = index;
            }
        }

        try copyBuffer(gpu, pool, buffer.buff_mem.buffer, staging_buff.buffer, @sizeOf(u32) * indices.len, mode);
    }

    pub fn setStorage(
        buffer: BufferHandle,
        comptime data: DataDescription,
        gpu: *Gpu,
        pool: vk.CommandPool,
        options: struct {
            data: []data.lastField(),
            index: usize,
        },
    ) !void {
        const trace = tracy.trace(@src());
        defer trace.end();

        if (options.data.len == 0) return;

        const size = data.getSize() + @sizeOf(data.lastField()) * (options.data.len - 1);
        const staging_buff = try gpu.createStagingBuffer(size);
        defer staging_buff.deinit(gpu);

        {
            const mem = try gpu.vkd.mapMemory(gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer gpu.vkd.unmapMemory(gpu.dev, staging_buff.memory);

            const storage_ptr: *data.T = @ptrCast(@alignCast(mem));

            const field_ptr: [*]data.lastField() = @ptrCast(@alignCast(&@field(storage_ptr, data.lastFieldName())));
            for (options.data, 0..) |val, i| {
                field_ptr[i] = val;
            }
        }

        // TODO: pass mode
        try copyBuffer(gpu, pool, buffer.buff_mem.buffer, staging_buff.buffer, size, .immediate);
    }

    pub fn setBytesStaging(buffer: BufferHandle, gpu: *Gpu, pool: vk.CommandPool, bytes: []const u8) !void {
        const trace = tracy.trace(@src());
        defer trace.end();

        const staging_buff = try gpu.createStagingBuffer(bytes.len);
        defer staging_buff.deinit(gpu);

        {
            const data = try gpu.vkd.mapMemory(gpu.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer gpu.vkd.unmapMemory(gpu.dev, staging_buff.memory);

            const data_bytes: [*]u8 = @ptrCast(@alignCast(data));
            @memcpy(data_bytes, bytes);
        }

        // TODO: pass mode
        try copyBuffer(gpu, pool, buffer.buff_mem.buffer, staging_buff.buffer, bytes.len, .immediate);
    }

    pub fn getData(buffer: BufferHandle, comptime self: DataDescription) *self.T {
        return @alignCast(@ptrCast(buffer.data.?));
    }

    pub fn setAsUniform(buffer: BufferHandle, comptime self: DataDescription, ubo: self.T) void {
        @as(*self.T, @alignCast(@ptrCast(buffer.data.?))).* = ubo;
    }
    pub fn setAsUniformField(buffer: BufferHandle, comptime self: DataDescription, comptime field: std.meta.FieldEnum(self.T), target: anytype) void {
        @field(@as(*self.T, @alignCast(@ptrCast(buffer.data.?))), @tagName(field)) = target;
    }
};

pub const DataDescription = struct {
    T: type,

    pub fn lastField(comptime data: DataDescription) type {
        const fields = std.meta.fields(data.T);
        return fields[fields.len - 1].type;
    }

    pub fn lastFieldName(comptime data: DataDescription) [:0]const u8 {
        const fields = std.meta.fields(data.T);
        return fields[fields.len - 1].name;
    }

    pub fn getSize(comptime self: DataDescription) usize {
        std.mem.doNotOptimizeAway(@sizeOf(self.T));
        return @sizeOf(self.T);
    }

    pub fn createBuffer(comptime self: DataDescription, gpu: *Gpu) !BufferHandle {
        return BufferHandle.init(gpu, .{ .size = self.getSize() });
    }
};

pub const GlobalUniform: DataDescription = .{ .T = extern struct { time: f32, in_resolution: [2]f32 align(2 * 4) } };
pub const SpriteUniform: DataDescription = .{ .T = extern struct { transform: math.Mat4, opacity: f32 } };

pub const SpritePipeline: PipelineDescription = .{
    .vertex_description = .{
        .vertex_attribs = &.{ .{ .size = 3 }, .{ .size = 2 } },
    },
    .render_type = .triangle,
    .depth_test = false,
    .uniform_sizes = &.{ GlobalUniform.getSize(), SpriteUniform.getSize() },
    .global_ubo = true,
};
