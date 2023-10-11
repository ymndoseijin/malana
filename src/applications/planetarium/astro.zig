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

const atan2 = std.math.atan2;
const sin = std.math.sin;
const cos = std.math.cos;

const TAU = 6.28318530718;

const Planetarium = @import("main.zig").Planetarium;

const SCALE = 2348.1034;

const Pixel = struct { r: u8, g: u8, b: u8, a: u8 };

const ImageTexture = struct {
    data: []Pixel,
    width: usize,
    height: usize,

    pub fn get(self: ImageTexture, x: usize, y: usize) Pixel {
        return self.data[self.width * y + x];
    }

    pub fn set(self: *ImageTexture, x: usize, y: usize, pix: Pixel) void {
        self.data[self.width * y + x] = pix;
    }
};

const Cubemap = struct {
    faces: [6]ImageTexture,
    pub fn deinit(self: *Cubemap) void {
        for (self.faces) |face| {
            common.allocator.free(face.data);
        }
    }
};

fn processImage(comptime name: []const u8) !Cubemap {
    var read_image = try img.Image.fromFilePath(common.allocator, "resources/" ++ name ++ ".qoi");
    defer read_image.deinit();

    var arr: []img.color.Rgba32 = undefined;
    switch (read_image.pixels) {
        .rgba32 => |data| {
            arr = data;
        },
        else => return error.InvalidImage,
    }

    const square_width = 500;

    var res: Cubemap = undefined;

    var og = ImageTexture{
        .data = try common.allocator.alloc(Pixel, arr.len),
        .width = read_image.width,
        .height = read_image.height,
    };
    defer common.allocator.free(og.data);

    for (arr, 0..) |pix, i| {
        og.data[i].r = pix.r;
        og.data[i].g = pix.g;
        og.data[i].b = pix.b;
        og.data[i].a = pix.a;
    }

    for (0..6) |face_idx| {
        var face_img = ImageTexture{
            .data = try common.allocator.alloc(Pixel, square_width * square_width),
            .width = square_width,
            .height = square_width,
        };
        for (0..face_img.width) |x_int| {
            for (0..face_img.height) |y_int| {
                var plane_x: f64 = @floatFromInt(x_int);
                plane_x /= @floatFromInt(face_img.width);
                plane_x *= 2;
                plane_x -= 1;
                var plane_y: f64 = @floatFromInt(y_int);
                plane_y /= @floatFromInt(face_img.height);
                plane_y *= 2;
                plane_y -= 1;

                //plane_x *= -1;
                //plane_y *= -1;

                const x: f64 = switch (face_idx) {
                    0 => -1.0,
                    1 => -plane_x,
                    2 => plane_x,
                    3 => 1.0,
                    4 => -plane_x,
                    5 => -plane_x,
                    else => unreachable,
                };
                const z: f64 = switch (face_idx) {
                    0 => -plane_y,
                    1 => 1.0,
                    2 => -plane_y,
                    3 => -plane_y,
                    4 => -1.0,
                    5 => -plane_y,
                    else => unreachable,
                };
                const y: f64 = switch (face_idx) {
                    0 => -plane_x,
                    1 => plane_y,
                    2 => -1.0,
                    3 => plane_x,
                    4 => -plane_y,
                    5 => 1.0,
                    else => unreachable,
                };

                const r = @sqrt(x * x + y * y + z * z);

                const w_s: f64 = @floatFromInt(og.width);
                const h_s: f64 = @floatFromInt(og.height);

                const x_f = std.math.atan2(f64, y, x) / TAU;
                const y_f = std.math.acos(z / r) / TAU * 2;

                const x_s: usize = @intFromFloat(@mod(x_f, 1) * w_s);
                const y_s: usize = @intFromFloat(@mod(y_f, 1) * h_s);

                face_img.set(x_int, y_int, og.get(x_s, y_s));
            }
        }
        res.faces[face_idx] = face_img;
    }

    return res;
}

