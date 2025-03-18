vkb: BaseDispatch,
vki: InstanceDispatch,
vkd: DeviceDispatch,

instance: vk.Instance,
surface: ?vk.SurfaceKHR,
pdev: vk.PhysicalDevice,
props: vk.PhysicalDeviceProperties,
mem_props: vk.PhysicalDeviceMemoryProperties,

dev: vk.Device,
graphics_queue: Queue,
compute_queue: Queue,
present_queue: Queue,

graphics_pool: vk.CommandPool,

depth_format: vk.Format,
debug_messenger: vk.DebugUtilsMessengerEXT,

const required_device_extensions = [_][*:0]const u8{
    vk.extensions.khr_swapchain.name,
    vk.extensions.khr_dynamic_rendering.name,
};

const apis: []const vk.ApiInfo = &.{
    .{ .base_commands = .{
        .createInstance = true,
        .enumerateInstanceLayerProperties = true,
        .getInstanceProcAddr = true,
    }, .instance_commands = .{
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
        .createDebugUtilsMessengerEXT = true,
        .destroyDebugUtilsMessengerEXT = true,
    }, .device_commands = .{
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
        .setDebugUtilsObjectNameEXT = true,
        .setDebugUtilsObjectTagEXT = true,
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
        .createComputePipelines = true,
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
        .cmdDispatch = true,
        .cmdBeginRendering = true,
        .cmdEndRendering = true,
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
    } },
    // Or you can add entire feature sets or extensions
    vk.features.version_1_0,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
};

const BaseDispatch = vk.BaseWrapper(apis);

const InstanceDispatch = vk.InstanceWrapper(apis);

const DeviceDispatch = vk.DeviceWrapper(apis);

pub fn init(ally: std.mem.Allocator, app_name: [*:0]const u8, window_or: ?*glfw.GLFWwindow) !Gpu {
    //@breakpoint();
    std.debug.print("Vulkan support: {}\n", .{glfw.glfwVulkanSupported()});
    var gpu: Gpu = undefined;
    gpu.vkb = try BaseDispatch.load(glfwGetInstanceProcAddress);

    if (builtin.mode != .ReleaseFast and !try checkValidationLayerSupport(ally, gpu.vkb)) return error.NoValidationLayers;

    var extensions = std.ArrayList(?[*:0]const u8).init(ally);
    defer extensions.deinit();

    var glfw_exts_count: u32 = 0;
    const glfw_exts_ptr = glfw.glfwGetRequiredInstanceExtensions(&glfw_exts_count);

    const glfw_exts = glfw_exts_ptr[0..glfw_exts_count];
    try extensions.appendSlice(glfw_exts);

    try extensions.append(vk.extensions.ext_debug_utils.name);

    const app_info: vk.ApplicationInfo = .{
        .p_application_name = app_name,
        .application_version = @bitCast(vk.makeApiVersion(0, 0, 0, 0)),
        .p_engine_name = app_name,
        .engine_version = @bitCast(vk.makeApiVersion(0, 0, 0, 0)),
        .api_version = @bitCast(vk.API_VERSION_1_3),
    };

    gpu.instance = try gpu.vkb.createInstance(&.{
        .p_application_info = &app_info,
        .enabled_extension_count = @intCast(extensions.items.len),
        .pp_enabled_extension_names = @ptrCast(extensions.items.ptr),
        .enabled_layer_count = if (builtin.mode != .ReleaseFast) @intCast(validation_layers.len) else 0,
        .pp_enabled_layer_names = @as([*]const [*:0]const u8, @ptrCast(&validation_layers)),
    }, null);

    gpu.vki = try InstanceDispatch.load(gpu.instance, gpu.vkb.dispatch.vkGetInstanceProcAddr);
    errdefer gpu.vki.destroyInstance(gpu.instance, null);

    gpu.debug_messenger = try gpu.vki.createDebugUtilsMessengerEXT(gpu.instance, &vk.DebugUtilsMessengerCreateInfoEXT{
        .message_severity = .{ .verbose_bit_ext = true, .warning_bit_ext = true, .error_bit_ext = true },
        .message_type = .{ .general_bit_ext = true, .validation_bit_ext = true, .performance_bit_ext = true },
        .pfn_user_callback = debugCallback,
        .p_user_data = null,
    }, null);

    gpu.surface = if (window_or) |win| try createSurface(gpu.instance, win) else null;
    errdefer if (gpu.surface) |surface| gpu.vki.destroySurfaceKHR(gpu.instance, surface, null);

    const candidate = try pickPhysicalDevice(gpu.vki, gpu.instance, ally, gpu.surface);
    gpu.pdev = candidate.pdev;
    gpu.props = candidate.props;
    gpu.dev = try initializeCandidate(gpu.vki, candidate);
    gpu.vkd = try DeviceDispatch.load(gpu.dev, gpu.vki.dispatch.vkGetDeviceProcAddr);
    errdefer gpu.vkd.destroyDevice(gpu.dev, null);

    gpu.graphics_queue = Queue.init(gpu.vkd, gpu.dev, candidate.queues.graphics_family);
    gpu.compute_queue = Queue.init(gpu.vkd, gpu.dev, candidate.queues.compute_family);
    gpu.present_queue = Queue.init(gpu.vkd, gpu.dev, candidate.queues.present_family);

    gpu.mem_props = gpu.vki.getPhysicalDeviceMemoryProperties(gpu.pdev);
    gpu.depth_format = try gpu.findDepthFormat();

    gpu.graphics_pool = try gpu.vkd.createCommandPool(gpu.dev, &.{
        .queue_family_index = gpu.graphics_queue.family,
        .flags = .{ .reset_command_buffer_bit = true },
    }, null);

    return gpu;
}

