const std = @import("std");

const assert = std.debug.assert;

pub const Mat4 = Mat(f32, 4, 4);
pub const Mat3 = Mat(f32, 3, 3);

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);

pub fn Vec(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @Vector(size, T);

        pub fn dot(a: Self, b: Self) T {
            return @reduce(.Add, a * b);
        }

        pub fn length(a: Self) T {
            return @sqrt(@reduce(.Add, a * a));
        }

        pub fn norm(a: Self) Self {
            return a / @splat(size, length(a));
        }

        pub fn proj(a: Self, b: Self) Self {
            return @splat(size, dot(b, a) / dot(a, a)) * a;
        }
    };
}

pub const Vec3Utils = struct {
    pub usingnamespace Vec(f32, 3);

    // eventually generalize to other dimensions
    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
    }
    pub fn crossn(a: Vec3, b: Vec3) Vec3 {
        return Vec3Utils.norm(Vec3Utils.cross(a, b));
    }
};

pub fn Mat(comptime T: type, comptime width: usize, comptime height: usize) type {
    return struct {
        pub const WIDTH: usize = width;
        pub const HEIGHT: usize = height;

        rows: [width]@Vector(height, T),

        pub fn init(rows: [width]@Vector(height, T)) @This() {
            return @This(){ .rows = rows };
        }

        pub fn identity() @This() {
            comptime assert(width == height);

            var id = @This().zero();

            inline for (0..width) |i| {
                id.rows[i][i] = 1;
            }

            return id;
        }

        pub fn translation(vec: @Vector(height - 1, T)) @This() {
            var res = identity();
            const arr: [height - 1]T = vec;
            inline for (arr, 0..) |vrow, i| {
                res.rows[width - 1][i] = vrow;
            }
            res.rows[width - 1][height - 1] = 1;
            return res;
        }

        pub fn zero() @This() {
            return @This().singleValue(0);
        }

        pub fn singleValue(default: T) @This() {
            return @This(){ .rows = .{.{default} ** height} ** width };
        }

        pub fn dot(self: @This(), vec: @Vector(width, T)) @Vector(width, T) {
            var res: @Vector(width, T) = undefined;
            inline for (self.rows, 0..) |row, i| {
                res[i] = @reduce(.Add, row * vec);
            }
            return res;
        }

        pub fn gramschmidt(self: @This()) @This() {
            var res: @This() = undefined;
            for (res.rows, self.rows, 0..) |res_row, vn, i| {
                res_row = vn;
                for (0..i) |j| {
                    res_row -= Vec(T, height).proj(res_row[j], vn);
                }
            }
            return res;
        }

        pub fn mul(self: @This(), comptime R: type, other: anytype) R {
            var res: R = undefined;
            inline for (self.rows, 0..) |row, i| {
                var column: @Vector(R.HEIGHT, T) = .{0} ** R.HEIGHT;

                inline for (0..width) |j| {
                    const mask = ([1]i32{@intCast(j)}) ** R.HEIGHT;
                    var vi = @shuffle(T, row, undefined, mask);

                    vi = vi * other.rows[j];
                    column += vi;
                }

                res.rows[i] = column;
            }
            return res;
        }
    };
}

pub fn perspectiveMatrix(fovy: f32, aspect: f32, nearZ: f32, farZ: f32) Mat4 {
    var res = Mat4.zero();

    var f = 1.0 / std.math.tan(fovy * 0.5);
    var f_n = 1.0 / (nearZ - farZ);

    res.rows[0][0] = f / aspect;
    res.rows[1][1] = f;
    res.rows[2][2] = (nearZ + farZ) * f_n;
    res.rows[2][3] = -1.0;
    res.rows[3][2] = 2.0 * nearZ * farZ * f_n;

    return res;
}

pub fn lookAtMatrix(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
    var res = Mat4.zero();

    const f = Vec3Utils.norm(center - eye);

    const s = Vec3Utils.norm(Vec3Utils.cross(f, up));
    const u = Vec3Utils.cross(s, f);

    res.rows[0][0] = s[0];
    res.rows[0][1] = u[0];
    res.rows[0][2] = -f[0];
    res.rows[1][0] = s[1];
    res.rows[1][1] = u[1];
    res.rows[1][2] = -f[1];
    res.rows[2][0] = s[2];
    res.rows[2][1] = u[2];
    res.rows[2][2] = -f[2];
    res.rows[3][0] = -Vec3Utils.dot(s, eye);
    res.rows[3][1] = -Vec3Utils.dot(u, eye);
    res.rows[3][2] = Vec3Utils.dot(f, eye);
    res.rows[0][3] = 0.0;
    res.rows[1][3] = 0.0;
    res.rows[2][3] = 0.0;
    res.rows[3][3] = 1.0;

    return res;
}

pub fn main() !void {
    var a = Mat(i32, 3, 3).init(.{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    });

    var b = Mat(i32, 3, 3).init(.{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
        .{ 7, 8, 9 },
    });
    std.debug.print("{any}\n", .{a.mul(Mat(i32, 3, 3), b)});
    std.debug.print("{any}\n", .{perspectiveMatrix(0.6, 1, 0.1, 2048)});
    std.debug.print("{d:.1}\n", .{a.dot(.{ 1, 2, 3 })});

    std.debug.print("{d:.1}\n", .{Vec(i32, 3).dot(.{ 1, 2, 3 }, .{ 1, 10, 100 })});
    std.debug.print("{d:.1}\n", .{Vec(f32, 2).proj(.{ 3, 1 }, .{ 2, 2 })});

    std.debug.print("{d:.1}\n", .{Vec3Utils.cross(.{ 2, -3, 1 }, .{ -2, 1, 1 })});
    std.debug.print("{d:.1}\n", .{Vec3Utils.norm(Vec3{ 2, -3, 1 })});

    const center = Vec3{ 0.54030, 0.00000, -0.84147 };
    const up = Vec3{ 0.00000, 1.00000, 0.00000 };

    std.debug.print("{d:.4}\n", .{Vec(f32, 2).norm(.{ 1, 1 })});
    std.debug.print("{d:.4}\n", .{lookAtMatrix(.{ 0, 0, 0 }, center, up).rows});
}
