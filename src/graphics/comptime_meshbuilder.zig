const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("graphics.zig");
const common = @import("common");

const BdfParse = @import("parsing").BdfParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const SpatialPipeline = graphics.SpatialPipeline;
const glfw = graphics.glfw;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub fn ComptimeMeshBuilder(list: anytype) struct { [@typeInfo(@TypeOf(list)).Struct.fields.len * 8]f32, [@typeInfo(@TypeOf(list)).Struct.fields.len / 4 * 6]u32 } {
    const len = list.len;
    var vert_buff: [len * 8]f32 = undefined;
    var ind_buff: [len / 4 * 6]u32 = undefined;

    inline for (list, 0..) |vert, i| {
        vert_buff[i * 8] = vert.pos[0];
        vert_buff[i * 8 + 1] = vert.pos[1];
        vert_buff[i * 8 + 2] = vert.pos[2];

        vert_buff[i * 8 + 3] = vert.uv[0];
        vert_buff[i * 8 + 4] = vert.uv[1];
        vert_buff[i * 8 + 5] = vert.norm[0];

        vert_buff[i * 8 + 6] = vert.norm[1];
        vert_buff[i * 8 + 7] = vert.norm[2];
    }

    for (0..len / 4) |i_in| {
        const i: u32 = @intCast(i_in);
        ind_buff[i * 6] = i * 4;
        ind_buff[i * 6 + 1] = i * 4 + 1;
        ind_buff[i * 6 + 2] = i * 4 + 2;

        ind_buff[i * 6 + 3] = i * 4 + 2;
        ind_buff[i * 6 + 4] = i * 4 + 3;
        ind_buff[i * 6 + 5] = i * 4;
    }

    return .{ vert_buff, ind_buff };
}
