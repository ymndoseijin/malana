const std = @import("std");

const assert = std.debug.assert;

pub const color = @import("color.zig");
const sin = std.math.sin;
const cos = std.math.cos;

pub const Mat4 = Mat(f32, 4, 4);
pub const Mat3 = Mat(f32, 3, 3);

pub fn Vec(comptime T: type, comptime size: usize) type {
    return struct {
        const Vector = @Vector(size, T);
        const Array = [size]T;
        const VecN = @This();

        val: Array,

        pub fn init(arr: Array) VecN {
            return .{ .val = arr };
        }

        pub fn splat(s: T) VecN {
            return VecN.init(.{s} ** size);
        }

        pub fn add(a: VecN, b: VecN) VecN {
            return VecN.init(a.toSimd() + b.toSimd());
        }

        pub fn mul(a: VecN, b: VecN) VecN {
            return VecN.init(a.toSimd() * b.toSimd());
        }

        pub fn div(a: VecN, b: VecN) VecN {
            return VecN.init(a.toSimd() / b.toSimd());
        }

        pub fn scale(a: VecN, s: T) VecN {
            const sv: Vector = @splat(s);
            return VecN.init(a.toSimd() * sv);
        }

        pub fn toSimd(a: VecN) Vector {
            return a.val;
        }

        pub fn sub(a: VecN, b: VecN) VecN {
            return VecN.init(a.toSimd() - b.toSimd());
        }

        pub fn interpolate(a: Vector, b: Vector, x: T) Vector {
            const left: Vector = @splat(1 - x);
            const right: Vector = @splat(x);
            return left * a + b * right;
        }

        pub fn dot(a: VecN, b: VecN) T {
            return @reduce(.Add, a.toSimd() * b.toSimd());
        }

        pub fn length(a: VecN) T {
            return @sqrt(@reduce(.Add, a.toSimd() * a.toSimd()));
        }

        pub fn norm(a: VecN) VecN {
            return a.scale(1.0 / a.length());
        }

        pub fn proj(a: Vector, b: Vector) Vector {
            const factor: Vector = @splat(dot(b, a) / dot(a, a));
            return factor * a;
        }

        pub fn cross(a_in: Vec3, b_in: Vec3) Vec3 {
            const a = a_in.val;
            const b = b_in.val;
            return Vec3.init(.{ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] });
        }
        pub fn crossn(a: Vec3, b: Vec3) Vec3 {
            return Vec3.norm(Vec3.cross(a, b));
        }
    };
}

pub const Vec2 = Vec(f32, 2);
pub const Vec3 = Vec(f32, 3);
pub const Vec4 = Vec(f32, 4);

pub fn Mat(comptime T: type, comptime width: usize, comptime height: usize) type {
    return extern struct {
        pub const WIDTH: usize = width;
        pub const HEIGHT: usize = height;

        columns: [width][height]T,

        pub fn init(columns: [width][height]T) @This() {
            return @This(){ .columns = columns };
        }

        pub fn identity() @This() {
            comptime assert(width == height);

            var id = @This().zero();

            inline for (0..width) |i| {
                id.columns[i][i] = 1;
            }

            return id;
        }

        pub fn cast(from: @This(), comptime cw: usize, comptime ch: usize) Mat(T, cw, ch) {
            var res: [cw][ch]T = undefined;
            inline for (0..cw) |i| {
                inline for (0..ch) |j| {
                    if (i < width and j < height) {
                        res[i][j] = from.columns[i][j];
                    } else {
                        if (i != j) {
                            res[i][j] = 0;
                        } else {
                            res[i][j] = 1;
                        }
                    }
                }
            }

            return Mat(T, cw, ch).init(res);
        }

        pub fn scaling(in_vec: Vec(T, width)) @This() {
            const vec = in_vec.toSimd();
            var res: [width][height]T = undefined;
            inline for (0..width) |i| {
                inline for (0..height) |j| {
                    if (i != j) {
                        res[i][j] = 0;
                    } else {
                        res[i][j] = vec[i];
                    }
                }
            }
            return @This().init(res);
        }

        pub fn translation(in_vec: Vec(T, height - 1)) @This() {
            const vec = in_vec.toSimd();
            var res = identity();
            const arr: [height - 1]T = vec;
            inline for (arr, 0..) |vcolumn, i| {
                res.columns[width - 1][i] = vcolumn;
            }
            res.columns[width - 1][height - 1] = 1;
            return res;
        }

        pub fn zero() @This() {
            return @This().singleValue(0);
        }

        pub fn singleValue(default: T) @This() {
            return @This(){ .columns = .{.{default} ** height} ** width };
        }

        pub fn dot(self: @This(), in_vec: Vec(T, width)) Vec(T, width) {
            const vec = in_vec.toSimd();
            var res: @Vector(height, T) = undefined;
            inline for (0..width) |i| {
                var row: @Vector(width, T) = undefined;
                inline for (self.columns, 0..) |col, j| {
                    row[j] = col[i];
                }

                res[i] = @reduce(.Add, row * vec);
            }
            return Vec(T, width).init(res);
        }

        pub fn gramschmidt(self: @This()) @This() {
            var res: @This() = undefined;
            for (&res.columns, self.columns, 0..) |*res_column, vn, i| {
                res_column = vn;
                for (0..i) |j| {
                    res_column -= Vec(T, height).proj(res_column[j], vn);
                }
            }
            return res;
        }

        pub fn mul(self: @This(), other: anytype) Mat(T, @TypeOf(other).WIDTH, HEIGHT) {
            const R = @TypeOf(other);
            var res: Mat(T, R.WIDTH, HEIGHT) = undefined;
            inline for (other.columns, 0..) |prev_column, i| {
                var column: @Vector(HEIGHT, T) = @splat(0);

                inline for (0..width) |j| {
                    const mask = ([1]i32{@intCast(j)}) ** HEIGHT;
                    var vi = @shuffle(T, prev_column, undefined, mask);

                    vi = vi * self.columns[j];
                    column += vi;
                }

                res.columns[i] = column;
            }
            return res;
        }

        pub fn determinant(self: @This()) T {
            if (width != height) @compileError("Non square matrix determinant");
            if (width == 2) {
                return self.columns[0][0] * self.columns[1][1] - self.columns[1][0] * self.columns[0][1];
            }
            var res: T = 0;
            const Rec = Mat(T, width - 1, width - 1);
            inline for (self.columns, 0..) |column, i| {
                var arr: [width - 1][width - 1]T = undefined;
                var idx: usize = 0;
                inline for (self.columns, 0..) |loop_column, j| {
                    if (i != j) {
                        @memcpy(&arr[idx], loop_column[1..]);
                        idx += 1;
                    }
                }
                const mat: Rec = Rec.init(arr);
                const sign = if (i % 2 == 0) 1 else -1;
                res += sign * column[0] * mat.determinant();
            }
            return res;
        }
    };
}

