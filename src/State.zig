main_win: *graphics.Window,
scene: graphics.Scene,
command_builder: graphics.CommandBuilder,
compute_builder: graphics.CommandBuilder,

first_pass: graphics.RenderPass,
post_drawing: *graphics.Drawing,
post_pipeline: graphics.RenderPipeline,

multisampling_tex: graphics.Texture,
post_color_tex: graphics.Texture,
post_depth_tex: graphics.Texture,

color_depth_target: graphics.RenderTarget,

image_index: graphics.Swapchain.ImageIndex = @enumFromInt(0),

cam: Camera,

current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1),
last_interact_keys: [glfw.GLFW_KEY_MENU + 1]f64 = .{0} ** (glfw.GLFW_KEY_MENU + 1),

down_num: usize = 0,
last_mods: i32 = 0,
time: f64,
last_time: f32,
dt: f32,

callback: Callback,

key_down_manager: SubscriptionManager(KeyDownFunction) = .{},
char_func_manager: SubscriptionManager(CharFunction) = .{},
scroll_func_manager: SubscriptionManager(ScrollFunction) = .{},
mouse_func_manager: SubscriptionManager(MouseFunction) = .{},
cursor_func_manager: SubscriptionManager(CursorFunction) = .{},
frame_func_manager: SubscriptionManager(FrameFunction) = .{},
key_func_manager: SubscriptionManager(KeyFunction) = .{},

ally: std.mem.Allocator,

pub const Context = struct {
    state: *State,
    ptr: *anyopaque,
    id: usize,
};

pub const KeyDownFunction = *const fn (Context, KeyState, i32, f32) anyerror!void;
pub const CharFunction = *const fn (Context, codepoint: u32) anyerror!void;
pub const ScrollFunction = *const fn (Context, xoffset: f64, yoffset: f64) anyerror!void;
pub const MouseFunction = *const fn (Context, button: i32, action: graphics.Action, mods: i32) anyerror!void;
pub const CursorFunction = *const fn (Context, xoffset: f64, yoffset: f64) anyerror!void;
pub const FrameFunction = *const fn (Context, width: i32, height: i32) anyerror!void;
pub const KeyFunction = *const fn (Context, key: i32, scancode: i32, action: graphics.Action, mods: i32) anyerror!void;

fn SubscriptionManager(comptime Function: type) type {
    return struct {
        last_id: usize = 0,
        list: std.ArrayListUnmanaged(Subscriber) = .{},

        const Manager = @This();
        pub const Subscriber = struct {
            func: Function,
            ptr: *anyopaque,
            id: usize,
        };

        // returns id of subscription
        pub fn subscribe(manager: *Manager, ally: std.mem.Allocator, options: struct {
            func: Function,
            ptr: *anyopaque = undefined,
        }) !usize {
            try manager.list.append(ally, .{
                .func = options.func,
                .ptr = options.ptr,
                .id = manager.last_id,
            });
            manager.last_id += 1;
            return manager.last_id - 1;
        }

        pub fn unsubscribe(manager: *Manager, id: usize) !void {
            var search_result: ?usize = null;
            for (manager.list.items, 0..) |item, idx| {
                if (item.id == id) {
                    search_result = idx;
                    break;
                }
            }

            if (search_result) |result_idx| {
                _ = try manager.list.swapRemove(result_idx);
            } else {
                return error.SubscriptionNotFound;
            }
        }
    };
}

const State = @This();

const std = @import("std");
const math = @import("math");
const numericals = @import("numericals");
const img = @import("img");

pub const Callback = @import("ui/callback.zig").Callback;
pub const Region = @import("ui/callback.zig").Region;

const geometry = @import("geometry");
const graphics = @import("graphics");
const common = @import("common");
const Parsing = @import("parsing");

const BdfParse = Parsing.BdfParse;
const ObjParse = graphics.ObjParse;
const VsopParse = Parsing.VsopParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;

const Camera = graphics.Camera;
const Cube = graphics.Cube;
const Line = graphics.Line;
const MeshBuilder = graphics.MeshBuilder;

