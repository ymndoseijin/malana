const std = @import("std");
const math = @import("math.zig");
const gl = @import("gl.zig");
const img = @import("img");
const geometry = @import("geometry.zig");
const graphics = @import("graphics.zig");
const common = @import("common.zig");

const BdfParse = @import("bdf.zig").BdfParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub const Camera = struct {
    perspective_mat: math.Mat4,

    transform_mat: math.Mat4,

    move: @Vector(3, f32) = .{ 7, 3.8, 13.7 },
    up: @Vector(3, f32) = .{ 0, 1, 0 },

    eye: [2]f32 = .{ 4.32, -0.23 },

    pub fn updateMat(self: *Camera) !void {
        const eye_x = self.eye[0];
        const eye_y = self.eye[1];

        const eye = Vec3{ std.math.cos(eye_x) * std.math.cos(eye_y), std.math.sin(eye_y), std.math.sin(eye_x) * std.math.cos(eye_y) };

        const view_mat = math.lookAtMatrix(.{ 0, 0, 0 }, eye, self.up);
        const translation_mat = Mat4.translation(-self.move);

        self.transform_mat = translation_mat.mul(Mat4, view_mat.mul(Mat4, self.perspective_mat));
    }

    pub fn setParameters(self: *Camera, fovy: f32, aspect: f32, nearZ: f32, farZ: f32) !void {
        self.perspective_mat = math.perspectiveMatrix(fovy, aspect, nearZ, farZ);
        try self.updateMat();
    }

    pub fn init(fovy: f32, aspect: f32, nearZ: f32, farZ: f32) !Camera {
        var init_cam = Camera{
            .transform_mat = undefined,
            .perspective_mat = math.perspectiveMatrix(fovy, aspect, nearZ, farZ),
        };

        try init_cam.updateMat();

        return init_cam;
    }
};

pub const Line = struct {
    pub fn init(drawing: *Drawing(.line), transform: *Mat4, a: Vec3, b: Vec3, c1: Vec3, c2: Vec3) !Line {
        var shader = try graphics.Shader.setupShader("shaders/line/vertex.glsl", "shaders/line/fragment.glsl");
        drawing.* = graphics.Drawing(.line).init(shader);

        const vertices = [_]f32{
            a[0], a[1], a[2], c1[0], c1[1], c1[2],
            b[0], b[1], b[2], c2[0], c2[1], c2[2],
        };
        const indices = [_]u32{ 0, 1 };

        drawing.bindVertex(&vertices, &indices);
        try drawing.uniform4fv_array.append(.{ .name = "transform", .value = &transform.rows[0][0] });

        return Line{
            .vertices = vertices,
            .indices = indices,
            .drawing = drawing,
        };
    }
    vertices: [12]f32,
    indices: [2]u32,
    drawing: *Drawing(.line),
};

pub const Cube = struct {
    // zig fmt: off
    pub const vertices = [_]f32{
        1, 1, 0, 0, 1, 0, 0, -1,
        0, 0, 0, 1, 0, 0, 0, -1,
        1, 0, 0, 0, 0, 0, 0, -1,
        0, 1, 0, 1, 1, 0, 0, -1, // this

        1, 1, 1, 0, 1, 1, 0, 0,
        1, 0, 0, 1, 0, 1, 0, 0,
        1, 0, 1, 0, 0, 1, 0, 0,
        1, 1, 0, 1, 1, 1, 0, 0,

        0, 1, 1, 0, 1, 0, 0, 1, // this
        1, 0, 1, 1, 0, 0, 0, 1,
        0, 0, 1, 0, 0, 0, 0, 1,
        1, 1, 1, 1, 1, 0, 0, 1,

        0, 1, 0, 0, 1, -1, 0, 0,
        0, 0, 1, 1, 0, -1, 0, 0,
        0, 0, 0, 0, 0, -1, 0, 0,
        0, 1, 1, 1, 1, -1, 0, 0, // outsider

        0, 1, 0, 0, 1, 0, 1, 0,
        1, 1, 1, 1, 0, 0, 1, 0,
        0, 1, 1, 0, 0, 0, 1, 0,
        1, 1, 0, 1, 1, 0, 1, 0,

        0, 0, 1, 0, 1, 0, -1, 0,
        1, 0, 0, 1, 0, 0, -1, 0,
        0, 0, 0, 0, 0, 0, -1, 0,
        1, 0, 1, 1, 1, 0, -1, 0,
    };
    // zig fmt: on

    pub fn getIndices() [6 * 24 / 4]u32 {
        var temp_indices: [6 * 24 / 4]u32 = undefined;
        inline for (0..24 / 4) |i| {
            temp_indices[6 * i] = 4 * i;
            temp_indices[6 * i + 1] = 4 * i + 1;
            temp_indices[6 * i + 2] = 4 * i + 2;
            temp_indices[6 * i + 3] = 4 * i + 3;
            temp_indices[6 * i + 4] = 4 * i + 1;
            temp_indices[6 * i + 5] = 4 * i;
        }

        return temp_indices;
    }

    pub var indices: [6 * 24 / 4]u32 = getIndices();
};