pub fn deinit(gpu: Gpu) void {
    gpu.vkd.destroyDevice(gpu.dev, null);
    if (gpu.surface) |surface| gpu.vki.destroySurfaceKHR(gpu.instance, surface, null);
    gpu.vki.destroyDebugUtilsMessengerEXT(gpu.instance, gpu.debug_messenger, null);
    gpu.vki.destroyInstance(gpu.instance, null);
}

pub fn deviceName(gpu: *const Gpu) []const u8 {
    return std.mem.sliceTo(&gpu.props.device_name, 0);
}

pub fn findMemoryTypeIndex(gpu: Gpu, memory_type_bits: u32, flags: vk.MemoryPropertyFlags) !u32 {
    for (gpu.mem_props.memory_types[0..gpu.mem_props.memory_type_count], 0..) |mem_type, i| {
        if (memory_type_bits & (@as(u32, 1) << @truncate(i)) != 0 and mem_type.property_flags.contains(flags)) {
            return @truncate(i);
        }
    }

    return error.NoSuitableMemoryType;
}

pub fn allocate(gpu: Gpu, requirements: vk.MemoryRequirements, flags: vk.MemoryPropertyFlags) !vk.DeviceMemory {
    return try gpu.vkd.allocateMemory(gpu.dev, &.{
        .allocation_size = requirements.size,
        .memory_type_index = try gpu.findMemoryTypeIndex(requirements.memory_type_bits, flags),
    }, null);
}

pub fn findSupportedFormat(gpu: *const Gpu, candidates: []const vk.Format, tiling: vk.ImageTiling, features: vk.FormatFeatureFlags) !vk.Format {
    for (candidates) |candidate| {
        const props = gpu.vki.getPhysicalDeviceFormatProperties(gpu.pdev, candidate);
        if (tiling == .linear and props.linear_tiling_features.contains(features)) {
            return candidate;
        } else if (tiling == .optimal and props.optimal_tiling_features.contains(features)) {
            return candidate;
        }
    }

    return error.NoSuitableFormat;
}

pub fn findDepthFormat(gpu: *const Gpu) !vk.Format {
    return gpu.findSupportedFormat(&.{ .d32_sfloat, .d32_sfloat_s8_uint, .d24_unorm_s8_uint }, .optimal, .{ .depth_stencil_attachment_bit = true });
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
            .shader_input_attachment_array_dynamic_indexing = vk.TRUE,
            .shader_uniform_texel_buffer_array_dynamic_indexing = vk.TRUE,
            .shader_storage_texel_buffer_array_dynamic_indexing = vk.TRUE,
            .shader_uniform_buffer_array_non_uniform_indexing = vk.TRUE,
            .shader_sampled_image_array_non_uniform_indexing = vk.TRUE,
            .shader_storage_buffer_array_non_uniform_indexing = vk.TRUE,
            .shader_storage_image_array_non_uniform_indexing = vk.TRUE,
            .shader_input_attachment_array_non_uniform_indexing = vk.TRUE,
            .shader_uniform_texel_buffer_array_non_uniform_indexing = vk.TRUE,
            .shader_storage_texel_buffer_array_non_uniform_indexing = vk.TRUE,
            .descriptor_binding_uniform_buffer_update_after_bind = vk.TRUE,
            .descriptor_binding_sampled_image_update_after_bind = vk.TRUE,
            .descriptor_binding_storage_image_update_after_bind = vk.TRUE,
            .descriptor_binding_storage_buffer_update_after_bind = vk.TRUE,
            .descriptor_binding_uniform_texel_buffer_update_after_bind = vk.TRUE,
            .descriptor_binding_storage_texel_buffer_update_after_bind = vk.TRUE,
            .descriptor_binding_update_unused_while_pending = vk.TRUE,
            .descriptor_binding_partially_bound = vk.TRUE,
            .descriptor_binding_variable_descriptor_count = vk.TRUE,
            .runtime_descriptor_array = vk.TRUE,
            // should take a *const anyopaque instead, but it doesn't
            .p_next = @constCast(&vk.PhysicalDeviceDynamicRenderingFeaturesKHR{
                .dynamic_rendering = vk.TRUE,
            }),
        },
    }, null);
}

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
        if (!layer_found) {
            std.debug.print("{s} not found\n", .{layer_name});
            return false;
        }
    }

    return true;
}

