const std = @import("std");

const atan2 = std.math.atan2;
const sin = std.math.sin;
const cos = std.math.cos;

const math = @import("math");
const Vec3 = math.Vec3;
const Mat3 = math.Mat3;

pub const KeplerElements = struct {
    a: f32,
    e: f32,
    arg: f32,
    long: f32,
    i: f32,
    m0: f32,
    t0: f32 = 0,
};

pub fn eulerMethod(comptime T: type, comptime f: fn (T) T, comptime dt: T) fn (T) T {
    return struct {
        pub fn fun(x: T) T {
            return (f(x + dt) - f(x)) / dt;
        }
    }.fun;
}

pub fn newtonMethod(comptime T: type, comptime f: fn (T) T, comptime df: fn (T) T) fn (T) T {
    return struct {
        pub fn fun(x: T) T {
            return x - f(x) / df(x);
        }
    }.fun;
}

const TAU = 6.28318530718;

pub fn keplerInverse(e: f32, mt: f32) f32 {
    var val: f32 = mt;

    for (0..10) |_| {
        const df = val - e * sin(val) - mt;
        const f = 1 - e * cos(val);
        val = val - df / f;
    }
    return val;
}

pub fn keplerToCart(elem: KeplerElements, t: f32, mu: f32) [2]Vec3 {
    const a = elem.a;
    const e = elem.e;
    const arg = elem.arg;
    const long = elem.long;
    const i = elem.i;
    const m0 = elem.m0;
    const t0 = elem.t0;

    const dt = 86400 * (t - t0);

    const mt = m0 + dt * @sqrt(mu / (a * a * a));

    const et = keplerInverse(e, mt);

    const vt = 2 * atan2(f32, @sqrt(1 + e) * sin(et / 2), @sqrt(1 - e) * cos(et / 2));

    const rc: Vec3 = @splat(a * (1 - e * cos(et)));

    const ot = rc * Vec3{ cos(vt), sin(vt), 0 };

    const v_factor: Vec3 = @splat(@sqrt(mu * a));
    const ot_v = v_factor / rc * Vec3{ -sin(et), @sqrt(1 - e * e) * cos(et), 0 };

    var rt = math.rotationZ(-long).mul(math.rotationX(-i).mul(math.rotationZ(-arg))).dot(ot);
    var rt_v = math.rotationZ(-long).mul(math.rotationX(-i).mul(math.rotationZ(-arg))).dot(ot_v);

    return .{ rt, rt_v };
}
