const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const numericals = @import("numericals");
const img = @import("img");
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

const astro = @import("astro.zig");

var current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1);
var down_num: usize = 0;
var last_mods: i32 = 0;

const DrawingList = union(enum) {
    line: *Drawing(graphics.LinePipeline),
    spatial: *Drawing(graphics.SpatialPipeline),
};

pub const Planetarium = struct {
    main_win: *graphics.Window,
    scene: graphics.Scene(DrawingList),
    skybox_scene: graphics.Scene(DrawingList),

    cam: Camera,
    cam_pos: @Vector(3, f64),
    other_pos: Vec3,

    fog: f32,

    variables: [2]f32 = .{ -4.0, 0.0 },
    time: f64,
    pub fn init() !Planetarium {
        var main_win = try graphics.Window.init(100, 100);

        main_win.setKeyCallback(keyFunc);
        main_win.setScrollCallback(scrollFunc);
        main_win.setFrameCallback(frameFunc);

        var cam = try Camera.init(0.6, 1, 0.1, 2048);
        cam.move = .{ 0, 0, 0 };
        try cam.updateMat();

        const now: f64 = @floatFromInt(std.time.timestamp());

        return Planetarium{
            .main_win = main_win,
            .cam = cam,
            .cam_pos = .{ 7, 3.8, 13.7 },
            .other_pos = .{ 7, 3.8, 13.7 },
            .fog = 2,
            .time = now / 86400.0 + 2440587.5,
            .scene = try graphics.Scene(DrawingList).init(),
            .skybox_scene = try graphics.Scene(DrawingList).init(),
        };
    }

    pub fn deinit(self: *Planetarium) void {
        self.main_win.deinit();
        self.scene.deinit();
        self.skybox_scene.deinit();
    }
};

var planetarium: Planetarium = undefined;

pub fn frameFunc(win: *anyopaque, width: i32, height: i32) !void {
    _ = win;
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try planetarium.cam.setParameters(0.6, w / h, 0.01, 2048 * 234);
}

var is_wireframe = false;

var variables_index: usize = 0;

pub fn scrollFunc(win: *anyopaque, x: f64, y: f64) !void {
    _ = win;
    _ = x;
    planetarium.variables[variables_index] += @floatCast(y / 20);
}

pub fn keyFunc(win: *anyopaque, key: i32, scancode: i32, action: i32, mods: i32) !void {
    _ = win;
    _ = scancode;

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

        if (key == glfw.GLFW_KEY_E) {
            variables_index += 1;
            variables_index %= planetarium.variables.len;
        }

        current_keys[@intCast(key)] = true;
        last_mods = mods;
        down_num += 1;
    } else if (action == glfw.GLFW_RELEASE) {
        current_keys[@intCast(key)] = false;
        down_num -= 1;
    }
}

const TAU = 6.28318530718;

pub fn key_down(keys: []bool, mods: i32, dt: f32) !void {
    if (keys[glfw.GLFW_KEY_Q]) {
        planetarium.main_win.alive = false;
    }

    var mine = Camera.DefaultSpatial;
    mine.move_speed = 250 * std.math.pow(f32, 2, planetarium.variables[0]);
    mine.speed_multiplier = 4;
    std.debug.print("{d:.4} ops\n", .{mine.move_speed});
    try planetarium.cam.spatialMove(keys, mods, dt, &planetarium.cam_pos, mine);
}
pub fn makeAxis() !void {
    var line = try Line.init(
        try planetarium.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 2, 0, 0 } },
        &[_]Vec3{ .{ 1, 0, 0 }, .{ 1, 0, 0 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    line.drawing.setUniformFloat("fog", planetarium.fog);
    try planetarium.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam_pos", &planetarium.other_pos);

    line = try Line.init(
        try planetarium.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 0, 2, 0 } },
        &[_]Vec3{ .{ 0, 1, 0 }, .{ 0, 1, 0 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    line.drawing.setUniformFloat("fog", planetarium.fog);
    try planetarium.cam.linkDrawing(line.drawing);
    try line.drawing.addUniformVec3("real_cam_pos", &planetarium.other_pos);

    line = try Line.init(
        try planetarium.scene.new(.line),
        &[_]Vec3{ .{ 0, 0.01, 0 }, .{ 0, 0, 2 } },
        &[_]Vec3{ .{ 0, 0, 1 }, .{ 0, 0, 1 } },
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );
    try planetarium.cam.linkDrawing(line.drawing);
    line.drawing.setUniformFloat("fog", planetarium.fog);
    try line.drawing.addUniformVec3("real_cam_pos", &planetarium.other_pos);
}

pub fn makeGrid() !void {
    const size = 100;
    for (0..size) |i| {
        var x: f32 = @floatFromInt(i);
        x -= size / 2;

        var line = try Line.init(
            try planetarium.scene.new(.line),
            &[_]Vec3{ .{ x, 0, -size / 2 }, .{ x, 0, size / 2 } },
            &[_]Vec3{ .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 } },
            try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
        );

        try planetarium.cam.linkDrawing(line.drawing);
        line.drawing.setUniformFloat("fog", planetarium.fog);
        try line.drawing.addUniformVec3("real_cam_pos", &planetarium.other_pos);

        line = try Line.init(
            try planetarium.scene.new(.line),
            &[_]Vec3{ .{ -size / 2, 0, x }, .{ size / 2, 0, x } },
            &[_]Vec3{ .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 } },
            try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
        );

        try planetarium.cam.linkDrawing(line.drawing);
        line.drawing.setUniformFloat("fog", planetarium.fog);
        try line.drawing.addUniformVec3("real_cam_pos", &planetarium.other_pos);
    }
}

