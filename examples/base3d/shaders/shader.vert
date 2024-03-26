#version 450
#define max_lights 256

layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec2 in_uv;
layout (location = 2) in vec3 in_normal;

layout (location = 0) out vec2 out_uv;
layout (location = 1) out vec3 out_normal;
layout (location = 2) out vec3 out_pos;

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;

struct Light {
   vec3 pos;
};

layout (binding = 1) uniform SpatialUBO {
   vec3 pos;
   int light_count;
   Light lights[max_lights];
} spatial_ubo;

layout (push_constant) uniform Constants {
   vec3 cam_pos;
   mat4 cam_transform;
} constants;

void main() {
   vec3 position = in_pos + spatial_ubo.pos;
   vec4 vert = constants.cam_transform*vec4(position-constants.cam_pos, 1.0);

   out_pos = position;
   gl_Position = vert;
   out_uv = in_uv;
   out_normal = in_normal;
}
