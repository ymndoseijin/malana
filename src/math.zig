const std = @import("std");

const assert = std.debug.assert;

pub const color = @import("color.zig");
const sin = std.math.sin;
const cos = std.math.cos;

pub const Mat4 = Mat(f32, 4, 4);
pub const Mat3 = Mat(f32, 3, 3);

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);

pub fn Vec(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @Vector(size, T);

        pub fn interpolate(a: Self, b: Self, x: T) Self {
            const left: Self = @splat(1 - x);
            const right: Self = @splat(x);
            return left * a + b * right;
        }

        pub fn dot(a: Self, b: Self) T {
            return @reduce(.Add, a * b);
        }

        pub fn length(a: Self) T {
            return @sqrt(@reduce(.Add, a * a));
        }

        pub fn norm(a: Self) Self {
            const len: Self = @splat(length(a));
            return a / len;
        }

        pub fn proj(a: Self, b: Self) Self {
            const factor: Self = @splat(dot(b, a) / dot(a, a));
            return factor * a;
        }

        pub fn cross(a: Vec3, b: Vec3) Vec3 {
            return .{ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
        }
        pub fn crossn(a: Vec3, b: Vec3) Vec3 {
            return Vec3Utils.norm(Vec3Utils.cross(a, b));
        }
    };
}

pub const Vec2Utils = Vec(f32, 2);

pub const Vec3Utils = Vec(f32, 3);

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

        pub fn scaling(vec: @Vector(width, T)) @This() {
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

        pub fn translation(vec: @Vector(height - 1, T)) @This() {
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

        pub fn dot(self: @This(), vec: @Vector(width, T)) @Vector(height, T) {
            var res: @Vector(height, T) = undefined;
            inline for (0..width) |i| {
                var row: @Vector(width, T) = undefined;
                inline for (self.columns, 0..) |col, j| {
                    row[j] = col[i];
                }

                res[i] = @reduce(.Add, row * vec);
            }
            return res;
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

// rotation is struct { angle: T = 0, center: @Vector(2, T) = .{ 0, 0 } }
pub fn transform2D(comptime T: type, scaling: @Vector(2, T), rotation: anytype, translation: @Vector(2, T)) Mat(T, 3, 3) {
    var rot = Mat(T, 3, 3).translation(@as(@Vector(2, T), @splat(-1)) * rotation.center);
    rot = rotation2D(T, rotation.angle).cast(3, 3).mul(rot);
    rot = Mat(T, 3, 3).translation(rotation.center).mul(rot);

    const trans = Mat(T, 3, 3).translation(.{ translation[0], translation[1] });
    const scale = Mat(T, 3, 3).scaling(.{ scaling[0], scaling[1], 1 });
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

pub fn lookAtMatrix(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
    const f = Vec3Utils.norm(center - eye);

    const s = Vec3Utils.norm(Vec3Utils.cross(f, up));
    const u = Vec3Utils.cross(s, f);

    return Mat4.init(.{
        .{ s[0], u[0], -f[0], 0 },
        .{ s[1], u[1], -f[1], 0 },
        .{ s[2], u[2], -f[2], 0 },
        .{ -Vec3Utils.dot(s, eye), -Vec3Utils.dot(u, eye), Vec3Utils.dot(f, eye), 1 },
    });
}

pub fn main() !void {
    var a = Mat(i32, 3, 3).init(.{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    });

    var b = Mat(i32, 3, 3).init(.{
        .{ 1, 2, 3 },
        .{ 3, 2, 1 },
        .{ 2, 1, 3 },
    });
    std.debug.print("{any}\n", .{a.mul(b)});
    std.debug.print("{any}\n", .{perspectiveMatrix(0.6, 1, 0.1, 2048)});
    std.debug.print("{d:.1}\n", .{a.dot(.{ 1, 2, 3 })});

    std.debug.print("{d:.1}\n", .{Vec(i32, 3).dot(.{ 1, 2, 3 }, .{ 1, 10, 100 })});
    std.debug.print("{d:.1}\n", .{Vec(f32, 2).proj(.{ 3, 1 }, .{ 2, 2 })});

    std.debug.print("{d:.1}\n", .{Vec3Utils.cross(.{ 2, -3, 1 }, .{ -2, 1, 1 })});
    std.debug.print("{d:.1}\n", .{Vec3Utils.norm(Vec3{ 2, -3, 1 })});

    const center = Vec3{ 0.54030, 0.00000, -0.84147 };
    const up = Vec3{ 0.00000, 1.00000, 0.00000 };

    std.debug.print("{d:.4}\n", .{Vec(f32, 2).norm(.{ 1, 1 })});
    std.debug.print("{d:.4}\n", .{lookAtMatrix(.{ 0, 0, 0 }, center, up).columns});

    var c = Mat(i32, 2, 2).init(.{
        .{ 1, 2 },
        .{ 3, 4 },
    });
    std.debug.print("{d:.4}\n", .{c.determinant()});
    std.debug.print("{d:.4}\n", .{b.determinant()});
}