pub fn orbit(state: *Planetarium, a: f64, e: f64, inc: f64, long: f64, arg: f64) !void {
    const amount = 200;
    var verts = std.ArrayList(Vec3).init(common.allocator);
    var colors = std.ArrayList(Vec3).init(common.allocator);

    defer verts.deinit();
    defer colors.deinit();

    var first_v: Vec3 = undefined;
    var last_c: Vec3 = undefined;

    var first = true;

    for (0..amount) |i| {
        var elems: numericals.KeplerElements = .{
            .a = a,
            .e = e,
            .i = inc,
            .arg = arg,
            .long = long,
            .m0 = 0,
        };

        const f: f32 = @floatFromInt(i);

        var v = f / amount * TAU;
        elems.m0 = atan2(f64, -@sqrt(1 - elems.e * elems.e) * sin(v), -elems.e - cos(v)) + TAU / 2.0 - elems.e * (@sqrt(1 - elems.e * elems.e) * sin(v)) / (1 + elems.e * cos(v));

        var res = numericals.keplerToCart(elems, 0, elems.m0);
        res[0] *= @splat(SCALE);

        var vec = Vec3{ @floatCast(res[0][0]), @floatCast(res[0][1]), @floatCast(res[0][2]) };
        var color_vec = Vec3{ @floatCast(res[1][0]), @floatCast(res[1][1]), @floatCast(res[1][2]) };

        try verts.append(.{ vec[0], vec[2], vec[1] });
        try colors.append(color_vec);

        if (first) {
            first_v = .{ vec[0], vec[2], vec[1] };
            first = false;
        }

        v = (f + 1) / amount * TAU;
        elems.m0 = atan2(f64, -@sqrt(1 - elems.e * elems.e) * sin(v), -elems.e - cos(v)) + TAU / 2.0 - elems.e * (@sqrt(1 - elems.e * elems.e) * sin(v)) / (1 + elems.e * cos(v));

        res = numericals.keplerToCart(elems, 0, elems.m0);
        res[0] *= @splat(SCALE);

        vec = Vec3{ @floatCast(res[0][0]), @floatCast(res[0][1]), @floatCast(res[0][2]) };
        color_vec = Vec3{ @floatCast(res[1][0]), @floatCast(res[1][1]), @floatCast(res[1][2]) };

        try verts.append(.{ vec[0], vec[2], vec[1] });
        try colors.append(color_vec);
        last_c = color_vec;
    }

    try verts.append(first_v);
    try colors.append(last_c);

    var line = try Line.init(
        try state.scene.new(.line),
        verts.items,
        colors.items,
        try graphics.Shader.setupShader(@embedFile("shaders/line/vertex.glsl"), @embedFile("shaders/line/fragment.glsl")),
    );

    try state.cam.linkDrawing(line.drawing);
    line.drawing.setUniformFloat("fog", state.fog);
    try line.drawing.addUniformVec3("real_cam_pos", &state.other_pos);
}