const Mat4 = math.Mat4;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec3Utils = math.Vec3Utils;

const SpatialPipeline = graphics.SpatialPipeline;

const TAU = 6.28318530718;

var is_wireframe = false;

fn defaultKeyDown(_: KeyState, _: i32, _: f32) !void {
    return;
}

fn defaultChar(_: u32) !void {
    return;
}

fn defaultScroll(_: f64, _: f64) !void {
    return;
}

fn defaultMouse(_: i32, _: graphics.Action, _: i32) !void {
    return;
}

fn defaultCursor(_: f64, _: f64) !void {
    return;
}

fn defaultFrame(_: i32, _: i32) !void {
    return;
}

fn defaultKey(_: i32, _: i32, _: graphics.Action, _: i32) !void {
    return;
}

pub const KeyState = struct {
    pressed_table: []bool,
    last_interact_table: []f64,
};

pub const post_description = graphics.PipelineDescription{
    .vertex_description = .{
        .vertex_attribs = &[_]graphics.VertexAttribute{ .{ .size = 3 }, .{ .size = 2 } },
    },
    .render_type = .triangle,
    .depth_test = false,
    .sets = &.{.{ .bindings = &.{
        .{ .uniform = .{
            .size = graphics.GlobalUniform.getSize(),
        } },
        .{ .sampler = .{} },
    } }},
    .global_ubo = true,
    .cull_type = .none,
};

pub fn init(ally: std.mem.Allocator, info: struct {
    window: graphics.WindowInfo = .{},
    scene: graphics.Scene.SceneInfo = .{},
}) !*State {
    try graphics.initGraphics(ally);
    _ = graphics.glfw.glfwWindowHint(graphics.glfw.GLFW_SAMPLES, 4);

    const state = try ally.create(State);

    var main_win = try ally.create(graphics.Window);
    main_win.* = try graphics.Window.initBare(info.window, ally);

    try main_win.addToMap(state);

    main_win.setKeyCallback(keyFunc);
    main_win.setFrameCallback(frameFunc);
    main_win.setCharCallback(charFunc);
    main_win.setScrollCallback(scrollFunc);
    main_win.setCursorCallback(cursorFunc);
    main_win.setMouseButtonCallback(mouseFunc);

    var cam = try Camera.init(0.6, 1, 0.1, 2048);
    cam.move = Vec3.init(.{ 0, 0, 0 });
    try cam.updateMat();
    const swapchain = main_win.swapchain;

    // Create a separate render target for post processing
    const first_pass = try graphics.RenderPass.init(&main_win.gpu, .{
        .format = main_win.swapchain.surface_format.format,
        .target = true,
        //.multisampling = true,
    });

    const multisampling_tex = try graphics.Texture.init(main_win, swapchain.extent.width, swapchain.extent.height, .{
        //.multisampling = true,
        .preferred_format = main_win.preferred_format,
    });
    const depth_tex = try graphics.Texture.init(main_win, swapchain.extent.width, swapchain.extent.height, .{
        .preferred_format = .depth,
        //.multisampling = true,
    });
    const post_tex = try graphics.Texture.init(main_win, swapchain.extent.width, swapchain.extent.height, .{
        .type = .render_target,
        .preferred_format = main_win.preferred_format,
    });

    var scene = try graphics.Scene.init(main_win, info.scene);

    const gpu = &main_win.gpu;

    const post_pipeline = try graphics.RenderPipeline.init(ally, .{
        .description = post_description,
        .shaders = &main_win.default_shaders.post_shaders,
        .rendering = main_win.rendering_options,
        .gpu = gpu,
        .flipped_z = scene.flip_z,
    });

    const post_drawing = try scene.new();

    try post_drawing.init(ally, gpu, .{
        .pipeline = post_pipeline,
        .target = .{ .swapchain = {} },
        .flip_z = .false,
    });
    try post_drawing.descriptor.updateDescriptorSets(gpu, .{ .samplers = &.{.{
        .idx = 1,
        .textures = &.{post_tex},
    }} });

    try post_description.vertex_description.bindVertex(post_drawing, gpu, &.{
        .{ .{ -1, -1, 1 }, .{ 0, 0 } },
        .{ .{ 1, -1, 1 }, .{ 1, 0 } },
        .{ .{ 1, 1, 1 }, .{ 1, 1 } },
        .{ .{ -1, 1, 1 }, .{ 0, 1 } },
    }, &.{ 0, 1, 2, 2, 3, 0 }, .immediate);

    state.* = State{
        .main_win = main_win,
        .cam = cam,
        .time = 0,
        .dt = 0,
        .command_builder = try graphics.CommandBuilder.init(&main_win.gpu, main_win.pool, ally),
        .compute_builder = try graphics.CommandBuilder.init(&main_win.gpu, main_win.pool, ally),
        .multisampling_tex = multisampling_tex,

        .post_color_tex = post_tex,
        .post_depth_tex = depth_tex,

        .color_depth_target = .{
            .texture = .{
                // kind of an issue, also kind of not really, just throw an arena
                .color_textures = try ally.dupe(*graphics.Texture, &.{&state.post_color_tex}),
                .depth_texture = &state.post_depth_tex,
                .region = .{},
            },
        },

        .scene = scene,
        .first_pass = first_pass,
        .post_drawing = post_drawing,
        .post_pipeline = post_pipeline,
        .last_time = @as(f32, @floatCast(graphics.glfw.glfwGetTime())),
        .callback = try Callback.init(ally, main_win),
        .ally = ally,
    };

    return state;
}

