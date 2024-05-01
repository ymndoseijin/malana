#version 450
#extension GL_EXT_nonuniform_qualifier : require
#define max_lights 256
#define PI 3.14159265359

layout (location = 0) out vec4 out_color;

layout (location = 0) in vec2 in_uv;
layout (location = 1) in vec3 in_normal;
layout (location = 2) in vec3 in_pos;

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;

struct Light {
   vec3 pos;
   vec3 intensity;
};

layout (binding = 1) uniform SpatialUBO {
   vec4 pos;
} spatial_ubo;

layout (binding = 2) uniform sampler2D tex;

layout (push_constant) uniform Constants {
   vec3 cam_pos;
   mat4 cam_transform;
   int light_count;
} constants;

void main() {
   out_color = vec4(vec3((texture(tex, in_uv).r/10)), 1);
}
