const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const numericals = @import("numericals");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("graphics");
const common = @import("common");
const Parsing = @import("parsing");

const Fun = struct {
    pub fn pow(a: f32, b: f32) f32 {
        return std.math.pow(f32, a, b);
    }
    pub fn sin(x: f32) f32 {
        return std.math.sin(x);
    }
};

const RuntimeEval = @import("eval.zig").RuntimeEval(f32, false, Fun);

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

var current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1);
var down_num: usize = 0;
var last_mods: i32 = 0;

const TAU = 6.28318530718;

const DrawingList = union(enum) {
    line: *Drawing(graphics.LinePipeline),
    spatial: *Drawing(graphics.SpatialPipeline),
};

pub const State = struct {
    main_win: *graphics.Window,
    scene: graphics.Scene(DrawingList),
    skybox_scene: graphics.Scene(DrawingList),

    cam: Camera,

    time: f64,

    input_mode: bool,
    plot_eq: [:0]const u8,
    scratch_text: std.ArrayList(u8),

    pub fn init() !State {
        var main_win = try graphics.Window.init(100, 100);

        main_win.setKeyCallback(keyFunc);
        main_win.setCharCallback(charFunc);
        main_win.setFrameCallback(frameFunc);

        var cam = try Camera.init(0.6, 1, 0.1, 2048);
        cam.move = .{ 0, 0, 0 };
        try cam.updateMat();

        return State{
            .main_win = main_win,
            .cam = cam,
            .time = 0,
            .scene = try graphics.Scene(DrawingList).init(),
            .skybox_scene = try graphics.Scene(DrawingList).init(),
            .input_mode = false,
            .plot_eq = try common.allocator.dupeZ(u8, "const z = 0.2*(sin(x*10*sin(t))+sin(y*10*sin(t)));"),
            .scratch_text = std.ArrayList(u8).init(common.allocator),
        };
    }

    pub fn deinit(self: *State) void {
        self.main_win.deinit();
        self.scene.deinit();
        self.skybox_scene.deinit();
        self.scratch_text.deinit();
        common.allocator.free(self.plot_eq);
    }
};

var state: State = undefined;

fn frameFunc(win: *anyopaque, width: i32, height: i32) !void {
    _ = win;
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try state.cam.setParameters(0.6, w / h, 0.1, 2048);
}

var is_wireframe = false;

fn charFunc(win: *anyopaque, codepoint: u32) !void {
    _ = win;

    if (state.input_mode) {
        var buff: [16]u8 = undefined;
        const size = try std.unicode.utf8Encode(@intCast(codepoint), &buff);
        const result = buff[0..size];

        for (result) |char| {
            try state.scratch_text.append(char);
        }
    } else if (codepoint == 'i') {
        state.input_mode = true;
    }
}

fn keyFunc(win: *anyopaque, key: i32, scancode: i32, action: i32, mods: i32) !void {
    _ = win;
    _ = scancode;

    if (action == glfw.GLFW_PRESS) {
        defer down_num += 1;
        if (state.input_mode) {
            switch (key) {
                glfw.GLFW_KEY_ESCAPE => {
                    state.input_mode = false;
                    //state.scratch_text.shrinkRetainingCapacity(0);
                },
                glfw.GLFW_KEY_ENTER => {
                    state.input_mode = false;
                    common.allocator.free(state.plot_eq);
                    state.plot_eq = try common.allocator.dupeZ(u8, state.scratch_text.items);
                },
                glfw.GLFW_KEY_BACKSPACE => {
                    state.scratch_text.shrinkRetainingCapacity(state.scratch_text.items.len - 1);
                },
                else => {},
            }
            return;
        }
        switch (key) {
            glfw.GLFW_KEY_C => {
                if (is_wireframe) {
                    gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
                    is_wireframe = false;
                } else {
                    gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
                    is_wireframe = true;
                }
            },
            else => {},
        }
        current_keys[@intCast(key)] = true;
        last_mods = mods;
    } else if (action == glfw.GLFW_RELEASE) {
        current_keys[@intCast(key)] = false;
        down_num -= 1;
    }
}

