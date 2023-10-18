const std = @import("std");
const math = @import("math");
const gl = @import("gl");
const img = @import("img");
const geometry = @import("geometry");
const graphics = @import("../graphics.zig");
const common = @import("common");

const BdfParse = @import("parsing").BdfParse;

const Mesh = geometry.Mesh;
const Vertex = geometry.Vertex;
const HalfEdge = geometry.HalfEdge;

const Drawing = graphics.Drawing;
const glfw = graphics.glfw;
const Mat3 = math.Mat3;
const Vec3 = math.Vec3;
const Vec3Utils = math.Vec3Utils;

pub const Sprite = struct {
    pub fn initRgba(drawing: *Drawing(graphics.FlatPipeline), data: anytype) !Sprite {
        var shader = try graphics.Shader.setupShader(@embedFile("shaders/sprite/vertex.glsl"), @embedFile("shaders/sprite/fragment.glsl"));

        drawing.* = graphics.Drawing(graphics.FlatPipeline).init(shader);

        const w: f32 = @floatFromInt(data.width);
        const h: f32 = @floatFromInt(data.height);

        drawing.bindVertex(&.{
            .{ 0, 0, 1, 0, 0 },
            .{ w, 0, 1, 1, 0 },
            .{ w, h, 1, 1, 1 },
            .{ 0, h, 1, 0, 1 },
        }, &.{ 0, 1, 2, 2, 3, 0 });

        drawing.shader.setUniformMat3("transform", Mat3.identity());
        const tex = graphics.Texture.init(.{ .mag_filter = .linear, .min_filter = .linear, .texture_type = .flat });
        try tex.setFromRgba(data, true);
        try drawing.addTexture(tex);

        return Sprite{
            .drawing = drawing,
            .width = w,
            .height = w,
            .transform = .{
                .scale = .{ 1, 1 },
                .rotation = .{ .angle = 0, .center = .{ w / 2, h / 2 } },
                .translation = .{ 0, 0 },
            },
        };
    }

    pub fn init(scene: anytype, path: []const u8) !Sprite {
        var drawing = try scene.new(graphics.FlatPipeline);

        var shader = try graphics.Shader.setupShader(@embedFile("shaders/sprite/vertex.glsl"), @embedFile("shaders/sprite/fragment.glsl"));

        drawing.* = graphics.Drawing(graphics.FlatPipeline).init(shader);

        const wi, const hi = try drawing.textureFromPath(path);

        const w: f32 = @floatFromInt(wi);
        const h: f32 = @floatFromInt(hi);

        drawing.bindVertex(&.{
            .{ 0, 0, 1, 0, 0 },
            .{ w, 0, 1, 1, 0 },
            .{ w, h, 1, 1, 1 },
            .{ 0, h, 1, 0, 1 },
        }, &.{ 0, 1, 2, 2, 3, 0 });

        drawing.shader.setUniformMat3("transform", Mat3.identity());

        return Sprite{
            .drawing = drawing,
            .width = w,
            .height = h,
            .transform = .{
                .scale = .{ 1, 1 },
                .rotation = .{ .angle = 0, .center = .{ w / 2, h / 2 } },
                .translation = .{ 0, 0 },
            },
        };
    }

    pub fn textureFromPath(self: *Sprite, path: []const u8) !Sprite {
        const wi, const hi = try self.drawing.textureFromPath(path);

        const w: f32 = @floatFromInt(wi);
        const h: f32 = @floatFromInt(hi);

        self.drawing.bindVertex(&.{
            0, 0, 1, 0, 0,
            w, 0, 1, 1, 0,
            w, h, 1, 1, 1,
            0, h, 1, 0, 1,
        }, &.{ 0, 1, 2, 2, 3, 0 });

        self.width = w;
        self.height = h;
    }

    pub fn updateTransform(self: Sprite) void {
        self.drawing.shader.setUniformMat3("transform", math.transform2D(f32, self.transform.scale, self.transform.rotation, self.transform.translation));
    }

    width: f32,
    height: f32,
    transform: graphics.Transform2D,
    drawing: *Drawing(graphics.FlatPipeline),
};
