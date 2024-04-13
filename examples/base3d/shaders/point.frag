#version 450

layout (location = 0) in vec4 color;
layout (location = 1) in vec2 uv;
layout (location = 0) out vec4 out_color;

void main() {
   vec2 pos_center = uv - vec2(0.5);
   out_color = vec4(0.0);
   if (length(pos_center) < 0.5) {
      out_color = color;
   }
}
