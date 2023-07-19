const std = @import("std");
const math = @import("math.zig");
const gl = @import("gl.zig");
const numericals = @import("numericals.zig");
const img = @import("img");
const geometry = @import("geometry.zig");
const graphics = @import("graphics.zig");
const graphics_set = @import("graphics_set.zig");
const common = @import("common.zig");

const BdfParse = @import("bdf.zig").BdfParse;
const ObjParse = @import("obj.zig").ObjParse;
const VsopParse = @import("vsop.zig").VsopParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;

const Camera = graphics_set.Camera;
const Cube = graphics_set.Cube;
const Line = graphics_set.Line;
const MeshBuilder = graphics_set.MeshBuilder;

const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

const atan2 = std.math.atan2;
const sin = std.math.sin;
const cos = std.math.cos;

var current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1);
var down_num: usize = 0;
var last_mods: i32 = 0;

var main_win: *graphics.Window = undefined;
var scene: graphics.Scene = undefined;

var cam: Camera = undefined;
var fog: f32 = 2;

pub fn frameFunc(win: *graphics.Window, width: i32, height: i32) !void {
    _ = win;
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try cam.setParameters(0.6, w / h, 0.1, 2048);
}

var is_wireframe = false;

pub fn keyFunc(win: *graphics.Window, key: i32, scancode: i32, action: i32, mods: i32) !void {
    _ = win;
    _ = scancode;

    if (action == glfw.GLFW_PRESS) {
        if (key == glfw.GLFW_KEY_C) {
            std.debug.print("abc\n", .{});
            if (is_wireframe) {
                gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
                is_wireframe = false;
            } else {
                gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
                is_wireframe = true;
            }
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
    _ = mods;

    var look_speed: f32 = 1 * dt;
    var speed: f32 = 2;

    const eye_x = cam.eye[0];
    const eye_y = cam.eye[1];

    if (keys[glfw.GLFW_KEY_LEFT_SHIFT]) {
        speed *= 7;
        look_speed *= 2;
    }

    std.debug.print("{d:.4} {d:.4}\n", .{ speed, look_speed });

    const speed_vec: Vec3 = @splat(speed * dt);
    const eye = speed_vec * Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

    const cross_eye = speed_vec * -Vec3Utils.crossn(eye, cam.up);

    const up_eye = speed_vec * Vec3Utils.crossn(eye, cross_eye);

    if (keys[glfw.GLFW_KEY_Q]) {
        main_win.alive = false;
    }

    if (keys[glfw.GLFW_KEY_W]) {
        cam.move += eye;
    }

    if (keys[glfw.GLFW_KEY_S]) {
        cam.move -= eye;
    }

    if (keys[glfw.GLFW_KEY_A]) {
        cam.move += cross_eye;
    }

    if (keys[glfw.GLFW_KEY_D]) {
        cam.move -= cross_eye;
    }

    if (keys[glfw.GLFW_KEY_R]) {
        cam.move += up_eye;
    }

    if (keys[glfw.GLFW_KEY_F]) {
        cam.move -= up_eye;
    }

    if (keys[graphics.glfw.GLFW_KEY_L]) {
        cam.eye[0] += look_speed;
    }

    if (keys[graphics.glfw.GLFW_KEY_H]) {
        cam.eye[0] -= look_speed;
    }

    if (keys[graphics.glfw.GLFW_KEY_K]) {
        if (cam.eye[1] < TAU) cam.eye[1] += look_speed;
    }

    if (keys[graphics.glfw.GLFW_KEY_J]) {
        if (cam.eye[1] > -TAU) cam.eye[1] -= look_speed;
    }

    try cam.updateMat();
}
pub fn makeAxis() !void {
    var line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ 0, 0.01, 0 }, .{ 2, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 0, 0 });
    try line.drawing.addUniformFloat("fog", &fog);

    line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ 0, 0.01, 0 }, .{ 0, 2, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 });
    try line.drawing.addUniformFloat("fog", &fog);

    line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ 0, 0.01, 0 }, .{ 0, 0, 2 }, .{ 0, 0, 1 }, .{ 0, 0, 1 });
    try line.drawing.addUniformFloat("fog", &fog);
}

pub fn makeGrid() !void {
    const size = 100;
    for (0..size) |i| {
        var x: f32 = @floatFromInt(i);
        x -= size / 2;

        var line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ x, 0, -size / 2 }, .{ x, 0, size / 2 }, .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 });
        try line.drawing.addUniformFloat("fog", &fog);
        line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ -size / 2, 0, x }, .{ size / 2, 0, x }, .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 });
        try line.drawing.addUniformFloat("fog", &fog);
    }
}

