const math = @import("math.zig");
const std = @import("std");
const testing = std.testing;

const Vec3 = math.Vec3;

pub const Vertex = struct {
    pos: Vec3,
};

pub const Face = struct {
    vertices: []*Vertex,
};

pub const HalfEdge = struct {
    next: ?*HalfEdge,
    twin: ?*HalfEdge,

    vertex: *Vertex,
    face: *Face,
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

    // only for triangles rn
    //pub fn subdivide(self: *Mesh, half_edge: *HalfEdge) void {
    //}

    const Pair = struct { usize, usize };

    pub fn makeFrom(self: *Mesh, vertices: []const f32, in_indices: []const u32, comptime offset: usize, comptime length: usize, comptime n: comptime_int) !*HalfEdge {
        const allocator = self.arena.allocator();

        var indices = try allocator.dupe(u32, in_indices);

        var seen = std.ArrayList(struct { Vec3, usize }).init(self.arena.allocator());
        defer seen.deinit();

        var converted = std.ArrayList(Vertex).init(self.arena.allocator());
        defer converted.deinit();

        for (0..@divExact(vertices.len, length)) |i| {
            var pos: Vec3 = .{ vertices[i * length + offset], vertices[i * length + offset + 1], vertices[i * length + offset + 2] };

            var copy = false;
            for (seen.items) |candidate| {
                if (@reduce(.And, candidate[0] == pos)) {
                    std.debug.print("found!!!!!!!!!!!!!!!!!!!\n\n\n\n", .{});
                    copy = true;
                    for (indices) |*mut| {
                        if (mut.* == i) {
                            mut.* = @intCast(candidate[1]);
                            std.debug.print("changed {} and {d:.4} == {d:.4} to {}\n", .{ i, pos, candidate[0], candidate[1] });
                        }
                    }
                    break;
                }
            }
            if (!copy) {
                try seen.append(.{ pos, i });
            }

            try converted.append(.{ .pos = pos });
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

        var map = std.AutoHashMap(Pair, *HalfEdge).init(allocator);
        defer map.deinit();

        for (indices, 0..) |index, i| {
            var current_vertex = &vertices[index];
            var next_or: ?usize = if (i < indices.len - 1) indices[i + 1] else null;

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
                next_or = first_index;

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
                var key: Pair = if (index > next_vertex) .{ index, next_vertex } else .{ next_vertex, index };
                if (map.get(key)) |half_twin| {
                    if (half_twin.twin != null) {
                        return error.TooManyTwins;
                    }
                    half_twin.twin = half_edge;
                    half_edge.twin = half_twin;
                    std.debug.print("\nFound twin at {d:.4} {any:.4}\n", .{ half_twin.vertex.pos, half_twin.twin });
                } else {
                    //std.debug.print("adding twin candidate at {any} {any}\n", .{ key, half_edge });
                    try map.put(key, half_edge);
                }
            }
        }

        return start;
    }
};

pub fn main() !void {
    var mesh = Mesh.init(@import("common.zig").allocator);
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
