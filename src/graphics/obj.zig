const std = @import("std");
const builtin = @import("builtin");
const math = @import("math");

const geometry = @import("geometry");
const graphics = @import("graphics.zig");
const MeshBuilder = graphics.MeshBuilder;
const Vertex = geometry.Vertex;

pub var gpa = std.heap.GeneralPurposeAllocator(.{
    .stack_trace_frames = 1000,
}){};
pub const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

pub const ObjParse = struct {
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !ObjParse {
        return ObjParse{ .allocator = alloc };
    }

    pub fn parse(self: *ObjParse, path: [:0]const u8) !MeshBuilder {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [4096]u8 = undefined;

        const alloc = self.allocator;

        var vertices = std.ArrayList(math.Vec3).init(alloc);
        var norms = std.ArrayList(math.Vec3).init(alloc);
        var uvs = std.ArrayList(math.Vec2).init(alloc);
        defer vertices.deinit();
        defer norms.deinit();
        defer uvs.deinit();

        var mesh = try MeshBuilder.init(self.allocator);

        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var spaces = std.mem.splitAny(u8, line, " ");
            const identity = spaces.next() orelse return error.InvalidLine;
            if (std.mem.eql(u8, identity, "f")) {
                var face: [3]Vertex = undefined;
                var i: usize = 0;
                var rolled_over = false;

                while (spaces.next()) |element| {
                    if (element.len < 3) continue;

                    if (rolled_over) face[1] = face[2];

                    var slashes = std.mem.splitAny(u8, element, "/");

                    const vert_id = slashes.next() orelse return error.InvalidFace;
                    const uv_id_or = slashes.next();
                    const norm_id_or = slashes.next();

                    face[i].pos = vertices.items[try std.fmt.parseInt(usize, vert_id, 10) - 1];
                    face[i].norm = blk: {
                        if (norm_id_or) |norm_id| {
                            if (norm_id.len != 0) {
                                break :blk norms.items[try std.fmt.parseInt(usize, norm_id, 10) - 1];
                            }
                        }
                        break :blk math.Vec3.init(.{ 0, 0, 0 });
                    };
                    face[i].uv = blk: {
                        if (uv_id_or) |uv_id| {
                            if (uv_id.len != 0) {
                                break :blk uvs.items[try std.fmt.parseInt(usize, uv_id, 10) - 1];
                            }
                        }
                        break :blk math.Vec2.init(.{ 0, 0 });
                    };

                    if (i == 2) {
                        try mesh.addTri(face);
                        rolled_over = true;
                    } else {
                        i += 1;
                    }
                }
            } else if (std.mem.eql(u8, identity, "v")) {
                const x_str = spaces.next() orelse return error.InvalidVertex;
                const y_str = spaces.next() orelse return error.InvalidVertex;
                const z_str = spaces.next() orelse return error.InvalidVertex;

                const x = try std.fmt.parseFloat(f32, x_str);
                const y = try std.fmt.parseFloat(f32, y_str);
                const z = try std.fmt.parseFloat(f32, z_str);

                try vertices.append(math.Vec3.init(.{ x, y, z }));
            } else if (std.mem.eql(u8, identity, "vn")) {
                const x_str = spaces.next() orelse return error.InvalidVertex;
                const y_str = spaces.next() orelse return error.InvalidVertex;
                const z_str = spaces.next() orelse return error.InvalidVertex;

                const x = try std.fmt.parseFloat(f32, x_str);
                const y = try std.fmt.parseFloat(f32, y_str);
                const z = try std.fmt.parseFloat(f32, z_str);

                try norms.append(math.Vec3.init(.{ x, y, z }));
            } else if (std.mem.eql(u8, identity, "vt")) {
                const u_str = spaces.next() orelse return error.InvalidUv;
                const v_str = spaces.next() orelse return error.InvalidUv;

                const u = try std.fmt.parseFloat(f32, u_str);
                const v = try std.fmt.parseFloat(f32, v_str);

                try uvs.append(math.Vec2.init(.{ u, v }));
            }
        }

        return mesh;
    }
};

pub fn main() !void {
    var obj = try ObjParse.init(@import("common").allocator);
    std.debug.print("{}\n", .{(try obj.parse("resources/camera.obj")).indices.items.len});
}
