const std = @import("std");

const atan2 = std.math.atan2;
const sin = std.math.sin;
const cos = std.math.cos;

const math = @import("math");
const Vec3 = math.Vec3;
const Mat3 = math.Mat3;

pub const KeplerElements = struct {
    a: f64,
    e: f64,
    arg: f64,
    long: f64,
    i: f64,
    m0: f64,
    t0: f64 = 0,
};

pub const sun_mu = 1.32712440018e20;
pub const sun_mu_au = 1.32712440018e20;

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

pub fn keplerInverse(e: f64, mt: f64) f64 {
    var val: f64 = mt;

    for (0..10) |_| {
        const df = val - e * sin(val) - mt;
        const f = 1 - e * cos(val);
        val = val - df / f;
    }
    return val;
}

pub fn keplerToCart(elem: KeplerElements, t: f64, mu: f64) [2]@Vector(3, f64) {
    const a = elem.a;
    const e = elem.e;
    const arg = elem.arg;
    const long = elem.long;
    const i = elem.i;
    const m0 = elem.m0;
    const t0 = elem.t0;

    const dt = 86400 * (t - t0);

    const mt = @mod(m0 + dt * @sqrt(mu / (1.496e11 * 1.496e11 * 1.496e11 * a * a * a)), TAU);

    const et = keplerInverse(e, mt);

    const vt = 2 * atan2(f64, @sqrt(1 + e) * sin(et / 2), @sqrt(1 - e) * cos(et / 2));

    const rc: @Vector(3, f64) = @splat(a * (1 - e * cos(et)));

    const ot = rc * @Vector(3, f64){ cos(vt), sin(vt), 0 };

    const v_factor: @Vector(3, f64) = @splat(@sqrt(mu * a));
    const ot_v = v_factor / rc * @Vector(3, f64){ -sin(et), @sqrt(1 - e * e) * cos(et), 0 };

    var rt = math.rotationZ(f64, -long).mul(math.rotationX(f64, -i).mul(math.rotationZ(f64, -arg))).dot(ot);
    var rt_v = math.rotationZ(f64, -long).mul(math.rotationX(f64, -i).mul(math.rotationZ(f64, -arg))).dot(ot_v);

    return .{ rt, rt_v };
}
