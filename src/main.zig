const std = @import("std");
const math = @import("math.zig");
const gl = @import("gl.zig");
const img = @import("img");
const geometry = @import("geometry.zig");
const graphics = @import("graphics.zig");
const graphics_set = @import("graphics_set.zig");
const common = @import("common.zig");

const BdfParse = @import("bdf.zig").BdfParse;

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

var current_keys: [glfw.GLFW_KEY_MENU + 1]bool = .{false} ** (glfw.GLFW_KEY_MENU + 1);
var down_num: usize = 0;
var last_mods: i32 = 0;

var main_win: *graphics.Window = undefined;
var scene: graphics.Scene = undefined;

var cam: Camera = undefined;

pub fn frameFunc(win: *graphics.Window, width: i32, height: i32) !void {
    _ = win;
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);
    try cam.setParameters(0.6, w / h, 0.1, 2048);
}

pub fn keyFunc(win: *graphics.Window, key: i32, scancode: i32, action: i32, mods: i32) !void {
    _ = win;
    _ = scancode;

    if (action == glfw.GLFW_PRESS) {
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

    const eye = @splat(3, speed * dt) * Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

    const cross_eye = @splat(3, speed * dt) * -Vec3Utils.crossn(eye, cam.up);

    const up_eye = @splat(3, speed * dt) * Vec3Utils.crossn(eye, cross_eye);

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

    line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ 0, 0.01, 0 }, .{ 0, 2, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 });

    line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ 0, 0.01, 0 }, .{ 0, 0, 2 }, .{ 0, 0, 1 }, .{ 0, 0, 1 });
}

pub fn makeGrid() !void {
    const size = 100;
    for (0..size) |i| {
        var x: f32 = @floatFromInt(i);
        x -= size / 2;

        var line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ x, 0, -size / 2 }, .{ x, 0, size / 2 }, .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 });
        line = try Line.init(try scene.new(.line), &cam.transform_mat, .{ -size / 2, 0, x }, .{ size / 2, 0, x }, .{ 0.5, 0.5, 0.5 }, .{ 0.5, 0.5, 0.5 });
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
    //gl.enable(gl.CULL_FACE);
    //gl.cullFace(gl.FRONT);
    gl.enable(gl.BLEND);
    gl.lineWidth(3);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    main_win.setKeyCallback(keyFunc);
    main_win.setFrameCallback(frameFunc);

    cam = try Camera.init(0.6, 1, 0.1, 2048);

    scene = try graphics.Scene.init();
    defer scene.deinit();

    var text = try graphics_set.Text.init(try scene.new(.spatial), bdf, .{ 0, 0, 0 }, "cam: { 4.3200, -0.2300 } { 4.6568, 3.9898, 15.5473 }");
    defer text.deinit();

    var atlas_cube = try graphics_set.makeCube(try scene.new(.spatial), .{ 10, 1, 0 }, &cam.transform_mat);
    var rgba_image = try graphics_set.Text.makeAtlas(bdf);
    defer common.allocator.free(rgba_image.data);

    std.debug.print("atlas is {d:4} {d:4}\n", .{ rgba_image.width, rgba_image.height });

    try atlas_cube.drawing.textureFromRgba(rgba_image.data, rgba_image.width, rgba_image.height);

    for ("*hello!", 0..) |c, i| {
        var cube = try graphics_set.makeCube(try scene.new(.spatial), .{ 10, 0, @as(f32, @floatFromInt(i)) }, &cam.transform_mat);

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
        .uv_offset = 3,
        .length = 8,
    }, 3);

    //var edge: ?*HalfEdge = try mesh.makeFrom(&vertices, &indices, 0, 3, 3);
    //try recurseHalf(&set, edge, false);
    //set.clearRetainingCapacity();

    var subdivide_set = std.AutoHashMap(?*HalfEdge, [2]*HalfEdge).init(common.allocator);
    try mesh.subdivide(cube.?, &subdivide_set);
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

            if (edge.next) |_| {
                //var pos_a = edge.vertex.pos;
                //var pos_b = next.vertex.pos;

                if (edge.twin) |twin| {
                    try stack.append(twin);
                    //try scene.append(.line, try Line.init(pos_a, pos_b, .{ 0.0, 0.0, 0.0 }, .{ 0.5, 0.0, 0.0 }));
                    //} else {
                    //try scene.append(.line try Line.init(pos_a, pos_b, .{ 0.3, 0.3, 0.3 }, .{ 0.0, 0.0, 0.0 }));
                }
            }
            try stack.append(edge.next);
        }
    }

    var subdivided = try builder.toSpatial(try scene.new(.spatial), &cam.transform_mat);
    subdivided.drawing.bindVertex(builder.vertices.items, builder.indices.items);
    try subdivided.drawing.textureFromPath("comofas.png");
    builder.deinit();
    set.deinit();

    while (main_win.alive) {
        graphics.waitGraphicsEvent();

        gl.clearColor(0.2, 0.2, 0.2, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time = @as(f32, @floatCast(glfw.glfwGetTime()));

        if (down_num > 0) {
            try key_down(&current_keys, last_mods, time - last_time);
        }

        try text.printFmt("cam: {d:.4} {d:.4}\n", .{ cam.eye, cam.move });

        try scene.draw(main_win.*);

        last_time = time;

        graphics.glfw.glfwSwapBuffers(main_win.glfw_win);
    }
}