pub fn bdfToRgba(bdf: *BdfParse, c: u8) ![12 * 12]img.color.Rgba32 {
    var buf: [12 * 12]img.color.Rgba32 = undefined;
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

pub fn recurseHalf(mesh: *MeshBuilder, set: *std.AutoHashMap(*HalfEdge, void), edge: ?*HalfEdge, comptime will_render: bool) !void {
    if (edge) |actual| {
        if (set.get(actual)) |_| {
            return;
        }
        try set.put(actual, void{});

        if (will_render) {
            var v = actual.face.vertices;
            try mesh.addTri(.{ v[0].*, v[1].*, v[2].* });
        }

        if (actual.next) |next| {
            var line: Line = undefined;
            var pos_a = actual.vertex.pos;
            var pos_b = next.vertex.pos;

            if (actual.twin) |twin| {
                try recurseHalf(mesh, set, twin, will_render);
                line = try Line.init(try scene.new(.line), pos_a, pos_b, .{ 0.0, 0.0, 0.0 }, .{ 0.5, 0.0, 0.0 });
            } else {
                line = try Line.init(try scene.new(.line), pos_a, pos_b, .{ 0.3, 0.3, 0.3 }, .{ 0.0, 0.0, 0.0 });
            }
        }
        try recurseHalf(mesh, set, actual.next, will_render);
    }
}

const Planet = struct {
    vsop: VsopParse(3),
    subdivided: graphics_set.SpatialMesh,

    pub fn deinit(self: *Planet) void {
        self.vsop.deinit();
    }

    pub fn update(self: *Planet, time: f32) void {
        _ = time;
        const now: f64 = @floatFromInt(std.time.timestamp());
        const real_time = now / 86400.0 + 2440587.5;
        const venus_pos = self.vsop.at((real_time - 2451545.0) / 365250.0);

        var pos = Vec3{ @floatCast(venus_pos[0]), @floatCast(venus_pos[2]), @floatCast(venus_pos[1]) };
        pos *= @splat(10.0);

        self.subdivided.pos = pos;
    }

    pub fn initUniform(self: *Planet) !void {
        try self.subdivided.initUniform();
    }

    pub fn init(comptime name: []const u8, mesh: MeshBuilder) !Planet {
        var subdivided = try mesh.toSpatial(
            try scene.new(.spatial),
            .{
                .vert = "shaders/ball/vertex.glsl",
                .frag = "shaders/ball/fragment.glsl",
                .transform = &cam.transform_mat,
                .pos = .{ 0, 2, 0 },
            },
        );
        try subdivided.drawing.addUniformFloat("fog", &fog);

        subdivided.drawing.bindVertex(mesh.vertices.items, mesh.indices.items);

        try subdivided.drawing.textureFromPath("comofas.png");
        return .{
            .vsop = try VsopParse(3).init("vsop87/VSOP87C." ++ name),
            .subdivided = subdivided,
        };
    }
};

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    try graphics.initGraphics();
    defer graphics.deinitGraphics();
    main_win = try graphics.Window.init(100, 100);
    defer main_win.deinit();

    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
    gl.enable(gl.BLEND);
    gl.lineWidth(3);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    main_win.setKeyCallback(keyFunc);
    main_win.setFrameCallback(frameFunc);

    cam = try Camera.init(0.6, 1, 0.1, 2048);

    scene = try graphics.Scene.init();
    defer scene.deinit();

    var text = try graphics_set.Text.init(try scene.new(.spatial), bdf, .{ 0, 0, 0 }, "cam: { 4.3200, -0.2300 } { 4.6568, 3.9898, 15.5473 }");
    try text.initUniform();
    try text.drawing.addUniformFloat("fog", &fog);
    defer text.deinit();

    var atlas_cube = try graphics_set.makeCube(try scene.new(.spatial), .{ 10, 1, 0 }, &cam.transform_mat);
    try atlas_cube.initUniform();
    var rgba_image = try graphics_set.Text.makeAtlas(bdf);
    defer common.allocator.free(rgba_image.data);

    std.debug.print("atlas is {d:4} {d:4}\n", .{ rgba_image.width, rgba_image.height });

    try atlas_cube.drawing.textureFromRgba(rgba_image.data, rgba_image.width, rgba_image.height);

    for ("*hello!", 0..) |c, i| {
        var cube = try graphics_set.makeCube(try scene.new(.spatial), .{ 10, 0, @as(f32, @floatFromInt(i)) }, &cam.transform_mat);
        try cube.initUniform();

        var rgba = try bdfToRgba(&bdf, c);

        try cube.drawing.textureFromRgba(&rgba, 12, 12);
    }

    try makeAxis();
    try makeGrid();

    var last_time: f32 = 0;

    // mesh testing

    var mesh = Mesh.init(common.allocator);
    defer mesh.deinit();

    const vertices = [_]f32{
        0, 0, 0,
        0, 1, 0,
        1, 1, 0,
    };
    _ = vertices;

    const indices = [_]u32{
        0, 1, 2,
    };
    _ = indices;

    var cube: ?*HalfEdge = try mesh.makeFrom(&Cube.vertices, &Cube.indices, .{
        .pos_offset = 0,
        .norm_offset = 5,
        .uv_offset = 3,
        .length = 8,
    }, 3);

    //var edge: ?*HalfEdge = try mesh.makeFrom(&vertices, &indices, 0, 3, 3);
    //try recurseHalf(&set, edge, false);
    //set.clearRetainingCapacity();

    var subdivide_set = std.AutoHashMap(?*HalfEdge, [2]*HalfEdge).init(common.allocator);
    subdivide_set.clearRetainingCapacity();
    try mesh.subdivide(cube.?, &subdivide_set);
    subdivide_set.clearRetainingCapacity();
    try mesh.subdivide(cube.?, &subdivide_set);
    subdivide_set.clearRetainingCapacity();
    try mesh.subdivide(cube.?, &subdivide_set);
    subdivide_set.deinit();

    var builder = try MeshBuilder.init();

    var set = std.AutoHashMap(*HalfEdge, void).init(common.allocator);

    var stack = std.ArrayList(?*HalfEdge).init(common.allocator);
    defer stack.deinit();
    try stack.append(cube);

    while (stack.items.len > 0) {
        var edge_or = stack.pop();
        if (edge_or) |edge| {
            if (set.get(edge)) |_| continue;
            try set.put(edge, void{});

            var v = edge.face.vertices;

            const offset = Vec3{ -0.5, -0.5, -0.5 };

            var a = v[0].*;
            var b = v[1].*;
            var c = v[2].*;
            a.pos += offset;
            b.pos += offset;
            c.pos += offset;

            try builder.addTri(.{ a, b, c });

            if (edge.next) |next| {
                var pos_a = edge.vertex.pos + offset;
                var pos_b = next.vertex.pos + offset;

                if (edge.twin) |twin| {
                    try stack.append(twin);
                    var line = try Line.init(try scene.new(.line), &cam.transform_mat, pos_a, pos_b, .{ 0.0, 0.0, 0.0 }, .{ 0.5, 0.0, 0.0 });
                    try line.drawing.addUniformFloat("fog", &fog);
                } else {
                    var line = try Line.init(try scene.new(.line), &cam.transform_mat, pos_a, pos_b, .{ 0.3, 0.3, 0.3 }, .{ 0.0, 0.0, 0.0 });
                    try line.drawing.addUniformFloat("fog", &fog);
                }
            }
            try stack.append(edge.next);
        }
    }

    var obj_parser = try ObjParse.init(common.allocator);
    var obj_builder = try obj_parser.parse("resources/table.obj");

    var camera_obj = try obj_builder.toSpatial(
        try scene.new(.spatial),
        .{
            .vert = "shaders/triangle/vertex.glsl",
            .frag = "shaders/triangle/fragment.glsl",
            .transform = &cam.transform_mat,
        },
    );

    try camera_obj.initUniform();
    try camera_obj.drawing.addUniformFloat("fog", &fog);

    camera_obj.drawing.bindVertex(obj_builder.vertices.items, obj_builder.indices.items);
    try camera_obj.drawing.textureFromPath("resources/gray.png");
    obj_builder.deinit();

    //try (try graphics_set.makeCube(try scene.new(.spatial), .{ 0, 2, 0 }, &cam.transform_mat)).drawing.textureFromPath("comofas.png");

    var timer: f32 = 0;

    //glfw.glfwSwapInterval(0);

    const planets_suffix = .{ "mer", "ven", "ear", "mar", "jup", "sat", "ura", "nep" };
    var planets: [planets_suffix.len]Planet = undefined;
    inline for (planets_suffix, 0..) |name, i| {
        planets[i] = try Planet.init(name, builder);
        try planets[i].initUniform();
    }

    defer inline for (&planets) |*planet| {
        planet.deinit();
    };

    builder.deinit();
    set.deinit();

    while (main_win.alive) {
        graphics.waitGraphicsEvent();

        gl.clearColor(0.2, 0.2, 0.2, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time = @as(f32, @floatCast(glfw.glfwGetTime()));

        const dt = time - last_time;

        if (down_num > 0) {
            try key_down(&current_keys, last_mods, dt);
        }

        //var elems: numericals.KeplerElements = .{
        //    .a = 2.7,
        //    .e = 0.6,
        //    .i = 0,
        //    .arg = TAU / 4.0,
        //    .long = 0,
        //    .m0 = 0,
        //};

        //const v = 0.0;
        //elems.m0 = atan2(f32, -@sqrt(1 - elems.e * elems.e) * sin(v), -elems.e - cos(v)) + TAU / 2.0 - elems.e * (@sqrt(1 - elems.e * elems.e) * sin(v)) / (1 + elems.e * cos(v));

        inline for (&planets) |*planet| {
            planet.update(time);
        }
        timer += dt;

        if (timer > 0.025) {
            try text.printFmt("撮影機: あああ {d:.4} {d:.4} {d:.4}\n", .{ cam.eye, cam.move, 1 / dt });
            timer = 0;
        }

        try scene.draw(main_win.*);

        last_time = time;

        graphics.glfw.glfwSwapBuffers(main_win.glfw_win);
    }
}
