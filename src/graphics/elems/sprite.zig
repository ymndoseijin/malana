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

const SpriteInfo = struct {
    path: ?[]const u8 = null,
    rgba: ?graphics.Image = null,
    shaders: ?[2][:0]const u8 = null,
};

pub const Sprite = struct {
    pub fn init(scene: anytype, info: SpriteInfo) !Sprite {
        var drawing = try scene.new(graphics.FlatPipeline);

        const vert, const frag = if (info.shaders) |pair| pair else .{ @embedFile("shaders/sprite/vertex.glsl"), @embedFile("shaders/sprite/fragment.glsl") };
        var shader = try graphics.Shader.setupShader(vert, frag);

        drawing.* = graphics.Drawing(graphics.FlatPipeline).init(shader);

        var tex = graphics.Texture.init(.{ .mag_filter = .linear, .min_filter = .mipmap, .texture_type = .flat });

        if (info.path) |path| {
            try tex.setFromPath(path);
        } else if (info.rgba) |data| {
            try tex.setFromRgba(data, true);
        }
        try drawing.addTexture(tex);

        const w: f32 = @floatFromInt(tex.width);
        const h: f32 = @floatFromInt(tex.height);

        drawing.shader.setUniformMat3("transform", Mat3.identity());

        drawing.bindVertex(&.{
            .{ 0, 0, 1, 0, 0 },
            .{ w, 0, 1, 1, 0 },
            .{ w, h, 1, 1, 1 },
            .{ 0, h, 1, 0, 1 },
        }, &.{ 0, 1, 2, 2, 3, 0 });

        drawing.shader.setUniformMat3("transform", Mat3.identity());
        drawing.shader.setUniformFloat("opacity", 1.0);

        return Sprite{
            .drawing = drawing,
            .width = w,
            .height = h,
            .opacity = 1.0,
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

    pub fn setOpacity(self: *Sprite, opacity: f32) void {
        self.opacity = opacity;
        self.drawing.shader.setUniformFloat("opacity", opacity);
    }

    width: f32,
    height: f32,
    opacity: f32,
    transform: graphics.Transform2D,

    drawing: *Drawing(graphics.FlatPipeline),
};
