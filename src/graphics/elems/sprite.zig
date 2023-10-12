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
    pub fn init(drawing: *Drawing(graphics.FlatPipeline), path: []const u8) !Sprite {
        var shader = try graphics.Shader.setupShader(@embedFile("shaders/sprite/vertex.glsl"), @embedFile("shaders/sprite/fragment.glsl"));

        var read_image = try img.Image.fromFilePath(common.allocator, path);
        defer read_image.deinit();

        var arr: []img.color.Rgba32 = undefined;
        switch (read_image.pixels) {
            .rgba32 => |data| {
                arr = data;
            },
            else => return error.InvalidImage,
        }

        var og = ImageTexture{
            .data = try common.allocator.alloc(Pixel, arr.len),
            .width = read_image.width,
            .height = read_image.height,
        };
        defer common.allocator.free(og.data);

        for (arr, 0..) |pix, i| {
            og.data[i].r = pix.r;
            og.data[i].g = pix.g;
            og.data[i].b = pix.b;
            og.data[i].a = pix.a;
        }

        drawing.* = graphics.Drawing(graphics.FlatPipeline).init(shader);

        const w: f32 = @floatFromInt(read_image.width);
        const h: f32 = @floatFromInt(read_image.height);

        drawing.bindVertex(&.{
            0, 0, 1, 0, 0,
            w, 0, 1, 1, 0,
            w, h, 1, 1, 1,
            0, h, 1, 0, 1,
        }, &.{ 0, 1, 2, 2, 3, 0 });

        try drawing.textureFromRgba(og.data, og.width, og.height);

        drawing.setUniformMat3("transform", Mat3.identity());

        return Sprite{
            .drawing = drawing,
            .transform = .{
                .scale = .{ 1, 1 },
                .rotation = .{ .angle = 0, .center = .{ w / 2, h / 2 } },
                .translation = .{ 0, 0 },
            },
        };
    }

    pub fn updateTransform(self: Sprite) void {
        self.drawing.setUniformMat3("transform", math.transform2D(f32, self.transform.scale, self.transform.rotation, self.transform.translation));
    }

    transform: graphics.Transform2D,
    drawing: *Drawing(graphics.FlatPipeline),
};

const Pixel = struct { r: u8, g: u8, b: u8, a: u8 };

const ImageTexture = struct {
    data: []Pixel,
    width: usize,
    height: usize,

    pub fn get(self: ImageTexture, x: usize, y: usize) Pixel {
        return self.data[self.width * y + x];
    }

    pub fn set(self: *ImageTexture, x: usize, y: usize, pix: Pixel) void {
        self.data[self.width * y + x] = pix;
    }
};
