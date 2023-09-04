const std = @import("std");
const display = @import("display.zig");

const math = @import("math");
const gl = @import("gl");
const common = @import("common");
const numericals = @import("numericals");
const geometry = @import("geometry");
const graphics = @import("graphics");

const Parsing = @import("parsing");

const zilliam = @import("zilliam");

const BdfParse = Parsing.BdfParse;
const ObjParse = graphics.ObjParse;
const VsopParse = Parsing.VsopParse;

const Pga = zilliam.PGA(f32, 3);
const Point = Pga.Point;

const Vertex = geometry.Vertex;

var state: *display.State = undefined;

fn key_down(keys: []const bool, mods: i32, dt: f32) !void {
    if (keys[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }

    try state.cam.spatialMove(keys, mods, dt, &state.cam.move, graphics.Camera.DefaultSpatial);
}

const Plane = struct {
    mesh: graphics.SpatialMesh,
    line: *graphics.Drawing(graphics.LinePipeline),

    pub fn init() !Plane {
        var mesh = try graphics.SpatialMesh.init(
            try state.scene.new(.spatial),
            .{ 0, 0, 0 },
            try graphics.Shader.setupShader(
                @embedFile("shaders/triangle/vertex.glsl"),
                @embedFile("shaders/triangle/fragment.glsl"),
            ),
        );
        try state.cam.linkDrawing(mesh.drawing);
        try mesh.initUniform();

        var line = try state.scene.new(.line);
        line.* = graphics.Drawing(graphics.LinePipeline).init(
            try graphics.Shader.setupShader(
                @embedFile("shaders/line/vertex.glsl"),
                @embedFile("shaders/line/fragment.glsl"),
            ),
        );
        try state.cam.linkDrawing(line);

        return .{
            .mesh = mesh,
            .line = line,
        };
    }

    pub fn update(self: Plane, p: anytype) void {
        const radius = 1;

        const a = Point.create(.{ -radius, 0, -radius }).regressive(Point.create(.{ -radius, 1, -radius }));
        const b = Point.create(.{ -radius, 0, radius }).regressive(Point.create(.{ -radius, 1, radius }));
        const c = Point.create(.{ radius, 0, radius }).regressive(Point.create(.{ radius, 1, radius }));
        const d = Point.create(.{ radius, 0, -radius }).regressive(Point.create(.{ radius, 1, -radius }));

        const center = Point.get(Point.create(.{ 0, 0, 0 }).regressive(Point.create(.{ 0, 1, 0 })).wedge(p));

        const norm = math.Vec3Utils.norm(Point.get(p.hodge())) + center;

        const v1 = Vertex{
            .pos = Point.get(a.wedge(p)),
            .norm = norm,
            .uv = .{ 0, 0 },
        };
        const v2 = Vertex{
            .pos = Point.get(b.wedge(p)),
            .norm = norm,
            .uv = .{ 0, 1 },
        };
        const v3 = Vertex{
            .pos = Point.get(c.wedge(p)),
            .norm = norm,
            .uv = .{ 1, 1 },
        };
        const v4 = Vertex{
            .pos = Point.get(d.wedge(p)),
            .norm = norm,
            .uv = .{ 1, 0 },
        };

        var res = graphics.ComptimeMeshBuilder(.{ v1, v2, v3, v4 });

        self.mesh.drawing.bindVertex(&res[0], &res[1]);

        const buff = [_]f32{
            center[0], center[1], center[2],
            0.0,       0.0,       1.0,
            norm[0],   norm[1],   norm[2],
            0.0,       0.0,       1.0,
        };
        self.line.bindVertex(&buff, &.{ 0, 1 });
    }
};

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    var bdf = try BdfParse.init();
    defer bdf.deinit();
    try bdf.parse("b12.bdf");

    try graphics.initGraphics();
    defer graphics.deinitGraphics();

    state = try display.State.init();
    defer state.deinit();

    //gl.cullFace(gl.FRONT);
    gl.enable(gl.BLEND);
    gl.lineWidth(2);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var text = try graphics.Text.init(
        try state.scene.new(.spatial),
        bdf,
        .{ 0, 0, 0 },
    );
    defer text.deinit();

    try text.initUniform();

    state.key_down = key_down;

    var plane = try Plane.init();

    try graphics.Grid(&state.scene, &state.cam);
    try graphics.Axis(&state.scene, &state.cam);

    while (state.main_win.alive) {
        try state.updateEvents();

        const O = Point.create(.{ 0, @floatCast(-1 + state.time / 5), 0 });
        const C = Point.create(.{ 1, 1, 1 });
        const B = Point.create(.{ -1, 1, 1 });

        const OCB = O.regressive(C).regressive(B);

        plane.update(OCB);

        try text.printFmt("{d:.4} {d:.1} いいの、吸っちゃっていいの？", .{ state.cam.move, 1 / state.dt });
        try state.render();
    }
}
