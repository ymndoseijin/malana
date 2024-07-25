#version 450

layout (location = 0) in vec3 in_pos;

layout (location = 2) out vec3 out_pos;

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;


layout (push_constant) uniform Constants {
   vec3 cam_pos;
   mat4 cam_transform;
} constants;

void main() {
   vec4 vert = constants.cam_transform*vec4(in_pos-constants.cam_pos, 1.0);

   out_pos = in_pos;
   gl_Position = vert;
}

