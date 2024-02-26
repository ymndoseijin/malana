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
pub const SpatialMesh = @import("spatialmesh.zig").SpatialMesh;
pub const ObjParse = @import("obj.zig").ObjParse;
pub const ComptimeMeshBuilder = @import("comptime_meshbuilder.zig").ComptimeMeshBuilder;

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

    allocator: Allocator,

    surface_format: vk.SurfaceFormatKHR,
    present_mode: vk.PresentModeKHR,
    extent: vk.Extent2D,
    handle: vk.SwapchainKHR,

    swap_images: []SwapImage,

    pub fn init(gc: *const GraphicsContext, allocator: Allocator, extent: vk.Extent2D) !Swapchain {
        return try initRecycle(gc, allocator, extent, .null_handle);
    }

    pub fn initRecycle(gc: *const GraphicsContext, allocator: Allocator, extent: vk.Extent2D, old_handle: vk.SwapchainKHR) !Swapchain {
        const caps = try gc.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(gc.pdev, gc.surface);
        const actual_extent = findActualExtent(caps, extent);
        if (actual_extent.width == 0 or actual_extent.height == 0) {
            return error.InvalidSurfaceDimensions;
        }

        const surface_format = try findSurfaceFormat(gc, allocator);
        const present_mode = try findPresentMode(gc, allocator);

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
            .old_swapchain = old_handle,
        }, null);
        errdefer gc.vkd.destroySwapchainKHR(gc.dev, handle, null);

        if (old_handle != .null_handle) {
            gc.vkd.destroySwapchainKHR(gc.dev, old_handle, null);
        }

        const swap_images = try initSwapchainImages(gc, handle, surface_format.format, allocator);
        errdefer {
            for (swap_images) |si| si.deinit(gc);
            allocator.free(swap_images);
        }
        //errdefer gc.vkd.destroySemaphore(gc.dev, next_image_acquired, null);

        return Swapchain{
            .allocator = allocator,
            .surface_format = surface_format,
            .present_mode = present_mode,
            .extent = actual_extent,
            .handle = handle,
            .swap_images = swap_images,
        };
    }

    fn deinitExceptSwapchain(self: Swapchain, gc: *GraphicsContext) void {
        for (self.swap_images) |si| si.deinit(gc);
        self.allocator.free(self.swap_images);
    }

    pub fn deinit(self: Swapchain, gc: *GraphicsContext) void {
        self.deinitExceptSwapchain(gc);
        gc.vkd.destroySwapchainKHR(gc.dev, self.handle, null);
    }

    pub fn recreate(self: *Swapchain, gc: *GraphicsContext, new_extent: vk.Extent2D) !void {
        const allocator = self.allocator;
        const old_handle = self.handle;
        self.deinitExceptSwapchain(gc);
        self.* = try initRecycle(gc, allocator, new_extent, old_handle);
    }
};

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,

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

        const render_finished = try gc.vkd.createSemaphore(gc.dev, &.{}, null);
        errdefer gc.vkd.destroySemaphore(gc.dev, render_finished, null);

        const frame_fence = try gc.vkd.createFence(gc.dev, &.{ .flags = .{ .signaled_bit = true } }, null);
        errdefer gc.vkd.destroyFence(gc.dev, frame_fence, null);

        return SwapImage{
            .image = image,
            .view = view,
            .image_acquired = image_acquired,
            .render_finished = render_finished,
            .frame_fence = frame_fence,
        };
    }

    fn deinit(self: SwapImage, gc: *const GraphicsContext) void {
        self.waitForFence(gc) catch return;
        gc.vkd.destroyImageView(gc.dev, self.view, null);
        gc.vkd.destroySemaphore(gc.dev, self.image_acquired, null);
        gc.vkd.destroySemaphore(gc.dev, self.render_finished, null);
        gc.vkd.destroyFence(gc.dev, self.frame_fence, null);
    }

    fn waitForFence(self: SwapImage, gc: *const GraphicsContext) !void {
        _ = try gc.vkd.waitForFences(gc.dev, 1, @ptrCast(&self.frame_fence), vk.TRUE, std.math.maxInt(u64));
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

fn findSurfaceFormat(gc: *const GraphicsContext, allocator: Allocator) !vk.SurfaceFormatKHR {
    const preferred = vk.SurfaceFormatKHR{
        .format = .b8g8r8a8_srgb,
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

    return surface_formats[0]; // There must always be at least one supported surface format
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
};

pub const Texture = struct {
    info: TextureInfo,

    width: u32,
    height: u32,

    // vulkan
    image: vk.Image,
    window: *Window,
    sampler: vk.Sampler,
    image_view: vk.ImageView,
    memory: vk.DeviceMemory,

    pub fn init(win: *Window, width: u32, height: u32, info: TextureInfo) !Texture {
        const image_info: vk.ImageCreateInfo = .{
            .image_type = .@"2d",
            .extent = .{ .width = width, .height = height, .depth = 1 },
            .mip_levels = 1,
            .array_layers = 1,
            .format = .r8g8b8a8_srgb,
            .tiling = .linear,
            .initial_layout = .undefined,
            .usage = .{ .transfer_dst_bit = true, .sampled_bit = true },
            .samples = .{ .@"1_bit" = true },
            .sharing_mode = .exclusive,
        };

        const image = try win.gc.vkd.createImage(win.gc.dev, &image_info, null);
        const mem_reqs = win.gc.vkd.getImageMemoryRequirements(win.gc.dev, image);
        const image_memory = try win.gc.allocate(mem_reqs, .{ .device_local_bit = true });
        try win.gc.vkd.bindImageMemory(win.gc.dev, image, image_memory, 0);

        return .{
            .info = info,
            .image = image,
            .window = win,
            .width = width,
            .height = height,
            .sampler = undefined,
            .image_view = undefined,
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

        tex.sampler = try gc.vkd.createSampler(gc.dev, &sampler_info, null);
    }

    fn createImageView(tex: *Texture) !void {
        const gc = &tex.window.gc;

        const view_info: vk.ImageViewCreateInfo = .{
            .image = tex.image,
            .view_type = .@"2d",
            .format = .r8g8b8a8_srgb,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        };

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
                .layer_count = 1,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{ .width = tex.width, .height = tex.height, .depth = 1 },
        };

        tex.window.gc.vkd.cmdCopyBufferToImage(cmdbuf, buffer, tex.image, .transfer_dst_optimal, 1, @ptrCast(&region));

        try finishSingleCommandBuffer(cmdbuf, &tex.window.gc);
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

        try transitionImageLayout(&tex.window.gc, tex.window.pool, tex.image, .undefined, .transfer_dst_optimal);
        try tex.copyBufferToImage(staging_buff.buffer);
        try transitionImageLayout(&tex.window.gc, tex.window.pool, tex.image, .transfer_dst_optimal, .shader_read_only_optimal);
    }

    pub fn setFromRgba(self: *Texture, rgba: anytype) !void {
        try self.createImage(rgba);
        try self.createImageView();
        try self.createTextureSampler();
    }
};

pub fn transitionImageLayout(gc: *const GraphicsContext, pool: vk.CommandPool, image: vk.Image, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) !void {
    const cmdbuf = try createSingleCommandBuffer(gc, pool);
    defer freeSingleCommandBuffer(cmdbuf, gc, pool);

    const barrier: vk.ImageMemoryBarrier = .{
        .old_layout = old_layout,
        .new_layout = new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresource_range = .{
            // stencil also has to be marked if the format supports it
            .aspect_mask = if (new_layout == .depth_stencil_attachment_optimal) .{ .depth_bit = true } else .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .src_access_mask = switch (old_layout) {
            .undefined => .{},
            .transfer_dst_optimal => .{ .transfer_write_bit = true },
            else => return error.InvalidOldLayout,
        },
        .dst_access_mask = switch (new_layout) {
            .transfer_dst_optimal => .{ .transfer_write_bit = true },
            .shader_read_only_optimal => .{ .shader_read_bit = true },
            .depth_stencil_attachment_optimal => .{ .depth_stencil_attachment_read_bit = true, .depth_stencil_attachment_write_bit = true },
            else => return error.InvalidNewLayout,
        },
    };

    gc.vkd.cmdPipelineBarrier(
        cmdbuf,
        switch (old_layout) {
            .undefined => .{ .top_of_pipe_bit = true },
            .transfer_dst_optimal => .{ .transfer_bit = true },
            else => return error.InvalidOldLayout,
        },
        switch (new_layout) {
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
    vk_pipeline: vk.Pipeline,

    uniform_buffers: [][]UniformBuffer,
    //uniform_buffers: [pipeline.samplers][]UniformBuffer,
    descriptor_sets: []vk.DescriptorSet,

    descriptor_pool: vk.DescriptorPool,
    descriptor_layout: vk.DescriptorSetLayout,

    layout: vk.PipelineLayout,

    window: *Window,

    global_ubo: bool,

    const UniformBuffer = struct {
        buff_mem: BufferMemory,
        data: *anyopaque,
    };

    pub fn init(drawing: *Drawing, ally: std.mem.Allocator, win: *Window, shaders: []Shader, pipeline: RenderPipeline) !void {
        const gc = &win.gc;

        var bindings = try ally.alloc(vk.DescriptorSetLayoutBinding, pipeline.uniform_sizes.len + pipeline.samplers.len);
        defer ally.free(bindings);
        for (0..pipeline.uniform_sizes.len) |i| {
            bindings[i] = vk.DescriptorSetLayoutBinding{
                .binding = @intCast(i),
                .descriptor_count = 1,
                .descriptor_type = .uniform_buffer,
                .p_immutable_samplers = null,
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
            };
        }
        for (0..pipeline.samplers.len) |i| {
            bindings[pipeline.uniform_sizes.len + i] = vk.DescriptorSetLayoutBinding{
                .binding = @intCast(pipeline.uniform_sizes.len + i),
                .descriptor_count = 1,
                .descriptor_type = .combined_image_sampler,
                .p_immutable_samplers = null,
                .stage_flags = .{ .fragment_bit = true },
            };
        }

        const layout_info: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = @intCast(bindings.len),
            .p_bindings = bindings.ptr,
        };

        const descriptor_layout = try gc.vkd.createDescriptorSetLayout(gc.dev, &layout_info, null);
        const pipeline_layout = try gc.vkd.createPipelineLayout(gc.dev, &.{
            .flags = .{},
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast(&descriptor_layout),
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
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
                    .cull_mode = .{ .back_bit = true },
                    .front_face = .clockwise,
                    .depth_bias_enable = vk.FALSE,
                    .depth_bias_constant_factor = 0,
                    .depth_bias_clamp = 0,
                    .depth_bias_slope_factor = 0,
                    .line_width = 1,
                },
                .p_multisample_state = &vk.PipelineMultisampleStateCreateInfo{
                    .rasterization_samples = .{ .@"1_bit" = true },
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
                .render_pass = win.render_pass,
                .subpass = 0,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = -1,
            }),
            null,
            @ptrCast(&vk_pipeline),
        );

        const frames: u32 = frames_in_flight;

        const pool_sizes = try ally.alloc(vk.DescriptorPoolSize, bindings.len);
        defer ally.free(pool_sizes);

        for (pool_sizes, bindings) |*pool_size, binding| {
            pool_size.* = .{
                .type = binding.descriptor_type,
                //.descriptor_count = binding.descriptor_count * max_sets,
                .descriptor_count = frames,
            };
        }

        const pool_info = vk.DescriptorPoolCreateInfo{
            .max_sets = frames,
            .p_pool_sizes = pool_sizes.ptr,
            .pool_size_count = @intCast(bindings.len),
        };

        const uniforms = try ally.alloc([]UniformBuffer, pipeline.uniform_sizes.len);

        for (uniforms) |*u| u.* = &.{};

        drawing.* = .{
            //.cube_textures = std.ArrayList(u32).init(ally),
            .vert_count = 0,
            .vk_pipeline = vk_pipeline,
            .layout = pipeline_layout,
            .vertex_buffer = null,
            .index_buffer = null,
            .descriptor_pool = try gc.vkd.createDescriptorPool(gc.dev, &pool_info, null),
            .uniform_buffers = uniforms,
            .descriptor_sets = &.{},
            .descriptor_layout = descriptor_layout,
            .window = win,
            .global_ubo = pipeline.global_ubo,
            //.shader = shader,
            //.textures = std.ArrayList(Texture).init(ally),
        };

        try drawing.createUniformBuffers(ally, pipeline);
        try drawing.createDescriptorSets(ally, pipeline);
    }

    pub fn deinit(
        self: *Drawing,
        ally: std.mem.Allocator,
    ) void {
        //self.textures.deinit();
        //self.cube_textures.deinit();
        //self.vertex_buffer.deinit(&self.window.gc);
        //self.index_buffer.deinit(&self.window.gc);

        const win = self.window;

        win.gc.vkd.deviceWaitIdle(win.gc.dev) catch return;

        win.gc.vkd.destroyPipeline(win.gc.dev, self.vk_pipeline, null);
        win.gc.vkd.destroyPipelineLayout(win.gc.dev, self.layout, null);

        for (self.uniform_buffers) |ubs| {
            for (ubs) |ub| ub.buff_mem.deinit(&win.gc);
            ally.free(ubs);
        }
        ally.free(self.uniform_buffers);

        win.gc.vkd.destroyDescriptorPool(win.gc.dev, self.descriptor_pool, null);

        win.gc.vkd.destroyDescriptorSetLayout(win.gc.dev, self.descriptor_layout, null);

        ally.free(self.descriptor_sets);

        if (self.index_buffer) |ib| ib.deinit(&win.gc);
        if (self.vertex_buffer) |vb| vb.deinit(&win.gc);

        // for (size_t i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        //     vkDestroySemaphore(device, renderFinishedSemaphores[i], nullptr);
        //     vkDestroySemaphore(device, imageAvailableSemaphores[i], nullptr);
        //     vkDestroyFence(device, inFlightFences[i], nullptr);
        // }

        // vkDestroyCommandPool(device, commandPool, nullptr);

        // vkDestroyDevice(device, nullptr);

        // if (enableValidationLayers) {
        //     DestroyDebugUtilsMessengerEXT(instance, debugMessenger, nullptr);
        // }

        // vkDestroySurfaceKHR(instance, surface, nullptr);
        // vkDestroyInstance(instance, nullptr);
    }

    const cubemapOrientation = enum { xp, yp, zp, xm, ym, zm };

    pub fn getIthTexture(comptime T: type, i: usize) !T {
        if (i > 31) return error.TooManyTextures;
        return @intCast(0x84C0 + i);
    }

    pub fn createDescriptorSets(self: *Drawing, ally: std.mem.Allocator, pipeline: RenderPipeline) !void {
        var gc = &self.window.gc;
        const layouts = try ally.alloc(vk.DescriptorSetLayout, frames_in_flight);
        defer ally.free(layouts);
        for (layouts) |*l| l.* = self.descriptor_layout;

        const frames: u32 = @intCast(frames_in_flight);
        const allocate_info = vk.DescriptorSetAllocateInfo{
            .descriptor_pool = self.descriptor_pool,
            .descriptor_set_count = frames,
            .p_set_layouts = layouts.ptr,
        };

        self.descriptor_sets = try ally.alloc(vk.DescriptorSet, frames_in_flight);

        try gc.vkd.allocateDescriptorSets(gc.dev, &allocate_info, self.descriptor_sets.ptr);
        try self.updateDescriptorSets(ally, pipeline);
    }

    pub fn updateDescriptorSets(self: *Drawing, ally: std.mem.Allocator, pipeline: RenderPipeline) !void {
        var gc = &self.window.gc;
        for (0..frames_in_flight) |i| {
            var descriptor_writes = try ally.alloc(vk.WriteDescriptorSet, pipeline.samplers.len + pipeline.uniform_sizes.len);
            var buffer_info = try ally.alloc(vk.DescriptorBufferInfo, pipeline.samplers.len + pipeline.uniform_sizes.len);

            defer ally.free(descriptor_writes);
            defer ally.free(buffer_info);

            for (0.., self.uniform_buffers, pipeline.uniform_sizes) |binding_i, *uniform, uniform_size| {
                buffer_info[binding_i] = vk.DescriptorBufferInfo{
                    .buffer = uniform.*[i].buff_mem.buffer,
                    .offset = 0,
                    .range = uniform_size,
                };

                descriptor_writes[binding_i] = vk.WriteDescriptorSet{
                    .dst_set = self.descriptor_sets[i],
                    .dst_binding = @intCast(binding_i),
                    .dst_array_element = 0,
                    .descriptor_type = .uniform_buffer,
                    .descriptor_count = 1,
                    .p_buffer_info = @ptrCast(&buffer_info[binding_i]),
                    .p_image_info = undefined,
                    .p_texel_buffer_view = undefined,
                };
            }

            var image_info = try ally.alloc(vk.DescriptorImageInfo, pipeline.samplers.len + pipeline.uniform_sizes.len);
            defer ally.free(image_info);

            for (0.., pipeline.samplers) |texture_i, texture| {
                image_info[texture_i] = vk.DescriptorImageInfo{
                    .image_layout = .shader_read_only_optimal,
                    .image_view = texture.image_view,
                    .sampler = texture.sampler,
                };

                descriptor_writes[pipeline.uniform_sizes.len + texture_i] = vk.WriteDescriptorSet{
                    .dst_set = self.descriptor_sets[i],
                    .dst_binding = @intCast(pipeline.uniform_sizes.len + texture_i),
                    .dst_array_element = 0,
                    .descriptor_type = .combined_image_sampler,
                    .descriptor_count = 1,
                    .p_buffer_info = undefined,
                    .p_image_info = @ptrCast(&image_info[texture_i]),
                    .p_texel_buffer_view = undefined,
                };
            }

            gc.vkd.updateDescriptorSets(gc.dev, @intCast(descriptor_writes.len), descriptor_writes.ptr, 0, null);
        }
    }

    pub fn createUniformBuffers(self: *Drawing, ally: std.mem.Allocator, pipeline: RenderPipeline) !void {
        for (pipeline.uniform_sizes, self.uniform_buffers) |uniform_size, *uniform_buffer| {
            var gc = &self.window.gc;

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

    pub fn draw(self: *Drawing, frame_id: usize, command_buffer: vk.CommandBuffer) !void {
        const gc = &self.window.gc;

        gc.vkd.cmdBindPipeline(command_buffer, .graphics, self.vk_pipeline);
        const offset = [_]vk.DeviceSize{0};
        if (self.vertex_buffer) |vb| gc.vkd.cmdBindVertexBuffers(command_buffer, 0, 1, @ptrCast(&vb.buffer), &offset);
        gc.vkd.cmdBindDescriptorSets(
            command_buffer,
            .graphics,
            self.layout,
            0,
            1,
            @ptrCast(&self.descriptor_sets[frame_id]),
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

pub fn getFramebufferSize(win_or: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    const glfw_win = win_or orelse return;

    if (windowMap.?.get(glfw_win)) |map| {
        var win = map[1];

        win.gc.vkd.deviceWaitIdle(win.gc.dev) catch |err| {
            printError(err);
        };

        if (win.fixed_size) {
            _ = glfw.glfwSetWindowSize(glfw_win, win.frame_width, win.frame_height);
            if (!win.size_dirty) return;
        }

        win.swapchain.recreate(&win.gc, .{ .width = @intCast(width), .height = @intCast(height) }) catch |err| {
            printError(err);
        };

        win.destroyFramebuffers();
        win.depth_buffer.deinit(&win.gc);
        win.depth_buffer = Window.createDepthBuffer(&win.gc, win.swapchain, win.pool) catch |err| {
            printError(err);
        };

        win.framebuffers = Window.createFramebuffers(&win.gc, win.ally, win.render_pass, win.swapchain, win.depth_buffer) catch |err| {
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

pub const WindowInfo = struct {
    width: i32 = 256,
    height: i32 = 256,
    resizable: bool = true,
    name: [:0]const u8 = "default name",
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
    ally: std.mem.Allocator,

    events: EventTable,

    gc: GraphicsContext,
    swapchain: Swapchain,
    render_pass: vk.RenderPass,
    pool: vk.CommandPool,
    framebuffers: []vk.Framebuffer,
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

        pub fn init(gc: GraphicsContext) !DefaultShaders {
            const sprite_vert = try Shader.init(gc, &elem_shaders.sprite_vert, .vertex);
            const sprite_frag = try Shader.init(gc, &elem_shaders.sprite_frag, .fragment);

            const color_vert = try Shader.init(gc, &elem_shaders.color_vert, .vertex);
            const color_frag = try Shader.init(gc, &elem_shaders.color_frag, .fragment);

            const text_vert = try Shader.init(gc, &elem_shaders.text_vert, .vertex);
            const text_frag = try Shader.init(gc, &elem_shaders.text_frag, .fragment);

            const textft_vert = try Shader.init(gc, &elem_shaders.textft_vert, .vertex);
            const textft_frag = try Shader.init(gc, &elem_shaders.textft_frag, .fragment);

            return .{
                .sprite_shaders = .{ sprite_vert, sprite_frag },
                .color_shaders = .{ color_vert, color_frag },
                .text_shaders = .{ text_vert, text_frag },
                .textft_shaders = .{ textft_vert, textft_frag },
            };
        }

        pub fn deinit(self: DefaultShaders, gc: GraphicsContext) void {
            for (self.sprite_shaders) |s| s.deinit(gc);
            for (self.color_shaders) |s| s.deinit(gc);
            for (self.text_shaders) |s| s.deinit(gc);
            for (self.textft_shaders) |s| s.deinit(gc);
        }
    };

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
        for (self.framebuffers) |fb| self.gc.vkd.destroyFramebuffer(self.gc.dev, fb, null);
    }

    fn createFramebuffers(gc: *GraphicsContext, allocator: Allocator, render_pass: vk.RenderPass, swapchain: Swapchain, depth_image_or: ?DepthBuffer) ![]vk.Framebuffer {
        const framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.swap_images.len);
        errdefer allocator.free(framebuffers);

        var i: usize = 0;
        errdefer for (framebuffers[0..i]) |fb| gc.vkd.destroyFramebuffer(gc.dev, fb, null);

        for (framebuffers) |*fb| {
            if (depth_image_or) |depth_image| {
                const attachments = [2]vk.ImageView{ swapchain.swap_images[i].view, depth_image.view };
                fb.* = try gc.vkd.createFramebuffer(gc.dev, &.{
                    .render_pass = render_pass,
                    .attachment_count = attachments.len,
                    .p_attachments = &attachments,
                    .width = swapchain.extent.width,
                    .height = swapchain.extent.height,
                    .layers = 1,
                }, null);
            } else {
                fb.* = try gc.vkd.createFramebuffer(gc.dev, &.{
                    .render_pass = render_pass,
                    .attachment_count = 1,
                    .p_attachments = @ptrCast(&swapchain.swap_images[i].view),
                    .width = swapchain.extent.width,
                    .height = swapchain.extent.height,
                    .layers = 1,
                }, null);
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
        try transitionImageLayout(gc, pool, image, .undefined, .depth_stencil_attachment_optimal);

        return .{ .view = depth_image_view, .image = image, .memory = image_memory };
    }
    pub fn init(info: WindowInfo, ally: std.mem.Allocator) !*Window {
        var win = try ally.create(Window);
        win.* = try initBare(info, ally);
        try win.addToMap(win);
        return win;
    }

    fn createRenderPass(gc: *const GraphicsContext, swapchain: Swapchain) !vk.RenderPass {
        const color_attachment = vk.AttachmentDescription{
            .format = swapchain.surface_format.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .present_src_khr,
        };

        const color_attachment_ref = vk.AttachmentReference{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const depth_attachment = vk.AttachmentDescription{
            .format = try gc.findDepthFormat(),
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .dont_care,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .depth_stencil_attachment_optimal,
        };

        const depth_attachment_ref = vk.AttachmentReference{
            .attachment = 1,
            .layout = .depth_stencil_attachment_optimal,
        };

        const subpass = vk.SubpassDescription{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast(&color_attachment_ref),
            .p_depth_stencil_attachment = @ptrCast(&depth_attachment_ref),
        };

        const dependency = vk.SubpassDependency{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true, .early_fragment_tests_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true, .early_fragment_tests_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true, .depth_stencil_attachment_write_bit = true },
        };

        const attachments = &[2]vk.AttachmentDescription{ color_attachment, depth_attachment };

        return try gc.vkd.createRenderPass(gc.dev, &.{
            .attachment_count = @intCast(attachments.len),
            .p_attachments = attachments.ptr,
            .subpass_count = 1,
            .p_subpasses = @as([*]const vk.SubpassDescription, @ptrCast(&subpass)),
            .dependency_count = 1,
            .p_dependencies = @as([*]const vk.SubpassDependency, @ptrCast(&dependency)),
        }, null);
    }

    pub fn initBare(info: WindowInfo, ally: std.mem.Allocator) !Window {
        glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, if (info.resizable) glfw.GLFW_TRUE else glfw.GLFW_FALSE);
        glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
        std.debug.print("por que {any}\n", .{info});
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

        const swapchain = try Swapchain.init(&gc, ally, .{ .width = @intCast(info.width), .height = @intCast(info.height) });

        const render_pass = try createRenderPass(&gc, swapchain);

        const pool = try gc.vkd.createCommandPool(gc.dev, &.{
            .queue_family_index = gc.graphics_queue.family,
            .flags = .{ .reset_command_buffer_bit = true },
        }, null);

        const depth_buffer = try createDepthBuffer(&gc, swapchain, pool);

        const framebuffers = try createFramebuffers(&gc, ally, render_pass, swapchain, depth_buffer);

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

    pub fn deinit(self: *Window) void {
        self.default_shaders.deinit(self.gc);
        self.gc.vkd.destroyCommandPool(self.gc.dev, self.pool, null);

        for (self.framebuffers) |fb| self.gc.vkd.destroyFramebuffer(self.gc.dev, fb, null);
        self.ally.free(self.framebuffers);

        self.gc.vkd.destroyRenderPass(self.gc.dev, self.render_pass, null);
        self.depth_buffer.deinit(&self.gc);

        self.swapchain.deinit(&self.gc);
        self.gc.deinit();
        glfw.glfwDestroyWindow(self.glfw_win);
        //gl.makeDispatchTableCurrent(null);
        glfw.glfwTerminate();
        self.ally.destroy(self);
    }
};

pub const Transform2D = struct {
    scale: math.Vec2,
    rotation: struct { angle: f32, center: math.Vec2 },
    translation: math.Vec2,
    pub fn getMat(self: Transform2D) math.Mat3 {
        return math.transform2D(f32, self.scale, self.rotation, self.translation);
    }
    pub fn getInverseMat(self: Transform2D) math.Mat3 {
        return math.transform2D(f32, math.Vec2{ 1, 1 } / self.scale, .{ .angle = -self.rotation.angle, .center = self.rotation.center }, math.Vec2{ -1, -1 } * self.translation / self.scale);
    }
    pub fn apply(self: Transform2D, v: math.Vec2) math.Vec2 {
        var res: [3]f32 = self.getMat().dot(.{ v[0], v[1], 1 });
        return res[0..2].*;
    }

    pub fn reverse(self: Transform2D, v: math.Vec2) math.Vec2 {
        var res: [3]f32 = self.getInverseMat().dot(.{ v[0], v[1], 1 });
        return res[0..2].*;
    }
};

const Uniform1f = struct {
    name: [:0]const u8,
    value: *f32,
};

const Uniform3f = struct {
    name: [:0]const u8,
    value: *math.Vec3,
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

pub const Scene = struct {
    drawing_array: std.ArrayList(*Drawing),

    // vulkan
    command_buffers: []vk.CommandBuffer,
    window: *Window,

    frame_id: usize,

    const Self = @This();
    pub fn init(win: *Window) !Self {
        const cmd_buffs = try win.ally.alloc(vk.CommandBuffer, frames_in_flight);

        try win.gc.vkd.allocateCommandBuffers(win.gc.dev, &.{
            .command_pool = win.pool,
            .level = .primary,
            .command_buffer_count = @as(u32, @truncate(cmd_buffs.len)),
        }, cmd_buffs.ptr);

        return Self{
            .drawing_array = std.ArrayList(*Drawing).init(win.ally),
            .command_buffers = cmd_buffs,
            .window = win,
            .frame_id = 0,
        };
    }

    pub fn update(self: *Self) !void {
        const time = @as(f32, @floatCast(glfw.glfwGetTime()));
        const now: f32 = time;
        const resolution: math.Vec2 = .{ @floatFromInt(self.window.frame_width), @floatFromInt(self.window.frame_height) };

        const gc = &self.window.gc;
        const swapchain = &self.window.swapchain;

        const clear_color = vk.ClearValue{
            .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
        };
        const clear_depth = vk.ClearValue{
            .depth_stencil = .{ .depth = 1, .stencil = 0 },
        };

        const extent = self.window.swapchain.extent;
        //std.debug.print("{} {}\n", .{ extent.width, extent.height });

        const cmdbuf = self.command_buffers[self.frame_id];

        const current = &swapchain.swap_images[self.frame_id];

        try current.waitForFence(gc);

        const result = try gc.vkd.acquireNextImageKHR(
            gc.dev,
            swapchain.handle,
            std.math.maxInt(u64),
            current.image_acquired,
            .null_handle,
        );

        try gc.vkd.resetFences(gc.dev, 1, @ptrCast(&current.frame_fence));
        try gc.vkd.resetCommandBuffer(cmdbuf, .{});

        try gc.vkd.beginCommandBuffer(cmdbuf, &.{});
        gc.vkd.cmdSetViewport(cmdbuf, 0, 1, @ptrCast(&vk.Viewport{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(extent.width)),
            .height = @as(f32, @floatFromInt(extent.height)),
            .min_depth = 0,
            .max_depth = 1,
        }));
        gc.vkd.cmdSetScissor(cmdbuf, 0, 1, @ptrCast(&vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = extent,
        }));

        const render_area = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = extent,
        };

        gc.vkd.cmdBeginRenderPass(cmdbuf, &.{
            .render_pass = self.window.render_pass,
            .framebuffer = self.window.framebuffers[result.image_index],
            .render_area = render_area,
            .clear_value_count = 2,
            .p_clear_values = &[2]vk.ClearValue{ clear_color, clear_depth },
        }, .@"inline");

        for (self.drawing_array.items) |elem| {
            if (elem.global_ubo) GlobalUniform.setUniform(elem, 0, .{ .time = now, .in_resolution = resolution });
            try elem.draw(self.frame_id, cmdbuf);
        }

        gc.vkd.cmdEndRenderPass(cmdbuf);
        try gc.vkd.endCommandBuffer(cmdbuf);

        const wait_stage = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        try gc.vkd.queueSubmit(gc.graphics_queue.handle, 1, &[_]vk.SubmitInfo{.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&current.image_acquired),
            .p_wait_dst_stage_mask = &wait_stage,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&cmdbuf),
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(&current.render_finished),
        }}, current.frame_fence);

        _ = try gc.vkd.queuePresentKHR(gc.present_queue.handle, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @as([*]const vk.Semaphore, @ptrCast(&current.render_finished)),
            .swapchain_count = 1,
            .p_swapchains = @as([*]const vk.SwapchainKHR, @ptrCast(&swapchain.handle)),
            .p_image_indices = @as([*]const u32, @ptrCast(&result.image_index)),
        });

        self.frame_id = (self.frame_id + 1) % frames_in_flight;
    }

    pub fn deinit(self: *Self) void {
        for (self.drawing_array.items) |elem| {
            elem.deinit(self.window.ally);
            self.window.ally.destroy(elem);
        }

        self.drawing_array.deinit();

        self.window.gc.vkd.freeCommandBuffers(self.window.gc.dev, self.window.pool, @intCast(self.command_buffers.len), self.command_buffers.ptr);
        self.window.ally.free(self.command_buffers);
    }

    pub fn new(self: *Self) !*Drawing {
        const val = try self.window.ally.create(Drawing);
        try self.drawing_array.append(val);

        return val;
    }

    pub fn delete(self: *Self, ally: std.mem.Allocator, drawing: *Drawing) !void {
        const idx = std.mem.indexOfScalar(*Drawing, self.drawing_array.items, drawing) orelse return error.DeletedDrawingNotInScene;

        var rem = self.drawing_array.swapRemove(idx);
        rem.deinit(ally);
        ally.destroy(rem);
    }

    pub fn draw(self: *Self) !void {
        try self.update();
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
};

pub const RenderPipeline = struct {
    vertex_description: VertexDescription,
    render_type: RenderType,
    depth_test: bool,
    cull_face: bool,
    cull_type: CullType = .back,

    uniform_sizes: []const usize = &.{},
    samplers: []const Texture = &.{},
    // assume DefaultUbo at index 0
    global_ubo: bool = false,

    pub fn getInitType(comptime pipeline: RenderPipeline) type {
        return struct {
            samplers: [pipeline.samplers]Texture,
        };
    }

    pub fn getBindingDescription(pipeline: RenderPipeline) vk.VertexInputBindingDescription {
        return .{
            .binding = 0,
            .stride = @intCast(pipeline.vertex_description.getVertexSize()),
            .input_rate = .vertex,
        };
    }

    pub fn getAttributeDescription(pipeline: RenderPipeline) []vk.VertexInputAttributeDescription {
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

    pub fn getAttributeType(comptime pipeline: RenderPipeline) type {
        var types: []const type = &.{};
        for (pipeline.vertex_description.vertex_attribs) |attrib| {
            const t = attrib.getType();
            types = types ++ .{t};
        }
        return std.meta.Tuple(types);
    }
};

pub const FlatPipeline = RenderPipeline{
    .vertex_attrib = &VertexAttribute{ .{ .size = 3 }, .{ .size = 2 } },
    .render_type = .triangle,
    .depth_test = false,
    .cull_face = false,
};

pub const SpatialPipeline = RenderPipeline{
    .vertex_attrib = &[_]VertexAttribute{ .{ .size = 3 }, .{ .size = 2 }, .{ .size = 3 } },
    .render_type = .triangle,
    .depth_test = true,
    .cull_face = false,
};

pub const LinePipeline = RenderPipeline{
    .vertex_attrib = &[_]VertexAttribute{ .{ .size = 3 }, .{ .size = 3 } },
    .render_type = .line,
    .depth_test = true,
    .cull_face = false,
};

pub const UniformDescription = struct {
    type: type,

    pub fn getSize(comptime self: UniformDescription) usize {
        std.mem.doNotOptimizeAway(@sizeOf(self.type));
        return @sizeOf(self.type);
    }

    pub fn setUniform(comptime self: UniformDescription, draw: *Drawing, binding_idx: usize, ubo: self.type) void {
        for (draw.uniform_buffers[binding_idx]) |mapped_buff| {
            @as(*self.type, @alignCast(@ptrCast(mapped_buff.data))).* = ubo;
        }
    }
    pub fn setUniformField(comptime self: UniformDescription, draw: *Drawing, binding_idx: usize, comptime field: std.meta.FieldEnum(self.type), target: anytype) void {
        for (draw.uniform_buffers[binding_idx]) |mapped_buff| {
            @field(@as(*self.type, @alignCast(@ptrCast(mapped_buff.data))), @tagName(field)) = target;
        }
    }
};

pub const GlobalUniform: UniformDescription = .{ .type = extern struct { time: f32, in_resolution: math.Vec2 } };
pub const SpriteUniform: UniformDescription = .{ .type = extern struct { transform: math.Mat4, opacity: f32 } };

pub const SpritePipeline = RenderPipeline{
    .vertex_description = .{
        .vertex_attribs = &[_]VertexAttribute{ .{ .size = 3 }, .{ .size = 2 } },
    },
    .render_type = .triangle,
    .depth_test = false,
    .cull_face = false,
    .uniform_sizes = &.{ GlobalUniform.getSize(), SpriteUniform.getSize() },
    .global_ubo = true,
};
