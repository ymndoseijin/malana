#version 450

struct Particle {
   vec2 position;
   vec2 velocity;
   vec4 color;
};

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;
layout(std140, binding = 1) readonly buffer ParticleBuffer {
   Particle particles[];
};

layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec2 in_uv;
layout (location = 0) out vec4 color;
layout (location = 1) out vec2 uv;

void main() {
   Particle p = particles[uint(gl_InstanceIndex)];
   vec3 adjusted = in_pos * vec3(vec2(100/global_ubo.in_resolution), 1.0);
   vec3 pos = adjusted + vec3(p.position, 0.0);
   vec4 vert = vec4(pos, 1.0);

   color = p.color;
   uv = in_uv;
   gl_Position = vert;
}
