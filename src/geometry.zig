const math = @import("math");
const std = @import("std");

pub const parsing = @import("parsing");

pub const Vertex = struct {
    pos: math.Vec3,
    norm: math.Vec3,
    uv: math.Vec2,
    pub const Zero: Vertex = .{ .pos = .init(.{ 0, 0, 0 }), .norm = .init(.{ 0, 0, 0 }), .uv = .init(.{ 0, 0 }) };
};

pub const HalfEdge = struct {
    next: ?*HalfEdge,
    twin: ?*HalfEdge,

    // vertex idx
    idx: u32,
    // half-edge of incident face
    // face: ?*HalfEdge,

    pub fn initOn(other: *HalfEdge, ally: std.mem.Allocator, vert: u32) !*HalfEdge {
        if (other.twin != null) return error.NotYet;

        const new = try ally.create(HalfEdge);
        new.* = .{
            .next = null,
            .twin = other,
            .idx = vert,
        };

        other.twin = new;

        return new;
    }
};

pub const HalfGraph = struct {
    const Pair = struct { u32, u32 };

    edge_map: std.AutoHashMapUnmanaged(Pair, *HalfEdge),

    pub fn deinit(graph: *HalfGraph, ally: std.mem.Allocator) void {
        graph.edge_map.deinit(ally);
    }

    pub fn addTri(graph: *HalfGraph, ally: std.mem.Allocator, face: [3]u32) !void {
        // assert face >= 1
        var in_start = true;
        var previous_or: ?*HalfEdge = null;
        var first: *HalfEdge = undefined;

        for (face, 0..) |start, i| {
            const next_i = if (i + 1 >= face.len) 0 else i + 1;
            const end = face[next_i];

            const res = graph.getEdge(.{ start, end });
            const edge: *HalfEdge = blk: {
                if (res) |twin| {
                    break :blk try twin.initOn(ally, start);
                } else {
                    const new = try ally.create(HalfEdge);

                    new.* = .{
                        .next = null,
                        .twin = null,
                        .idx = start,
                    };

                    try graph.putEdge(ally, .{ start, end }, new);

                    break :blk new;
                }
            };

            if (previous_or) |previous| previous.next = edge;
            previous_or = edge;

            if (in_start) {
                first = edge;
                in_start = false;
            }
        }

        previous_or.?.next = first;
    }

    pub fn putEdge(graph: *HalfGraph, ally: std.mem.Allocator, pair: Pair, edge: *HalfEdge) !void {
        return graph.edge_map.put(ally, if (pair[0] > pair[1]) pair else .{ pair[1], pair[0] }, edge);
    }

    pub fn getEdge(graph: HalfGraph, pair: Pair) ?*HalfEdge {
        return graph.edge_map.get(if (pair[0] > pair[1]) pair else .{ pair[1], pair[0] });
    }
};

test {
    // a graph needs an arena to be properly deinited
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const ally = arena.allocator();

    var graph: HalfGraph = .{ .edge_map = .empty };
    defer graph.deinit(ally);

    //graph.addVertices(&.{
    //    .{ 1.0, 4.0, 0.0 },
    //    .{ 3.0, 4.0, 0.0 },
    //    .{ 0.0, 2.0, 0.0 },
    //    .{ 2.0, 2.0, 0.0 },
    //});
    try graph.addTri(ally, .{ 0, 2, 3 });
    try graph.addTri(ally, .{ 0, 3, 1 });

    const edge = graph.getEdge(.{ 0, 3 });

    try std.testing.expect(edge.?.idx == 3);
    try std.testing.expect(edge.?.next.?.idx == 0);

    try std.testing.expect(edge.?.twin.?.idx == 0);
    try std.testing.expect(edge.?.twin.?.next.?.idx == 3);
}
