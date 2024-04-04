// TODO: remove pub
pub const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

const AREA_SIZE = 512;

const img = @import("img");
const common = @import("common");
const std = @import("std");
const math = @import("math");
const freetype = @import("freetype");

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
pub const ColoredRect = @import("elems/color_rect.zig").ColoredRect;

pub const MeshBuilder = @import("meshbuilder.zig").MeshBuilder;
pub const SpatialMesh = @import("elems/spatialmesh.zig").SpatialMesh;
pub const ObjParse = @import("obj.zig").ObjParse;
pub const ComptimeMeshBuilder = @import("comptime_meshbuilder.zig").ComptimeMeshBuilder;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec3;

const elem_shaders = @import("elem_shaders");

// vulkan stuff copy pasted
const required_device_extensions = [_][*:0]const u8{vk.extension_info.khr_swapchain.name};

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceLayerProperties = true,
    .getInstanceProcAddr = true,
});

const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .createDevice = true,
    .destroySurfaceKHR = true,
    .enumeratePhysicalDevices = true,
    .getPhysicalDeviceProperties = true,
    .enumerateDeviceExtensionProperties = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
    .getPhysicalDeviceMemoryProperties = true,
    .getPhysicalDeviceFormatProperties = true,
    .getDeviceProcAddr = true,
});

const DeviceDispatch = vk.DeviceWrapper(.{
    .destroyDevice = true,
    .getDeviceQueue = true,
    .createSemaphore = true,
    .createFence = true,
    .createImageView = true,
    .destroyImageView = true,
    .destroySemaphore = true,
    .destroyFence = true,
    .getSwapchainImagesKHR = true,
    .createSwapchainKHR = true,
    .destroySwapchainKHR = true,
    .acquireNextImageKHR = true,
    .deviceWaitIdle = true,
    .waitForFences = true,
    .resetFences = true,
    .queueSubmit = true,
    .queuePresentKHR = true,
    .createCommandPool = true,
    .destroyCommandPool = true,
    .allocateCommandBuffers = true,
    .freeCommandBuffers = true,
    .queueWaitIdle = true,
    .createShaderModule = true,
    .destroyShaderModule = true,
    .createPipelineLayout = true,
    .destroyPipelineLayout = true,
    .createRenderPass = true,
    .destroyRenderPass = true,
    .createGraphicsPipelines = true,
    .destroyPipeline = true,
    .createFramebuffer = true,
    .destroyFramebuffer = true,
    .beginCommandBuffer = true,
    .endCommandBuffer = true,
    .allocateMemory = true,
    .freeMemory = true,
    .createBuffer = true,
    .destroyBuffer = true,
    .getBufferMemoryRequirements = true,
    .mapMemory = true,
    .unmapMemory = true,
    .bindBufferMemory = true,
    .cmdBeginRenderPass = true,
    .cmdEndRenderPass = true,
    .cmdBindPipeline = true,
    .cmdDraw = true,
    .cmdDrawIndexed = true,
    .cmdSetViewport = true,
    .cmdPushConstants = true,
    .cmdSetScissor = true,
    .cmdBindVertexBuffers = true,
    .cmdBindIndexBuffer = true,
    .cmdCopyBuffer = true,
    .cmdPipelineBarrier = true,
    .cmdCopyBufferToImage = true,
    .createImage = true,
    .getImageMemoryRequirements = true,
    .bindImageMemory = true,
    .createDescriptorPool = true,
    .allocateDescriptorSets = true,
    .updateDescriptorSets = true,
    .cmdBindDescriptorSets = true,
    .createDescriptorSetLayout = true,
    .resetCommandBuffer = true,
    .createSampler = true,
    .destroyDescriptorSetLayout = true,
    .destroyDescriptorPool = true,
    .destroySampler = true,
    .destroyImage = true,
});

pub const GraphicsContext = struct {
    vkb: BaseDispatch,
    vki: InstanceDispatch,
    vkd: DeviceDispatch,

    instance: vk.Instance,
    surface: vk.SurfaceKHR,
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    mem_props: vk.PhysicalDeviceMemoryProperties,

    dev: vk.Device,
    graphics_queue: Queue,
    present_queue: Queue,

    depth_format: vk.Format,

    pub fn init(allocator: std.mem.Allocator, app_name: [*:0]const u8, window: *glfw.GLFWwindow) !GraphicsContext {
        var self: GraphicsContext = undefined;
        self.vkb = try BaseDispatch.load(glfwGetInstanceProcAddress);

        if (!try checkValidationLayerSupport(allocator, self.vkb)) return error.NoValidationLayers;

        var glfw_exts_count: u32 = 0;
        const glfw_exts = glfw.glfwGetRequiredInstanceExtensions(&glfw_exts_count);

        const app_info = vk.ApplicationInfo{
            .p_application_name = app_name,
            .application_version = vk.makeApiVersion(0, 0, 0, 0),
            .p_engine_name = app_name,
            .engine_version = vk.makeApiVersion(0, 0, 0, 0),
            .api_version = vk.API_VERSION_1_2,
        };

        self.instance = try self.vkb.createInstance(&.{
            .p_application_info = &app_info,
            .enabled_extension_count = glfw_exts_count,
            .pp_enabled_extension_names = @as([*]const [*:0]const u8, @ptrCast(glfw_exts)),
            .enabled_layer_count = @intCast(validation_layers.len),
            .pp_enabled_layer_names = @as([*]const [*:0]const u8, @ptrCast(&validation_layers)),
        }, null);

        self.vki = try InstanceDispatch.load(self.instance, self.vkb.dispatch.vkGetInstanceProcAddr);
        errdefer self.vki.destroyInstance(self.instance, null);

        self.surface = try createSurface(self.instance, window);
        errdefer self.vki.destroySurfaceKHR(self.instance, self.surface, null);

        const candidate = try pickPhysicalDevice(self.vki, self.instance, allocator, self.surface);
        self.pdev = candidate.pdev;
        self.props = candidate.props;
        self.dev = try initializeCandidate(self.vki, candidate);
        self.vkd = try DeviceDispatch.load(self.dev, self.vki.dispatch.vkGetDeviceProcAddr);
        errdefer self.vkd.destroyDevice(self.dev, null);

        self.graphics_queue = Queue.init(self.vkd, self.dev, candidate.queues.graphics_family);
        self.present_queue = Queue.init(self.vkd, self.dev, candidate.queues.present_family);

        self.mem_props = self.vki.getPhysicalDeviceMemoryProperties(self.pdev);
        self.depth_format = try self.findDepthFormat();

        return self;
    }

    pub fn deinit(self: GraphicsContext) void {
        self.vkd.destroyDevice(self.dev, null);
        self.vki.destroySurfaceKHR(self.instance, self.surface, null);
        self.vki.destroyInstance(self.instance, null);
    }

    pub fn deviceName(self: *const GraphicsContext) []const u8 {
        return std.mem.sliceTo(&self.props.device_name, 0);
    }

    pub fn findMemoryTypeIndex(self: GraphicsContext, memory_type_bits: u32, flags: vk.MemoryPropertyFlags) !u32 {
        for (self.mem_props.memory_types[0..self.mem_props.memory_type_count], 0..) |mem_type, i| {
            if (memory_type_bits & (@as(u32, 1) << @truncate(i)) != 0 and mem_type.property_flags.contains(flags)) {
                return @truncate(i);
            }
        }

        return error.NoSuitableMemoryType;
    }

    pub fn allocate(self: GraphicsContext, requirements: vk.MemoryRequirements, flags: vk.MemoryPropertyFlags) !vk.DeviceMemory {
        return try self.vkd.allocateMemory(self.dev, &.{
            .allocation_size = requirements.size,
            .memory_type_index = try self.findMemoryTypeIndex(requirements.memory_type_bits, flags),
        }, null);
    }

    pub fn findSupportedFormat(gc: *const GraphicsContext, candidates: []const vk.Format, tiling: vk.ImageTiling, features: vk.FormatFeatureFlags) !vk.Format {
        for (candidates) |candidate| {
            const props = gc.vki.getPhysicalDeviceFormatProperties(gc.pdev, candidate);
            if (tiling == .linear and props.linear_tiling_features.contains(features)) {
                return candidate;
            } else if (tiling == .optimal and props.optimal_tiling_features.contains(features)) {
                return candidate;
            }
        }

        return error.NoSuitableFormat;
    }

    pub fn findDepthFormat(gc: *const GraphicsContext) !vk.Format {
        return gc.findSupportedFormat(&.{ .d32_sfloat, .d32_sfloat_s8_uint, .d24_unorm_s8_uint }, .optimal, .{ .depth_stencil_attachment_bit = true });
    }

    pub fn createStagingBuffer(gc: *GraphicsContext, size: usize) !BufferMemory {
        const staging_buffer = try gc.vkd.createBuffer(gc.dev, &.{
            .size = size,
            .usage = .{ .transfer_src_bit = true },
            .sharing_mode = .exclusive,
        }, null);

        const staging_mem_reqs = gc.vkd.getBufferMemoryRequirements(gc.dev, staging_buffer);
        const staging_memory = try gc.allocate(staging_mem_reqs, .{ .host_visible_bit = true, .host_coherent_bit = true });
        try gc.vkd.bindBufferMemory(gc.dev, staging_buffer, staging_memory, 0);

        return .{ .buffer = staging_buffer, .memory = staging_memory };
    }
};

pub const BufferMemory = struct {
    pub fn deinit(buff: BufferMemory, gc: *GraphicsContext) void {
        gc.vkd.destroyBuffer(gc.dev, buff.buffer, null);
        gc.vkd.freeMemory(gc.dev, buff.memory, null);
    }
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
};

pub const Queue = struct {
    handle: vk.Queue,
    family: u32,

    fn init(vkd: DeviceDispatch, dev: vk.Device, family: u32) Queue {
        return .{
            .handle = vkd.getDeviceQueue(dev, family, 0),
            .family = family,
        };
    }
};

fn createSurface(instance: vk.Instance, window: *glfw.GLFWwindow) !vk.SurfaceKHR {
    var surface: vk.SurfaceKHR = undefined;
    if (glfwCreateWindowSurface(instance, window, null, &surface) != .success) {
        return error.SurfaceInitFailed;
    }

    return surface;
}

