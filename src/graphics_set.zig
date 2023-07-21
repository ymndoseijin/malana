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

        self.transform_mat = self.perspective_mat.mul(view_mat.mul(translation_mat));
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
    pub fn init(drawing: *Drawing(.line), transform: *Mat4, vert: []const Vec3, color: []const Vec3) !Line {
        var shader = try graphics.Shader.setupShader("shaders/line/vertex.glsl", "shaders/line/fragment.glsl");
        drawing.* = graphics.Drawing(.line).init(shader);

        var vertices = std.ArrayList(f32).init(common.allocator);
        var indices = std.ArrayList(u32).init(common.allocator);

        defer vertices.deinit();
        defer indices.deinit();

        for (vert, color, 0..) |v, c, i| {
            const arr = .{ v[0], v[1], v[2], c[0], c[1], c[2] };
            inline for (arr) |f| {
                try vertices.append(f);
            }
            try indices.append(@intCast(i));
        }

        drawing.bindVertex(vertices.items, indices.items);
        try drawing.addUniformMat4("transform", transform);

        return Line{
            .vertices = vertices.items,
            .indices = indices.items,
            .drawing = drawing,
        };
    }
    vertices: []f32,
    indices: []u32,
    drawing: *Drawing(.line),
};

pub const Cube = struct {
    pub const vertices = [_]f32{
        0.0, 1.0, 0.0, 1.0,    0.5,  -0.0, 1.0,  -0.0,
        1.0, 1.0, 1.0, 0.6667, 0.75, -0.0, 1.0,  -0.0,
        1.0, 1.0, 0.0, 0.6667, 0.5,  -0.0, 1.0,  -0.0,
        1.0, 1.0, 1.0, 0.6667, 0.75, -0.0, -0.0, 1.0,
        0.0, 0.0, 1.0, 0.3333, 1.0,  -0.0, -0.0, 1.0,
        1.0, 0.0, 1.0, 0.3333, 0.75, -0.0, -0.0, 1.0,
        0.0, 1.0, 1.0, 0.6667, 0.0,  -1.0, -0.0, -0.0,
        0.0, 0.0, 0.0, 0.3333, 0.25, -1.0, -0.0, -0.0,
        0.0, 0.0, 1.0, 0.3333, 0.0,  -1.0, -0.0, -0.0,
        1.0, 0.0, 0.0, 0.3333, 0.5,  -0.0, -1.0, -0.0,
        0.0, 0.0, 1.0, -0.0,   0.75, -0.0, -1.0, -0.0,
        0.0, 0.0, 0.0, -0.0,   0.5,  -0.0, -1.0, -0.0,
        1.0, 1.0, 0.0, 0.6667, 0.5,  1.0,  -0.0, -0.0,
        1.0, 0.0, 1.0, 0.3333, 0.75, 1.0,  -0.0, -0.0,
        1.0, 0.0, 0.0, 0.3333, 0.5,  1.0,  -0.0, -0.0,
        0.0, 1.0, 0.0, 0.6667, 0.25, -0.0, -0.0, -1.0,
        1.0, 0.0, 0.0, 0.3333, 0.5,  -0.0, -0.0, -1.0,
        0.0, 0.0, 0.0, 0.3333, 0.25, -0.0, -0.0, -1.0,
        0.0, 1.0, 0.0, 1.0,    0.5,  -0.0, 1.0,  -0.0,
        0.0, 1.0, 1.0, 1.0,    0.75, -0.0, 1.0,  -0.0,
        1.0, 1.0, 1.0, 0.6667, 0.75, -0.0, 1.0,  -0.0,
        1.0, 1.0, 1.0, 0.6667, 0.75, -0.0, -0.0, 1.0,
        0.0, 1.0, 1.0, 0.6667, 1.0,  -0.0, -0.0, 1.0,
        0.0, 0.0, 1.0, 0.3333, 1.0,  -0.0, -0.0, 1.0,
        0.0, 1.0, 1.0, 0.6667, 0.0,  -1.0, -0.0, -0.0,
        0.0, 1.0, 0.0, 0.6667, 0.25, -1.0, -0.0, -0.0,
        0.0, 0.0, 0.0, 0.3333, 0.25, -1.0, -0.0, -0.0,
        1.0, 0.0, 0.0, 0.3333, 0.5,  -0.0, -1.0, -0.0,
        1.0, 0.0, 1.0, 0.3333, 0.75, -0.0, -1.0, -0.0,
        0.0, 0.0, 1.0, -0.0,   0.75, -0.0, -1.0, -0.0,
        1.0, 1.0, 0.0, 0.6667, 0.5,  1.0,  -0.0, -0.0,
        1.0, 1.0, 1.0, 0.6667, 0.75, 1.0,  -0.0, -0.0,
        1.0, 0.0, 1.0, 0.3333, 0.75, 1.0,  -0.0, -0.0,
        0.0, 1.0, 0.0, 0.6667, 0.25, -0.0, -0.0, -1.0,
        1.0, 1.0, 0.0, 0.6667, 0.5,  -0.0, -0.0, -1.0,
        1.0, 0.0, 0.0, 0.3333, 0.5,  -0.0, -0.0, -1.0,
    };

    pub var indices = [_]u32{
        0,  1,  2,
        3,  4,  5,
        6,  7,  8,
        9,  10, 11,
        12, 13, 14,
        15, 16, 17,
        18, 19, 20,
        21, 22, 23,
        24, 25, 26,
        27, 28, 29,
        30, 31, 32,
        33, 34, 35,
    };
};

