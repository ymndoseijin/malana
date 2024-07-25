const std = @import("std");
const math = @import("math.zig");

pub fn parseHexRGBA(in_hex: []const u8) ![4]f32 {
    const hex = std.mem.trim(u8, in_hex, "#");
    if (hex.len < 6) return error.InvalidStringSize;

    const r: f32 = @floatFromInt(try std.fmt.parseInt(u8, hex[0..2], 16));
    const g: f32 = @floatFromInt(try std.fmt.parseInt(u8, hex[2..4], 16));
    const b: f32 = @floatFromInt(try std.fmt.parseInt(u8, hex[4..6], 16));
    const a: f32 = if (hex.len < 8) 255 else @floatFromInt(try std.fmt.parseInt(u8, hex[6..8], 16));

    return .{ r / 255, g / 255, b / 255, a / 255 };
}

pub fn parseHexRGB(in_hex: []const u8) ![3]f32 {
    const hex = std.mem.trim(u8, in_hex, "#");
    if (hex.len < 6) return error.InvalidStringSize;

    const r: f32 = @floatFromInt(try std.fmt.parseInt(u8, hex[0..2], 16));
    const g: f32 = @floatFromInt(try std.fmt.parseInt(u8, hex[2..4], 16));
    const b: f32 = @floatFromInt(try std.fmt.parseInt(u8, hex[4..6], 16));

    return .{ r / 255, g / 255, b / 255 };
}
