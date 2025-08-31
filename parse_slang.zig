// this parses a slang utilizing their json reflection interface and converts
// to automatically generate Pipeline in Malana, right now it's definitely not
// spec compliant and it assumes a certain coding style in the slang shaders
// like always having explicit bindings, vertex shader returns a struct always
// and so on, some of these might change with time, others might not

pub const BindingType = enum {
    pushConstantBuffer,
    descriptorTableSlot,
    varyingInput,
    varyingOutput,
};

pub const Binding = union(enum) {
    descriptor: struct {
        type: BindingType,
        index: u32,
        space: u32,
        count: ?u32 = null,
    },
    uniform: struct {
        offset: u32,
        size: u32,
        elementStride: ?u32,
    },

    pub fn jsonParseFromValue(ally: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) !Binding {
        _ = options;
        _ = ally;
        const obj = value.object;
        const kind_val = obj.get("kind") orelse return error.MissingField;
        const kind_str = kind_val.string;

        if (std.mem.eql(u8, kind_str, "uniform")) {
            const offset: u32 = @intCast((obj.get("offset") orelse return error.MissingField).integer);
            const size: u32 = @intCast((obj.get("size") orelse return error.MissingField).integer);
            const elementStride: ?u32 = if (obj.get("elementStride")) |stride|
                @intCast(stride.integer)
            else
                null;

            return .{ .uniform = .{ .offset = offset, .size = size, .elementStride = elementStride } };
        } else {
            const index: u32 = @intCast((obj.get("index") orelse return error.MissingField).integer);
            const space: u32 = if (obj.get("space")) |s| @intCast(s.integer) else 0;
            const count: ?u32 = if (obj.get("count")) |c| @intCast(c.integer) else null;

            return .{ .descriptor = .{
                .type = std.meta.stringToEnum(BindingType, kind_str) orelse return error.UnexpectedToken,
                .index = index,
                .space = space,
                .count = count,
            } };
        }
    }

    pub fn jsonParse(ally: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Binding {
        const tmp = try Value.jsonParse(ally, source, options);

        return jsonParseFromValue(ally, tmp, options);
    }
};

pub const VarLayout = struct {
    binding: Binding,
    type: ?*SlangType = null,
};

pub const Field = struct {
    name: []const u8,
    type: *SlangType,
    binding: ?Binding = null,
    stage: ?[]const u8 = null,
    semanticName: ?[]const u8 = null,
};

pub const Struct = struct {
    name: []const u8,
    fields: []Field,
};

pub const StructOrigin = enum {
    undefined,
    constant_buffer,
    resource,
};
pub const StructSearch = struct {
    strut: Struct,
    origin: StructOrigin,
    pub fn generateZigTypes(search: StructSearch, writer: *std.Io.Writer) !void {
        try writer.print("pub const {s}: graphics.DataDescription = .{{\n", .{search.strut.name});
        try writer.print("    .T = extern struct {{\n", .{});
        // TODO: technically you should sort these by their bindings but you personally don't use that
        for (search.strut.fields) |field| {
            try writer.print("        {s}: ", .{field.name});
            try field.type.*.writeZigIdentifier(writer, search.origin);
            if (field.type.* == .@"struct") try writer.print(".T", .{});
            try writer.print(",\n", .{});
        }
        try writer.print("    }},\n", .{});
        try writer.print("}};\n\n", .{});
    }
};

pub const SlangType = union(enum) {
    pub const Vector = struct { elementCount: u32, elementType: *SlangType };

    pub const Shape = enum {
        texture2D,
        textureCube,
        structuredBuffer,
    };

    scalar: struct {
        pub const ScalarType = enum {
            f32,
            u32,
            i32,

            pub fn toString(s: ScalarType) []const u8 {
                return switch (s) {
                    .f32 => return "f32",
                    .u32 => return "u32",
                    .i32 => return "i32",
                };
            }
        };
        scalarType: []const u8,

        pub fn toEnum(scalar: @This()) !ScalarType {
            if (std.mem.eql(u8, scalar.scalarType, "uint32")) {
                return .u32;
            } else if (std.mem.eql(u8, scalar.scalarType, "float32")) {
                return .f32;
            } else if (std.mem.eql(u8, scalar.scalarType, "int32")) {
                return .i32;
            }
            return error.UnhandledScalar;
        }
    },

    vector: Vector,
    matrix: struct { rowCount: u32, columnCount: u32, elementType: *SlangType },
    array: Vector,
    @"struct": Struct,
    resource: struct {
        baseShape: Shape,
        combined: ?bool = null,
        resultType: *SlangType,
    },
    constantBuffer: struct { elementType: *SlangType, containerVarLayout: ?VarLayout = null, elementVarLayout: ?VarLayout = null },
    uniform: struct { offset: u32, size: u32, elementStride: u32 },

    pub fn writeZigIdentifier(slang: SlangType, writer: *std.Io.Writer, origin_or: ?StructOrigin) !void {
        switch (slang) {
            .@"struct" => |strut| {
                try writer.print("{s}", .{strut.name});
            },
            .scalar => |scalar| {
                const scalar_enum = try scalar.toEnum();
                try writer.print("{s}", .{scalar_enum.toString()});
                if (origin_or) |origin| {
                    switch (origin) {
                        .constant_buffer => switch (scalar_enum) {
                            .f32 => try writer.print(" align(4 * 4)", .{}),
                            .u32, .i32 => {},
                        },
                        .resource => switch (scalar_enum) {
                            .f32 => try writer.print(" align(4 * 2)", .{}),
                            .u32, .i32 => {},
                        },
                        .undefined => {},
                    }
                }
            },
            // TODO: alignment
            .vector, .array => |vec| {
                try writer.print("[{}]", .{vec.elementCount});
                try writeZigIdentifier(vec.elementType.*, writer, origin_or);
            },
            .matrix => |mat| {
                try writer.print("[{}][{}]", .{ mat.rowCount, mat.columnCount });
                try writeZigIdentifier(mat.elementType.*, writer, origin_or);
            },
            .constantBuffer, .resource, .uniform => {
                return error.InvalidIdentifier;
            },
        }
    }

    pub fn searchStructs(
        slang: SlangType,
        map: *std.StringArrayHashMapUnmanaged(StructSearch),
        ally: std.mem.Allocator,
        origin: StructOrigin,
    ) !void {
        switch (slang) {
            .@"struct" => |strut| {
                try map.put(ally, strut.name, .{
                    .strut = strut,
                    .origin = origin,
                });
                for (strut.fields) |field| {
                    try field.type.searchStructs(map, ally, origin);
                }
            },
            .vector, .array => |vec| try vec.elementType.searchStructs(map, ally, .undefined),
            .matrix => |mat| try mat.elementType.searchStructs(map, ally, .undefined),
            .constantBuffer => |cb| try cb.elementType.searchStructs(map, ally, .constant_buffer),
            .resource => |res| try res.resultType.searchStructs(map, ally, .resource),
            else => {},
        }
    }

    fn parseTypePtr(ally: std.mem.Allocator, v: Value, options: std.json.ParseOptions) !*SlangType {
        const parsed = try std.json.parseFromValue(SlangType, ally, v, options);
        const ptr = try ally.create(SlangType);
        ptr.* = parsed.value;
        return ptr;
    }

    pub fn jsonParseFromValue(ally: std.mem.Allocator, value: Value, options: std.json.ParseOptions) !SlangType {
        const obj = value.object;
        const kind_val = obj.get("kind") orelse return error.MissingField;
        const kind_str = kind_val.string;

        if (std.mem.eql(u8, kind_str, "scalar")) {
            const scalarType = (obj.get("scalarType") orelse return error.MissingField).string;

            return .{ .scalar = .{ .scalarType = scalarType } };
        } else if (std.mem.eql(u8, kind_str, "vector")) {
            const elementCount: u32 = @intCast((obj.get("elementCount") orelse return error.MissingField).integer);
            const elem_val = obj.get("elementType") orelse return error.MissingField;

            return .{ .vector = .{ .elementCount = elementCount, .elementType = try parseTypePtr(ally, elem_val, options) } };
        } else if (std.mem.eql(u8, kind_str, "matrix")) {
            const rowCount: u32 = @intCast((obj.get("rowCount") orelse return error.MissingField).integer);
            const colCount: u32 = @intCast((obj.get("columnCount") orelse return error.MissingField).integer);
            const elem_val = obj.get("elementType") orelse return error.MissingField;

            return .{ .matrix = .{ .rowCount = rowCount, .columnCount = colCount, .elementType = try parseTypePtr(ally, elem_val, options) } };
        } else if (std.mem.eql(u8, kind_str, "array")) {
            const elementCount: u32 = @intCast((obj.get("elementCount") orelse return error.MissingField).integer);
            const elem_val = obj.get("elementType") orelse return error.MissingField;

            return .{ .array = .{ .elementCount = elementCount, .elementType = try parseTypePtr(ally, elem_val, options) } };
        } else if (std.mem.eql(u8, kind_str, "struct")) {
            const name_opt = if (obj.get("name")) |n| n.string else return error.UnexpectedToken;
            const fields_val = obj.get("fields") orelse return error.MissingField;
            const fields = try std.json.parseFromValue([]Field, ally, fields_val, options);

            return .{ .@"struct" = .{ .name = name_opt, .fields = fields.value } };
        } else if (std.mem.eql(u8, kind_str, "resource")) {
            const baseShape = (obj.get("baseShape") orelse return error.MissingField).string;
            const combined_opt = if (obj.get("combined")) |c| c.bool else null;
            const res_val = obj.get("resultType") orelse return error.MissingField;

            return .{ .resource = .{
                .baseShape = std.meta.stringToEnum(Shape, baseShape) orelse return error.UnexpectedToken,
                .combined = combined_opt,
                .resultType = try parseTypePtr(ally, res_val, options),
            } };
        } else if (std.mem.eql(u8, kind_str, "constantBuffer")) {
            const elem_val = obj.get("elementType") orelse return error.MissingField;
            const elem = try parseTypePtr(ally, elem_val, options);

            const container_val = obj.get("containerVarLayout");
            const element_val = obj.get("elementVarLayout");

            var container_layout: ?VarLayout = null;
            if (container_val) |c| container_layout = (try std.json.parseFromValue(VarLayout, ally, c, options)).value;

            var element_layout: ?VarLayout = null;
            if (element_val) |e| element_layout = (try std.json.parseFromValue(VarLayout, ally, e, options)).value;

            return .{ .constantBuffer = .{ .elementType = elem, .containerVarLayout = container_layout, .elementVarLayout = element_layout } };
        } else if (std.mem.eql(u8, kind_str, "uniform")) {
            const offset: u32 = @intCast((obj.get("offset") orelse return error.MissingField).integer);
            const size: u32 = @intCast((obj.get("size") orelse return error.MissingField).integer);
            const stride: u32 = @intCast((obj.get("elementStride") orelse return error.MissingField).integer);

            return .{ .uniform = .{ .offset = offset, .size = size, .elementStride = stride } };
        }
        return error.UnexpectedToken;
    }

    pub fn jsonParse(ally: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !SlangType {
        const tmp = try Value.jsonParse(ally, source, options);

        return jsonParseFromValue(ally, tmp, options);
    }
};

pub const Parameter = struct {
    name: []const u8,
    //binding: ?Binding = null,
    binding: Binding,
    type: *SlangType,
};

pub const Result = struct {
    stage: []const u8,
    binding: Binding,
    type: *SlangType,
};

pub const EntryBinding = struct {
    name: []const u8,
    binding: Binding,
};

pub const EntryPoint = struct {
    name: []const u8,
    stage: enum {
        vertex,
        fragment,
    },
    parameters: []Parameter,
    result: ?Result = null,
    bindings: []EntryBinding,
};

pub const ShaderJson = struct {
    parameters: []Parameter,
    entryPoints: []EntryPoint,
};

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    var buff: [256]u8 = undefined;

    const output_directory = args[1];

    var shader_i: usize = 2;
    while (shader_i + 1 < args.len) : (shader_i += 2) {
        const shader_path = args[shader_i + 1];
        const shader_name = std.fs.path.stem(shader_path);

        var output_file = try std.fs.cwd().createFile(
            args[shader_i],
            .{},
        );
        defer output_file.close();
        var output_writer = output_file.writer(&buff);
        const output = &output_writer.interface;

        const json_path = try std.fs.path.join(arena, &.{
            output_directory,
            try std.fmt.allocPrint(arena, "{s}.json", .{shader_name}),
        });
        const reflection_cmd: []const []const u8 = &.{
            "slangc",
            "-reflection-json",
            json_path,
            "-target",
            "spirv",
            shader_path,
        };
        _ = try std.process.Child.run(.{
            .allocator = arena,
            .argv = reflection_cmd,
        });

        var shader_file = try std.fs.cwd().openFile(json_path, .{});
        var shader_reader = shader_file.reader(&buff);
        const shader = &shader_reader.interface;

        // NOTE: ShaderJson is actually leaky I think?
        const raw_json = try shader.readAlloc(arena, try shader_reader.getSize());
        const parsed = std.json.parseFromSliceLeaky(ShaderJson, arena, raw_json, .{ .ignore_unknown_fields = true }) catch |err| {
            std.debug.print("err at: {s}\n", .{shader_path});
            return err;
        };

        for (parsed.entryPoints) |entry| {
            const spv_path =
                try std.fs.path.join(arena, &.{
                    output_directory,
                    try std.fmt.allocPrint(arena, "{s}-{s}.spv", .{ shader_name, entry.name }),
                });
            _ = try std.process.Child.run(.{
                .allocator = arena,
                .argv = &.{
                    "slangc",
                    "-profile",
                    "glsl_450",
                    "-target",
                    "spirv",
                    "-g",
                    "-entry",
                    entry.name,
                    "-o",
                    spv_path,
                    shader_path,
                },
            });
        }

        var structs: std.StringArrayHashMapUnmanaged(StructSearch) = .empty;

        // TODO: search for structs in entryPoints
        for (parsed.parameters) |parameter| {
            try parameter.type.searchStructs(&structs, arena, .undefined);
        }

        for (structs.values()) |strut| {
            try strut.generateZigTypes(output);
        }

        const Context = struct {
            pub fn lessThan(_: @This(), a: Parameter, b: Parameter) bool {
                if (a.binding.descriptor.space == b.binding.descriptor.space) {
                    return a.binding.descriptor.index < b.binding.descriptor.index;
                }
                return a.binding.descriptor.space < b.binding.descriptor.space;
            }
        };
        std.mem.sort(Parameter, parsed.parameters, Context{}, Context.lessThan);
        try output.print("pub const description: graphics.reflection.Description = .{{\n", .{});

        for (parsed.entryPoints) |entry| {
            std.mem.sort(Parameter, entry.parameters, Context{}, Context.lessThan);
            if (entry.stage == .vertex) {
                try output.print("    .vertex_description = .{{\n", .{});
                try output.print("        .vertex_attribs = &.{{\n", .{});
                for (entry.parameters) |parameter| {
                    std.debug.assert(parameter.type.* == .vector or parameter.type.* == .scalar);
                    if (parameter.type.* == .vector) {
                        const vec = parameter.type.vector;
                        const attribute_name = switch (try vec.elementType.scalar.toEnum()) {
                            .f32 => "float",
                            .i32 => "i32",
                            .u32 => "uint",
                        };
                        try output.print("            .{{ .size = {}, .attribute = .{s} }},\n", .{ vec.elementCount, attribute_name });
                    } else if (parameter.type.* == .scalar) {
                        const scalar = parameter.type.scalar;
                        const attribute_name = switch (try scalar.toEnum()) {
                            .f32 => "float",
                            .i32 => "i32",
                            .u32 => "uint",
                        };
                        try output.print("            .{{ .size = 1, .attribute = .{s} }},\n", .{attribute_name});
                    }
                }
                try output.print("        }},\n", .{});
                try output.print("    }},\n", .{});

                // assume no more than one vertex shader, can you even have more?
                break;
            }
        }

        try output.print("    .sets = &.{{\n", .{});
        var seen_boundless = false;
        var push_constants: ?SlangType = null;
        if (parsed.parameters.len > 0) {
            var last_set: u32 = 0;

            try output.print("        .{{\n", .{});
            try output.print("            .bindings = &.{{\n", .{});

            for (parsed.parameters) |parameter| {
                const descriptor = parameter.binding.descriptor;

                if (descriptor.type == .pushConstantBuffer) {
                    push_constants = parameter.type.*;
                    continue;
                }

                if (last_set != descriptor.space) {
                    last_set = descriptor.space;
                    try output.print("            }},\n", .{});
                    try output.print("        }},\n", .{});
                    try output.print("        .{{\n", .{});
                    try output.print("            .bindings = &.{{\n", .{});
                }

                switch (parameter.type.*) {
                    .constantBuffer => |cb| {
                        // TODO: what if elementType is not a struct?
                        try output.print("                .{{ .uniform = .{{ .size = ", .{});
                        try cb.elementType.writeZigIdentifier(output, null);
                        try output.print(".getSize() }} }},\n", .{});
                    },
                    .resource => |res| {
                        switch (res.baseShape) {
                            .structuredBuffer => {
                                // TODO: what if elementType is not a struct?
                                try output.print("                .{{ .storage = .{{ .size = ", .{});
                                try res.resultType.writeZigIdentifier(output, null);
                                try output.print(".getSize(), .boundless = true }} }},\n", .{});
                                seen_boundless = true;
                            },
                            .texture2D, .textureCube => {
                                try output.print("                .{{ .sampler = .{{}}}},\n", .{});
                            },
                        }
                    },
                    // TODO: do I even have proper texture arrays? do I even need them?? I do need array structs though at the very least
                    .array => |arr| {
                        switch (arr.elementType.*) {
                            .resource => |res| {
                                std.debug.assert(res.baseShape == .texture2D or
                                    res.baseShape == .textureCube);
                                try output.print("                .{{ .sampler = .{{ .boundless = true }} }},\n", .{});
                            },
                            .constantBuffer => |cb| {
                                try output.print("                .{{ .uniform = .{{ .size = ", .{});
                                try cb.elementType.writeZigIdentifier(output, null);
                                try output.print(".getSize(), .boundless = true }} }},\n", .{});
                            },
                            else => return error.UnhandledArray,
                        }
                        seen_boundless = true;
                    },
                    else => return error.InvalidParameter,
                }
            } else {
                try output.print("            }},\n", .{});
                try output.print("        }},\n", .{});
            }
        }
        try output.print("    }},\n", .{});
        // .constants_size = PushConstants.getSize(),
        if (push_constants) |constants| {
            std.debug.assert(constants == .constantBuffer);
            std.debug.assert(constants.constantBuffer.elementType.* == .@"struct");
            const strut = constants.constantBuffer.elementType.@"struct";
            try output.print("    .constants_size = {s}.getSize(),\n", .{strut.name});
        }
        try output.print("    .attachments = &.{{\n", .{});

        for (parsed.entryPoints) |entry| {
            for (entry.parameters) |parameter| {
                switch (parameter.binding) {
                    .descriptor => |desc| {
                        if (desc.type == .varyingOutput) try output.print("        .{{}},\n", .{});
                    },
                    else => {},
                }
            }
            if (entry.stage != .fragment) continue;
            if (entry.result) |res| {
                switch (res.type.*) {
                    .@"struct" => |strut| {
                        for (strut.fields) |field| {
                            _ = field;
                            try output.print("        .{{}},\n", .{});
                        }
                    },
                    else => {
                        try output.print("        .{{}},\n", .{});
                    },
                }
            }
        }
        try output.print("    }},\n", .{});
        try output.print("    .entry_names = &.{{\n", .{});
        for (parsed.entryPoints) |entry| {
            try output.print("        \"{s}.{s}\",\n", .{ shader_name, entry.name });
        }
        try output.print("    }},\n", .{});
        try output.print("    .binding_rfl = &.{{\n", .{});
        for (parsed.parameters) |parameter| {
            const descriptor = parameter.binding.descriptor;
            if (descriptor.type == .pushConstantBuffer) {
                continue;
            }
            try output.print("        .{{\n", .{});
            try output.print("            .name = \"{s}\",\n", .{parameter.name});
            try output.print("            .set = {},\n", .{descriptor.space});
            try output.print("            .idx = {},\n", .{descriptor.index});
            try output.print("        }},\n", .{});
        }
        try output.print("    }},\n", .{});

        if (seen_boundless) {
            try output.print("    .bindless = true,\n", .{});
        } else {
            try output.print("    .bindless = false,\n", .{});
        }
        try output.print("}};\n\n", .{});

        for (parsed.entryPoints) |entry| {
            const spv_path =
                try std.fs.path.join(arena, &.{
                    output_directory,
                    try std.fmt.allocPrint(arena, "{s}-{s}.spv", .{ shader_name, entry.name }),
                });
            try output.print("pub const {s}: []align(@alignOf(u32)) const u8 = @alignCast(@embedFile(\"{s}\"));\n", .{
                entry.name,
                spv_path,
            });
        }
        try output.print("const graphics = @import(\"ui\").graphics;", .{});

        try output.flush();
    }

    return std.process.cleanExit();
}

const std = @import("std");
const Value = std.json.Value;