pub fn makeCube(drawing: *Drawing(.spatial), pos: Vec3, transform: *Mat4) !SpatialMesh {
    var mesh = try SpatialMesh.init(drawing, pos, transform, try graphics.Shader.setupShader("shaders/cube/vertex.glsl", "shaders/cube/fragment.glsl"));
    mesh.drawing.bindVertex(&Cube.vertices, &Cube.indices);
    return mesh;
}

pub const SpatialMesh = struct {
    drawing: *Drawing(.spatial),
    pos: Vec3,
    transform: *Mat4,

    pub fn initUniform(self: *SpatialMesh) !void {
        try self.drawing.addUniformVec3("pos", &self.pos);
    }

    pub fn update(self: *SpatialMesh) void {
        try self.drawing.addUniformMat4("transform", self.transform);
    }

    pub fn init(drawing: *Drawing(.spatial), pos: Vec3, transform: *Mat4, shader: u32) !SpatialMesh {
        drawing.* = graphics.Drawing(.spatial).init(shader);

        try drawing.addUniformMat4("transform", transform);

        return SpatialMesh{
            .drawing = drawing,
            .pos = pos,
            .transform = transform,
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
            v[0].pos[0], v[0].pos[1], v[0].pos[2], v[0].uv[0], v[0].uv[1], v[0].norm[0], v[0].norm[1], v[0].norm[2],
            v[1].pos[0], v[1].pos[1], v[1].pos[2], v[1].uv[0], v[1].uv[1], v[1].norm[0], v[1].norm[1], v[1].norm[2],
            v[2].pos[0], v[2].pos[1], v[2].pos[2], v[2].uv[0], v[2].uv[1], v[2].norm[0], v[2].norm[1], v[2].norm[2],
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

    const SpatialFormat = struct {
        vert: [:0]const u8,
        frag: [:0]const u8,
        transform: *Mat4,
        pos: Vec3 = .{ 0, 0, 0 },
    };

    pub fn toSpatial(self: MeshBuilder, drawing: *Drawing(.spatial), comptime format: SpatialFormat) !SpatialMesh {
        _ = self;
        return try SpatialMesh.init(
            drawing,
            format.pos,
            format.transform,
            try graphics.Shader.setupShader(format.vert, format.frag),
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

const fs = 15;

pub fn bdfToRgba(res: []bool) ![fs * fs]img.color.Rgba32 {
    var buf: [fs * fs]img.color.Rgba32 = undefined;
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
    pos: Vec3,

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
                const char_x = j % bdf.width;
                const char_y = @divFloor(j, bdf.width);
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
        var x_int: u32 = 0;

        var utf8 = (try std.unicode.Utf8View.init(text)).iterator();

        var is_start = true;

        while (utf8.nextCodepoint()) |c| : (x_int += 1) {
            const count_float: f32 = @floatFromInt(self.bdf.map.items.len);
            const size: u32 = @intFromFloat(@ceil(@sqrt(count_float)));
            const size_f: f32 = @ceil(@sqrt(count_float));

            for (self.bdf.map.items, 0..) |search, i| {
                if (search[0] == c) {
                    if (!is_start) {
                        const bbx_width: f32 = @floatFromInt(search[2] + 2);
                        const width: f32 = @floatFromInt(self.bdf.width);
                        x += bbx_width / width + 2 / width;
                    } else {
                        is_start = false;
                    }

                    const atlas_x: f32 = @floatFromInt(i % size);
                    const atlas_y: f32 = @floatFromInt(@divFloor(i, size) + 1);

                    //std.debug.print("coords {} {d} {d} {d:.4} {d:.4}\n", .{ c, i, size, atlas_x, atlas_y });

                    const c_vert = [_]f32{
                        x,     0, 0, atlas_x,     size_f - atlas_y,     0, 0, 0,
                        x + 1, 0, 0, atlas_x + 1, size_f - atlas_y,     0, 0, 0,
                        x + 1, 1, 0, atlas_x + 1, size_f - atlas_y + 1, 0, 0, 0,
                        x,     1, 0, atlas_x,     size_f - atlas_y + 1, 0, 0, 0,
                    };

                    const start: u32 = x_int * 4;

                    try indices.append(start);
                    try indices.append(start + 1);
                    try indices.append(start + 2);
                    try indices.append(start);
                    try indices.append(start + 2);
                    try indices.append(start + 3);

                    inline for (c_vert) |val| {
                        try vertices.append(val);
                    }
                    break;
                }
            }
        }

        self.drawing.bindVertex(vertices.items, indices.items);
    }

    pub fn deinit(self: *Text) void {
        common.allocator.free(self.atlas.data);
    }

    pub fn initUniform(self: *Text) !void {
        try self.drawing.addUniformVec3("pos", &self.pos);
    }

    pub fn init(drawing: *Drawing(.spatial), bdf: BdfParse, pos: Vec3, text: []const u8) !Text {
        drawing.* = graphics.Drawing(.spatial).init(try graphics.Shader.setupShader("shaders/text/vertex.glsl", "shaders/text/fragment.glsl"));

        var atlas = try makeAtlas(bdf);

        try drawing.textureFromRgba(atlas.data, atlas.width, atlas.height);

        var res = Text{
            .bdf = bdf,
            .pos = pos,
            .drawing = drawing,
            .atlas = atlas,
        };
        try res.print(text);

        return res;
    }
};
