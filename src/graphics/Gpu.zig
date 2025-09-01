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
swapchain_format: vk.Format,
debug_messenger: vk.DebugUtilsMessengerEXT,

vma_ally: vma.VmaAllocator,

const required_device_extensions = [_][*:0]const u8{
    vk.extensions.khr_swapchain.name,
    vk.extensions.khr_dynamic_rendering.name,
    vk.extensions.khr_shader_draw_parameters.name,
};

const BaseDispatch = vk.BaseWrapper;

const InstanceDispatch = vk.InstanceWrapper;

const DeviceDispatch = vk.DeviceWrapper;

/// the center of the API
/// WARNING: swapchain_format is left **undefined** by default, and is instead defined at the Window
pub fn init(ally: std.mem.Allocator, app_name: [*:0]const u8, window_or: ?*glfw.GLFWwindow) !Gpu {
    std.debug.print("Vulkan support: {}\n", .{glfw.glfwVulkanSupported()});
    var gpu: Gpu = undefined;
    gpu.vkb = BaseDispatch.load(glfwGetInstanceProcAddress);

    if (builtin.mode != .ReleaseFast and !try checkValidationLayerSupport(ally, gpu.vkb))
        return error.NoValidationLayers;

    var extensions: std.ArrayList(?[*:0]const u8) = .empty;
    defer extensions.deinit(ally);

    var glfw_exts_count: u32 = 0;
    const glfw_exts_ptr = glfw.glfwGetRequiredInstanceExtensions(&glfw_exts_count);

    const glfw_exts = glfw_exts_ptr[0..glfw_exts_count];
    try extensions.appendSlice(ally, glfw_exts);

    try extensions.append(ally, vk.extensions.ext_debug_utils.name);

    const app_info: vk.ApplicationInfo = .{
        .p_application_name = app_name,
        .application_version = @bitCast(vk.makeApiVersion(0, 0, 0, 0)),
        .p_engine_name = "Malana",
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

    gpu.vki = InstanceDispatch.load(gpu.instance, gpu.vkb.dispatch.vkGetInstanceProcAddr.?);
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
    gpu.vkd = DeviceDispatch.load(gpu.dev, gpu.vki.dispatch.vkGetDeviceProcAddr.?);
    errdefer gpu.vkd.destroyDevice(gpu.dev, null);

    gpu.graphics_queue = Queue.init(gpu.vkd, gpu.dev, candidate.queues.graphics_family);
    gpu.compute_queue = Queue.init(gpu.vkd, gpu.dev, candidate.queues.compute_family);
    gpu.present_queue = Queue.init(gpu.vkd, gpu.dev, candidate.queues.present_family);

    gpu.mem_props = gpu.vki.getPhysicalDeviceMemoryProperties(gpu.pdev);
    gpu.depth_format = try gpu.findDepthFormat();

    // WARNING: left undefined
    gpu.swapchain_format = undefined;

    gpu.graphics_pool = try gpu.vkd.createCommandPool(gpu.dev, &.{
        .queue_family_index = gpu.graphics_queue.family,
        .flags = .{ .reset_command_buffer_bit = true },
    }, null);

    const vulkan_functions: vma.VmaVulkanFunctions = .{
        .vkGetInstanceProcAddr = @ptrCast(gpu.vkb.dispatch.vkGetInstanceProcAddr.?),
        .vkGetDeviceProcAddr = @ptrCast(gpu.vki.dispatch.vkGetDeviceProcAddr.?),
    };

    const allocatorCreateInfo: vma.VmaAllocatorCreateInfo = .{
        .flags = vma.VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT,
        .vulkanApiVersion = @bitCast(vk.API_VERSION_1_3),
        .physicalDevice = @ptrFromInt(@intFromEnum(gpu.pdev)),
        .device = @ptrFromInt(@intFromEnum(gpu.dev)),
        .instance = @ptrFromInt(@intFromEnum(gpu.instance)),
        .pVulkanFunctions = &vulkan_functions,
    };

    if (vma.vmaCreateAllocator(&allocatorCreateInfo, &gpu.vma_ally) != 0) return error.VmaInitError;

    return gpu;
}

pub fn deinit(gpu: Gpu) void {
    vma.vmaDestroyAllocator(gpu.vma_ally);
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

    const features: vk.PhysicalDeviceFeatures = .{
        .sampler_anisotropy = vk.TRUE,
        .independent_blend = vk.TRUE,
    };

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

    // p -> primary color
    // s -> secondary color
    // r -> reset
    std.log.err("{[p]s}Validation Error [{[s]s}{[severity]f}{[p]s}]:{[r]s} {[message]s}", .{
        .severity = message_severity,
        .message = p_callback_data.?.p_message.?,
        .p = "\u{001b}[0;31m",
        .s = "\u{001b}[0;90m",
        .r = "\u{001b}[0m",
    });

    if (callback_data.p_objects) |obj_ptr| {
        const objects = obj_ptr[0..callback_data.object_count];
        if (objects.len > 0) {
            // zig why the hell would you add unused arguments here do you hate me
            std.log.err("{[p]s}Objects:{[r]s}", .{
                .p = "\u{001b}[0;31m",
                .r = "\u{001b}[0m",
            });
            for (objects) |object| {
                std.log.err("{[p]s}\"{[s]s}{[name]s}{[p]s}\" {[s]s}{[typ]}{[p]s} ({[s]s}{[handle]}{[p]s}): \"{[s]s}{[map]s}{[p]s}\"{[r]s}", .{
                    .name = object.p_object_name orelse "(?)",
                    .typ = object.object_type,
                    .handle = object.object_handle,
                    .map = graphics.global_object_map.get(object.object_handle) orelse "(?)",
                    .p = "\u{001b}[0;31m",
                    .s = "\u{001b}[0;90m",
                    .r = "\u{001b}[0m",
                });
            }
        }
    }

    if (message_severity.error_bit_ext) {
        //@breakpoint();
    }

    return vk.FALSE;
}

pub fn createIndexBuffer(
    gpu: Gpu,
    indices: []const u32,
    mode: graphics.CommandMode,
) !graphics.BufferHandle {
    const index_buffer = try graphics.BufferHandle.init(gpu, .{ .size = @sizeOf(u32) * indices.len, .buffer_type = .index });
    try index_buffer.setIndices(gpu, indices, 0, mode);

    return index_buffer;
}

pub fn waitIdle(gpu: *const Gpu) !void {
    try gpu.vkd.deviceWaitIdle(gpu.dev);
}

const Gpu = @This();

const vk = @import("vulkan");
pub const vma = @import("vma");
const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.GLFWwindow, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

pub const glfw = @import("glfw");
