pub const BindingReflection = struct {
    name: [:0]const u8,
    set: u32,
    idx: u32,
};

pub const Description = struct {
    vertex_description: graphics.VertexDescription,
    constants_size: ?usize = null,
    sets: []const graphics.Set = &.{},
    bindless: bool,
    attachments: []const struct {},
    entry_names: []const []const u8,
    binding_rfl: []const BindingReflection,

    pub fn getWriteType(comptime desc: Description) type {
        const default_buff: ?graphics.BufferHandle = null;
        const default_tex: ?[]graphics.Texture = null;
        const default_tex_single: ?graphics.Texture = null;

        var fields: [desc.binding_rfl.len]std.builtin.Type.StructField = undefined;
        for (&fields, desc.binding_rfl) |*f, rfl| {
            const binding = desc.sets[rfl.set].bindings[rfl.idx];
            const binding_type = switch (binding) {
                .uniform, .storage => ?graphics.BufferHandle,
                .sampler => |samp| if (!samp.boundless) ?graphics.Texture else ?[]graphics.Texture,
            };
            f.* = .{
                .name = rfl.name,
                .type = binding_type,
                .default_value_ptr = @ptrCast(@alignCast(switch (binding) {
                    .uniform, .storage => &default_buff,
                    .sampler => |samp| if (!samp.boundless) &default_tex_single else &default_tex,
                })),
                .is_comptime = false,
                .alignment = @alignOf(binding_type),
            };
        }
        return @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = &fields,
                .decls = &.{},
                .is_tuple = false,
            },
        });
    }

    pub fn updateDescriptorSets(comptime desc: Description, gpu: graphics.Gpu, descriptor: *graphics.Descriptor, write: desc.getWriteType()) !void {
        var samplers_buf: [desc.binding_rfl.len]graphics.Descriptor.SamplerWrite = undefined;
        var uniforms_buf: [desc.binding_rfl.len]graphics.Descriptor.UniformWrite = undefined;
        var storage_buf: [desc.binding_rfl.len]graphics.Descriptor.StorageWrite = undefined;

        var samplers: std.ArrayList(graphics.Descriptor.SamplerWrite) = .initBuffer(&samplers_buf);
        var uniforms: std.ArrayList(graphics.Descriptor.UniformWrite) = .initBuffer(&uniforms_buf);
        var storage: std.ArrayList(graphics.Descriptor.StorageWrite) = .initBuffer(&storage_buf);

        inline for (std.meta.fields(desc.getWriteType()), desc.binding_rfl) |field, rfl| {
            const binding = desc.sets[rfl.set].bindings[rfl.idx];
            if (@field(write, field.name)) |val| {
                if (field.type == ?graphics.Texture) {
                    try samplers.appendBounded(.{
                        .dst = 0,
                        .set = rfl.set,
                        .idx = rfl.idx,
                        .textures = &.{val},
                    });
                } else if (field.type == ?[]graphics.Texture) {
                    try samplers.appendBounded(.{
                        .dst = 0,
                        .set = rfl.set,
                        .idx = rfl.idx,
                        .textures = val,
                    });
                } else if (binding == .uniform) {
                    try uniforms.appendBounded(.{
                        .dst = 0,
                        .set = rfl.set,
                        .idx = rfl.idx,
                        .buffer = val,
                    });
                } else if (binding == .storage) {
                    try storage.appendBounded(.{
                        .dst = 0,
                        .set = rfl.set,
                        .idx = rfl.idx,
                        .buffer = val,
                    });
                }
            }
        }

        try descriptor.updateDescriptorSets(gpu, .{
            .samplers = samplers.items,
            .uniforms = uniforms.items,
            .storage = storage.items,
        });
    }

    pub fn getRenderDescription(desc: Description, options: struct {
        render_type: graphics.RenderType,
        depth_test: bool,
        depth_write: bool,
        cull_type: graphics.CullType,
    }) graphics.PipelineDescription {
        return .{
            .vertex_description = desc.vertex_description,
            .constants_size = desc.constants_size,
            .sets = desc.sets,
            .render_type = options.render_type,
            .depth_test = options.depth_test,
            .depth_write = options.depth_write,
            .cull_type = options.cull_type,
            .bindless = desc.bindless,
        };
    }

    pub fn initRender(
        desc: Description,
        ally: std.mem.Allocator,
        gpu: graphics.Gpu,
        options: struct {
            shaders: []const graphics.Shader,
            render_type: graphics.RenderType,
            depth_test: bool,
            depth_write: bool,
            cull_type: graphics.CullType,
            flipped_z: bool,

            attachments: []const graphics.AttachmentOptions.Description,
            depth: ?graphics.AttachmentOptions.DepthDescription,
        },
    ) !graphics.RenderPipeline {
        std.debug.print("{} and {}\n", .{ desc.attachments.len, options.attachments.len });
        std.debug.assert(desc.attachments.len == options.attachments.len);
        return graphics.RenderPipeline.init(ally, .{
            .description = desc.getRenderDescription(.{
                .render_type = options.render_type,
                .depth_test = options.depth_test,
                .depth_write = options.depth_write,
                .cull_type = options.cull_type,
            }),
            .gpu = gpu,
            .shaders = options.shaders,
            .rendering = .{
                .descriptions = options.attachments,
                .depth = options.depth,
            },
            .flipped_z = options.flipped_z,
        });
    }

    //const pipeline = try graphics.RenderPipeline.init(ally, .{
    //    .description = PipelineDescription,
    //    .shaders = &.{ pipeline_vert, pipeline_frag },
    //    .rendering = .{
    //        .descriptions = &.{
    //            .{ .format = .s8_bgra, .blending = null },
    //            .{ .format = .f16_rgba, .blending = null },
    //            .{ .format = .f16_rgba, .blending = null },
    //        },
    //        .depth = .{ .format = .depth },
    //    },
    //    .gpu = gpu,
    //    .flipped_z = true,
    //});
};

const graphics = @import("graphics.zig");
const std = @import("std");