pub const KeplerPlanet = struct {
    ref: *@Vector(3, f64),
    parent_mu: f64,
    name: []const u8,
    subdivided: graphics.SpatialMesh,
    sky: graphics.SpatialMesh,
    elems: numericals.KeplerElements,

    pub fn update(self: *KeplerPlanet, state: *Planetarium) void {
        const t = state.time;

        var res = numericals.keplerToCart(self.elems, @floatCast(t), self.parent_mu);
        std.debug.print("pf {d:.10}\n", .{res[0]});
        res[0] /= @splat(149597870.7);

        res[0] += self.ref.*;
        res[0] *= @splat(SCALE);

        var venus_pos = Vec3{ @floatCast(res[0][0]), @floatCast(res[0][1]), @floatCast(res[0][2]) };

        std.debug.print("PORRA {d:.4}\n", .{venus_pos});

        self.sky.drawing.setUniformVec3("planet_pos", venus_pos);

        venus_pos -= state.other_pos;

        const pos_m = Mat4.translation(venus_pos);
        var model = pos_m;

        self.subdivided.drawing.setUniformMat4("model", model);
        self.subdivided.pos = venus_pos;

        self.sky.drawing.setUniformMat4("model", model);
        self.sky.pos = venus_pos;
    }

    pub fn init(comptime name: []const u8, parent: *@Vector(3, f64), parent_mu: f64, elems: numericals.KeplerElements, mesh: MeshBuilder, state: *Planetarium) !KeplerPlanet {
        var subdivided = try mesh.toSpatial(
            try state.scene.new(.spatial),
            .{
                .vert = @embedFile("shaders/ball/vertex.glsl"),
                .frag = @embedFile("shaders/ball/fragment.glsl"),
                .pos = .{ 0, 0, 0 },
            },
        );

        try state.cam.linkDrawing(subdivided.drawing);
        try subdivided.drawing.addUniformVec3("real_cam_pos", &state.other_pos);
        subdivided.drawing.setUniformFloat("fog", state.fog);

        subdivided.drawing.bindVertex(mesh.vertices.items, mesh.indices.items);

        var res = try processImage(name);
        defer res.deinit();

        try subdivided.drawing.cubemapFromRgba(.{
            res.faces[0],
            res.faces[3],
            res.faces[1],
            res.faces[4],
            res.faces[5],
            res.faces[2],
        }, res.faces[0].width, res.faces[0].height);

        var sky = try mesh.toSpatial(
            try state.scene.new(.spatial),
            .{
                .vert = @embedFile("shaders/sky/vertex.glsl"),
                .frag = @embedFile("shaders/sky/fragment.glsl"),
                .pos = .{ 0, 0, 0 },
            },
        );

        try state.cam.linkDrawing(sky.drawing);
        try sky.drawing.addUniformVec3("real_cam_pos", &state.other_pos);
        sky.drawing.setUniformFloat("fog", state.fog);

        try sky.drawing.addUniformFloat("falloff", &state.variables[1]);
        sky.drawing.bindVertex(mesh.vertices.items, mesh.indices.items);

        return .{
            .ref = parent,
            .parent_mu = parent_mu,
            .elems = elems,
            .subdivided = subdivided,
            .sky = sky,
            .name = name,
        };
    }
};

pub const VsopPlanet = struct {
    vsop: VsopParse(3),
    orb_vsop: VsopParse(6),
    subdivided: graphics.SpatialMesh,
    sky: graphics.SpatialMesh,

    name: []const u8,
    pos: @Vector(3, f64),

    pub fn deinit(self: *VsopPlanet) void {
        self.vsop.deinit();
        self.orb_vsop.deinit();
    }

    pub fn update(self: *VsopPlanet, state: *Planetarium) void {
        var og_pos: @Vector(3, f64) = self.vsop.at((state.time - 2451545.0) / 365250.0);

        var venus_pos = @Vector(3, f64){ og_pos[1], og_pos[2], og_pos[0] };

        venus_pos = math.rotationY(f64, TAU / 4.0).dot(venus_pos);
        self.pos = venus_pos;

        //std.debug.print("{d:.4} {s} POR QUE\n", .{ @reduce(.Add, og_pos * og_pos), self.name });

        venus_pos *= @splat(SCALE);

        var pos = Vec3{ @floatCast(venus_pos[0]), @floatCast(venus_pos[1]), @floatCast(venus_pos[2]) };

        self.sky.drawing.setUniformVec3("planet_pos", pos);

        venus_pos -= state.cam_pos;

        pos = Vec3{ @floatCast(venus_pos[0]), @floatCast(venus_pos[1]), @floatCast(venus_pos[2]) };

        const pos_m = Mat4.translation(pos);
        var model = pos_m;

        self.subdivided.drawing.setUniformMat4("model", model);
        self.subdivided.pos = pos;

        self.sky.drawing.setUniformMat4("model", model);
        self.sky.pos = pos;
    }

    pub fn initUniform(self: *VsopPlanet) !void {
        try self.subdivided.initUniform();
        try self.sky.initUniform();
    }

    pub fn init(comptime name: []const u8, mesh: MeshBuilder, state: *Planetarium) !VsopPlanet {
        var subdivided = try mesh.toSpatial(
            try state.scene.new(.spatial),
            .{
                .vert = @embedFile("shaders/ball/vertex.glsl"),
                .frag = @embedFile("shaders/ball/fragment.glsl"),
                .pos = .{ 0, 0, 0 },
            },
        );

        try state.cam.linkDrawing(subdivided.drawing);
        try subdivided.drawing.addUniformVec3("real_cam_pos", &state.other_pos);
        subdivided.drawing.setUniformFloat("fog", state.fog);

        subdivided.drawing.bindVertex(mesh.vertices.items, mesh.indices.items);

        var res = try processImage(name);
        defer res.deinit();

        try subdivided.drawing.cubemapFromRgba(.{
            res.faces[0],
            res.faces[3],
            res.faces[1],
            res.faces[4],
            res.faces[5],
            res.faces[2],
        }, res.faces[0].width, res.faces[0].height);

        var sky = try mesh.toSpatial(
            try state.scene.new(.spatial),
            .{
                .vert = @embedFile("shaders/sky/vertex.glsl"),
                .frag = @embedFile("shaders/sky/fragment.glsl"),
                .pos = .{ 0, 0, 0 },
            },
        );

        try state.cam.linkDrawing(sky.drawing);
        try sky.drawing.addUniformVec3("real_cam_pos", &state.other_pos);
        sky.drawing.setUniformFloat("fog", state.fog);

        try sky.drawing.addUniformFloat("falloff", &state.variables[1]);
        sky.drawing.bindVertex(mesh.vertices.items, mesh.indices.items);

        const actual = if (comptime std.mem.eql(u8, "ear", name)) "emb" else name;

        return .{
            .vsop = try VsopParse(3).init("vsop87/VSOP87C." ++ name),
            .orb_vsop = try VsopParse(6).init("vsop87/VSOP87." ++ actual),
            .pos = .{ 0, 0, 0 },
            .subdivided = subdivided,
            .sky = sky,
            .name = name,
        };
    }
};

