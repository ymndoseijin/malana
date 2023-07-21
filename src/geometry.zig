const math = @import("math");
const std = @import("std");
const testing = std.testing;

const Vec3 = math.Vec3;
const Vec2 = math.Vec2;

const Vec3Utils = math.Vec3Utils;
const Vec2Utils = math.Vec2Utils;

pub const Vertex = struct {
    pos: Vec3,
    norm: Vec3,
    uv: Vec2,
    pub const Zero = Vertex{ .pos = .{ 0, 0, 0 }, .norm = .{ 0, 0, 0 }, .uv = .{ 0, 0 } };
};

// potential footgun, face holds a pointer to vertices, so if you change it you might change it to other faces as well
pub const Face = struct {
    vertices: []*Vertex,

    pub fn init(alloc: std.mem.Allocator, vertices: []const *Vertex) !*Face {
        var face = try alloc.create(Face);
        face.vertices = try alloc.dupe(*Vertex, vertices);

        return face;
    }
};

pub const HalfEdge = struct {
    next: ?*HalfEdge,
    twin: ?*HalfEdge,

    vertex: *Vertex,
    face: *Face,

    pub fn makeTri(mut: *HalfEdge, allocator: std.mem.Allocator, tri: []const *Vertex) !void {
        var b = try allocator.create(HalfEdge);
        var c = try allocator.create(HalfEdge);

        mut.* = HalfEdge{
            .vertex = tri[0],
            .next = b,
            .twin = mut.twin, // temp
            .face = try Face.init(allocator, tri),
        };

        b.* = HalfEdge{
            .vertex = tri[1],
            .next = c,
            .twin = null,
            .face = try Face.init(allocator, tri),
        };
        c.* = HalfEdge{
            .vertex = tri[2],
            .next = mut,
            .twin = null,
            .face = try Face.init(allocator, tri),
        };
    }

    pub fn halfVert(self: HalfEdge) Vertex {
        if (self.next) |next_edge| {
            var a = self.vertex;
            var b = next_edge.vertex;
            const pos = Vec3Utils.interpolate(a.pos, b.pos, 0.5);
            const norm = Vec3Utils.interpolate(a.norm, b.norm, 0.5);
            const uv = Vec2Utils.interpolate(a.uv, b.uv, 0.5);
            return Vertex{ .pos = pos, .uv = uv, .norm = norm };
        }
        return Vertex.Zero;
    }
};