fn initializeCandidate(vki: InstanceDispatch, candidate: DeviceCandidate) !vk.Device {
    const priority = [_]f32{1};
    const qci = [_]vk.DeviceQueueCreateInfo{
        .{
            .queue_family_index = candidate.queues.graphics_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
        .{
            .queue_family_index = candidate.queues.present_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
    };

    const queue_count: u32 = if (candidate.queues.graphics_family == candidate.queues.present_family)
        1
    else
        2;

    const features: vk.PhysicalDeviceFeatures = .{ .sampler_anisotropy = vk.TRUE };

    return try vki.createDevice(candidate.pdev, &.{
        .queue_create_info_count = queue_count,
        .p_queue_create_infos = &qci,
        .enabled_extension_count = required_device_extensions.len,
        .pp_enabled_extension_names = @as([*]const [*:0]const u8, @ptrCast(&required_device_extensions)),
        .p_enabled_features = &features,
        .p_next = &vk.PhysicalDeviceDescriptorIndexingFeatures{
            .descriptor_binding_partially_bound = vk.TRUE,
            .descriptor_binding_update_unused_while_pending = vk.TRUE,
            .descriptor_binding_variable_descriptor_count = vk.TRUE,
            .descriptor_binding_uniform_buffer_update_after_bind = vk.TRUE,
            .descriptor_binding_sampled_image_update_after_bind = vk.TRUE,
        },
    }, null);
}

const DeviceCandidate = struct {
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queues: QueueAllocation,
};

const QueueAllocation = struct {
    graphics_family: u32,
    present_family: u32,
};

fn pickPhysicalDevice(
    vki: InstanceDispatch,
    instance: vk.Instance,
    allocator: std.mem.Allocator,
    surface: vk.SurfaceKHR,
) !DeviceCandidate {
    var device_count: u32 = undefined;
    _ = try vki.enumeratePhysicalDevices(instance, &device_count, null);

    const pdevs = try allocator.alloc(vk.PhysicalDevice, device_count);
    defer allocator.free(pdevs);

    _ = try vki.enumeratePhysicalDevices(instance, &device_count, pdevs.ptr);

    for (pdevs) |pdev| {
        if (try checkSuitable(vki, pdev, allocator, surface)) |candidate| {
            return candidate;
        }
    }

    return error.NoSuitableDevice;
}

fn checkSuitable(
    vki: InstanceDispatch,
    pdev: vk.PhysicalDevice,
    allocator: std.mem.Allocator,
    surface: vk.SurfaceKHR,
) !?DeviceCandidate {
    const props = vki.getPhysicalDeviceProperties(pdev);

    if (!try checkExtensionSupport(vki, pdev, allocator)) {
        return null;
    }

    if (!try checkSurfaceSupport(vki, pdev, surface)) {
        return null;
    }

    if (try allocateQueues(vki, pdev, allocator, surface)) |allocation| {
        return DeviceCandidate{
            .pdev = pdev,
            .props = props,
            .queues = allocation,
        };
    }

    return null;
}

fn allocateQueues(vki: InstanceDispatch, pdev: vk.PhysicalDevice, allocator: std.mem.Allocator, surface: vk.SurfaceKHR) !?QueueAllocation {
    var family_count: u32 = undefined;
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &family_count, null);

    const families = try allocator.alloc(vk.QueueFamilyProperties, family_count);
    defer allocator.free(families);
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &family_count, families.ptr);

    var graphics_family: ?u32 = null;
    var present_family: ?u32 = null;

    for (families, 0..) |properties, i| {
        const family: u32 = @intCast(i);

        if (graphics_family == null and properties.queue_flags.graphics_bit) {
            graphics_family = family;
        }

        if (present_family == null and (try vki.getPhysicalDeviceSurfaceSupportKHR(pdev, family, surface)) == vk.TRUE) {
            present_family = family;
        }
    }

    if (graphics_family != null and present_family != null) {
        return QueueAllocation{
            .graphics_family = graphics_family.?,
            .present_family = present_family.?,
        };
    }

    return null;
}

fn checkSurfaceSupport(vki: InstanceDispatch, pdev: vk.PhysicalDevice, surface: vk.SurfaceKHR) !bool {
    var format_count: u32 = undefined;
    _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(pdev, surface, &format_count, null);

    var present_mode_count: u32 = undefined;
    _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(pdev, surface, &present_mode_count, null);

    return format_count > 0 and present_mode_count > 0;
}

