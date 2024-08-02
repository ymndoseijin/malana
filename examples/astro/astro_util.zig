const std = @import("std");
const ui = @import("ui");
const math = ui.math;
const parsing = ui.geometry.parsing;

const VsopParse = parsing.VsopParse;

const TAU = 6.28318530718;
const Vec3 = math.Vec(f64, 3);

pub const VsopPlanet = struct {
    vsop: VsopParse(3),
    orb_vsop: VsopParse(6),

    name: []const u8,
    pos: Vec3,

    pub fn deinit(self: *VsopPlanet, ally: std.mem.Allocator) void {
        self.vsop.deinit(ally);
        self.orb_vsop.deinit(ally);
    }

    pub fn update(self: *VsopPlanet, time: f64) void {
        const og_pos = Vec3.init(self.vsop.at((time - 2451545.0) / 365250.0));

        var venus_pos = Vec3.init(.{ og_pos.val[1], og_pos.val[2], og_pos.val[0] });

        venus_pos = math.rotationY(f64, TAU / 4.0).dot(venus_pos);
        self.pos = venus_pos;

        self.pos = self.pos.scale(10);
    }

    pub fn init(comptime name: []const u8, ally: std.mem.Allocator) !VsopPlanet {
        const actual = if (comptime std.mem.eql(u8, "ear", name)) "emb" else name;

        return .{
            .vsop = try VsopParse(3).init(ally, "vsop87/VSOP87C." ++ name),
            .orb_vsop = try VsopParse(6).init(ally, "vsop87/VSOP87." ++ actual),
            .pos = Vec3.init(.{ 0, 0, 0 }),
            .name = name,
        };
    }
};
