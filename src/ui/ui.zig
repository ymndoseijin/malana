const std = @import("std");
const math = @import("math");
const numericals = @import("numericals");
const img = @import("img");

pub const Callback = @import("callback.zig").Callback;
pub const Region = @import("callback.zig").Region;

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

pub const Ui = struct {
    main_win: *graphics.Window,
    scene: graphics.Scene,

    post_scene: graphics.Scene,
    first_pass: graphics.RenderPass,
    post_drawing: *graphics.Drawing,
    post_pipeline: graphics.RenderPipeline,
    post_buffer: graphics.Framebuffer,
    post_color_tex: graphics.Texture,
    post_depth_tex: graphics.Texture,

    cam: Camera,

    time: f64,

    current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1),
    last_interact_keys: [glfw.GLFW_KEY_MENU + 1]f64 = .{0} ** (glfw.GLFW_KEY_MENU + 1),

    down_num: usize = 0,
    last_mods: i32 = 0,

    last_time: f32,
    dt: f32,

    callback: Callback,
    bdf: BdfParse,

    key_down: *const fn (KeyState, i32, f32) anyerror!void = defaultKeyDown,
    char_func: *const fn (codepoint: u32) anyerror!void = defaultChar,
    scroll_func: *const fn (xoffset: f64, yoffset: f64) anyerror!void = defaultScroll,
    mouse_func: *const fn (button: i32, action: graphics.Action, mods: i32) anyerror!void = defaultMouse,
    cursor_func: *const fn (xoffset: f64, yoffset: f64) anyerror!void = defaultCursor,
    frame_func: *const fn (width: i32, height: i32) anyerror!void = defaultFrame,
    key_func: *const fn (key: i32, scancode: i32, action: graphics.Action, mods: i32) anyerror!void = defaultKey,

    const UiInfo = struct {
        window: graphics.WindowInfo = .{},
        scene: graphics.SceneInfo = .{},
    };

    const post_description = graphics.PipelineDescription{
        .vertex_description = .{
            .vertex_attribs = &[_]graphics.VertexAttribute{ .{ .size = 3 }, .{ .size = 2 } },
        },
        .render_type = .triangle,
        .depth_test = false,
        .uniform_sizes = &.{graphics.GlobalUniform.getSize()},
        .sampler_count = 1,
        .global_ubo = true,
    };

    pub fn init(ally: std.mem.Allocator, info: UiInfo) !*Ui {
        var bdf = try BdfParse.init();
        try bdf.parse("b12.bdf");

        try graphics.initGraphics(ally);
        _ = graphics.glfw.glfwWindowHint(graphics.glfw.GLFW_SAMPLES, 4);

        const state = try ally.create(Ui);

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
        cam.move = .{ 0, 0, 0 };
        try cam.updateMat();
        const swapchain = main_win.swapchain;

        // Create a separate render target for post processing
        const first_pass = try graphics.RenderPass.init(&main_win.gc, .{ .format = main_win.swapchain.surface_format.format, .target = true });
        const post_tex = try graphics.Texture.init(main_win, swapchain.extent.width, swapchain.extent.height, .{
            .is_render_target = true,
            .preferred_format = main_win.preferred_format,
        });
        const depth_tex = try graphics.Texture.init(main_win, swapchain.extent.width, swapchain.extent.height, .{ .preferred_format = .depth });

        var post_scene = try graphics.Scene.init(main_win, info.scene);
        const post_drawing = try post_scene.new();

        const post_pipeline = try graphics.RenderPipeline.init(ally, .{
            .description = post_description,
            .shaders = &main_win.default_shaders.post_shaders,
            .render_pass = main_win.render_pass,
            .gc = &main_win.gc,
            .flipped_z = post_scene.flip_z,
        });

        try post_drawing.init(ally, .{
            .win = main_win,
            .pipeline = post_pipeline,
            .samplers = &.{post_tex},
        });

        try post_description.vertex_description.bindVertex(post_drawing, &.{
            .{ .{ -1, -1, 1 }, .{ 0, 0 } },
            .{ .{ 1, -1, 1 }, .{ 1, 0 } },
            .{ .{ 1, 1, 1 }, .{ 1, 1 } },
            .{ .{ -1, 1, 1 }, .{ 0, 1 } },
        }, &.{ 0, 1, 2, 2, 3, 0 });

        const framebuffer = try graphics.Framebuffer.init(&main_win.gc, .{
            .attachments = &.{ post_tex.image_view, depth_tex.image_view },
            .render_pass = first_pass.pass,
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
        });

        var info_mut = info.scene;
        info_mut.render_pass = &state.first_pass;

        state.* = Ui{
            .main_win = main_win,
            .cam = cam,
            .bdf = bdf,
            .time = 0,
            .dt = 0,
            .scene = try graphics.Scene.init(main_win, info_mut),
            .post_color_tex = post_tex,
            .post_depth_tex = depth_tex,
            .post_scene = post_scene,
            .first_pass = first_pass,
            .post_drawing = post_drawing,
            .post_buffer = framebuffer,
            .post_pipeline = post_pipeline,
            .last_time = @as(f32, @floatCast(graphics.glfw.glfwGetTime())),
            .callback = try Callback.init(ally, main_win),
        };

        return state;
    }

    pub fn charFunc(ptr: *anyopaque, codepoint: u32) !void {
        var state: *Ui = @ptrCast(@alignCast(ptr));
        try state.callback.getChar(codepoint);
        try state.char_func(codepoint);
    }

    pub fn scrollFunc(ptr: *anyopaque, xoffset: f64, yoffset: f64) !void {
        var state: *Ui = @ptrCast(@alignCast(ptr));
        try state.callback.getScroll(xoffset, yoffset);
        try state.scroll_func(xoffset, yoffset);
    }

    pub fn mouseFunc(ptr: *anyopaque, button: i32, action: graphics.Action, mods: i32) !void {
        var state: *Ui = @ptrCast(@alignCast(ptr));
        try state.callback.getMouse(button, action, mods);
        try state.mouse_func(button, action, mods);
    }

    pub fn cursorFunc(ptr: *anyopaque, xoffset: f64, yoffset: f64) !void {
        var state: *Ui = @ptrCast(@alignCast(ptr));
        try state.callback.getCursor(xoffset, yoffset);
        try state.cursor_func(xoffset, yoffset);
    }

    pub fn updateEvents(state: *Ui) !void {
        var time = @as(f32, @floatCast(graphics.glfw.glfwGetTime()));

        graphics.waitGraphicsEvent();

        time = @as(f32, @floatCast(graphics.glfw.glfwGetTime()));

        state.dt = time - state.last_time;
        state.time = time;

        if (state.down_num > 0) {
            try state.key_down(.{ .pressed_table = &state.current_keys, .last_interact_table = &state.last_interact_keys }, state.last_mods, state.dt);
        }

        state.last_time = time;
    }

    pub fn draw(state: *Ui) !void {
        const scene = &state.scene;

        const gc = &scene.window.gc;
        const swapchain = &scene.window.swapchain;
        const frame_id = scene.window.command_builder.frame_id;
        const extent = scene.window.swapchain.extent;
        const builder = &scene.window.command_builder;

        try swapchain.wait(gc, frame_id);

        const image_index = try swapchain.acquireImage(gc, frame_id);
        // build command
        try builder.beginCommand(gc);
        try builder.setViewport(gc, .{ .flip_z = scene.flip_z, .width = extent.width, .height = extent.height });

        builder.beginRenderPass(gc, state.first_pass, state.post_buffer, .{
            .x = 0,
            .y = 0,
            .width = extent.width,
            .height = extent.height,
        });

        const resolution: math.Vec2 = .{ @floatFromInt(scene.window.frame_width), @floatFromInt(scene.window.frame_height) };
        const now: f32 = @floatCast(glfw.glfwGetTime());
        for (scene.drawing_array.items) |elem| {
            if (elem.global_ubo) graphics.GlobalUniform.setUniform(elem, 0, .{ .time = now, .in_resolution = resolution });
            try elem.draw(scene.window.command_builder.frame_id, builder.getCurrent());
        }

        builder.endRenderPass(gc);

        try builder.setViewport(gc, .{ .flip_z = false, .width = extent.width, .height = extent.height });
        builder.beginRenderPass(gc, scene.window.render_pass, scene.window.framebuffers[@intFromEnum(image_index)], .{
            .x = 0,
            .y = 0,
            .width = extent.width,
            .height = extent.height,
        });

        graphics.GlobalUniform.setUniform(state.post_drawing, 0, .{ .time = now, .in_resolution = resolution });
        try state.post_drawing.draw(scene.window.command_builder.frame_id, builder.getCurrent());

        builder.endRenderPass(gc);

        try builder.endCommand(gc);

        // submit
        try swapchain.submit(gc, scene.window.command_builder, .{ .wait = &.{swapchain.image_acquired[scene.window.command_builder.frame_id]} });
        try swapchain.present(gc, .{ .wait = &.{swapchain.render_finished[frame_id]}, .image_index = image_index });
        scene.window.command_builder.next();
    }

    pub fn render(state: *Ui) !void {
        state.cam.eye = state.cam.eye;
        try state.cam.updateMat();

        try state.draw();

        graphics.glfw.glfwSwapBuffers(state.main_win.glfw_win);
    }

    pub fn deinit(self: *Ui, ally: std.mem.Allocator) void {
        self.main_win.gc.vkd.deviceWaitIdle(self.main_win.gc.dev) catch return;

        self.post_color_tex.deinit();
        self.post_depth_tex.deinit();
        self.post_buffer.deinit(self.main_win.gc);
        self.first_pass.deinit(&self.main_win.gc);
        self.post_pipeline.deinit(&self.main_win.gc);

        self.callback.deinit();
        self.scene.deinit();
        self.post_scene.deinit();
        self.main_win.deinit();
        self.bdf.deinit();
        graphics.deinitGraphics();
        ally.destroy(self);
    }

    fn frameFunc(ptr: *anyopaque, width: i32, height: i32) !void {
        var state: *Ui = @ptrCast(@alignCast(ptr));
        try state.main_win.gc.vkd.deviceWaitIdle(state.main_win.gc.dev);

        const w: f32 = @floatFromInt(width);
        const h: f32 = @floatFromInt(height);
        try state.cam.setParameters(0.6, w / h, 0.1, 2048);

        state.post_color_tex.deinit();
        state.post_depth_tex.deinit();

        state.post_color_tex = try graphics.Texture.init(state.main_win, @intCast(width), @intCast(height), .{
            .is_render_target = true,
            .preferred_format = state.main_win.preferred_format,
        });
        state.post_depth_tex = try graphics.Texture.init(state.main_win, @intCast(width), @intCast(height), .{ .preferred_format = .depth });

        state.post_buffer.deinit(state.main_win.gc);
        state.post_buffer = try graphics.Framebuffer.init(&state.main_win.gc, .{
            .attachments = &.{ state.post_color_tex.image_view, state.post_depth_tex.image_view },
            .render_pass = state.first_pass.pass,
            .width = @intCast(width),
            .height = @intCast(height),
        });

        try state.post_drawing.updateDescriptorSets(state.main_win.ally, &.{state.post_color_tex});

        try state.callback.getFrame(width, height);
        try state.frame_func(width, height);
    }

    fn keyFunc(ptr: *anyopaque, key: i32, scancode: i32, action: graphics.Action, mods: i32) !void {
        var state: *Ui = @ptrCast(@alignCast(ptr));

        try state.callback.getKey(key, scancode, action, mods);
        try state.key_func(key, scancode, action, mods);

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
};