fn checkExtensionSupport(
    vki: InstanceDispatch,
    pdev: vk.PhysicalDevice,
    allocator: std.mem.Allocator,
) !bool {
    var count: u32 = undefined;
    _ = try vki.enumerateDeviceExtensionProperties(pdev, null, &count, null);

    const propsv = try allocator.alloc(vk.ExtensionProperties, count);
    defer allocator.free(propsv);

    _ = try vki.enumerateDeviceExtensionProperties(pdev, null, &count, propsv.ptr);

    for (required_device_extensions) |ext| {
        for (propsv) |props| {
            if (std.mem.eql(u8, std.mem.span(ext), std.mem.sliceTo(&props.extension_name, 0))) {
                break;
            }
        } else {
            return false;
        }
    }

    return true;
}
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

    pub fn init(gc: *const GraphicsContext, ally: Allocator, extent: vk.Extent2D, format: PreferredFormat) !Swapchain {
        const finished = try ally.alloc(vk.Semaphore, frames_in_flight);
        for (finished) |*f| f.* = try gc.vkd.createSemaphore(gc.dev, &.{}, null);

        const image = try ally.alloc(vk.Semaphore, frames_in_flight);
        for (image) |*f| f.* = try gc.vkd.createSemaphore(gc.dev, &.{}, null);

        const frame_fence = try ally.alloc(vk.Fence, frames_in_flight);
        for (frame_fence) |*f| f.* = try gc.vkd.createFence(gc.dev, &.{ .flags = .{ .signaled_bit = true } }, null);

        return try initRecycle(gc, ally, .{
            .extent = extent,
            .old_handle = .null_handle,
            .format = format,
            .finished = finished,
            .image = image,
            .frames = frame_fence,
        });
    }

    pub fn initRecycle(gc: *const GraphicsContext, ally: Allocator, options: struct {
        extent: vk.Extent2D,
        old_handle: vk.SwapchainKHR,
        format: PreferredFormat,
        finished: []vk.Semaphore,
        image: []vk.Semaphore,
        frames: []vk.Fence,
    }) !Swapchain {
        const caps = try gc.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(gc.pdev, gc.surface);
        const actual_extent = findActualExtent(caps, options.extent);
        if (actual_extent.width == 0 or actual_extent.height == 0) {
            return error.InvalidSurfaceDimensions;
        }

        const surface_format = try findSurfaceFormat(gc, ally, options.format);
        const present_mode: vk.PresentModeKHR = .fifo_khr;

        var image_count = caps.min_image_count + 1;
        if (caps.max_image_count > 0) {
            image_count = @min(image_count, caps.max_image_count);
        }

        const qfi = [_]u32{ gc.graphics_queue.family, gc.present_queue.family };
        const sharing_mode: vk.SharingMode = if (gc.graphics_queue.family != gc.present_queue.family)
            .concurrent
        else
            .exclusive;

        const handle = try gc.vkd.createSwapchainKHR(gc.dev, &.{
            .surface = gc.surface,
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
        errdefer gc.vkd.destroySwapchainKHR(gc.dev, handle, null);

        if (options.old_handle != .null_handle) {
            gc.vkd.destroySwapchainKHR(gc.dev, options.old_handle, null);
        }

        const swap_images = try initSwapchainImages(gc, handle, surface_format.format, ally);
        errdefer {
            for (swap_images) |si| si.deinit(gc);
            ally.free(swap_images);
        }
        //errdefer gc.vkd.destroySemaphore(gc.dev, next_image_acquired, null);

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

    fn deinitExceptSwapchain(self: Swapchain, gc: *GraphicsContext) void {
        for (self.swap_images) |si| si.deinit(gc);
        self.ally.free(self.swap_images);
    }

    pub fn deinit(self: Swapchain, gc: *GraphicsContext) void {
        self.deinitExceptSwapchain(gc);
        gc.vkd.destroySwapchainKHR(gc.dev, self.handle, null);

        for (self.render_finished) |s| gc.vkd.destroySemaphore(gc.dev, s, null);
        self.ally.free(self.render_finished);

        for (self.image_acquired) |s| gc.vkd.destroySemaphore(gc.dev, s, null);
        self.ally.free(self.image_acquired);

        for (self.frame_fence) |f| gc.vkd.destroyFence(gc.dev, f, null);
        self.ally.free(self.frame_fence);
    }

    pub fn recreate(self: *Swapchain, gc: *GraphicsContext, new_extent: vk.Extent2D, format: PreferredFormat) !void {
        const ally = self.ally;
        const old_handle = self.handle;
        self.deinitExceptSwapchain(gc);
        self.* = try initRecycle(gc, ally, .{
            .extent = new_extent,
            .old_handle = old_handle,
            .format = format,
            .finished = self.render_finished,
            .image = self.image_acquired,
            .frames = self.frame_fence,
        });
    }

    pub fn wait(swapchain: *Swapchain, gc: *GraphicsContext, frame_id: usize) !void {
        _ = try gc.vkd.waitForFences(gc.dev, 1, @ptrCast(&swapchain.frame_fence[frame_id]), vk.TRUE, std.math.maxInt(u64));
        try gc.vkd.resetFences(gc.dev, 1, @ptrCast(&swapchain.frame_fence[frame_id]));
    }

    pub fn acquireImage(swapchain: *Swapchain, gc: *GraphicsContext, frame_id: usize) !ImageIndex {
        return @enumFromInt((try gc.vkd.acquireNextImageKHR(
            gc.dev,
            swapchain.handle,
            std.math.maxInt(u64),
            swapchain.image_acquired[frame_id],
            .null_handle,
        )).image_index);
    }
    pub fn submit(swapchain: *Swapchain, gc: *GraphicsContext, builder: CommandBuilder, info: struct { wait: []const vk.Semaphore }) !void {
        const wait_stage = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        const cmdbuf = builder.getCurrent();

        try gc.vkd.queueSubmit(gc.graphics_queue.handle, 1, &[_]vk.SubmitInfo{.{
            .wait_semaphore_count = @intCast(info.wait.len),
            .p_wait_semaphores = info.wait.ptr,
            .p_wait_dst_stage_mask = &wait_stage,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&cmdbuf),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(&swapchain.render_finished[builder.frame_id]),
        }}, swapchain.frame_fence[builder.frame_id]);
    }

    pub fn present(swapchain: *Swapchain, gc: *GraphicsContext, info: struct {
        wait: []const vk.Semaphore,
        image_index: ImageIndex,
    }) !void {
        _ = try gc.vkd.queuePresentKHR(gc.present_queue.handle, &.{
            .wait_semaphore_count = @intCast(info.wait.len),
            .p_wait_semaphores = info.wait.ptr,
            .swapchain_count = 1,
            .p_swapchains = @as([*]const vk.SwapchainKHR, @ptrCast(&swapchain.handle)),
            .p_image_indices = @as([*]const u32, @ptrCast(&info.image_index)),
        });
    }
};

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,

    fn init(gc: *const GraphicsContext, image: vk.Image, format: vk.Format) !SwapImage {
        const view = try gc.vkd.createImageView(gc.dev, &.{
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
        errdefer gc.vkd.destroyImageView(gc.dev, view, null);

        const image_acquired = try gc.vkd.createSemaphore(gc.dev, &.{}, null);
        errdefer gc.vkd.destroySemaphore(gc.dev, image_acquired, null);

        return SwapImage{
            .image = image,
            .view = view,
            .image_acquired = image_acquired,
        };
    }

    fn deinit(self: SwapImage, gc: *const GraphicsContext) void {
        //self.waitForFence(gc) catch return;
        gc.vkd.destroyImageView(gc.dev, self.view, null);
        gc.vkd.destroySemaphore(gc.dev, self.image_acquired, null);
    }
};

fn initSwapchainImages(gc: *const GraphicsContext, swapchain: vk.SwapchainKHR, format: vk.Format, allocator: Allocator) ![]SwapImage {
    var count: u32 = undefined;
    _ = try gc.vkd.getSwapchainImagesKHR(gc.dev, swapchain, &count, null);
    const images = try allocator.alloc(vk.Image, count);
    defer allocator.free(images);
    _ = try gc.vkd.getSwapchainImagesKHR(gc.dev, swapchain, &count, images.ptr);

    const swap_images = try allocator.alloc(SwapImage, count);
    errdefer allocator.free(swap_images);

    var i: usize = 0;
    errdefer for (swap_images[0..i]) |si| si.deinit(gc);

    for (images) |image| {
        swap_images[i] = try SwapImage.init(gc, image, format);
        i += 1;
    }

    return swap_images;
}

fn findSurfaceFormat(gc: *const GraphicsContext, allocator: Allocator, format: PreferredFormat) !vk.SurfaceFormatKHR {
    const preferred = vk.SurfaceFormatKHR{
        .format = format.getSurfaceFormat(gc.*),
        .color_space = .srgb_nonlinear_khr,
    };

    var count: u32 = undefined;
    _ = try gc.vki.getPhysicalDeviceSurfaceFormatsKHR(gc.pdev, gc.surface, &count, null);
    const surface_formats = try allocator.alloc(vk.SurfaceFormatKHR, count);
    defer allocator.free(surface_formats);
    _ = try gc.vki.getPhysicalDeviceSurfaceFormatsKHR(gc.pdev, gc.surface, &count, surface_formats.ptr);

    for (surface_formats) |sfmt| {
        if (std.meta.eql(sfmt, preferred)) {
            return preferred;
        }
    }

    return surface_formats[0];
}

fn findPresentMode(gc: *const GraphicsContext, allocator: Allocator) !vk.PresentModeKHR {
    var count: u32 = undefined;
    _ = try gc.vki.getPhysicalDeviceSurfacePresentModesKHR(gc.pdev, gc.surface, &count, null);
    const present_modes = try allocator.alloc(vk.PresentModeKHR, count);
    defer allocator.free(present_modes);
    _ = try gc.vki.getPhysicalDeviceSurfacePresentModesKHR(gc.pdev, gc.surface, &count, present_modes.ptr);

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

// eventually make a helper struct for any sized command buffers
fn createSingleCommandBuffer(gc: *const GraphicsContext, pool: vk.CommandPool) !vk.CommandBuffer {
    var cmdbuf: vk.CommandBuffer = undefined;
    try gc.vkd.allocateCommandBuffers(gc.dev, &.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&cmdbuf));
    try gc.vkd.beginCommandBuffer(cmdbuf, &.{
        .flags = .{ .one_time_submit_bit = true },
    });
    return cmdbuf;
}

fn freeSingleCommandBuffer(cmdbuf: vk.CommandBuffer, gc: *const GraphicsContext, pool: vk.CommandPool) void {
    gc.vkd.freeCommandBuffers(gc.dev, pool, 1, @ptrCast(&cmdbuf));
}

fn finishSingleCommandBuffer(cmdbuf: vk.CommandBuffer, gc: *const GraphicsContext) !void {
    try gc.vkd.endCommandBuffer(cmdbuf);

    const si = vk.SubmitInfo{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&cmdbuf),
        .p_wait_dst_stage_mask = undefined,
    };
    try gc.vkd.queueSubmit(gc.graphics_queue.handle, 1, @ptrCast(&si), .null_handle);
    try gc.vkd.queueWaitIdle(gc.graphics_queue.handle);
}

fn copyBuffer(gc: *const GraphicsContext, pool: vk.CommandPool, dst: vk.Buffer, src: vk.Buffer, size: vk.DeviceSize) !void {
    const cmdbuf = try createSingleCommandBuffer(gc, pool);
    defer freeSingleCommandBuffer(cmdbuf, gc, pool);

    const region = vk.BufferCopy{
        .src_offset = 0,
        .dst_offset = 0,
        .size = size,
    };
    gc.vkd.cmdCopyBuffer(cmdbuf, src, dst, 1, @ptrCast(&region));

    try finishSingleCommandBuffer(cmdbuf, gc);
}

const validation_layers = [_][]const u8{"VK_LAYER_KHRONOS_validation"};

fn checkValidationLayerSupport(ally: std.mem.Allocator, vkb: BaseDispatch) !bool {
    var layer_count: u32 = 0;
    _ = try vkb.enumerateInstanceLayerProperties(&layer_count, null);

    const available_layers = try ally.alloc(vk.LayerProperties, layer_count);
    _ = try vkb.enumerateInstanceLayerProperties(&layer_count, available_layers.ptr);
    defer ally.free(available_layers);

    for (validation_layers) |layer_name| {
        var layer_found = false;
        for (available_layers) |prop| {
            if (std.mem.eql(u8, layer_name, prop.layer_name[0..layer_name.len])) {
                layer_found = true;
                break;
            }
        }
        if (!layer_found) return false;
    }

    return true;
}

// end

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
    multisampling: bool = false,
    is_render_target: bool = false,
    cubemap: bool = false,
    preferred_format: ?PreferredFormat = null,
};

