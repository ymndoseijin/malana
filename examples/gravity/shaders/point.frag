#version 450

layout (location = 0) in vec2 velocity;
layout (location = 0) out vec4 out_color;

void main() {
   vec3 res = vec3(normalize(velocity), pow(abs(velocity), vec2(1 / 2.2)));
   out_color = vec4(res, 1.0);
}
