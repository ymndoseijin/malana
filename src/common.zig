const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub var gpa_instance = std.heap.GeneralPurposeAllocator(.{
    .stack_trace_frames = 1000,
}){};
pub const allocator = if (builtin.mode == .Debug) gpa_instance.allocator() else std.heap.c_allocator;

pub fn FieldArrayList(comptime T: type) type {
    return struct {
        const Self = @This();

        const fields = std.meta.fields(T);

        pub const Field = std.meta.FieldEnum(T);
        pub const Enums = std.enums.values(Field);

        fn FieldType(comptime field: Field) type {
            return std.meta.fieldInfo(T, field).type;
        }

        pub const List = struct {
            ptrs: [fields.len][*]u8,

            pub fn init(gpa: Allocator) !List {
                var ptrs: [fields.len][*]u8 = undefined;
                inline for (fields, 0..) |field, i| {
                    var val = try gpa.alloc(std.ArrayList(field.type), 1);
                    var arr = std.ArrayList(field.type).init(gpa);
                    @memset(val, arr);
                    ptrs[i] = @ptrCast(@alignCast(val));
                }
                return List{ .ptrs = ptrs };
            }
        };

        lists: List,

        pub fn array(self: *Self, comptime field: Field) *std.ArrayList(FieldType(field)) {
            var pointer: [*]std.ArrayList(FieldType(field)) = @ptrCast(@alignCast(self.lists.ptrs[@intFromEnum(field)]));
            return &pointer[0];
        }
        pub fn init(gpa: Allocator) !Self {
            return Self{ .lists = try List.init(gpa) };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            inline for (fields, 0..) |field, i| {
                const pointer: [*]std.ArrayList(field.type) = @ptrCast(@alignCast(self.lists.ptrs[i]));
                pointer[0].deinit();
                gpa.destroy(&pointer[0]);
            }
        }
    };
}

test "field array" {
    const ally = testing.allocator;
    const FieldList = FieldArrayList(struct { a: u8, b: u5 });
    var arr = try FieldList.init(ally);
    defer arr.deinit(ally);

    try arr.array(.a).append(3);

    try testing.expectEqualSlices(u8, arr.array(.a).items, &[_]u8{3});
    try testing.expectEqualSlices(u5, arr.array(.b).items, &[_]u5{});

    try arr.array(.b).append(1);

    try testing.expectEqualSlices(u8, arr.array(.a).items, &[_]u8{3});
    try testing.expectEqualSlices(u5, arr.array(.b).items, &[_]u5{1});

    inline for (FieldList.Enums) |field| {
        arr.array(field).items[0] += 1;
    }

    try testing.expectEqualSlices(u8, arr.array(.a).items, &[_]u8{4});
    try testing.expectEqualSlices(u5, arr.array(.b).items, &[_]u5{2});
}
