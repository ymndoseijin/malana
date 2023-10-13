const std = @import("std");

const ui = @import("ui");
const graphics = ui.graphics;
const Vec3 = ui.Vec3;
const Pga = ui.geometry.Pga;
const Point = Pga.Point;
const Vertex = ui.Vertex;
const common = ui.common;

var state: *ui.display.State = undefined;

var ray_mesh: LineMesh = undefined;
var cam_ray: Pga.Line.Type = undefined;

fn key_down(keys: []const bool, mods: i32, dt: f32) !void {
    if (keys[graphics.glfw.GLFW_KEY_Q]) {
        state.main_win.alive = false;
    }
    if (keys[graphics.glfw.GLFW_KEY_U]) {
        const ray = state.cam.getRay();
        ray_mesh.update(ray, .{ .r_x = 1, .r_y = 1 });
        cam_ray = ray;
    }

    try state.cam.spatialMove(keys, mods, dt, &state.cam.move, graphics.elems.Camera.DefaultSpatial);
}

const LineDescription = struct {
    r_x: f32,
    r_y: f32,
};

const PointDescription = struct {
    color: Vec3,
    border_color: Vec3,
    r_x: f32,
    r_y: f32,
    border_r: f32,
    z_index: f32,
};

const LineMesh = struct {
    mesh: *graphics.Drawing(graphics.LinePipeline),

    pub fn init() !LineMesh {
        var line = try state.scene.new(.line);
        line.* = graphics.Drawing(graphics.LinePipeline).init(
            try graphics.Shader.setupShader(
                @embedFile("shaders/line/vertex.glsl"),
                @embedFile("shaders/line/fragment.glsl"),
            ),
        );
        try state.cam.linkDrawing(line);
        return .{
            .mesh = line,
        };
    }

    pub fn update(self: LineMesh, l: anytype, desc: LineDescription) void {
        const plane_a = Point.create(.{ desc.r_x, 0, 0 }).regressive(Point.create(.{ desc.r_x, 1, 0 })).regressive(Point.create(.{ desc.r_x, 0, 1 }));
        const plane_b = Point.create(.{ 0, 0, desc.r_y }).regressive(Point.create(.{ 0, 1, desc.r_y })).regressive(Point.create(.{ 1, 0, desc.r_y }));

        const p1 = Point.get(l.wedge(plane_a));
        const p2 = Point.get(l.wedge(plane_b));

        const buff = [_]f32{
            p1[0], p1[1], p1[2],
            0.0,   0.0,   1.0,
            p2[0], p2[1], p2[2],
            0.0,   0.0,   1.0,
        };
        self.mesh.bindVertex(&buff, &.{ 0, 1 });
    }
};

const PointMesh = struct {
    mesh: *graphics.Drawing(graphics.FlatPipeline),

    pub fn init() !PointMesh {
        var mesh = try state.flat_scene.new(.flat);
        mesh.* = graphics.Drawing(graphics.FlatPipeline).init(
            try graphics.Shader.setupShader(
                @embedFile("shaders/circle/vertex.glsl"),
                @embedFile("shaders/circle/fragment.glsl"),
            ),
        );
        //try state.cam.linkDrawing(mesh);

        return .{
            .mesh = mesh,
        };
    }

    pub fn update(self: PointMesh, p: anytype, desc: PointDescription) void {
        const width: f32 = @floatFromInt(state.main_win.current_width);
        const height: f32 = @floatFromInt(state.main_win.current_height);

        const radius = .{ desc.r_x / width, desc.r_y / height };

        self.mesh.setUniformVec3("color", desc.color);
        self.mesh.setUniformVec3("border_color", desc.border_color);
        self.mesh.setUniformFloat("border_r", desc.border_r);

        var p_v: Vec3 = Point.get(p);

        var w_coords: @Vector(4, f32) = state.cam.transform_mat.dot(@as([3]f32, p_v - state.cam.move) ++ .{0});
        w_coords /= @splat(w_coords[3]);
        var coords: Vec3 = @as([4]f32, w_coords)[0..3].*;
        coords[2] = desc.z_index;

        const v1 = @as([3]f32, coords - Vec3{ -radius[0], -radius[1], 0 }) ++ .{ 0, 0 };
        const v2 = @as([3]f32, coords - Vec3{ -radius[0], radius[1], 0 }) ++ .{ 0, 1 };
        const v3 = @as([3]f32, coords - Vec3{ radius[0], radius[1], 0 }) ++ .{ 1, 1 };
        const v4 = @as([3]f32, coords - Vec3{ radius[0], -radius[1], 0 }) ++ .{ 1, 0 };

        self.mesh.bindVertex(&(v1 ++ v2 ++ v3 ++ v4), &.{ 0, 1, 3, 1, 2, 3 });
    }
};