fn createSurface(instance: vk.Instance, window: *glfw.GLFWwindow) !vk.SurfaceKHR {
    var surface: vk.SurfaceKHR = undefined;
    if (glfwCreateWindowSurface(instance, window, null, &surface) != .success) {
        return error.SurfaceInitFailed;
    }

    return surface;
}

const DeviceCandidate = struct {
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queues: QueueAllocation,
};

const QueueAllocation = struct {
    graphics_family: u32,
    compute_family: u32,
    present_family: u32,
};

fn pickPhysicalDevice(
    vki: InstanceDispatch,
    instance: vk.Instance,
    allocator: std.mem.Allocator,
    surface: ?vk.SurfaceKHR,
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
    surface_or: ?vk.SurfaceKHR,
) !?DeviceCandidate {
    const props = vki.getPhysicalDeviceProperties(pdev);

    if (!try checkExtensionSupport(vki, pdev, allocator)) {
        return null;
    }

    if (surface_or) |surface| {
        if (!try checkSurfaceSupport(vki, pdev, surface)) {
            return null;
        }
    }

    if (try allocateQueues(vki, pdev, allocator, surface_or)) |allocation| {
        return .{
            .pdev = pdev,
            .props = props,
            .queues = allocation,
        };
    }

    return null;
}

fn allocateQueues(vki: InstanceDispatch, pdev: vk.PhysicalDevice, allocator: std.mem.Allocator, surface_or: ?vk.SurfaceKHR) !?QueueAllocation {
    var family_count: u32 = undefined;
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &family_count, null);

    const families = try allocator.alloc(vk.QueueFamilyProperties, family_count);
    defer allocator.free(families);
    vki.getPhysicalDeviceQueueFamilyProperties(pdev, &family_count, families.ptr);

    var graphics_family: ?u32 = null;
    var compute_family: ?u32 = null;
    var present_family: ?u32 = null;

    for (families, 0..) |properties, i| {
        const family: u32 = @intCast(i);

        if (graphics_family == null and properties.queue_flags.graphics_bit) {
            graphics_family = family;
        }

        if (compute_family == null and properties.queue_flags.graphics_bit and properties.queue_flags.compute_bit) {
            compute_family = family;
        }

        if (present_family == null) {
            if (surface_or) |surface| {
                if (try vki.getPhysicalDeviceSurfaceSupportKHR(pdev, family, surface) == vk.TRUE) {
                    present_family = family;
                }
            } else {
                present_family = family;
            }
        }
    }

    if (graphics_family != null and present_family != null) {
        return QueueAllocation{
            .graphics_family = graphics_family.?,
            .compute_family = compute_family.?,
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

fn debugCallback(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    message_types: vk.DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(vk.vulkan_call_conv) vk.Bool32 {
    _ = message_types;

    const callback_data = p_callback_data.?;

    std.debug.print("validation {}: {s}\n", .{ message_severity, p_callback_data.?.p_message.? });

    if (callback_data.p_objects) |obj_ptr| {
        const objects = obj_ptr[0..callback_data.object_count];
        if (objects.len > 0) {
            std.debug.print("objects:\n", .{});
            for (objects) |object| {
                std.debug.print("{s} {} ({}): {s}\n", .{
                    object.p_object_name orelse "unknown name",
                    object.object_type,
                    object.object_handle,
                    graphics.global_object_map.get(object.object_handle) orelse "unknown handle",
                });
            }
        }
    }

    if (message_severity.error_bit_ext) {
        //@panic("error\n");
    }
    return vk.FALSE;
}

pub fn createStagingBuffer(gpu: *Gpu, size: usize) !graphics.BufferMemory {
    const staging_buffer = try gpu.vkd.createBuffer(gpu.dev, &.{
        .size = size,
        .usage = .{ .transfer_src_bit = true },
        .sharing_mode = .exclusive,
    }, null);

    if (builtin.mode == .Debug) {
        try graphics.addDebugMark(gpu.*, .buffer, @intFromEnum(staging_buffer), "staging buffer");
    }

    const staging_mem_reqs = gpu.vkd.getBufferMemoryRequirements(gpu.dev, staging_buffer);
    const staging_memory = try gpu.allocate(staging_mem_reqs, .{ .host_visible_bit = true, .host_coherent_bit = true });
    try gpu.vkd.bindBufferMemory(gpu.dev, staging_buffer, staging_memory, 0);

    return .{
        .buffer = staging_buffer,
        .memory = staging_memory,
        .offset = 0,
        .size = size,
    };
}

const Gpu = @This();

const vk = @import("vulkan");
const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.GLFWwindow, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

pub const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});