const fs = 15;

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

pub fn bdfToRgba(bdf: *BdfParse, c: u8) ![fs * fs]img.color.Rgba32 {
    var buf: [fs * fs]img.color.Rgba32 = undefined;
    var res = try bdf.getChar(c);
    for (res, 0..) |val, i| {
        if (val) {
            buf[i] = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
        } else {
            buf[i] = .{ .r = 30, .g = 100, .b = 100, .a = 255 };
        }
    }
    return buf;
}

pub fn makeSphere() !Mesh {
    var mesh = Mesh.init(common.allocator);

    var obj_parser = try ObjParse.init(common.allocator);
    var obj_builder = try obj_parser.parse("resources/cube.obj");
    defer obj_builder.deinit();

    try mesh.makeFrom(obj_builder.vertices.items, obj_builder.indices.items, .{
        .pos_offset = 0,
        .uv_offset = 3,
        .norm_offset = 5,
        .length = 8,
    }, 3);

    try mesh.subdivideMesh(5);

    var set = std.AutoHashMap(*HalfEdge, void).init(common.allocator);
    var stack = std.ArrayList(?*HalfEdge).init(common.allocator);

    defer set.deinit();
    defer stack.deinit();

    try stack.append(mesh.first_half);

    while (stack.items.len > 0) {
        var edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            var position = &edge.vertex.pos;

            position.* /= @splat(@sqrt(@reduce(.Add, position.* * position.*)));

            if (edge.next) |_| {
                if (edge.twin) |twin| {
                    try stack.append(twin);
                }
            }
            try stack.append(edge.next);
        }
    }

    try mesh.fixNormals();

    return mesh;
}

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    const elements: numericals.KeplerElements = .{
        .a = 384748,
        .e = 0.0549006,
        .i = 0,
        .arg = 0,
        .long = 0,
        .m0 = 0,
        .t0 = 0,
    };
    var res = numericals.keplerToCart(elements, 0, 0);
    std.debug.print("pf {d:.10}\n", .{res[0]});
    //std.os.exit(0);

    var bdf = try BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    try graphics.initGraphics();
    defer graphics.deinitGraphics();

    planetarium = try Planetarium.init();
    defer planetarium.deinit();

    gl.cullFace(gl.BACK);
    gl.enable(gl.BLEND);
    gl.lineWidth(2);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var text = try graphics.Text.init(try planetarium.scene.new(.spatial), bdf, .{ 0, 0, 0 });
    try text.initUniform();
    defer text.deinit();

    try makeAxis();
    //try makeGrid();

    var last_time: f32 = 0;

    var sphere = try makeSphere();
    defer sphere.deinit();
    var builder = try toMesh(sphere.first_half.?);
    defer builder.deinit();

    var timer: f32 = 0;

    //const planets_suffix = .{ "mer", "ven", "ear", "mar", "jup", "sat", "ura", "nep" };
    const planets_suffix = .{"ear"};
    var planets: [planets_suffix.len]astro.VsopPlanet = undefined;
    inline for (planets_suffix, 0..) |name, i| {
        planets[i] = try astro.VsopPlanet.init(name, builder, &planetarium);
        try planets[i].initUniform();
        planets[i].update(&planetarium);
        planetarium.cam_pos += planets[i].sky.pos + planetarium.cam_pos;

        const elems = planets[i].orb_vsop.at((planetarium.time - 2451545.0) / 365250.0);
        std.debug.print("{d:.4}\n", .{elems});

        const k = elems[2];
        const h = elems[3];
        const q = elems[4];
        const p = elems[5];

        const atan = std.math.atan;
        const asin = std.math.asin;

        const pq_r = p * p + q * q;
        const hk_r = h * h + k * k;

        const o = -2 * atan((q - @sqrt(pq_r)) / p);
        const inc = -2 * asin((pq_r - q * @sqrt(pq_r)) / (q - @sqrt(pq_r)));

        const e = (-hk_r + k * @sqrt(hk_r)) / (k - @sqrt(hk_r));
        const w = -2 * atan((k - @sqrt(hk_r)) / h);

        try astro.orbit(&planetarium, @floatCast(elems[0]), @floatCast(e), @floatCast(inc), @floatCast(o), @floatCast(w - o));
    }

    defer inline for (&planets) |*planet| {
        planet.deinit();
    };

    var obj_parser = try ObjParse.init(common.allocator);
    var obj_builder = try obj_parser.parse("resources/table.obj");

    var camera_obj = try obj_builder.toSpatial(
        try planetarium.scene.new(.spatial),
        .{
            .vert = @embedFile("shaders/triangle/vertex.glsl"),
            .frag = @embedFile("shaders/triangle/fragment.glsl"),
            .pos = .{ 0, 0, 0 },
        },
    );

    try planetarium.cam.linkDrawing(camera_obj.drawing);

    try camera_obj.initUniform();
    try camera_obj.drawing.addUniformFloat("fog", &planetarium.fog);

    camera_obj.drawing.bindVertex(obj_builder.vertices.items, obj_builder.indices.items);
    try camera_obj.drawing.textureFromPath("resources/table.png");
    obj_builder.deinit();

    //try astro.star(&planetarium);

    var p = try astro.KeplerPlanet.init("ear", &planets[0].pos, 1.32712440018e17, elements, builder, &planetarium);
    p.update(&planetarium);

    //try astro.orbit(&planetarium, elements.a, elements.e, elements.i, elements.long, elements.arg);

    while (planetarium.main_win.alive) {
        graphics.waitGraphicsEvent();

        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time = @as(f32, @floatCast(glfw.glfwGetTime()));

        const dt = time - last_time;
        planetarium.time += dt * 0;

        var pos_m = Mat4.translation(-planetarium.other_pos);
        camera_obj.drawing.setUniformMat4("model", pos_m);

        if (down_num > 0) {
            try key_down(&current_keys, last_mods, dt);
        }

        planetarium.cam.eye = planetarium.cam.eye;
        try planetarium.cam.updateMat();

        inline for (&planets) |*planet| {
            planet.update(&planetarium);
        }

        p.update(&planetarium);

        timer += dt;

        if (timer > 0.05) {
            try text.printFmt("⠓ り 撮影機: あああ {d:.4} {d:.4} {d:.4} {d:.4}\n", .{ planetarium.variables, planetarium.cam.eye, planetarium.other_pos, 1 / dt });
            timer = 0;
        }

        gl.disable(gl.DEPTH_TEST);
        gl.disable(gl.CULL_FACE);
        try planetarium.skybox_scene.draw(planetarium.main_win.*);

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.CULL_FACE);
        gl.cullFace(gl.BACK);
        try planetarium.scene.draw(planetarium.main_win.*);

        last_time = time;

        graphics.glfw.glfwSwapBuffers(planetarium.main_win.glfw_win);
        planetarium.other_pos[0] = @floatCast(planetarium.cam_pos[0]);
        planetarium.other_pos[1] = @floatCast(planetarium.cam_pos[1]);
        planetarium.other_pos[2] = @floatCast(planetarium.cam_pos[2]);
    }
}
