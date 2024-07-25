#version 450
#extension GL_EXT_nonuniform_qualifier : require

#define PI 3.14159265359

layout (location = 0) out vec4 out_color;

layout (location = 0) in vec2 in_uv;
layout (location = 1) in vec3 in_normal;
layout (location = 2) in vec3 in_pos;

layout (set = 0, binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;

layout (set = 0, binding = 1) uniform SpatialUBO {
   vec4 pos;
} spatial_ubo;

layout (push_constant) uniform Constants {
   vec3 cam_pos;
   mat4 cam_transform;
} constants;

void main() {
   out_color = vec4(in_uv, 1, 1);
}