pub fn makeCube(drawing: *Drawing(.spatial), pos: Vec3, transform: *Mat4) !SpatialMesh {
    var mesh = try SpatialMesh.init(drawing, pos, transform, try graphics.Shader.setupShader("shaders/cube/vertex.glsl", "shaders/cube/fragment.glsl"));
    mesh.drawing.bindVertex(&Cube.vertices, &Cube.indices);
    return mesh;
}

pub const SpatialMesh = struct {
    drawing: *Drawing(.spatial),

    pub fn updatePos(self: *SpatialMesh, pos: Vec3) void {
        self.drawing.uniform3f_array[0].value = pos;
    }

    pub fn init(drawing: *Drawing(.spatial), pos: Vec3, transform: *Mat4, shader: u32) !SpatialMesh {
        drawing.* = graphics.Drawing(.spatial).init(shader);

        try drawing.uniform4fv_array.append(.{ .name = "transform", .value = &transform.rows[0][0] });
        try drawing.uniform3f_array.append(.{ .name = "pos", .value = pos });

        return SpatialMesh{
            .drawing = drawing,
        };
    }
};

pub const MeshBuilder = struct {
    vertices: std.ArrayList(f32),
    indices: std.ArrayList(u32),
    count: u32,

    pub fn deinit(self: *MeshBuilder) void {
        self.vertices.deinit();
        self.indices.deinit();
    }

    pub fn addTri(self: *MeshBuilder, v: [3]Vertex) !void {
        const vertices = [_]f32{
            v[0].pos[0], v[0].pos[1], v[0].pos[2], v[0].uv[0], v[0].uv[1], 0, 0, 0,
            v[1].pos[0], v[1].pos[1], v[1].pos[2], v[1].uv[0], v[1].uv[1], 0, 0, 0,
            v[2].pos[0], v[2].pos[1], v[2].pos[2], v[2].uv[0], v[2].uv[1], 0, 0, 0,
        };

        const indices = [_]u32{
            self.count, self.count + 1, self.count + 2,
        };

        inline for (vertices) |vert| {
            try self.vertices.append(vert);
        }

        inline for (indices) |i| {
            try self.indices.append(i);
        }

        self.count += 3;
    }

    pub fn toSpatial(self: *MeshBuilder, drawing: *Drawing(.spatial), transform: *Mat4) !SpatialMesh {
        _ = self;
        return try SpatialMesh.init(
            drawing,
            .{ 0, 0, 0 },
            transform,
            try graphics.Shader.setupShader("shaders/triangle/vertex.glsl", "shaders/triangle/fragment.glsl"),
        );
    }

    pub fn init() !MeshBuilder {
        return MeshBuilder{
            .count = 0,
            .vertices = std.ArrayList(f32).init(common.allocator),
            .indices = std.ArrayList(u32).init(common.allocator),
        };
    }
};

pub fn bdfToRgba(res: []bool) ![12 * 12]img.color.Rgba32 {
    var buf: [12 * 12]img.color.Rgba32 = undefined;
    for (res, 0..) |val, i| {
        if (val) {
            buf[i] = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
        } else {
            buf[i] = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
        }
    }
    return buf;
}

pub const Image = struct {
    width: u32,
    height: u32,
    data: []img.color.Rgba32,
};