pub const Texture = struct {
    // eventually remove
    info: TextureInfo,

    width: u32,
    height: u32,

    // vulkan
    image: vk.Image,
    image_view: vk.ImageView,
    window: *Window,
    sampler: vk.Sampler,
    memory: vk.DeviceMemory,

    pub fn init(win: *Window, width: u32, height: u32, info: TextureInfo) !Texture {
        const format = if (info.preferred_format) |f| f else win.preferred_format;

        const image_info: vk.ImageCreateInfo = .{
            .image_type = .@"2d",
            .extent = .{ .width = width, .height = height, .depth = 1 },
            .mip_levels = 1,
            .array_layers = if (info.cubemap) 6 else 1,
            .format = if (info.multisampling and info.preferred_format != .depth) win.preferred_format.getSurfaceFormat(win.gc) else format.getSurfaceFormat(win.gc),
            .tiling = blk: {
                if (info.is_render_target or info.multisampling) {
                    break :blk .optimal;
                } else {
                    break :blk switch (format) {
                        .depth => .optimal,
                        .unorm, .srgb => .linear,
                    };
                }
            },
            .initial_layout = .undefined,
            .usage = blk: {
                if (info.multisampling and info.preferred_format != .depth) break :blk .{ .transient_attachment_bit = true, .color_attachment_bit = true };
                if (info.is_render_target) {
                    break :blk .{ .color_attachment_bit = true, .sampled_bit = true };
                } else {
                    break :blk switch (format) {
                        .depth => .{ .depth_stencil_attachment_bit = true },
                        .unorm, .srgb => .{ .transfer_dst_bit = true, .sampled_bit = true },
                    };
                }
            },
            .samples = if (info.multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
            .sharing_mode = .exclusive,
            .flags = if (info.cubemap) .{ .cube_compatible_bit = true } else .{},
        };

        const image = try win.gc.vkd.createImage(win.gc.dev, &image_info, null);
        const mem_reqs = win.gc.vkd.getImageMemoryRequirements(win.gc.dev, image);
        const image_memory = try win.gc.allocate(mem_reqs, .{ .device_local_bit = true });
        try win.gc.vkd.bindImageMemory(win.gc.dev, image, image_memory, 0);

        if (format == .depth) try transitionImageLayout(&win.gc, win.pool, image, .{
            .old_layout = .undefined,
            .new_layout = .depth_stencil_attachment_optimal,
        });

        const view_info: vk.ImageViewCreateInfo = .{
            .image = image,
            .view_type = if (info.cubemap) .cube else .@"2d",
            .format = format.getSurfaceFormat(win.gc),
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = if (format == .depth) .{ .depth_bit = true } else .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = if (info.cubemap) 6 else 1,
            },
        };

        const properties = win.gc.vki.getPhysicalDeviceProperties(win.gc.pdev);

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
            .compare_enable = vk.FALSE,
            .compare_op = .always,
            .mipmap_mode = .linear,
            .mip_lod_bias = 0,
            .min_lod = 0,
            .max_lod = 0,
        };

        return .{
            .info = info,
            .image = image,
            .window = win,
            .width = width,
            .height = height,
            .sampler = try win.gc.vkd.createSampler(win.gc.dev, &sampler_info, null),
            .image_view = try win.gc.vkd.createImageView(win.gc.dev, &view_info, null),
            .memory = image_memory,
        };
    }

    pub fn deinit(self: Texture) void {
        const win = self.window;
        win.gc.vkd.destroySampler(win.gc.dev, self.sampler, null);
        win.gc.vkd.destroyImageView(win.gc.dev, self.image_view, null);
        win.gc.vkd.destroyImage(win.gc.dev, self.image, null);
        win.gc.vkd.freeMemory(win.gc.dev, self.memory, null);
    }

    pub fn initFromMemory(ally: std.mem.Allocator, win: *Window, buffer: []const u8, info: TextureInfo) !Texture {
        var read_image = try img.Image.fromMemory(ally, buffer);
        defer read_image.deinit();

        switch (read_image.pixels) {
            .rgba32 => |data| {
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

    pub fn initFromPath(ally: std.mem.Allocator, win: *Window, path: []const u8, info: TextureInfo) !Texture {
        var read_image = try img.Image.fromFilePath(ally, path);
        defer read_image.deinit();

        switch (read_image.pixels) {
            .rgba32 => |data| {
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

    fn createTextureSampler(tex: *Texture) !void {
        const gc = &tex.window.gc;
        const properties = gc.vki.getPhysicalDeviceProperties(gc.pdev);

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
        win.gc.vkd.destroySampler(win.gc.dev, tex.sampler, null);
        tex.sampler = try gc.vkd.createSampler(gc.dev, &sampler_info, null);
    }

    fn createImageView(tex: *Texture) !void {
        const gc = &tex.window.gc;

        const view_info: vk.ImageViewCreateInfo = .{
            .image = tex.image,
            .view_type = if (tex.info.cubemap) .cube else .@"2d",
            .format = tex.window.preferred_format.getSurfaceFormat(gc.*),
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
        win.gc.vkd.destroyImageView(win.gc.dev, tex.image_view, null);
        tex.image_view = try gc.vkd.createImageView(gc.dev, &view_info, null);
    }

    fn copyBufferToImage(tex: Texture, buffer: vk.Buffer) !void {
        const cmdbuf = try createSingleCommandBuffer(&tex.window.gc, tex.window.pool);
        defer freeSingleCommandBuffer(cmdbuf, &tex.window.gc, tex.window.pool);

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

        tex.window.gc.vkd.cmdCopyBufferToImage(cmdbuf, buffer, tex.image, .transfer_dst_optimal, 1, @ptrCast(&region));

        try finishSingleCommandBuffer(cmdbuf, &tex.window.gc);
    }

    pub fn setCube(tex: Texture, ally: std.mem.Allocator, paths: [6][]const u8) !void {
        const size = tex.width * tex.height;
        const staging_buff = try tex.window.gc.createStagingBuffer(size * 4 * 6);
        defer staging_buff.deinit(&tex.window.gc);

        const Rgba = struct {
            b: u8,
            g: u8,
            r: u8,
            a: u8,
        };

        {
            const data = try tex.window.gc.vkd.mapMemory(tex.window.gc.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer tex.window.gc.vkd.unmapMemory(tex.window.gc.dev, staging_buff.memory);

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

        try transitionImageLayout(&tex.window.gc, tex.window.pool, tex.image, .{
            .old_layout = .undefined,
            .new_layout = .transfer_dst_optimal,
            .layer_count = 6,
        });
        try tex.copyBufferToImage(staging_buff.buffer);
        try transitionImageLayout(&tex.window.gc, tex.window.pool, tex.image, .{
            .old_layout = .transfer_dst_optimal,
            .new_layout = .shader_read_only_optimal,
            .layer_count = 6,
        });
    }

    pub fn createImage(tex: Texture, rgba: anytype) !void {
        const PixelFormat = @TypeOf(rgba.data[0]);

        const staging_buff = try tex.window.gc.createStagingBuffer(@sizeOf(PixelFormat) * rgba.data.len);
        defer staging_buff.deinit(&tex.window.gc);

        {
            const data = try tex.window.gc.vkd.mapMemory(tex.window.gc.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer tex.window.gc.vkd.unmapMemory(tex.window.gc.dev, staging_buff.memory);

            for (@as([*]PixelFormat, @ptrCast(data))[0..rgba.data.len], 0..) |*p, i| p.* = rgba.data[i];
        }

        try transitionImageLayout(&tex.window.gc, tex.window.pool, tex.image, .{
            .old_layout = .undefined,
            .new_layout = .transfer_dst_optimal,
            .layer_count = if (tex.info.cubemap) 6 else 1,
        });
        try tex.copyBufferToImage(staging_buff.buffer);
        try transitionImageLayout(&tex.window.gc, tex.window.pool, tex.image, .{
            .old_layout = .transfer_dst_optimal,
            .new_layout = .shader_read_only_optimal,
            .layer_count = if (tex.info.cubemap) 6 else 1,
        });
    }

    pub fn setFromRgba(self: *Texture, rgba: anytype) !void {
        try self.createImage(rgba);
        try self.createImageView();
        try self.createTextureSampler();
    }
};

pub fn transitionImageLayout(gc: *const GraphicsContext, pool: vk.CommandPool, image: vk.Image, options: struct {
    old_layout: vk.ImageLayout,
    new_layout: vk.ImageLayout,
    layer_count: u32 = 1,
}) !void {
    const cmdbuf = try createSingleCommandBuffer(gc, pool);
    defer freeSingleCommandBuffer(cmdbuf, gc, pool);

    const barrier: vk.ImageMemoryBarrier = .{
        .old_layout = options.old_layout,
        .new_layout = options.new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresource_range = .{
            // stencil also has to be marked if the format supports it
            .aspect_mask = if (options.new_layout == .depth_stencil_attachment_optimal) .{ .depth_bit = true } else .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = options.layer_count,
        },
        .src_access_mask = switch (options.old_layout) {
            .undefined => .{},
            .transfer_dst_optimal => .{ .transfer_write_bit = true },
            else => return error.InvalidOldLayout,
        },
        .dst_access_mask = switch (options.new_layout) {
            .transfer_dst_optimal => .{ .transfer_write_bit = true },
            .shader_read_only_optimal => .{ .shader_read_bit = true },
            .depth_stencil_attachment_optimal => .{ .depth_stencil_attachment_read_bit = true, .depth_stencil_attachment_write_bit = true },
            else => return error.InvalidNewLayout,
        },
    };

    gc.vkd.cmdPipelineBarrier(
        cmdbuf,
        switch (options.old_layout) {
            .undefined => .{ .top_of_pipe_bit = true },
            .transfer_dst_optimal => .{ .transfer_bit = true },
            else => return error.InvalidOldLayout,
        },
        switch (options.new_layout) {
            .transfer_dst_optimal => .{ .transfer_bit = true },
            .shader_read_only_optimal => .{ .fragment_shader_bit = true },
            .depth_stencil_attachment_optimal => .{ .early_fragment_tests_bit = true },
            else => return error.InvalidOldLayout,
        },
        .{},
        0,
        null,
        0,
        null,
        1,
        @ptrCast(&barrier),
    );

    try finishSingleCommandBuffer(cmdbuf, gc);
}

const ShaderType = enum {
    vertex,
    fragment,
    compute,
};

pub const Shader = struct {
    module: vk.ShaderModule,
    type: ShaderType,

    pub fn init(gc: GraphicsContext, file_src: []align(@alignOf(u32)) const u8, shader_enum: ShaderType) !Shader {
        const module = try gc.vkd.createShaderModule(gc.dev, &.{
            .code_size = file_src.len,
            .p_code = std.mem.bytesAsSlice(u32, file_src).ptr,
        }, null);
        return Shader{
            .module = module,
            .type = shader_enum,
        };
    }

    pub fn deinit(self: *const Shader, gc: GraphicsContext) void {
        gc.vkd.destroyShaderModule(gc.dev, self.module, null);
    }
};

pub const Drawing = struct {
    //textures: std.ArrayList(Texture),
    //cube_textures: std.ArrayList(u32),

    vert_count: usize,

    // vulkan
    vertex_buffer: ?BufferMemory,
    index_buffer: ?BufferMemory,
    uniform_buffers: [][]UniformBuffer,
    descriptor_sets: []vk.DescriptorSet,
    descriptor_pool: vk.DescriptorPool,

    window: *Window,
    global_ubo: bool,
    pipeline: RenderPipeline,

    const UniformBuffer = struct {
        buff_mem: BufferMemory,
        data: *anyopaque,
    };

    pub const Info = struct {
        win: *Window,
        pipeline: RenderPipeline,
        samplers: []const SamplerWrite = &.{},
    };

    pub fn init(drawing: *Drawing, ally: std.mem.Allocator, info: Info) !void {
        const win = info.win;
        const pipeline = info.pipeline;
        const gc = &win.gc;

        const frames: u32 = frames_in_flight;

        const pool_sizes = try ally.alloc(vk.DescriptorPoolSize, pipeline.bindings.len);
        defer ally.free(pool_sizes);

        for (pool_sizes, pipeline.bindings) |*pool_size, binding| {
            pool_size.* = .{
                .type = binding.descriptor_type,
                .descriptor_count = frames * binding.descriptor_count,
            };
        }

        const pool_info = vk.DescriptorPoolCreateInfo{
            .max_sets = frames,
            .p_pool_sizes = pool_sizes.ptr,
            .pool_size_count = @intCast(pipeline.bindings.len),
            .flags = if (pipeline.description.bindless) .{ .update_after_bind_bit = true } else .{},
        };

        const uniforms = try ally.alloc([]UniformBuffer, pipeline.description.uniform_sizes.len);

        for (uniforms) |*u| u.* = &.{};

        drawing.* = .{
            //.cube_textures = std.ArrayList(u32).init(ally),
            .vert_count = 0,
            .pipeline = info.pipeline,
            .vertex_buffer = null,
            .index_buffer = null,
            .descriptor_pool = try gc.vkd.createDescriptorPool(gc.dev, &pool_info, null),
            .uniform_buffers = uniforms,
            .descriptor_sets = &.{},
            .window = win,
            .global_ubo = pipeline.description.global_ubo,
        };

        try drawing.createUniformBuffers(ally);
        try drawing.createDescriptorSets(ally, info.samplers);
    }

    pub fn deinit(self: *Drawing, ally: std.mem.Allocator) void {
        const win = self.window;

        win.gc.vkd.deviceWaitIdle(win.gc.dev) catch return;

        for (self.uniform_buffers) |ubs| {
            for (ubs) |ub| ub.buff_mem.deinit(&win.gc);
            ally.free(ubs);
        }
        ally.free(self.uniform_buffers);

        win.gc.vkd.destroyDescriptorPool(win.gc.dev, self.descriptor_pool, null);
        ally.free(self.descriptor_sets);

        if (self.index_buffer) |ib| ib.deinit(&win.gc);
        if (self.vertex_buffer) |vb| vb.deinit(&win.gc);
    }

    pub fn createDescriptorSets(self: *Drawing, ally: std.mem.Allocator, samplers: []const SamplerWrite) !void {
        var gc = &self.window.gc;
        const layouts = try ally.alloc(vk.DescriptorSetLayout, frames_in_flight);
        defer ally.free(layouts);
        for (layouts) |*l| l.* = self.pipeline.descriptor_layout;

        const pipeline = self.pipeline.description;

        const counts = try ally.alloc(u32, frames_in_flight);
        defer ally.free(counts);

        for (counts) |*c| {
            c.* = if (pipeline.bindless) 256 else 1;
        }

        const variable_counts: vk.DescriptorSetVariableDescriptorCountAllocateInfo = .{
            .descriptor_set_count = frames_in_flight,
            .p_descriptor_counts = counts.ptr,
        };

        const frames: u32 = @intCast(frames_in_flight);
        const allocate_info = vk.DescriptorSetAllocateInfo{
            .descriptor_pool = self.descriptor_pool,
            .descriptor_set_count = frames,
            .p_set_layouts = layouts.ptr,
            .p_next = &variable_counts,
        };

        self.descriptor_sets = try ally.alloc(vk.DescriptorSet, frames_in_flight);

        try gc.vkd.allocateDescriptorSets(gc.dev, &allocate_info, self.descriptor_sets.ptr);
        try self.updateDescriptorSets(ally, samplers);
    }

    pub const SamplerWrite = struct {
        dst: u32 = 0,
        textures: []const Texture = &.{},
    };

    pub fn updateDescriptorSets(self: *Drawing, ally: std.mem.Allocator, samplers: []const SamplerWrite) !void {
        var gc = &self.window.gc;
        try gc.vkd.deviceWaitIdle(gc.dev);

        const pipeline_desc = self.pipeline.description;

        if (pipeline_desc.sampler_descriptions.len != samplers.len) return error.InvalidSamplerCount;

        for (0..frames_in_flight) |i| {
            var arena = std.heap.ArenaAllocator.init(ally);
            defer arena.deinit();
            const arena_ally = arena.allocator();

            var descriptor_writes = std.ArrayList(vk.WriteDescriptorSet).init(arena_ally);
            defer descriptor_writes.deinit();

            for (0.., self.uniform_buffers, pipeline_desc.uniform_sizes) |binding_i, *uniform, uniform_enum| {
                const uniform_size: usize = @intFromEnum(uniform_enum);

                const buffer_info = try arena_ally.alloc(vk.DescriptorBufferInfo, 1);

                buffer_info[0] = vk.DescriptorBufferInfo{
                    .buffer = uniform.*[i].buff_mem.buffer,
                    .offset = 0,
                    .range = uniform_size,
                };

                try descriptor_writes.append(.{
                    .dst_set = self.descriptor_sets[i],
                    .dst_binding = @intCast(binding_i),
                    .dst_array_element = 0,
                    .descriptor_type = .uniform_buffer,
                    .descriptor_count = 1,
                    .p_buffer_info = @ptrCast(&buffer_info[0]),
                    .p_image_info = undefined,
                    .p_texel_buffer_view = undefined,
                });
            }

            for (0.., samplers) |textures_i, write| {
                const image_infos = try arena_ally.alloc(vk.DescriptorImageInfo, write.textures.len);

                for (image_infos, 0..) |*info, texture_i| info.* = .{
                    .image_layout = .shader_read_only_optimal,
                    .image_view = write.textures[texture_i].image_view,
                    .sampler = write.textures[texture_i].sampler,
                };

                try descriptor_writes.append(.{
                    .dst_set = self.descriptor_sets[i],
                    .dst_binding = @intCast(pipeline_desc.uniform_sizes.len + textures_i),
                    .dst_array_element = 0,
                    .descriptor_type = .combined_image_sampler,
                    .descriptor_count = @intCast(write.textures.len),
                    .p_buffer_info = undefined,
                    .p_image_info = image_infos.ptr,
                    .p_texel_buffer_view = undefined,
                });
            }

            gc.vkd.updateDescriptorSets(gc.dev, @intCast(descriptor_writes.items.len), descriptor_writes.items.ptr, 0, null);
        }
    }

    pub fn createUniformBuffers(self: *Drawing, ally: std.mem.Allocator) !void {
        for (self.pipeline.description.uniform_sizes, self.uniform_buffers) |uniform_enum, *uniform_buffer| {
            var gc = &self.window.gc;
            const uniform_size: usize = @intFromEnum(uniform_enum);

            uniform_buffer.* = try ally.alloc(UniformBuffer, frames_in_flight);

            for (uniform_buffer.*) |*mapped_buff| {
                const buffer = try gc.vkd.createBuffer(gc.dev, &.{
                    .size = uniform_size,
                    .usage = .{ .uniform_buffer_bit = true },
                    .sharing_mode = .exclusive,
                }, null);

                const mem_reqs = gc.vkd.getBufferMemoryRequirements(gc.dev, buffer);
                const memory = try gc.allocate(mem_reqs, .{ .host_visible_bit = true, .host_coherent_bit = true });
                try gc.vkd.bindBufferMemory(gc.dev, buffer, memory, 0);

                const data = try gc.vkd.mapMemory(gc.dev, memory, 0, vk.WHOLE_SIZE, .{});

                mapped_buff.*.buff_mem = .{ .buffer = buffer, .memory = memory };
                mapped_buff.*.data = data.?;
            }
        }
    }

    //pub fn addTexture(self: *Drawing, texture: Texture) !void {
    //    try self.textures.append(texture);
    //}

    pub fn bindIndexBuffer(self: *Drawing, indices: []const u32) !void {
        var gc = &self.window.gc;
        const pool = self.window.pool;

        if (self.index_buffer) |ib| {
            try gc.vkd.deviceWaitIdle(gc.dev);
            ib.deinit(gc);
        }

        const buffer = try gc.vkd.createBuffer(gc.dev, &.{
            .size = @sizeOf(u32) * indices.len,
            .usage = .{ .transfer_dst_bit = true, .index_buffer_bit = true },
            .sharing_mode = .exclusive,
        }, null);

        const mem_reqs = gc.vkd.getBufferMemoryRequirements(gc.dev, buffer);
        const memory = try gc.allocate(mem_reqs, .{ .device_local_bit = true });
        try gc.vkd.bindBufferMemory(gc.dev, buffer, memory, 0);

        const staging_buff = try gc.createStagingBuffer(@sizeOf(u32) * indices.len);
        defer staging_buff.deinit(gc);

        {
            const data = try gc.vkd.mapMemory(gc.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer gc.vkd.unmapMemory(gc.dev, staging_buff.memory);

            const gpu_indices: [*]u32 = @ptrCast(@alignCast(data));
            for (indices, 0..) |index, i| {
                gpu_indices[i] = index;
            }
        }

        try copyBuffer(&self.window.gc, pool, buffer, staging_buff.buffer, @sizeOf(u32) * indices.len);

        self.index_buffer = .{ .buffer = buffer, .memory = memory };
    }

    pub fn draw(self: *Drawing, command_buffer: vk.CommandBuffer, options: struct {
        frame_id: usize,
        bind_pipeline: bool,
    }) !void {
        const gc = &self.window.gc;

        if (options.bind_pipeline) gc.vkd.cmdBindPipeline(command_buffer, .graphics, self.pipeline.vk_pipeline);
        const offset = [_]vk.DeviceSize{0};
        if (self.vertex_buffer) |vb| gc.vkd.cmdBindVertexBuffers(command_buffer, 0, 1, @ptrCast(&vb.buffer), &offset);
        gc.vkd.cmdBindDescriptorSets(
            command_buffer,
            .graphics,
            self.pipeline.layout,
            0,
            1,
            @ptrCast(&self.descriptor_sets[options.frame_id]),
            0,
            null,
        );
        if (self.index_buffer) |ib| {
            gc.vkd.cmdBindIndexBuffer(command_buffer, ib.buffer, 0, .uint32);
            gc.vkd.cmdDrawIndexed(command_buffer, @intCast(self.vert_count), 1, 0, 0, 0);
        } else gc.vkd.cmdDraw(command_buffer, @intCast(self.vert_count), 1, 0, 0);
    }
};

const MapType = struct {
    *anyopaque,
    *Window,
};

// global var
var windowMap: ?std.AutoHashMap(*glfw.GLFWwindow, MapType) = null;
pub var ft_lib: freetype.Library = undefined;

pub fn initGraphics(ally: std.mem.Allocator) !void {
    if (glfw.glfwInit() == glfw.GLFW_FALSE) return GlfwError.FailedGlfwInit;

    if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
        std.log.err("GLFW could not find libvulkan", .{});
        return error.NoVulkan;
    }

    windowMap = std.AutoHashMap(*glfw.GLFWwindow, MapType).init(ally);

    glfw.glfwWindowHint(glfw.GLFW_SAMPLES, 4); // 4x antialiasing
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4); // We want OpenGL 3.3
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 6);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE); // We don't want the old OpenGL

    ft_lib = try freetype.Library.init();
}

pub fn deinitGraphics() void {
    windowMap.?.deinit();
    ft_lib.deinit();
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

        win.gc.vkd.deviceWaitIdle(win.gc.dev) catch |err| {
            printError(err);
        };

        if (win.fixed_size) {
            _ = glfw.glfwSetWindowSize(glfw_win, win.frame_width, win.frame_height);
            if (!win.size_dirty) return;
        }

        swapchain.recreate(&win.gc, .{ .width = @intCast(in_width), .height = @intCast(in_height) }, win.preferred_format) catch |err| {
            printError(err);
        };

        const width: i32 = @intCast(swapchain.extent.width);
        const height: i32 = @intCast(swapchain.extent.height);

        win.destroyFramebuffers();
        win.depth_buffer.deinit(&win.gc);
        win.depth_buffer = Window.createDepthBuffer(&win.gc, swapchain.*, win.pool) catch |err| {
            printError(err);
        };

        win.framebuffers = Window.createFramebuffers(&win.gc, win.ally, win.render_pass.pass, swapchain.*, win.depth_buffer) catch |err| {
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

const PreferredFormat = enum {
    unorm,
    srgb,
    depth,

    pub fn getSurfaceFormat(format: PreferredFormat, gc: GraphicsContext) vk.Format {
        return switch (format) {
            .srgb => .b8g8r8a8_srgb,
            .unorm => .b8g8r8a8_unorm,
            .depth => gc.depth_format,
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
        attachments: []const vk.ImageView,
        render_pass: vk.RenderPass,
        width: u32,
        height: u32,
    };
    buffer: vk.Framebuffer,

    pub fn deinit(fb: Framebuffer, gc: GraphicsContext) void {
        gc.vkd.destroyFramebuffer(gc.dev, fb.buffer, null);
    }
    pub fn init(gc: *const GraphicsContext, info: FramebufferInfo) !Framebuffer {
        return .{
            .buffer = try gc.vkd.createFramebuffer(gc.dev, &.{
                .render_pass = info.render_pass,
                .attachment_count = @intCast(info.attachments.len),
                .p_attachments = info.attachments.ptr,
                .width = info.width,
                .height = info.height,
                .layers = 1,
            }, null),
        };
    }
};

pub const RenderPass = struct {
    pass: vk.RenderPass,
    info: Info,

    pub const Info = struct {
        format: vk.Format,
        multisampling: bool = false,
        target: bool = false,
    };

    pub fn init(gc: *const GraphicsContext, info: Info) !RenderPass {
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

        const color_attachment_ref: vk.AttachmentReference = .{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const depth_attachment: vk.AttachmentDescription = .{
            .format = try gc.findDepthFormat(),
            .samples = if (info.multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .dont_care,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .depth_stencil_attachment_optimal,
        };

        const depth_attachment_ref: vk.AttachmentReference = .{
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

        const color_resolve_attachment_ref: vk.AttachmentReference = .{
            .attachment = 2,
            .layout = .color_attachment_optimal,
        };

        const subpass = vk.SubpassDescription{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast(&color_attachment_ref),
            .p_depth_stencil_attachment = @ptrCast(&depth_attachment_ref),
            .p_resolve_attachments = if (info.multisampling) @ptrCast(&color_resolve_attachment_ref) else null,
        };

        const color_dependency = vk.SubpassDependency{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .dst_stage_mask = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .src_access_mask = .{ .depth_stencil_attachment_write_bit = true },
            .dst_access_mask = .{ .depth_stencil_attachment_write_bit = true, .depth_stencil_attachment_read_bit = true },
        };

        const depth_dependency = vk.SubpassDependency{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_access_mask = .{ .color_attachment_write_bit = true, .color_attachment_read_bit = true },
        };

        const target_first_dependency = vk.SubpassDependency{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .fragment_shader_bit = true },
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{ .shader_read_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true },
        };

        const target_second_dependency = vk.SubpassDependency{
            .src_subpass = 0,
            .dst_subpass = vk.SUBPASS_EXTERNAL,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_stage_mask = .{ .fragment_shader_bit = true },
            .src_access_mask = .{ .color_attachment_write_bit = true },
            .dst_access_mask = .{ .shader_read_bit = true },
        };

        const dependencies: []const vk.SubpassDependency = blk: {
            if (info.target) {
                break :blk &.{ target_first_dependency, target_second_dependency };
            } else {
                break :blk &.{ color_dependency, depth_dependency };
            }
        };

        const attachments: []const vk.AttachmentDescription = blk: {
            if (info.multisampling) {
                break :blk &.{ color_attachment, depth_attachment, color_resolve_attachment };
            } else {
                break :blk &.{ color_attachment, depth_attachment };
            }
        };
        return .{
            .pass = try gc.vkd.createRenderPass(gc.dev, &.{
                .attachment_count = @intCast(attachments.len),
                .p_attachments = attachments.ptr,
                .subpass_count = 1,
                .p_subpasses = @as([*]const vk.SubpassDescription, @ptrCast(&subpass)),
                .dependency_count = @intCast(dependencies.len),
                .p_dependencies = dependencies.ptr,
            }, null),
            .info = info,
        };
    }

    pub fn deinit(pass: RenderPass, gc: *const GraphicsContext) void {
        gc.vkd.destroyRenderPass(gc.dev, pass.pass, null);
    }
};

pub const CommandBuilder = struct {
    buffers: []vk.CommandBuffer,
    frame_id: usize,

    pub const RenderRegion = struct {
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    };

    pub fn beginRenderPass(builder: CommandBuilder, gc: *GraphicsContext, render_pass: RenderPass, framebuffer: Framebuffer, region: RenderRegion) void {
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

        gc.vkd.cmdBeginRenderPass(cmdbuf, &.{
            .render_pass = render_pass.pass,
            .framebuffer = framebuffer.buffer,
            .render_area = render_area,
            .clear_value_count = @intCast(clear_values.len),
            .p_clear_values = clear_values.ptr,
        }, .@"inline");
    }

    pub fn setViewport(builder: *CommandBuilder, gc: *GraphicsContext, info: struct { flip_z: bool, width: u32, height: u32 }) !void {
        const cmdbuf = builder.getCurrent();
        if (info.flip_z) {
            gc.vkd.cmdSetViewport(cmdbuf, 0, 1, @ptrCast(&vk.Viewport{
                .x = 0,
                .y = @as(f32, @floatFromInt(info.height)),
                .width = @as(f32, @floatFromInt(info.width)),
                .height = -@as(f32, @floatFromInt(info.height)),
                .min_depth = 0,
                .max_depth = 1,
            }));
        } else {
            gc.vkd.cmdSetViewport(cmdbuf, 0, 1, @ptrCast(&vk.Viewport{
                .x = 0,
                .y = 0,
                .width = @as(f32, @floatFromInt(info.width)),
                .height = @as(f32, @floatFromInt(info.height)),
                .min_depth = 0,
                .max_depth = 1,
            }));
        }
        gc.vkd.cmdSetScissor(cmdbuf, 0, 1, @ptrCast(&vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = info.width, .height = info.height },
        }));
    }

    pub fn push(builder: *CommandBuilder, comptime self: DataDescription, gc: *GraphicsContext, pipeline: RenderPipeline, constants: *const self.T) void {
        const cmdbuf = builder.getCurrent();
        gc.vkd.cmdPushConstants(cmdbuf, pipeline.layout, .{ .vertex_bit = true, .fragment_bit = true }, 0, @intCast(@intFromEnum(self.getSize())), @alignCast(@ptrCast(constants)));
    }

    pub fn beginCommand(builder: *CommandBuilder, gc: *GraphicsContext) !void {
        const cmdbuf = builder.getCurrent();
        try gc.vkd.resetCommandBuffer(cmdbuf, .{});
        try gc.vkd.beginCommandBuffer(cmdbuf, &.{});
    }

    pub fn endRenderPass(builder: *CommandBuilder, gc: *GraphicsContext) void {
        const cmdbuf = builder.getCurrent();
        gc.vkd.cmdEndRenderPass(cmdbuf);
    }

    pub fn endCommand(builder: *CommandBuilder, gc: *GraphicsContext) !void {
        const cmdbuf = builder.getCurrent();
        try gc.vkd.endCommandBuffer(cmdbuf);
    }

    pub fn getCurrent(builder: CommandBuilder) vk.CommandBuffer {
        return builder.buffers[builder.frame_id];
    }

    pub fn next(builder: *CommandBuilder) void {
        builder.frame_id = (builder.frame_id + 1) % frames_in_flight;
    }
    pub fn init(gc: *GraphicsContext, pool: vk.CommandPool, ally: std.mem.Allocator) !CommandBuilder {
        const cmd_buffs = try ally.alloc(vk.CommandBuffer, frames_in_flight);

        try gc.vkd.allocateCommandBuffers(gc.dev, &.{
            .command_pool = pool,
            .level = .primary,
            .command_buffer_count = @as(u32, @truncate(cmd_buffs.len)),
        }, cmd_buffs.ptr);

        return .{
            .buffers = cmd_buffs,
            .frame_id = 0,
        };
    }

    pub fn deinit(builder: CommandBuilder, gc: *GraphicsContext, pool: vk.CommandPool, ally: std.mem.Allocator) void {
        gc.vkd.freeCommandBuffers(gc.dev, pool, @intCast(builder.buffers.len), builder.buffers.ptr);
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

    gc: GraphicsContext,
    swapchain: Swapchain,
    render_pass: RenderPass,
    pool: vk.CommandPool,
    framebuffers: []Framebuffer,
    depth_buffer: DepthBuffer,

    default_shaders: DefaultShaders,

    const DepthBuffer = struct {
        image: vk.Image,
        view: vk.ImageView,
        memory: vk.DeviceMemory,

        pub fn deinit(buffer: DepthBuffer, gc: *const GraphicsContext) void {
            gc.vkd.destroyImageView(gc.dev, buffer.view, null);
            gc.vkd.destroyImage(gc.dev, buffer.image, null);
            gc.vkd.freeMemory(gc.dev, buffer.memory, null);
        }
    };

    const DefaultShaders = struct {
        sprite_shaders: [2]Shader,
        color_shaders: [2]Shader,
        text_shaders: [2]Shader,
        textft_shaders: [2]Shader,
        post_shaders: [2]Shader,

        pub fn init(gc: GraphicsContext) !DefaultShaders {
            const sprite_vert = try Shader.init(gc, &elem_shaders.sprite_vert, .vertex);
            const sprite_frag = try Shader.init(gc, &elem_shaders.sprite_frag, .fragment);

            const color_vert = try Shader.init(gc, &elem_shaders.color_vert, .vertex);
            const color_frag = try Shader.init(gc, &elem_shaders.color_frag, .fragment);

            const text_vert = try Shader.init(gc, &elem_shaders.text_vert, .vertex);
            const text_frag = try Shader.init(gc, &elem_shaders.text_frag, .fragment);

            const textft_vert = try Shader.init(gc, &elem_shaders.textft_vert, .vertex);
            const textft_frag = try Shader.init(gc, &elem_shaders.textft_frag, .fragment);

            const post_vert = try Shader.init(gc, &elem_shaders.post_vert, .vertex);
            const post_frag = try Shader.init(gc, &elem_shaders.post_frag, .fragment);

            return .{
                .sprite_shaders = .{ sprite_vert, sprite_frag },
                .color_shaders = .{ color_vert, color_frag },
                .text_shaders = .{ text_vert, text_frag },
                .textft_shaders = .{ textft_vert, textft_frag },
                .post_shaders = .{ post_vert, post_frag },
            };
        }

        pub fn deinit(self: DefaultShaders, gc: GraphicsContext) void {
            for (self.sprite_shaders) |s| s.deinit(gc);
            for (self.color_shaders) |s| s.deinit(gc);
            for (self.text_shaders) |s| s.deinit(gc);
            for (self.textft_shaders) |s| s.deinit(gc);
            for (self.post_shaders) |s| s.deinit(gc);
        }
    };

    pub fn swapBuffers(self: Window) void {
        glfw.glfwSwapBuffers(self.glfw_win);
    }

    pub fn shouldClose(self: Window) bool {
        return glfw.glfwWindowShouldClose(self.glfw_win) != 0;
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
        for (self.framebuffers) |fb| fb.deinit(self.gc);
        self.ally.free(self.framebuffers);
    }

    fn createFramebuffers(gc: *GraphicsContext, allocator: Allocator, render_pass: vk.RenderPass, swapchain: Swapchain, depth_image_or: ?DepthBuffer) ![]Framebuffer {
        const framebuffers = try allocator.alloc(Framebuffer, swapchain.swap_images.len);
        errdefer allocator.free(framebuffers);

        var i: usize = 0;
        errdefer for (framebuffers[0..i]) |fb| gc.vkd.destroyFramebuffer(gc.dev, fb.buffer, null);

        for (framebuffers) |*fb| {
            if (depth_image_or) |depth_image| {
                fb.* = try Framebuffer.init(gc, .{
                    .attachments = &.{ swapchain.swap_images[i].view, depth_image.view },
                    .render_pass = render_pass,
                    .width = swapchain.extent.width,
                    .height = swapchain.extent.height,
                });
            } else {
                fb.* = try Framebuffer.init(gc, .{
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

    pub fn createDepthBuffer(gc: *GraphicsContext, swapchain: Swapchain, pool: vk.CommandPool) !DepthBuffer {
        const format = try gc.findDepthFormat();

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

        const image = try gc.vkd.createImage(gc.dev, &image_info, null);
        const mem_reqs = gc.vkd.getImageMemoryRequirements(gc.dev, image);
        const image_memory = try gc.allocate(mem_reqs, .{ .device_local_bit = true });

        try gc.vkd.bindImageMemory(gc.dev, image, image_memory, 0);

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

        const depth_image_view = try gc.vkd.createImageView(gc.dev, &view_info, null);
        try transitionImageLayout(gc, pool, image, .{
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

        var gc = try GraphicsContext.init(ally, info.name, glfw_win);

        const swapchain = try Swapchain.init(&gc, ally, .{ .width = @intCast(info.width), .height = @intCast(info.height) }, info.preferred_format);

        const render_pass = try RenderPass.init(&gc, .{ .format = swapchain.surface_format.format });

        const pool = try gc.vkd.createCommandPool(gc.dev, &.{
            .queue_family_index = gc.graphics_queue.family,
            .flags = .{ .reset_command_buffer_bit = true },
        }, null);

        const depth_buffer = try createDepthBuffer(&gc, swapchain, pool);

        const framebuffers = try createFramebuffers(&gc, ally, render_pass.pass, swapchain, depth_buffer);

        const events: EventTable = .{
            .key_func = null,
            .char_func = null,
            .scroll_func = null,
            .frame_func = null,
            .mouse_func = null,
            .cursor_func = null,
        };

        return Window{
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
            .gc = gc,
            .swapchain = swapchain,
            .render_pass = render_pass,
            .pool = pool,
            .framebuffers = framebuffers,
            .depth_buffer = depth_buffer,
            .default_shaders = try DefaultShaders.init(gc),
        };
    }

    pub fn deinit(win: *Window) void {
        win.default_shaders.deinit(win.gc);
        win.gc.vkd.destroyCommandPool(win.gc.dev, win.pool, null);

        for (win.framebuffers) |fb| fb.deinit(win.gc);
        win.ally.free(win.framebuffers);

        win.render_pass.deinit(&win.gc);
        win.depth_buffer.deinit(&win.gc);

        win.swapchain.deinit(&win.gc);
        win.gc.deinit();
        glfw.glfwDestroyWindow(win.glfw_win);
        //gl.makeDispatchTableCurrent(null);
        glfw.glfwTerminate();
        win.ally.destroy(win);
    }
};

pub const Transform2D = struct {
    scale: Vec2 = Vec2.init(.{ 1, 1 }),
    rotation: struct { angle: f32, center: Vec2 } = .{ .angle = 0, .center = Vec2.init(.{ 0, 0 }) },
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

pub const SceneInfo = struct {
    flip_z: bool = false,
    render_pass: ?*RenderPass = null,
};

pub const Scene = struct {
    drawing_array: std.ArrayList(*Drawing),
    window: *Window,
    render_pass: *RenderPass,
    flip_z: bool,
    default_pipelines: DefaultPipelines,

    const DefaultPipelines = struct {
        color: RenderPipeline,
        sprite: RenderPipeline,
        textft: RenderPipeline,

        pub fn init(win: *Window, render_pass: *RenderPass, flip_z: bool) !DefaultPipelines {
            const shaders = win.default_shaders;

            return .{
                .color = try RenderPipeline.init(win.ally, .{
                    .description = ColoredRect.description,
                    .shaders = &shaders.color_shaders,
                    .render_pass = render_pass.*,
                    .gc = &win.gc,
                    .flipped_z = flip_z,
                }),
                .sprite = try RenderPipeline.init(win.ally, .{
                    .description = Sprite.description,
                    .shaders = &shaders.sprite_shaders,
                    .render_pass = render_pass.*,
                    .gc = &win.gc,
                    .flipped_z = flip_z,
                }),
                .textft = try RenderPipeline.init(win.ally, .{
                    .description = TextFt.description,
                    .shaders = &shaders.textft_shaders,
                    .render_pass = render_pass.*,
                    .gc = &win.gc,
                    .flipped_z = flip_z,
                }),
            };
        }

        pub fn deinit(pipelines: *DefaultPipelines, gc: *const GraphicsContext) void {
            pipelines.color.deinit(gc);
            pipelines.sprite.deinit(gc);
            pipelines.textft.deinit(gc);
        }
    };

    pub fn init(win: *Window, info: SceneInfo) !Scene {
        const render_pass = if (info.render_pass) |pass| pass else &win.render_pass;
        return Scene{
            .drawing_array = std.ArrayList(*Drawing).init(win.ally),
            .window = win,
            .render_pass = render_pass,
            .flip_z = info.flip_z,
            .default_pipelines = try DefaultPipelines.init(win, render_pass, info.flip_z),
        };
    }

    pub fn deinit(scene: *Scene) void {
        for (scene.drawing_array.items) |elem| {
            elem.deinit(scene.window.ally);
            scene.window.ally.destroy(elem);
        }
        scene.drawing_array.deinit();
        scene.default_pipelines.deinit(&scene.window.gc);
    }

    pub fn new(scene: *Scene) !*Drawing {
        const val = try scene.window.ally.create(Drawing);
        try scene.drawing_array.append(val);

        return val;
    }

    pub fn delete(scene: *Scene, ally: std.mem.Allocator, drawing: *Drawing) void {
        const idx_or = std.mem.indexOfScalar(*Drawing, scene.drawing_array.items, drawing);
        if (idx_or) |idx| _ = scene.drawing_array.orderedRemove(idx);
        drawing.deinit(ally);
        ally.destroy(drawing);
    }

    pub fn draw(scene: *Scene, builder: *CommandBuilder) !void {
        const extent = scene.window.swapchain.extent;
        const now: f32 = @floatCast(glfw.glfwGetTime());
        const resolution: [2]f32 = .{ @floatFromInt(extent.width), @floatFromInt(extent.height) };
        const frame_id = builder.frame_id;

        var last_pipeline: u64 = 0;
        var is_first = true;
        for (scene.drawing_array.items) |elem| {
            if (elem.global_ubo) GlobalUniform.setAsUniform(elem, 0, .{ .time = now, .in_resolution = resolution });
            try elem.draw(builder.getCurrent(), .{
                .frame_id = frame_id,
                .bind_pipeline = is_first or (last_pipeline != @intFromEnum(elem.pipeline.vk_pipeline)),
            });
            last_pipeline = @intFromEnum(elem.pipeline.vk_pipeline);
            if (is_first) is_first = false;
        }
    }
};

pub fn getTime() f64 {
    return glfw.glfwGetTime();
}

const RenderType = enum {
    line,
    triangle,
};

pub const VertexAttribute = struct {
    attribute: enum {
        float,
        short,
    } = .float,

    size: usize,

    pub fn getType(comptime self: @This()) type {
        switch (self.attribute) {
            .float => return [self.size]f32,
            .short => return [self.size]i16,
        }
    }

    pub fn getSize(self: @This()) usize {
        switch (self.attribute) {
            .float => return @sizeOf(f32) * self.size,
            .short => return @sizeOf(i16) * self.size,
        }
    }

    pub fn getVK(self: @This()) !vk.Format {
        switch (self.attribute) {
            .float => {
                if (self.size == 2) {
                    return .r32g32_sfloat;
                } else if (self.size == 3) {
                    return .r32g32b32_sfloat;
                } else {
                    return error.UnsupportedVertexSize;
                }
            },
            .short => return .r16g16_sint,
        }
    }
};

pub const VertexDescription = struct {
    vertex_attribs: []const VertexAttribute,

    pub fn getAttributeType(comptime self: VertexDescription) type {
        var types: []const type = &.{};
        for (self.vertex_attribs) |attrib| {
            const t = attrib.getType();
            types = types ++ .{t};
        }
        return std.meta.Tuple(types);
    }

    pub fn getVertexSize(self: VertexDescription) usize {
        var total: usize = 0;
        for (self.vertex_attribs) |attrib| {
            total += attrib.size * @sizeOf(f32);
        }
        return total;
    }

    pub fn bindVertexBuffer(comptime self: VertexDescription, draw: *Drawing, vertices: []const self.getAttributeType()) !void {
        var gc = &draw.window.gc;
        const pool = draw.window.pool;

        if (draw.vertex_buffer) |vb| {
            try gc.vkd.deviceWaitIdle(gc.dev);
            vb.deinit(gc);
        }

        const buffer = try gc.vkd.createBuffer(gc.dev, &.{
            .size = self.getVertexSize() * vertices.len,
            .usage = .{ .transfer_dst_bit = true, .vertex_buffer_bit = true },
            .sharing_mode = .exclusive,
        }, null);

        const mem_reqs = gc.vkd.getBufferMemoryRequirements(gc.dev, buffer);
        const memory = try gc.allocate(mem_reqs, .{ .device_local_bit = true });
        try gc.vkd.bindBufferMemory(gc.dev, buffer, memory, 0);

        const staging_buff = try gc.createStagingBuffer(self.getVertexSize() * vertices.len);
        defer staging_buff.deinit(gc);

        {
            const data = try gc.vkd.mapMemory(gc.dev, staging_buff.memory, 0, vk.WHOLE_SIZE, .{});
            defer gc.vkd.unmapMemory(gc.dev, staging_buff.memory);

            const gpu_vertices: [*]self.getAttributeType() = @ptrCast(@alignCast(data));
            for (vertices, 0..) |vertex, i| {
                gpu_vertices[i] = vertex;
            }
        }

        try copyBuffer(&draw.window.gc, pool, buffer, staging_buff.buffer, self.getVertexSize() * vertices.len);

        draw.vertex_buffer = .{ .buffer = buffer, .memory = memory };
    }

    pub fn bindVertex(comptime self: VertexDescription, draw: *Drawing, vertices: []const self.getAttributeType(), indices: []const u32) !void {
        draw.vert_count = indices.len;

        try self.bindVertexBuffer(draw, vertices);
        try draw.bindIndexBuffer(indices);
    }
};

const CullType = enum {
    front,
    back,
    front_and_back,
    none,
};

pub const SamplerDescription = struct {
    boundless: bool = false,
};

pub const PipelineDescription = struct {
    vertex_description: VertexDescription,
    render_type: RenderType,
    depth_test: bool,
    cull_type: CullType = .none,

    constants_size: ?DataSize = null,
    uniform_sizes: []const DataSize = &.{},
    sampler_descriptions: []const SamplerDescription = &.{},
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

    pub fn getAttributeDescription(pipeline: PipelineDescription) []vk.VertexInputAttributeDescription {
        var loop: [pipeline.vertex_attrib.len]vk.VertexInputAttributeDescription = undefined;
        var off: u32 = 0;
        inline for (pipeline.vertex_attrib, 0..) |attrib, i| {
            loop[i] = .{
                .binding = 0,
                .location = i,
                .format = attrib.getVK(),
                .offset = off,
            };
            off += @sizeOf(attrib.getType());
        }

        return loop;
    }

    pub fn getAttributeType(comptime pipeline: PipelineDescription) type {
        var types: []const type = &.{};
        for (pipeline.vertex_description.vertex_attribs) |attrib| {
            const t = attrib.getType();
            types = types ++ .{t};
        }
        return std.meta.Tuple(types);
    }
};

pub const RenderPipeline = struct {
    ally: std.mem.Allocator,
    description: PipelineDescription,

    vk_pipeline: vk.Pipeline,
    layout: vk.PipelineLayout,
    descriptor_layout: vk.DescriptorSetLayout,
    bindings: []vk.DescriptorSetLayoutBinding,

    pub const Info = struct {
        description: PipelineDescription,
        shaders: []const Shader,
        render_pass: RenderPass,
        gc: *GraphicsContext,
        flipped_z: bool = false,
    };
    pub fn init(ally: std.mem.Allocator, info: Info) !RenderPipeline {
        const shaders = info.shaders;
        const pipeline = info.description;
        const gc = info.gc;

        var bindings = try ally.alloc(vk.DescriptorSetLayoutBinding, pipeline.uniform_sizes.len + pipeline.sampler_descriptions.len);

        var binding_flags = try ally.alloc(vk.DescriptorBindingFlags, pipeline.uniform_sizes.len + pipeline.sampler_descriptions.len);
        defer ally.free(binding_flags);

        for (0..pipeline.uniform_sizes.len) |i| {
            bindings[i] = .{
                .binding = @intCast(i),
                .descriptor_count = 1,
                .descriptor_type = .uniform_buffer,
                .p_immutable_samplers = null,
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
            };

            binding_flags[i] = .{};
        }

        for (pipeline.sampler_descriptions, 0..) |description, i| {
            bindings[pipeline.uniform_sizes.len + i] = vk.DescriptorSetLayoutBinding{
                .binding = @intCast(pipeline.uniform_sizes.len + i),
                .descriptor_count = if (description.boundless) 256 else 1,
                .descriptor_type = .combined_image_sampler,
                .p_immutable_samplers = null,
                .stage_flags = .{ .fragment_bit = true },
            };

            binding_flags[pipeline.uniform_sizes.len + i] = if (description.boundless) .{
                .variable_descriptor_count_bit = true,
                .partially_bound_bit = true,
                .update_after_bind_bit = true,
                .update_unused_while_pending_bit = true,
            } else .{};
        }

        const layout_info: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = @intCast(bindings.len),
            .p_bindings = bindings.ptr,
            .flags = .{ .update_after_bind_pool_bit = pipeline.bindless },
            .p_next = &vk.DescriptorSetLayoutBindingFlagsCreateInfo{
                .binding_count = @intCast(bindings.len),
                .p_binding_flags = binding_flags.ptr,
            },
        };

        const descriptor_layout = try gc.vkd.createDescriptorSetLayout(gc.dev, &layout_info, null);
        const pipeline_layout = try gc.vkd.createPipelineLayout(gc.dev, &.{
            .flags = .{},
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast(&descriptor_layout),
            .push_constant_range_count = if (pipeline.constants_size) |_| 1 else 0,
            .p_push_constant_ranges = if (pipeline.constants_size) |size| @ptrCast(&vk.PushConstantRange{
                .offset = 0,
                .size = @intCast(@intFromEnum(size)),
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
            }) else undefined,
        }, null);

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

        var attribute_desc = try ally.alloc(vk.VertexInputAttributeDescription, pipeline.vertex_description.vertex_attribs.len);
        defer ally.free(attribute_desc);
        {
            var off: u32 = 0;
            for (pipeline.vertex_description.vertex_attribs, 0..) |attrib, i| {
                attribute_desc[i] = .{
                    .binding = 0,
                    .location = @intCast(i),
                    .format = try attrib.getVK(),
                    .offset = off,
                };
                off += @intCast(attrib.getSize()); // ?
            }
        }

        const binding_description = pipeline.getBindingDescription();

        const dynstate = [_]vk.DynamicState{ .viewport, .scissor };

        var vk_pipeline: vk.Pipeline = undefined;
        _ = try gc.vkd.createGraphicsPipelines(
            gc.dev,
            .null_handle,
            1,
            @ptrCast(&vk.GraphicsPipelineCreateInfo{
                .flags = .{},
                .stage_count = @intCast(pssci.len),
                .p_stages = pssci.ptr,
                .p_vertex_input_state = &vk.PipelineVertexInputStateCreateInfo{
                    .vertex_binding_description_count = 1,
                    .p_vertex_binding_descriptions = @ptrCast(&binding_description),
                    .vertex_attribute_description_count = @intCast(attribute_desc.len),
                    .p_vertex_attribute_descriptions = attribute_desc.ptr,
                },
                .p_input_assembly_state = &vk.PipelineInputAssemblyStateCreateInfo{
                    .topology = .triangle_list,
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
                    .cull_mode = switch (pipeline.cull_type) {
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
                    .rasterization_samples = if (info.render_pass.info.multisampling) .{ .@"8_bit" = true } else .{ .@"1_bit" = true },
                    .sample_shading_enable = vk.FALSE,
                    .min_sample_shading = 1,
                    .alpha_to_coverage_enable = vk.FALSE,
                    .alpha_to_one_enable = vk.FALSE,
                },
                .p_depth_stencil_state = &vk.PipelineDepthStencilStateCreateInfo{
                    .depth_test_enable = if (pipeline.depth_test) vk.TRUE else vk.FALSE,
                    .depth_write_enable = if (pipeline.depth_test) vk.TRUE else vk.FALSE,
                    .depth_compare_op = .less,
                    .depth_bounds_test_enable = vk.FALSE,
                    .min_depth_bounds = 0,
                    .max_depth_bounds = 0,
                    .stencil_test_enable = vk.FALSE,
                    .front = undefined,
                    .back = undefined,
                },
                .p_color_blend_state = &vk.PipelineColorBlendStateCreateInfo{
                    .logic_op_enable = vk.FALSE,
                    .logic_op = .clear,
                    .attachment_count = 1,
                    .p_attachments = @ptrCast(&vk.PipelineColorBlendAttachmentState{
                        .blend_enable = vk.TRUE,
                        .src_color_blend_factor = .src_alpha,
                        .dst_color_blend_factor = .one_minus_src_alpha,
                        .color_blend_op = .add,
                        .src_alpha_blend_factor = .one,
                        .dst_alpha_blend_factor = .one_minus_src_alpha,
                        .alpha_blend_op = .add,
                        .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
                    }),
                    .blend_constants = [_]f32{ 0, 0, 0, 0 },
                },
                .p_dynamic_state = &vk.PipelineDynamicStateCreateInfo{
                    .flags = .{},
                    .dynamic_state_count = dynstate.len,
                    .p_dynamic_states = &dynstate,
                },
                .layout = pipeline_layout,
                .render_pass = info.render_pass.pass,
                .subpass = 0,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = -1,
            }),
            null,
            @ptrCast(&vk_pipeline),
        );
        return .{
            .vk_pipeline = vk_pipeline,
            .layout = pipeline_layout,
            .descriptor_layout = descriptor_layout,
            .ally = ally,
            .bindings = bindings,
            .description = info.description,
        };
    }

    pub fn deinit(self: *RenderPipeline, gc: *const GraphicsContext) void {
        self.ally.free(self.bindings);
        gc.vkd.deviceWaitIdle(gc.dev) catch return;
        gc.vkd.destroyPipeline(gc.dev, self.vk_pipeline, null);
        gc.vkd.destroyPipelineLayout(gc.dev, self.layout, null);
        gc.vkd.destroyDescriptorSetLayout(gc.dev, self.descriptor_layout, null);
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

pub const DataSize = enum(usize) { _ };

pub const DataDescription = struct {
    T: type,

    pub fn getSize(comptime self: DataDescription) DataSize {
        std.mem.doNotOptimizeAway(@sizeOf(self.T));
        return @enumFromInt(@sizeOf(self.T));
    }

    pub fn setAsUniform(comptime self: DataDescription, draw: *Drawing, binding_idx: usize, ubo: self.T) void {
        for (draw.uniform_buffers[binding_idx]) |mapped_buff| {
            @as(*self.T, @alignCast(@ptrCast(mapped_buff.data))).* = ubo;
        }
    }
    pub fn setAsUniformField(comptime self: DataDescription, draw: *Drawing, binding_idx: usize, comptime field: std.meta.FieldEnum(self.T), target: anytype) void {
        for (draw.uniform_buffers[binding_idx]) |mapped_buff| {
            @field(@as(*self.T, @alignCast(@ptrCast(mapped_buff.data))), @tagName(field)) = target;
        }
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