pub fn charFunc(ptr: *anyopaque, codepoint: u32) !void {
    var state: *State = @ptrCast(@alignCast(ptr));
    try state.callback.getChar(codepoint);

    for (state.char_func_manager.list.items) |sub| {
        try sub.func(.{
            .state = state,
            .ptr = sub.ptr,
            .id = sub.id,
        }, codepoint);
    }
}

pub fn scrollFunc(ptr: *anyopaque, xoffset: f64, yoffset: f64) !void {
    var state: *State = @ptrCast(@alignCast(ptr));
    try state.callback.getScroll(xoffset, yoffset);
    for (state.scroll_func_manager.list.items) |sub| {
        try sub.func(.{
            .state = state,
            .ptr = sub.ptr,
            .id = sub.id,
        }, xoffset, yoffset);
    }
}

pub fn mouseFunc(ptr: *anyopaque, button: i32, action: graphics.Action, mods: i32) !void {
    var state: *State = @ptrCast(@alignCast(ptr));
    try state.callback.getMouse(button, action, mods);
    for (state.mouse_func_manager.list.items) |sub| {
        try sub.func(.{
            .state = state,
            .ptr = sub.ptr,
            .id = sub.id,
        }, button, action, mods);
    }
}

pub fn cursorFunc(ptr: *anyopaque, x_pos: f64, y_pos: f64) !void {
    var state: *State = @ptrCast(@alignCast(ptr));
    try state.callback.getCursor(x_pos, y_pos);
    for (state.cursor_func_manager.list.items) |sub| {
        try sub.func(.{
            .state = state,
            .ptr = sub.ptr,
            .id = sub.id,
        }, x_pos, y_pos);
    }
}

pub fn updateEvents(state: *State) !void {
    var time = @as(f32, @floatCast(graphics.glfw.glfwGetTime()));

    graphics.waitGraphicsEvent();

    time = @as(f32, @floatCast(graphics.glfw.glfwGetTime()));

    state.dt = time - state.last_time;
    state.time = time;

    if (state.down_num > 0) {
        for (state.key_down_manager.list.items) |sub| {
            try sub.func(.{
                .state = state,
                .ptr = sub.ptr,
                .id = sub.id,
            }, .{ .pressed_table = &state.current_keys, .last_interact_table = &state.last_interact_keys }, state.last_mods, state.dt);
        }
    }

    state.last_time = time;
}

