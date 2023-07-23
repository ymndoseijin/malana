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

pub fn orbit(state: *Planetarium, a: f32, e: f32, inc: f32, long: f32, arg: f32) !void {
    const amount = 60;
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
        elems.m0 = atan2(f32, -@sqrt(1 - elems.e * elems.e) * sin(v), -elems.e - cos(v)) + TAU / 2.0 - elems.e * (@sqrt(1 - elems.e * elems.e) * sin(v)) / (1 + elems.e * cos(v));

        var res = numericals.keplerToCart(elems, 0, elems.m0);
        res[0] *= @splat(10.0);

        try verts.append(.{ res[0][0], res[0][2], res[0][1] });
        try colors.append(res[1]);

        if (first) {
            first_v = .{ res[0][0], res[0][2], res[0][1] };
            first = false;
        }

        v = (f + 1) / amount * TAU;
        elems.m0 = atan2(f32, -@sqrt(1 - elems.e * elems.e) * sin(v), -elems.e - cos(v)) + TAU / 2.0 - elems.e * (@sqrt(1 - elems.e * elems.e) * sin(v)) / (1 + elems.e * cos(v));

        res = numericals.keplerToCart(elems, 0, elems.m0);
        res[0] *= @splat(10.0);

        try verts.append(.{ res[0][0], res[0][2], res[0][1] });
        try colors.append(res[1]);
        last_c = res[1];
    }

    try verts.append(first_v);
    try colors.append(last_c);

    var line = try Line.init(try state.scene.new(.line), &state.cam.transform_mat, verts.items, colors.items);
    line.drawing.setUniformFloat("fog", &state.fog);
}

pub const Planet = struct {
    vsop: VsopParse(3),
    orb_vsop: VsopParse(6),
    subdivided: graphics.SpatialMesh,

    pub fn deinit(self: *Planet) void {
        self.vsop.deinit();
        self.orb_vsop.deinit();
    }

    pub fn update(self: *Planet, state: *Planetarium) void {
        const venus_pos = self.vsop.at((state.time - 2451545.0) / 365250.0);

        var pos = Vec3{ @floatCast(venus_pos[1]), @floatCast(venus_pos[2]), @floatCast(venus_pos[0]) };
        pos *= @splat(10.0);

        const rot_m = math.rotationY(f32, TAU / 4.0).cast(4, 4);
        const pos_m = Mat4.translation(pos);
        var model = rot_m.mul(pos_m.mul(Mat4.scaling(Vec4{ 0.2, 0.2, 0.2, 1.0 })));
        self.subdivided.drawing.setUniformMat4("model", &model);

        self.subdivided.pos = pos;
    }

    pub fn initUniform(self: *Planet) !void {
        try self.subdivided.initUniform();
    }

    pub fn init(comptime name: []const u8, mesh: MeshBuilder, state: *Planetarium) !Planet {
        var subdivided = try mesh.toSpatial(
            try state.scene.new(.spatial),
            &state.cam.transform_mat,
            .{
                .vert = "shaders/ball/vertex.glsl",
                .frag = "shaders/ball/fragment.glsl",
                .pos = .{ 0, 2, 0 },
            },
        );
        subdivided.drawing.setUniformFloat("fog", &state.fog);

        subdivided.drawing.bindVertex(mesh.vertices.items, mesh.indices.items);

        try subdivided.drawing.textureFromPath("comofas.png");

        const actual = if (comptime std.mem.eql(u8, "ear", name)) "emb" else name;

        return .{
            .vsop = try VsopParse(3).init("vsop87/VSOP87C." ++ name),
            .orb_vsop = try VsopParse(6).init("vsop87/VSOP87." ++ actual),
            .subdivided = subdivided,
        };
    }
};

pub fn star(state: *Planetarium) !void {
    var mesh = try graphics.SpatialMesh.init(
        try state.skybox_scene.new(.spatial),
        .{ 0.0, 0, 0 },
        &state.skybox_cam.transform_mat,
        try graphics.Shader.setupShader("shaders/star/vertex.glsl", "shaders/star/fragment.glsl"),
    );

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

        std.debug.print("{d} {d}\n", .{ ra, dec });
        //std.os.exit(0);

        const rot = math.rotationY(f64, ra).mul(math.rotationZ(f64, dec));

        const size = 0.01;

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

    mesh.drawing.setUniformFloat("fog", &state.fog);
}