pub fn star(state: *Planetarium) !void {
    var mesh = try graphics.SpatialMesh.init(
        try state.skybox_scene.new(.spatial),
        .{ 0.0, 0, 0 },
        try graphics.Shader.setupShader(@embedFile("shaders/star/vertex.glsl"), @embedFile("shaders/star/fragment.glsl")),
    );
    try state.cam.linkDrawing(mesh.drawing);

    var vertices = std.ArrayList(f32).init(common.allocator);
    var indices = std.ArrayList(u32).init(common.allocator);

    defer vertices.deinit();
    defer indices.deinit();

    var file = try std.fs.cwd().openFile("resources/astro/hygfull.csv", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [4096]u8 = undefined;

    var start = true;

    var i: u32 = 0;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (i += 1) {
        if (start) {
            start = false;
            continue;
        }

        var it = std.mem.splitAny(u8, line, ",");

        inline for (0..7) |_| {
            _ = it.next();
        }

        const ra = try std.fmt.parseFloat(f64, it.next().?) / 360 * TAU * 15;
        const dec = try std.fmt.parseFloat(f64, it.next().?) / 360 * TAU;

        _ = it.next();
        const mag = try std.fmt.parseFloat(f64, std.mem.trim(u8, it.next().?, " "));

        const rot = math.rotationY(f64, ra).mul(math.rotationZ(f64, dec));

        const size = 0.2 * std.math.pow(f64, 10, 0.1 * (-4.6 - mag));

        std.debug.print("{d} size {d} {d} {d}\n", .{ size, ra, dec, mag });

        const a = rot.dot(.{ 10.0, -size, -size });
        const b = rot.dot(.{ 10.0, size, -size });
        const c = rot.dot(.{ 10.0, -size, size });
        const d = rot.dot(.{ 10.0, size, size });

        const s: u32 = i * 4;

        const verts = [_]f32{
            @floatCast(a[0]), @floatCast(a[1]), @floatCast(a[2]), 0.0, 0.0, 0.0, 0.0, 0.0,
            @floatCast(b[0]), @floatCast(b[1]), @floatCast(b[2]), 1.0, 0.0, 0.0, 0.0, 0.0,
            @floatCast(c[0]), @floatCast(c[1]), @floatCast(c[2]), 0.0, 1.0, 0.0, 0.0, 0.0,
            @floatCast(d[0]), @floatCast(d[1]), @floatCast(d[2]), 1.0, 1.0, 0.0, 0.0, 0.0,
        };
        const idx = .{ s, s + 1, s + 2, s + 3, s + 2, s + 1 };

        inline for (verts) |val| {
            try vertices.append(val);
        }

        inline for (idx) |val| {
            try indices.append(val);
        }
    }
    mesh.drawing.bindVertex(vertices.items, indices.items);

    mesh.drawing.setUniformFloat("fog", state.fog);
}