pub const Text = struct {
    drawing: *Drawing(.spatial),
    bdf: BdfParse,
    atlas: Image,

    pub fn updatePos(self: *Text, pos: Vec3) void {
        self.drawing.uniform3f_array[0].value = pos;
    }

    pub fn makeAtlas(bdf: BdfParse) !Image {
        const count = bdf.map.items.len;

        const count_float: f32 = @floatFromInt(count);

        const size: u32 = @intFromFloat(@ceil(@sqrt(count_float)));

        const side_size: u32 = size * bdf.width;

        var atlas = try common.allocator.alloc(img.color.Rgba32, side_size * side_size);
        for (atlas) |*elem| {
            elem.* = .{ .r = 30, .g = 100, .b = 100, .a = 255 };
        }

        for (bdf.map.items, 0..) |search, i| {
            const atlas_x = (i % size) * bdf.width;
            const atlas_y = @divFloor(i, size) * bdf.width;
            const rgba = try bdfToRgba(search[1]);

            for (rgba, 0..) |color, j| {
                const char_x = j % 12;
                const char_y = @divFloor(j, 12);
                atlas[(atlas_y + char_y) * side_size + atlas_x + char_x] = color;
            }
        }

        return Image{ .data = atlas, .width = side_size, .height = side_size };
    }

    pub fn printFmt(self: *Text, comptime fmt: []const u8, fmt_args: anytype) !void {
        var buf: [4098]u8 = undefined;
        var str = try std.fmt.bufPrint(&buf, fmt, fmt_args);
        try self.print(str);
    }

    pub fn print(self: *Text, text: []const u8) !void {
        var vertices = std.ArrayList(f32).init(common.allocator);
        var indices = std.ArrayList(u32).init(common.allocator);
        defer vertices.deinit();
        defer indices.deinit();

        var x: f32 = 0;
        for (text, 0..) |c, x_int| {
            const count_float: f32 = @floatFromInt(self.bdf.map.items.len);
            const size: u32 = @intFromFloat(@ceil(@sqrt(count_float)));
            const size_f: f32 = @ceil(@sqrt(count_float));

            //std.debug.print("{d:.4} {d:.4}\n", .{ c, x });

            for (self.bdf.map.items, 0..) |search, i| {
                if (search[0] == c) {
                    const atlas_x: f32 = @floatFromInt(i % size);
                    const atlas_y: f32 = @floatFromInt(@divFloor(i, size));

                    const c_vert = [_]f32{
                        x,     0, 0, atlas_x,     size_f - atlas_y + 1, 0, 0, 0,
                        x + 1, 0, 0, atlas_x + 1, size_f - atlas_y + 1, 0, 0, 0,
                        x + 1, 1, 0, atlas_x + 1, size_f - atlas_y,     0, 0, 0,
                        x,     1, 0, atlas_x,     size_f - atlas_y,     0, 0, 0,
                    };

                    const start: u32 = @intCast(x_int * 4);

                    try indices.append(start);
                    try indices.append(start + 1);
                    try indices.append(start + 2);
                    try indices.append(start);
                    try indices.append(start + 2);
                    try indices.append(start + 3);

                    inline for (c_vert) |val| {
                        try vertices.append(val);
                    }

                    const bbx_width: f32 = @floatFromInt(search[2]);
                    const width: f32 = @floatFromInt(self.bdf.width);
                    x += bbx_width / width + 1 / width;

                    break;
                }
            }
        }

        self.drawing.bindVertex(vertices.items, indices.items);
    }

    pub fn deinit(self: *Text) void {
        common.allocator.free(self.atlas.data);
    }

    pub fn init(drawing: *Drawing(.spatial), bdf: BdfParse, pos: Vec3, text: []const u8) !Text {
        drawing.* = graphics.Drawing(.spatial).init(try graphics.Shader.setupShader("shaders/text/vertex.glsl", "shaders/text/fragment.glsl"));

        var atlas = try makeAtlas(bdf);

        try drawing.textureFromRgba(atlas.data, atlas.width, atlas.height);
        try drawing.uniform3f_array.append(.{ .name = "pos", .value = pos });

        var res = Text{
            .bdf = bdf,
            .drawing = drawing,
            .atlas = atlas,
        };
        try res.print(text);

        return res;
    }
};