pub fn rotation2D(comptime T: type, t: T) Mat(T, 2, 2) {
    return Mat(T, 2, 2).init(.{
        .{ cos(t), sin(t) },
        .{ -sin(t), cos(t) },
    });
}

pub fn transform2D(comptime T: type, scaling: Vec(T, 2), rotation: struct { angle: T, center: Vec(T, 2) }, translation: Vec(T, 2)) Mat(T, 3, 3) {
    var rot = Mat(T, 3, 3).translation(Vec2.init(.{ -1, -1 }).mul(rotation.center));
    rot = rotation2D(T, rotation.angle).cast(3, 3).mul(rot);
    rot = Mat(T, 3, 3).translation(rotation.center).mul(rot);

    const trans = Mat(T, 3, 3).translation(translation);
    const scale = Mat(T, 3, 3).scaling(Vec(T, 3).init(.{ scaling.val[0], scaling.val[1], 1 }));
    return trans.mul(rot.mul(scale));
}

pub fn rotationX(comptime T: type, t: T) Mat(T, 3, 3) {
    return Mat(T, 3, 3).init(.{
        .{ 1, 0, 0 },
        .{ 0, cos(t), sin(t) },
        .{ 0, -sin(t), cos(t) },
    });
}

pub fn rotationY(comptime T: type, t: T) Mat(T, 3, 3) {
    return Mat(T, 3, 3).init(.{
        .{ cos(t), 0, -sin(t) },
        .{ 0, 1, 0 },
        .{ sin(t), 0, cos(t) },
    });
}

pub fn rotationZ(comptime T: type, t: T) Mat(T, 3, 3) {
    return Mat(T, 3, 3).init(.{
        .{ cos(t), sin(t), 0 },
        .{ -sin(t), cos(t), 0 },
        .{ 0, 0, 1 },
    });
}

test "rot" {
    const mat = rotationY(3.14159).mul(rotationX(1.570796).mul(rotationZ(1.570796)));
    const res = mat.dot(.{ 1, 0, 0 });
    std.debug.print("\n{d:.4}\n", .{res});
    inline for (@as([3]f32, res), .{ 0, 0, -1 }) |i, j| {
        try std.testing.expectApproxEqAbs(i, j, 1e-1);
    }
}

pub fn perspectiveMatrix(fovy: f32, aspect: f32, nearZ: f32, farZ: f32) Mat4 {
    const f = 1.0 / std.math.tan(fovy * 0.5);
    const f_n = 1.0 / (nearZ - farZ);

    return Mat4.init(.{
        .{ f / aspect, 0, 0, 0 },
        .{ 0, f, 0, 0 },
        .{ 0, 0, (nearZ + farZ) * f_n, -1 },
        .{ 0, 0, 2 * nearZ * farZ * f_n, 0 },
    });
}

pub fn orthoMatrix(left: f32, right: f32, bottom: f32, top: f32, near_z: f32, far_z: f32) Mat4 {
    const rl = 1.0 / (right - left);
    const tb = 1.0 / (top - bottom);
    const f_n = -1.0 / (far_z - near_z);

    return Mat4.init(.{
        .{ 2 * rl, 0, 0, -(right + left) * rl },
        .{ 0, 2 * tb, 0, -(top + bottom) * tb },
        .{ 0, 0, f_n, near_z * f_n },
        .{ 0, 0, 0, 1 },
    });
}

pub fn lookAtMatrix(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
    const f_vec = center.sub(eye).norm();
    const s_vec = f_vec.cross(up).norm();
    const u_vec = s_vec.cross(f_vec);
    const f = f_vec.val;
    const s = s_vec.val;
    const u = u_vec.val;

    return Mat4.init(.{
        .{ s[0], u[0], -f[0], 0 },
        .{ s[1], u[1], -f[1], 0 },
        .{ s[2], u[2], -f[2], 0 },
        .{ -Vec3.dot(s_vec, eye), -Vec3.dot(u_vec, eye), Vec3.dot(f_vec, eye), 1 },
    });
}
