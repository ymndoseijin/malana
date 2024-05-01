#version 450

struct Particle {
   vec2 position;
   vec2 velocity;
   vec4 color;
};

layout (binding = 0) uniform UBO {
   float zoom;
   vec2 offset;
} ubo;

layout (location = 0) in vec2 pos;
layout (location = 1) in vec2 in_velocity;
layout (location = 0) out vec2 out_velocity;

void main() {
   out_velocity = in_velocity;

   gl_PointSize = 1.0;
   gl_Position = vec4((pos - ubo.offset) / ubo.zoom, 1.0, 1.0);
}