pub fn submit(state: *State) !void {
    const scene = &state.scene;
    const swapchain = &scene.window.swapchain;
    const gpu = &scene.window.gpu;
    const frame_id = state.command_builder.frame_id;

    try swapchain.submit(gpu, state.command_builder, .{ .wait = &.{.{ .semaphore = swapchain.image_acquired[frame_id], .type = .color }} });
    try swapchain.present(gpu, .{ .wait = &.{swapchain.render_finished[frame_id]}, .image_index = state.image_index });
    state.command_builder.next();
}

pub fn render(state: *State) !void {
    state.cam.eye = state.cam.eye;
    try state.cam.updateMat();

    try state.draw();
    state.main_win.swapBuffers();
}

pub fn deinit(state: *State, ally: std.mem.Allocator) void {
    state.main_win.gpu.vkd.deviceWaitIdle(state.main_win.gpu.dev) catch {};

    const gpu = &state.main_win.gpu;

    state.post_color_tex.deinit();
    state.multisampling_tex.deinit();
    state.post_depth_tex.deinit();
    state.first_pass.deinit(&state.main_win.gpu);
    state.post_pipeline.deinit(&state.main_win.gpu);

    state.post_drawing.deinitAllBuffers(ally, gpu.*);
    ally.destroy(state.post_drawing);

    state.callback.deinit();
    state.scene.deinit();
    state.command_builder.deinit(&state.main_win.gpu, state.main_win.pool, state.main_win.ally);
    state.compute_builder.deinit(&state.main_win.gpu, state.main_win.pool, state.main_win.ally);
    state.main_win.deinit();
    graphics.deinitGraphics();

    state.key_down_manager.list.deinit(ally);
    state.char_func_manager.list.deinit(ally);
    state.scroll_func_manager.list.deinit(ally);
    state.mouse_func_manager.list.deinit(ally);
    state.cursor_func_manager.list.deinit(ally);
    state.frame_func_manager.list.deinit(ally);
    state.key_func_manager.list.deinit(ally);
}

fn frameFunc(ptr: *anyopaque, width: i32, height: i32) !void {
    var state: *State = @ptrCast(@alignCast(ptr));
    try state.main_win.gpu.vkd.deviceWaitIdle(state.main_win.gpu.dev);

    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try state.cam.setParameters(0.6, w / h, 0.1, 2048);

    state.post_color_tex.deinit();
    state.multisampling_tex.deinit();
    state.post_depth_tex.deinit();

    state.multisampling_tex = try graphics.Texture.init(state.main_win, @intCast(width), @intCast(height), .{
        //.multisampling = true,
        .preferred_format = state.main_win.preferred_format,
    });
    state.post_depth_tex = try graphics.Texture.init(state.main_win, @intCast(width), @intCast(height), .{
        //.multisampling = true,
        .preferred_format = .depth,
    });
    state.post_color_tex = try graphics.Texture.init(state.main_win, @intCast(width), @intCast(height), .{
        .type = .render_target,
        .preferred_format = state.main_win.preferred_format,
    });

    try state.post_drawing.descriptor.updateDescriptorSets(&state.main_win.gpu, .{ .samplers = &.{.{
        .idx = 1,
        .textures = &.{state.post_color_tex},
    }} });

    try state.callback.getFrame(width, height);

    for (state.frame_func_manager.list.items) |sub| {
        try sub.func(.{
            .state = state,
            .ptr = sub.ptr,
            .id = sub.id,
        }, width, height);
    }
}

fn keyFunc(ptr: *anyopaque, key: i32, scancode: i32, action: graphics.Action, mods: i32) !void {
    if (key < 0) return;

    var state: *State = @ptrCast(@alignCast(ptr));

    try state.callback.getKey(key, scancode, action, mods);

    for (state.key_func_manager.list.items) |sub| {
        try sub.func(.{
            .state = state,
            .ptr = sub.ptr,
            .id = sub.id,
        }, key, scancode, action, mods);
    }

    if (action == .press) {
        state.current_keys[@intCast(key)] = true;
        state.last_interact_keys[@intCast(key)] = state.time;

        state.last_mods = mods;
        state.down_num += 1;
    } else if (action == .release) {
        state.current_keys[@intCast(key)] = false;
        state.last_interact_keys[@intCast(key)] = state.time;

        state.down_num -= 1;
    }
}