const Motor = Pga.Blades.Types[22];

fn applyMotor(m: Motor, p: anytype) @TypeOf(p) {
    return m.mul(p).mul(m.reverse()).toType(@TypeOf(p));
}

const PlaneMesh = struct {
    mesh: graphics.SpatialMesh,

    pub fn init() !PlaneMesh {
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

        return .{
            .mesh = mesh,
        };
    }

    pub fn update(self: PlaneMesh, p: anytype) void {
        const radius = 1;

        const ground = Point.create(.{ 0, 0, 0 }).regressive(Point.create(.{ 1, 0, 0 })).regressive(Point.create(.{ 0, 0, 1 }));
        const motor = p.normalized().mul(ground).sqrt();

        var a = applyMotor(motor, Point.create(.{ -radius, 0, -radius }));
        var b = motor.mul(Point.create(.{ -radius, 0, radius })).mul(motor.reverse());
        var c = motor.mul(Point.create(.{ radius, 0, radius })).mul(motor.reverse());
        var d = motor.mul(Point.create(.{ radius, 0, -radius })).mul(motor.reverse());

        //const center = Point.get(Point.create(.{ 0, 0, 0 }).regressive(Point.create(.{ 0, 1, 0 })).wedge(p));

        //const norm = math.Vec3Utils.norm(Point.get(p.hodge()));
        const norm = .{ 0, 0, 0 };

        const v1 = Vertex{
            .pos = Point.get(a),
            .norm = norm,
            .uv = .{ 0, 0 },
        };
        const v2 = Vertex{
            .pos = Point.get(b),
            .norm = norm,
            .uv = .{ 0, 1 },
        };
        const v3 = Vertex{
            .pos = Point.get(c),
            .norm = norm,
            .uv = .{ 1, 1 },
        };
        const v4 = Vertex{
            .pos = Point.get(d),
            .norm = norm,
            .uv = .{ 1, 0 },
        };

        var res = graphics.ComptimeMeshBuilder(.{ v1, v2, v3, v4 });

        self.mesh.drawing.bindVertex(&res[0], &res[1]);
    }
};

pub fn main() !void {
    defer _ = common.gpa_instance.deinit();

    state = try ui.display.State.init();
    defer state.deinit();

    var text = try graphics.elems.Text.init(
        try state.scene.new(.spatial),
        state.bdf,
        .{ 0, 20, 0 },
    );
    defer text.deinit();

    try text.initUniform();

    state.key_down = key_down;

    var plane = try PlaneMesh.init();

    var o_mesh = try PointMesh.init();
    var b_mesh = try PointMesh.init();
    var c_mesh = try PointMesh.init();

    try graphics.elems.Grid(&state.scene, &state.cam);
    try graphics.elems.Axis(&state.scene, &state.cam);

    //var cam_plane = try PlaneMesh.init();
    ray_mesh = try LineMesh.init();
    var cam_point = try PointMesh.init();
    cam_ray = state.cam.getRay();

    while (state.main_win.alive) {
        try state.updateEvents();

        const O = Point.create(.{ 0, @floatCast(-1 + state.time / 5), 0 });
        const C = Point.create(.{ 1, 0, 1 });
        const B = Point.create(.{ -1, 0, 1 });

        var OCB = O.regressive(C).regressive(B);

        plane.update(OCB);
        o_mesh.update(O, .{
            .color = .{ 1, 1, 0 },
            .border_color = .{ 1, 0, 0 },
            .r_x = 50,
            .r_y = 50,
            .border_r = 0.9,
            .z_index = -0.1,
        });
        b_mesh.update(B, .{
            .color = .{ 0, 1, 0 },
            .border_color = .{ 1, 0, 0 },
            .r_x = 50,
            .r_y = 50,
            .border_r = 0.9,
            .z_index = -0.2,
        });
        c_mesh.update(C, .{
            .color = .{ 0, 0, 1 },
            .border_color = .{ 1, 0, 0 },
            .r_x = 50,
            .r_y = 50,
            .border_r = 0.9,
            .z_index = -0.3,
        });

        cam_point.update(cam_ray.wedge(OCB), .{
            .color = .{ 1, 0, 1 },
            .border_color = .{ 1, 0, 0 },
            .r_x = 50,
            .r_y = 50,
            .border_r = 0.9,
            .z_index = -0.4,
        });
        //cam_plane.update(cam_p);

        try text.printFmt("{d:.4} {d:.1}", .{ state.cam.move, 1 / state.dt });
        try state.render();
    }
}
