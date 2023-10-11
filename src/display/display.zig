const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const numericals = @import("numericals");
const img = @import("img");
const Ui = @import("ui.zig").Ui;
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

const Camera = graphics.elems.Camera;
const Cube = graphics.elems.Cube;
const Line = graphics.elems.Line;
const MeshBuilder = graphics.MeshBuilder;

const Mat4 = math.Mat4;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec3Utils = math.Vec3Utils;

const SpatialPipeline = graphics.SpatialPipeline;

const TAU = 6.28318530718;

const DrawingList = union(enum) {
    line: *Drawing(graphics.LinePipeline),
    flat: *Drawing(graphics.FlatPipeline),
    spatial: *Drawing(graphics.SpatialPipeline),
};

var is_wireframe = false;

fn defaultKeyDown(_: []const bool, _: i32, _: f32) !void {
    return;
}

pub const State = struct {
    main_win: *graphics.Window,
    scene: graphics.Scene(DrawingList),
    skybox_scene: graphics.Scene(DrawingList),
    flat_scene: graphics.Scene(DrawingList),

    cam: Camera,

    time: f64,

    current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1),
    down_num: usize = 0,
    last_mods: i32 = 0,

    key_down: *const fn ([]const bool, i32, f32) anyerror!void = defaultKeyDown,
    last_time: f32,
    dt: f32,

    ui: Ui,
    bdf: BdfParse,

    pub fn init() !*State {
        var bdf = try BdfParse.init();
        try bdf.parse("b12.bdf");

        try graphics.initGraphics();
        defer graphics.deinitGraphics();

        gl.cullFace(gl.FRONT);
        gl.enable(gl.BLEND);
        gl.lineWidth(2);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        _ = graphics.glfw.glfwWindowHint(graphics.glfw.GLFW_SAMPLES, 4);
        gl.enable(gl.MULTISAMPLE);

        var state = try common.allocator.create(State);

        var main_win = try common.allocator.create(graphics.Window);
        main_win.* = try graphics.Window.initBare(100, 100);

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

        state.* = State{
            .main_win = main_win,
            .cam = cam,
            .bdf = bdf,
            .time = 0,
            .dt = 1,
            .scene = try graphics.Scene(DrawingList).init(),
            .skybox_scene = try graphics.Scene(DrawingList).init(),
            .flat_scene = try graphics.Scene(DrawingList).init(),
            .last_time = @as(f32, @floatCast(graphics.glfw.glfwGetTime())),
            .ui = try Ui.init(common.allocator, main_win),
        };

        return state;
    }

    pub fn charFunc(ptr: *anyopaque, codepoint: u32) !void {
        var state: *State = @ptrCast(@alignCast(ptr));
        try state.ui.getChar(codepoint);
    }

    pub fn scrollFunc(ptr: *anyopaque, xoffset: f64, yoffset: f64) !void {
        var state: *State = @ptrCast(@alignCast(ptr));
        try state.ui.getScroll(xoffset, yoffset);
    }

    pub fn mouseFunc(ptr: *anyopaque, button: i32, action: i32, mods: i32) !void {
        var state: *State = @ptrCast(@alignCast(ptr));
        try state.ui.getMouse(button, action, mods);
    }

    pub fn cursorFunc(ptr: *anyopaque, xoffset: f64, yoffset: f64) !void {
        var state: *State = @ptrCast(@alignCast(ptr));
        try state.ui.getCursor(xoffset, yoffset);
    }

    pub fn updateEvents(state: *State) !void {
        var time = @as(f32, @floatCast(graphics.glfw.glfwGetTime()));

        graphics.waitGraphicsEvent();

        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        time = @as(f32, @floatCast(graphics.glfw.glfwGetTime()));

        state.dt = time - state.last_time;
        state.time = time;

        if (state.down_num > 0) {
            try state.key_down(&state.current_keys, state.last_mods, state.dt);
        }

        state.last_time = time;
    }

    pub fn render(state: *State) !void {
        state.cam.eye = state.cam.eye;
        try state.cam.updateMat();

        gl.disable(gl.DEPTH_TEST);
        gl.disable(gl.CULL_FACE);
        try state.skybox_scene.draw(state.main_win.*);

        gl.enable(gl.DEPTH_TEST);
        //gl.enable(gl.CULL_FACE);
        //gl.cullFace(gl.BACK);
        try state.scene.draw(state.main_win.*);

        gl.disable(gl.DEPTH_TEST);
        gl.disable(gl.CULL_FACE);
        try state.flat_scene.draw(state.main_win.*);

        graphics.glfw.glfwSwapBuffers(state.main_win.glfw_win);
    }

    pub fn deinit(self: *State) void {
        self.main_win.deinit();
        self.scene.deinit();
        self.skybox_scene.deinit();
        self.flat_scene.deinit();
        self.bdf.deinit();
        common.allocator.destroy(self);
    }

    fn frameFunc(ptr: *anyopaque, width: i32, height: i32) !void {
        var state: *State = @ptrCast(@alignCast(ptr));

        const w: f32 = @floatFromInt(width);
        const h: f32 = @floatFromInt(height);
        try state.cam.setParameters(0.6, w / h, 0.1, 2048);

        try state.ui.getFrame(width, height);
    }

    fn keyFunc(ptr: *anyopaque, key: i32, scancode: i32, action: i32, mods: i32) !void {
        var state: *State = @ptrCast(@alignCast(ptr));

        try state.ui.getKey(key, scancode, action, mods);

        if (action == glfw.GLFW_PRESS) {
            if (key == glfw.GLFW_KEY_C) {
                if (is_wireframe) {
                    gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
                    is_wireframe = false;
                } else {
                    gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
                    is_wireframe = true;
                }
            }
            state.current_keys[@intCast(key)] = true;
            state.last_mods = mods;
            state.down_num += 1;
        } else if (action == glfw.GLFW_RELEASE) {
            state.current_keys[@intCast(key)] = false;
            state.down_num -= 1;
        }
    }
};
