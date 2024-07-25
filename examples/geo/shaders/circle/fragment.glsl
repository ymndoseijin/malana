#version 420 core
out vec4 FragColor;

in vec2 FragCoord;

const float feather = 0.02;
uniform float border_r;
uniform vec3 border_color;
uniform vec3 color;

void main()
{
   float r = length(FragCoord-vec2(0.5));

   vec4 border = mix(vec4(border_color, 0), vec4(border_color, 1.0), smoothstep(0.5, 0.5-feather, r));

   if (r < border_r/2) {
      FragColor = mix(border, vec4(color, 1.0), smoothstep(border_r/2, border_r/2-feather, r));
   } else if (r < 0.5) {
      FragColor = border;
   } else {
      FragColor = vec4(0.0);
   }
}