pub const Mesh = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(alloc: std.mem.Allocator) Mesh {
        var arena = std.heap.ArenaAllocator.init(alloc);
        return Mesh{
            .arena = arena,
        };
    }

    pub fn deinit(self: *Mesh) void {
        self.arena.deinit();
    }

    pub fn syncEdges(a: *HalfEdge, b: *HalfEdge, twins: [2]*HalfEdge) void {
        if (twins[0].vertex == a.vertex) {
            twins[0].twin = a;
            a.twin = twins[0];

            twins[1].twin = b;
            b.twin = twins[1];
        } else {
            twins[1].twin = a;
            a.twin = twins[1];

            twins[0].twin = b;
            b.twin = twins[0];
        }
    }

    pub const SubdivideEdge = enum {
        fucked,
        ok,
    };

    pub const SubdivideValue = struct { SubdivideEdge, [2]*HalfEdge };

    // only for triangles rn
    pub fn subdivide(self: *Mesh, half_edge: *HalfEdge, map: *std.AutoHashMap(?*HalfEdge, [2]*HalfEdge)) !void {
        const allocator = self.arena.allocator();
        var face: [3]*HalfEdge = .{ half_edge, half_edge.next.?, half_edge.next.?.next.? };

        inline for (face) |elem| {
            if (map.get(elem)) |_| {
                return;
            }
        }

        var a_vert: *Vertex = undefined;
        var b_vert: *Vertex = undefined;
        var c_vert: *Vertex = undefined;

        var new_verts = .{ &a_vert, &b_vert, &c_vert };

        inline for (new_verts, 0..) |vert, i| {
            vert.* = try allocator.create(Vertex);
            vert.*.* = face[i].halfVert();
        }

        var inner_triangle = try allocator.create(HalfEdge);
        try inner_triangle.makeTri(allocator, &[_]*Vertex{ a_vert, b_vert, c_vert });

        try face[0].makeTri(allocator, &[_]*Vertex{ face[0].vertex, a_vert, c_vert });
        try face[1].makeTri(allocator, &[_]*Vertex{ face[1].vertex, b_vert, a_vert });
        try face[2].makeTri(allocator, &[_]*Vertex{ face[2].vertex, c_vert, b_vert });

        try map.put(face[0], .{ face[0], face[1].next.?.next.? });
        try map.put(face[1], .{ face[1], face[2].next.?.next.? });
        try map.put(face[2], .{ face[2], face[0].next.?.next.? });

        try map.put(face[0].next.?.next.?, .{ face[2], face[0].next.?.next.? });
        try map.put(face[1].next.?.next.?, .{ face[0], face[1].next.?.next.? });
        try map.put(face[2].next.?.next.?, .{ face[1], face[2].next.?.next.? });

        const faces_left = .{ face[0], face[1], face[2] };
        const faces_right = .{ face[1], face[2], face[0] };

        inline for (faces_left, faces_right) |left, right| {
            if (map.get(left.twin)) |twins| {
                Mesh.syncEdges(left, right.next.?.next.?, .{ twins[0], twins[1] });
            } else {
                if (left.twin) |twin| {
                    try self.subdivide(twin, map);
                }
            }
        }

        inner_triangle.next.?.next.?.twin = face[0].next;
        face[0].next.?.twin = inner_triangle.next.?.next;

        inner_triangle.next.?.twin = face[2].next;
        face[2].next.?.twin = inner_triangle.next;

        inner_triangle.twin = face[1].next;
        face[1].next.?.twin = inner_triangle;
    }

    const Pair = struct { usize, usize };
    const Format = struct {
        pos_offset: usize,
        norm_offset: usize,
        uv_offset: usize,
        length: usize,
    };

    // this merges the vertices with the same pos rather than doing it properly
    pub fn makeFrom(self: *Mesh, vertices: []const f32, in_indices: []const u32, comptime format: Format, comptime n: comptime_int) !*HalfEdge {
        const allocator = self.arena.allocator();

        var indices = try allocator.dupe(u32, in_indices);

        var converted = std.ArrayList(Vertex).init(self.arena.allocator());
        defer converted.deinit();

        for (0..@divExact(vertices.len, format.length)) |i| {
            var pos: Vec3 = .{
                vertices[i * format.length + format.pos_offset],
                vertices[i * format.length + format.pos_offset + 1],
                vertices[i * format.length + format.pos_offset + 2],
            };

            var norm: Vec3 = .{
                vertices[i * format.length + format.norm_offset],
                vertices[i * format.length + format.norm_offset + 1],
                vertices[i * format.length + format.norm_offset + 2],
            };

            var uv: Vec2 = .{
                vertices[i * format.length + format.uv_offset],
                vertices[i * format.length + format.uv_offset + 1],
            };

            try converted.append(.{
                .pos = pos,
                .norm = norm,
                .uv = uv,
            });
        }

        var res = self.makeNgon(converted.items, indices, n);
        return res;
    }

    pub fn makeNgon(self: *Mesh, in_vert: []const Vertex, indices: []const u32, comptime n: comptime_int) !*HalfEdge {
        const allocator = self.arena.allocator();

        var vertices = try allocator.dupe(Vertex, in_vert);

        var face = try allocator.create(Face);
        face.vertices = try allocator.alloc(*Vertex, n);
        var face_i: usize = 0;

        var half_edge: *HalfEdge = undefined;
        var start: *HalfEdge = undefined;

        var first_face: *HalfEdge = undefined;
        var first_index: usize = undefined;

        var begin = true;

        var seen = std.ArrayList(struct { [2]Vec3, *HalfEdge }).init(allocator);
        defer seen.deinit();

        for (indices, 0..) |index, i| {
            var current_vertex = &vertices[index];

            var next_index: ?usize = if (i < indices.len - 1) indices[i + 1] else null;
            var next_or: ?*Vertex = if (next_index) |id| &vertices[id] else null;

            var previous_edge = half_edge;
            half_edge = try allocator.create(HalfEdge);

            half_edge.vertex = current_vertex;

            half_edge.face = face;

            half_edge.next = null;
            half_edge.twin = null;

            face.vertices[face_i] = current_vertex;
            if (face_i == 0) {
                first_face = half_edge;
                first_index = index;
            } else {
                previous_edge.next = half_edge;
            }

            if (face_i == n - 1) {
                half_edge.next = first_face;
                next_or = &vertices[first_index];

                previous_edge.next = half_edge;

                face = try allocator.create(Face);
                face.vertices = try allocator.alloc(*Vertex, n);

                face_i = 0;
            } else {
                face_i += 1;
            }

            if (begin) {
                begin = false;
                start = half_edge;
            }

            if (next_or) |next_vertex| {
                var a = [2]Vec3{ current_vertex.pos, next_vertex.pos };

                var not_found = true;
                for (seen.items) |candidate| {
                    var b = candidate[0];
                    if (@reduce(.And, a[0] == b[1]) and @reduce(.And, a[1] == b[0])) {
                        var half_twin = candidate[1];

                        if (half_twin.twin != null) {
                            return error.TooManyTwins;
                        }

                        half_twin.twin = half_edge;
                        half_edge.twin = half_twin;

                        not_found = false;

                        break;
                    }
                }

                if (not_found) {
                    try seen.append(.{ a, half_edge });
                }
            }
        }

        return start;
    }
};

pub fn main() !void {
    var mesh = Mesh.init(@import("common").allocator);
    defer mesh.deinit();

    var vertices = [_]Vertex{
        .{ .pos = .{ 0, 0, 0 } },
        .{ .pos = .{ 0, 1, 0 } },
        .{ .pos = .{ 0, 1, 1 } },
        .{ .pos = .{ 1, 1, 1 } },
    };

    var indices = [_]usize{ 0, 1, 2, 1, 2, 3 };

    std.debug.print("{}\n", .{try mesh.make(&vertices, &indices)});
}

test "half edge" {
    const ally = testing.allocator;
    var mesh = Mesh.init(ally);
    defer mesh.deinit();

    var vertices = [_]Vertex{
        .{ .pos = .{ 0, 0, 0 } },
        .{ .pos = .{ 0, 1, 0 } },
        .{ .pos = .{ 0, 1, 1 } },
        .{ .pos = .{ 1, 1, 1 } },
    };

    var indices = [_]usize{ 0, 1, 2, 1, 2, 3 };

    var edge: ?*HalfEdge = try mesh.make(&vertices, &indices);

    var i: usize = 0;
    while (edge) |actual| {
        std.debug.print("half edge at {}: {any:.4} {any:.4}\n", .{ i, actual.vertex.pos, actual.twin != null });
        edge = actual.next;
        i += 1;
    }
}