fn key_down(keys: []bool, mods: i32, dt: f32) !void {
    if (keys[glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    try state.cam.spatialMove(keys, mods, dt, &state.cam.move, Camera.DefaultSpatial);
}

pub fn plot(mesh: Mesh, ctx: *RuntimeEval, input: [:0]const u8) !graphics.MeshBuilder {
    var set = std.AutoHashMap(*HalfEdge, void).init(common.allocator);
    var stack = std.ArrayList(?*HalfEdge).init(common.allocator);

    defer set.deinit();
    defer stack.deinit();

    try stack.append(mesh.first_half);

    var ast = try std.zig.Ast.parse(common.allocator, input, .zig);
    defer ast.deinit(common.allocator);

    var buff: [2]u32 = undefined;
    const container = ast.fullContainerDecl(&buff, 0).?;
    if (container.ast.members.len == 0) return error.MissingMember;
    const index = ast.nodes.get(container.ast.members[0]).data.rhs;

    while (stack.items.len > 0) {
        var edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            var position = &edge.vertex.pos;

            const x = edge.vertex.uv[0] - 0.5;
            const y = edge.vertex.uv[1] - 0.5;

            try ctx.identifiers.put("x", x);
            try ctx.identifiers.put("y", y);

            position[2] = try ctx.traverse(ast, ast.nodes.get(index), index, 0);

            if (edge.next) |_| {
                if (edge.twin) |twin| {
                    try stack.append(twin);
                }
            }
            try stack.append(edge.next);
        }
    }

    return toMesh(mesh.first_half.?);
}

pub fn toMesh(half: *HalfEdge) !graphics.MeshBuilder {
    var builder = try graphics.MeshBuilder.init();

    var set = std.AutoHashMap(*HalfEdge, void).init(common.allocator);
    var stack = std.ArrayList(?*HalfEdge).init(common.allocator);

    defer set.deinit();
    defer stack.deinit();

    try stack.append(half);

    while (stack.items.len > 0) {
        var edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            var v = edge.face.vertices;

            var a = v[0].*;
            var b = v[1].*;
            var c = v[2].*;

            try builder.addTri(.{ a, b, c });

            if (edge.next) |_| {
                if (edge.twin) |twin| {
                    try stack.append(twin);
                }
            }
            try stack.append(edge.next);
        }
    }

    return builder;
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    try graphics.initGraphics();
    defer graphics.deinitGraphics();

    var bdf = try BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    state = try State.init();
    defer state.deinit();

    gl.cullFace(gl.FRONT);
    gl.enable(gl.BLEND);
    gl.lineWidth(2);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var surface = try graphics.SpatialMesh.init(
        try state.scene.new(.spatial),
        .{ 0, 0, 0 },
        try graphics.Shader.setupShader(
            @embedFile("shaders/image/vertex.glsl"),
            @embedFile("shaders/image/fragment.glsl"),
        ),
    );

    try state.cam.linkDrawing(surface.drawing);
    try surface.initUniform();

    var ctx = RuntimeEval.init(common.allocator);
    defer ctx.deinit();

    var model = math.rotationX(f32, -TAU / 4.0);
    surface.drawing.setUniformMat3("model", model);

    var last_time: f32 = 0;

    var text = try graphics.Text.init(
        try state.scene.new(.spatial),
        bdf,
        .{ 0, 14, 0 },
    );

    try text.initUniform();
    defer text.deinit();

    var mesh = Mesh.init(common.allocator);
    defer mesh.deinit();

    try mesh.makeFrom(&graphics.Square.vertices, &graphics.Square.indices, .{
        .pos_offset = 0,
        .uv_offset = 3,
        .norm_offset = 5,
        .length = 8,
    }, 3);

    try mesh.subdivideMesh(4);

    while (state.main_win.alive) {
        graphics.waitGraphicsEvent();

        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time = @as(f32, @floatCast(glfw.glfwGetTime()));

        const dt = time - last_time;
        state.time += dt * 0.5;

        blk: {
            try ctx.identifiers.put("t", @floatCast(state.time));
            var builder = plot(mesh, &ctx, state.plot_eq) catch |err| {
                switch (err) {
                    error.InvalidSides => std.debug.print("Invalid usage of operator\n", .{}),
                    error.UnknownIdentifier => std.debug.print("Unknown identifier\n", .{}),
                    error.InvalidNode => std.debug.print("Invalid node\n", .{}),
                    error.UnknownFunction => std.debug.print("Unknown function used\n", .{}),
                    error.InvalidNullNode => std.debug.print("Invalid starting node\n", .{}),
                    error.MissingMember => std.debug.print("Missing starting node\n", .{}),
                    else => return err,
                }
                common.allocator.free(state.plot_eq);
                state.plot_eq = try common.allocator.dupeZ(u8, "const z = 0;");
                break :blk;
            };
            surface.drawing.bindVertex(builder.vertices.items, builder.indices.items);
            builder.deinit();
        }

        if (down_num > 0) {
            try key_down(&current_keys, last_mods, dt);
        }

        if (@mod(@floor(state.time * 3), 2) == 0 or !state.input_mode) {
            try text.printFmt("cam: {} {d:.4} {d:.4} {d:.4} {d:.4}\n{s}\n", .{ state.input_mode, state.cam.eye, state.cam.move, 1 / dt, state.time, state.scratch_text.items });
        } else {
            try text.printFmt("cam: {} {d:.4} {d:.4} {d:.4} {d:.4}\n{s}█\n", .{ state.input_mode, state.cam.eye, state.cam.move, 1 / dt, state.time, state.scratch_text.items });
        }

        state.cam.eye = state.cam.eye;
        try state.cam.updateMat();

        gl.disable(gl.DEPTH_TEST);
        try state.skybox_scene.draw(state.main_win.*);

        gl.enable(gl.DEPTH_TEST);
        try state.scene.draw(state.main_win.*);

        last_time = time;

        graphics.glfw.glfwSwapBuffers(state.main_win.glfw_win);
    }
}
